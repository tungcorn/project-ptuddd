import 'dart:async';

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
  int initializeRequests = 0;
  int listenRequests = 0;
  int cancelRequests = 0;
  Object? permissionError;
  Object? initializeError;
  Object? cancelError;
  Future<MicPermission>? permissionResponse;
  Future<bool>? initializeResponse;

  @override
  Future<MicPermission> ensurePermission() async {
    permissionRequests++;
    if (permissionError != null) throw permissionError!;
    if (permissionResponse != null) return await permissionResponse!;
    return permission;
  }

  @override
  Future<void> openSettings() async => openedSettings = true;

  @override
  Future<bool> initialize() async {
    initializeRequests++;
    if (initializeError != null) throw initializeError!;
    if (initializeResponse != null) return await initializeResponse!;
    return available;
  }

  @override
  Future<void> listen({
    required void Function(SpeechHeard heard) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    listenRequests++;
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
  Future<void> cancel() async {
    cancelRequests++;
    if (cancelError != null) throw cancelError!;
  }
}

typedef _SpeechCallbacks = ({
  void Function(SpeechHeard) result,
  void Function(SpeechFailure) error,
  void Function() done,
});

/// Leaves recognition running so tests can order stop and platform callbacks.
class ControlledSpeechRecognizer extends FakeSpeechRecognizer {
  final sessions = <_SpeechCallbacks>[];
  int stopRequests = 0;
  Object? stopError;
  Future<void>? stopResponse;

  @override
  Future<void> listen({
    required void Function(SpeechHeard heard) onResult,
    required void Function(SpeechFailure failure) onError,
    required void Function() onDone,
  }) async {
    listenRequests++;
    sessions.add((result: onResult, error: onError, done: onDone));
  }

  @override
  Future<void> stop() async {
    stopRequests++;
    if (stopError != null) throw stopError!;
    final response = stopResponse;
    if (response != null) await response;
  }
}

class DelayedPauseEngine extends FakeAudioEngine {
  Completer<void>? nextPause;

  @override
  Future<void> pause() async {
    final gate = nextPause;
    nextPause = null;
    if (gate != null) await gate.future;
    await super.pause();
  }
}

void main() {
  late TestApp app;

  setUp(() async => app = await TestApp.create());
  tearDown(() => app.dispose());

  Future<ProviderContainer> pump(
    WidgetTester tester,
    SpeechRecognizer recognizer, {
    FakeAudioEngine? audio,
  }) async {
    final container = ProviderContainer(overrides: [
      // Replace the harness audio override when a test needs a delayed engine.
      ...app.overrides.where(
        (override) => audio == null || override.origin != audioEngineProvider,
      ),
      if (audio != null) audioEngineProvider.overrideWithValue(audio),
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

  testWidgets('temporary permission denial never initializes and can retry', (tester) async {
    final rec = FakeSpeechRecognizer(permission: MicPermission.denied);
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(find.byKey(const Key('mic-permission-view')), findsOneWidget);
    expect(rec.initializeRequests, 0);
    expect(rec.listenRequests, 0);
    expect(events, isEmpty);

    rec
      ..permission = MicPermission.granted
      ..transcripts = ['all is calm'];
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await settleIo(tester);
    expect(rec.permissionRequests, 2);
    expect(find.byKey(const Key('pron-score')), findsOneWidget);
    await closeStore(tester, app);
  });

  for (final step in ['permission', 'initialize']) {
    testWidgets('$step exception leaves preparation and allows retry', (tester) async {
      final rec = FakeSpeechRecognizer(transcripts: ['all is calm']);
      if (step == 'permission') {
        rec.permissionError = StateError('permission channel failed');
      } else {
        rec.initializeError = StateError('speech channel failed');
      }
      final container = await pump(tester, rec);
      final events = <LearningEvent>[];
      final sub = container.read(eventBusProvider).stream.listen(events.add);
      addTearDown(sub.cancel);

      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Nhận dạng giọng nói gặp lỗi'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(rec.listenRequests, 0);
      expect(events, isEmpty);

      rec
        ..permissionError = null
        ..initializeError = null;
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await settleIo(tester);
      expect(find.byKey(const Key('pron-score')), findsOneWidget);
      expect(events.where((e) => e.type == LearningEventType.pronunciationScored), hasLength(1));
      await closeStore(tester, app);
    });

    testWidgets('$step timeout ignores a late response after retry', (tester) async {
      final permission = Completer<MicPermission>();
      final initialization = Completer<bool>();
      final rec = FakeSpeechRecognizer(transcripts: ['all is calm']);
      if (step == 'permission') {
        rec.permissionResponse = permission.future;
      } else {
        rec.initializeResponse = initialization.future;
      }
      final container = await pump(tester, rec);
      final events = <LearningEvent>[];
      final sub = container.read(eventBusProvider).stream.listen(events.add);
      addTearDown(sub.cancel);

      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Chuẩn bị micro quá lâu'), findsOneWidget);
      expect(rec.cancelRequests, 1);
      expect(events, isEmpty);

      rec
        ..permissionResponse = null
        ..initializeResponse = null;
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await settleIo(tester);
      expect(rec.listenRequests, 1);
      expect(find.byKey(const Key('pron-score')), findsOneWidget);

      permission.complete(MicPermission.granted);
      initialization.complete(true);
      await tester.pump();
      expect(rec.listenRequests, 1);
      expect(events.where((e) => e.type == LearningEventType.pronunciationScored), hasLength(1));
      expect(tester.takeException(), isNull);
      await closeStore(tester, app);
    });

    for (final leave in [false, true]) {
      testWidgets('$step response after ${leave ? 'exit' : 'line change'} cannot start listening', (tester) async {
        final permission = Completer<MicPermission>();
        final initialization = Completer<bool>();
        final rec = FakeSpeechRecognizer();
        if (step == 'permission') {
          rec.permissionResponse = permission.future;
        } else {
          rec.initializeResponse = initialization.future;
        }
        final container = await pump(tester, rec);
        final events = <LearningEvent>[];
        final sub = container.read(eventBusProvider).stream.listen(events.add);
        addTearDown(sub.cancel);

        await tester.tap(find.byKey(const Key('mic-button')));
        await tester.pump();
        if (leave) {
          await tester.pumpWidget(const SizedBox());
        } else {
          await tester.tap(find.byTooltip('Câu sau'));
          await tester.pump();
        }
        expect(rec.cancelRequests, 1);

        permission.complete(MicPermission.granted);
        initialization.complete(true);
        await tester.pump();
        expect(rec.listenRequests, 0);
        if (step == 'permission') expect(rec.initializeRequests, 0);
        expect(events, isEmpty);
        expect(tester.takeException(), isNull);
        // Leaving also cancels the watchdog, so no stale timeout changes UI.
        await tester.pump(const Duration(seconds: 31));
        expect(find.text('Nhận dạng giọng nói gặp lỗi'), findsNothing);
        expect(find.text('Chuẩn bị micro quá lâu'), findsNothing);
        await closeStore(tester, app);
      });
    }
  }

  testWidgets('exit during player pause cannot request microphone later', (tester) async {
    final audio = DelayedPauseEngine();
    final rec = FakeSpeechRecognizer();
    await pump(tester, rec, audio: audio);
    final pause = Completer<void>();
    audio.nextPause = pause;
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(rec.permissionRequests, 0);

    await tester.pumpWidget(const SizedBox());
    pause.complete();
    await tester.pump();
    expect(rec.cancelRequests, 1);
    expect(rec.permissionRequests, 0);
    expect(rec.listenRequests, 0);
    expect(tester.takeException(), isNull);
    await closeStore(tester, app);
  });

  testWidgets('late old permission does not cancel the new preparation timeout', (tester) async {
    final permission = Completer<MicPermission>();
    final initialization = Completer<bool>();
    final rec = FakeSpeechRecognizer()..permissionResponse = permission.future;
    await pump(tester, rec);
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    rec
      ..permissionResponse = null
      ..initializeResponse = initialization.future;
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(rec.permissionRequests, 2);
    expect(rec.initializeRequests, 1);
    // Retry is below the microphone in a lazy ListView. Scroll back before
    // asserting its spinner; an offscreen child may no longer be built.
    await tester.scrollUntilVisible(
      find.byKey(const Key('mic-button')),
      -200,
      duration: Duration.zero,
    );
    permission.complete(MicPermission.granted);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pump(const Duration(seconds: 29));
    expect(find.text('Chuẩn bị micro quá lâu'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Chuẩn bị micro quá lâu'), findsOneWidget);
    expect(rec.cancelRequests, 2);
    initialization.complete(true);
    await tester.pump();
    expect(rec.listenRequests, 0);
    await closeStore(tester, app);
  });

  testWidgets('stop failure is explained, rejects old results and can retry', (tester) async {
    final rec = ControlledSpeechRecognizer()
      ..stopError = StateError('stop channel failed');
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    final old = rec.sessions.single;
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Nhận dạng giọng nói gặp lỗi'), findsOneWidget);
    expect(rec.stopRequests, 1);
    expect(rec.cancelRequests, 1);

    old.result(const SpeechHeard(['all is calm'], isFinal: true));
    old.done();
    await tester.pump();
    expect(events, isEmpty);
    expect(find.byKey(const Key('pron-score')), findsNothing);

    rec.stopError = null;
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(rec.listenRequests, 2);
    rec.sessions.last.result(const SpeechHeard(['all is calm'], isFinal: true));
    rec.sessions.last.done();
    await settleIo(tester);
    expect(find.byKey(const Key('pron-score')), findsOneWidget);
    expect(events.where((e) => e.type == LearningEventType.pronunciationScored), hasLength(1));
    await closeStore(tester, app);
  });

  testWidgets('pending stop disables controls and grades collected speech once', (tester) async {
    final stopped = Completer<void>();
    final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
    });

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    rec.sessions.single.result(const SpeechHeard(['all is calm'], isFinal: false));
    await tester.pump();
    // Both taps reach the same frame; the phase guard must reject the second.
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(rec.stopRequests, 1);
    expect(find.text('Đang dừng nhận dạng…'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('mic-button'))).onPressed, isNull);
    final sampleButton = find.ancestor(
      of: find.text('Nghe mẫu'),
      matching: find.byWidgetPredicate((widget) => widget is OutlinedButton),
    );
    expect(tester.widget<OutlinedButton>(sampleButton).onPressed, isNull);
    expect(events, isEmpty);

    stopped.complete();
    await settleIo(tester);
    expect(tester.widget<Text>(find.byKey(const Key('pron-score'))).data, '100');
    rec.sessions.single.done();
    rec.sessions.single.result(const SpeechHeard(['all is calm'], isFinal: true));
    await tester.pump();
    expect(events.where((e) => e.type == LearningEventType.pronunciationScored), hasLength(1));
    expect(tester.takeException(), isNull);
    await closeStore(tester, app);
  });

  testWidgets('final result during stop survives a late stop error', (tester) async {
    final stopped = Completer<void>();
    final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
    });

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    rec.sessions.single.result(const SpeechHeard(['all is calm'], isFinal: true));
    rec.sessions.single.done();
    await settleIo(tester);
    stopped.completeError(StateError('late stop error'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(tester.widget<Text>(find.byKey(const Key('pron-score'))).data, '100');
    expect(find.text('Nhận dạng giọng nói gặp lỗi'), findsNothing);
    expect(rec.cancelRequests, 0);
    expect(events.where((e) => e.type == LearningEventType.pronunciationScored), hasLength(1));
    await closeStore(tester, app);
  });

  testWidgets('stop without speech allows retry without recording a score', (tester) async {
    final rec = ControlledSpeechRecognizer();
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(find.text('Không nghe thấy giọng nói'), findsOneWidget);
    expect(events, isEmpty);
    await tester.ensureVisible(find.text('Thử lại'));
    await tester.tap(find.text('Thử lại'));
    await tester.pump();
    expect(rec.listenRequests, 2);
    await closeStore(tester, app);
  });

  testWidgets('old stop error and callbacks cannot affect a new line session', (tester) async {
    final stopped = Completer<void>();
    final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
    });

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    final old = rec.sessions.single;
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.tap(find.byTooltip('Câu sau'));
    await tester.pump();
    expect(rec.cancelRequests, 1);
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(rec.listenRequests, 2);

    stopped.completeError(StateError('old stop error'));
    old.result(const SpeechHeard(['all is calm'], isFinal: true));
    old.error(SpeechFailure.other);
    old.done();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Đang nghe… hãy nói ngay'), findsOneWidget);
    expect(events, isEmpty);
    rec.sessions.last.result(const SpeechHeard(['new line'], isFinal: true));
    await settleIo(tester);
    final scored = events.where((e) => e.type == LearningEventType.pronunciationScored).single;
    expect(scored.data['lineIndex'], 3);
    await closeStore(tester, app);
  });

  testWidgets('stop error after leaving the screen is contained', (tester) async {
    final stopped = Completer<void>();
    final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
    final container = await pump(tester, rec);
    final events = <LearningEvent>[];
    final sub = container.read(eventBusProvider).stream.listen(events.add);
    addTearDown(sub.cancel);
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
    });

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    stopped.completeError(StateError('stop error after exit'));
    rec.sessions.single.result(const SpeechHeard(['all is calm'], isFinal: true));
    rec.sessions.single.done();
    await tester.pump();
    expect(rec.cancelRequests, 1);
    expect(events, isEmpty);
    expect(tester.takeException(), isNull);
    await closeStore(tester, app);
  });

  testWidgets('sample plays only after stop completes for the current line', (tester) async {
    final stopped = Completer<void>();
    final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
    await pump(tester, rec);
    addTearDown(() {
      if (!stopped.isCompleted) stopped.complete();
    });

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    app.audio.log.clear();
    await tester.tap(find.text('Nghe mẫu'));
    await tester.pump();
    expect(rec.stopRequests, 1);
    expect(app.audio.log, isEmpty);

    stopped.complete();
    await settleIo(tester);
    expect(app.audio.log.where((s) => s.startsWith('seek:')), hasLength(1));
    expect(app.audio.log.where((s) => s == 'play'), hasLength(1));
    expect(rec.cancelRequests, 0);
    expect(tester.takeException(), isNull);
    await closeStore(tester, app);
  });

  for (final interruption in ['failure', 'line change', 'exit']) {
    testWidgets('sample playback is abandoned after stop $interruption', (tester) async {
      final stopped = Completer<void>();
      final rec = ControlledSpeechRecognizer()..stopResponse = stopped.future;
      await pump(tester, rec);
      addTearDown(() {
        if (!stopped.isCompleted) stopped.complete();
      });
      await tester.tap(find.byKey(const Key('mic-button')));
      await tester.pump();
      app.audio.log.clear();
      await tester.tap(find.text('Nghe mẫu'));
      await tester.pump();
      expect(rec.stopRequests, 1);
      if (interruption == 'line change') {
        await tester.tap(find.byTooltip('Câu sau'));
        await tester.pump();
      } else if (interruption == 'exit') {
        await tester.pumpWidget(const SizedBox());
      }
      if (interruption == 'failure') {
        stopped.completeError(StateError('sample stop failed'));
      } else {
        stopped.complete();
      }
      await settleIo(tester);
      expect(tester.takeException(), isNull);
      expect(app.audio.log.where((s) => s.startsWith('seek:') || s == 'play'), isEmpty);
      expect(rec.cancelRequests, 1);
      await closeStore(tester, app);
    });
  }

  testWidgets('cleanup failure while leaving preparation is contained', (tester) async {
    final permission = Completer<MicPermission>();
    final rec = FakeSpeechRecognizer()
      ..permissionResponse = permission.future
      ..cancelError = StateError('cancel channel failed');
    await pump(tester, rec);
    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    permission.complete(MicPermission.granted);
    await tester.pump();
    expect(rec.cancelRequests, 1);
    expect(rec.listenRequests, 0);
    expect(tester.takeException(), isNull);
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
