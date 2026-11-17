import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/practice/presentation/pronunciation_screen.dart';
import 'package:singlearn/features/practice/presentation/speech_recognizer.dart';

import 'harness.dart';

const songId = 'silent-night';

/// Recognizer that "hears" [transcripts] as soon as listening starts.
class FakeSpeechRecognizer implements SpeechRecognizer {
  FakeSpeechRecognizer({
    this.permission = MicPermission.granted,
    this.available = true,
    this.transcripts = const [],
    this.failure,
  });

  MicPermission permission;
  bool available;
  List<String> transcripts;
  SpeechFailure? failure;
  int permissionRequests = 0;
  bool openedSettings = false;

  @override
  Future<MicPermission> ensurePermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<void> openSettings() async => openedSettings = true;

  @override
  Future<bool> initialize() async => available;

  @override
  Future<void> listen({
    required void Function(SpeechHeard heard) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    if (failure != null) {
      onError(failure!);
      return;
    }
    onResult(SpeechHeard(transcripts, isFinal: true));
    onDone();
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<ProviderContainer> pump(WidgetTester tester, SpeechRecognizer recognizer) async {
    final container = ProviderContainer(overrides: [
      ...app.overrides,
      speechRecognizerProvider.overrideWithValue(recognizer),
    ]);
    addTearDown(container.dispose);
    // Open/seed Hive boxes in the real zone: opening or first-writing a box
    // inside fake async never completes and blocks Hive.close in tearDown.
    await tester.runAsync(() async {
      await app.store.get('downloads', '_');
      await container.read(songRepositoryProvider).allSongs();
      await container.read(songProgressRepositoryProvider).all();
      await container.read(vocabularyRepositoryProvider).words();
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const PronunciationScreen(songId: songId, initialLine: 2),
      ),
    ));
    await settleIo(tester);
    return container;
  }

  testWidgets('exact sentence scores 100 and is recorded', (tester) async {
    final rec = FakeSpeechRecognizer(transcripts: ['all is calm']);
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);

    expect(find.text('All is calm,'), findsWidgets);
    expect(find.textContaining('không chấm cao độ/nhịp'), findsOneWidget);

    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);

    expect(rec.permissionRequests, 1);
    expect(find.byKey(const Key('pron-score')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pron-score'))).data, '100');
    expect(find.text('Xuất sắc'), findsOneWidget);
    expect(find.byKey(const Key('marked-sentence')), findsOneWidget);

    final scored = events.where((e) => e.type == LearningEventType.pronunciationScored).single;
    expect(scored.id, startsWith('pron:$songId:2:'));
    expect(scored.id, isNot(contains(':try:')));
    expect(scored.data['score'], 100);

    final progress = (await tester.runAsync(
        () => container.read(songProgressRepositoryProvider).get(songId)))!;
    expect(progress.lineBestScores[2], 100);
    await settleIo(tester);
    expect(find.byKey(const Key('line-best')), findsOneWidget);
    await closeStore(tester, app);
  });

  testWidgets('low score is recorded as a try (no daily XP key)', (tester) async {
    final rec = FakeSpeechRecognizer(transcripts: ['hello']);
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);

    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);
    final scored = events.where((e) => e.type == LearningEventType.pronunciationScored).single;
    expect(scored.id, contains(':try:'));
    expect(find.text('Chưa đúng'), findsOneWidget);
    await closeStore(tester, app);
  });

  testWidgets('denied microphone shows the explanation and settings link', (tester) async {
    final rec = FakeSpeechRecognizer(permission: MicPermission.permanentlyDenied);
    await pump(tester, rec);

    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);

    expect(find.byKey(const Key('mic-permission-view')), findsOneWidget);
    expect(find.text('Cần quyền sử dụng micro'), findsOneWidget);
    await tester.ensureVisible(find.text('Mở cài đặt'));
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pump();
    expect(rec.openedSettings, isTrue);

    // After granting in settings, "Thử lại" works.
    rec
      ..permission = MicPermission.granted
      ..transcripts = ['all is calm'];
    await tester.tap(find.text('Thử lại'));
    await settleIo(tester);
    expect(find.byKey(const Key('pron-score')), findsOneWidget);
    await closeStore(tester, app);
  });

  testWidgets('no speech and unavailable recognizer are explained', (tester) async {
    final rec = FakeSpeechRecognizer(failure: SpeechFailure.noSpeech);
    await pump(tester, rec);
    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);
    expect(find.text('Không nghe thấy giọng nói'), findsOneWidget);

    rec.available = false;
    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);
    expect(find.text('Thiết bị không hỗ trợ nhận dạng giọng nói'), findsOneWidget);
    await closeStore(tester, app);
  });
}

/// Hive writes started by the screen run inside fake async and only finish
/// while the test pumps, so the store is closed here (tearDown would hang).
Future<void> closeStore(WidgetTester tester, TestApp app) async {
  await tester.pumpWidget(const SizedBox());
  var closed = false;
  app.store.close().then((_) => closed = true);
  for (var i = 0; i < 40 && !closed; i++) {
    await settleIo(tester, rounds: 1);
  }
  expect(closed, isTrue, reason: 'Hive boxes closed');
}
