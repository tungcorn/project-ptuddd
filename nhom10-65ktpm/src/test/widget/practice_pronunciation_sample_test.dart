import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/player/presentation/player_controller.dart';
import 'package:singlearn/features/practice/presentation/pronunciation_screen.dart';
import 'package:singlearn/features/practice/presentation/speech_recognizer.dart';
import 'package:singlearn/features/progress/data/progress_service.dart';

import '../helpers.dart' show FakeRemote;
import 'harness.dart';

const _uid = 'm3-sample-test';
const _songId = 'silent-night';
const _route = '/pronunciation';

class _PendingSeek {
  _PendingSeek(this.position);

  final Duration position;
  final acknowledgement = Completer<void>();
}

/// Move/emit the position first, then hold the native acknowledgement. Tests
/// assert that acknowledgement is still pending before changing/leaving UI.
class _Audio extends FakeAudioEngine {
  final seeks = <_PendingSeek>[];

  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);
    final pending = _PendingSeek(position);
    seeks.add(pending);
    await pending.acknowledgement.future;
  }

  void releaseAll() {
    for (final seek in seeks) {
      if (!seek.acknowledgement.isCompleted) seek.acknowledgement.complete();
    }
  }
}

typedef _Callbacks = ({
  void Function(SpeechHeard) result,
  void Function() done,
});

/// No platform permission or speech calls, including when providers dispose.
class _Recognizer implements SpeechRecognizer {
  int permissionRequests = 0;
  final sessions = <_Callbacks>[];

  @override
  Future<MicPermission> ensurePermission() async {
    permissionRequests++;
    return MicPermission.granted;
  }

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> listen({
    required void Function(SpeechHeard) onResult,
    required void Function(SpeechFailure) onError,
    required void Function() onDone,
  }) async {
    sessions.add((result: onResult, done: onDone));
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class _Fixture {
  _Fixture(
    this.container,
    this.audio,
    this.recognizer,
    this.store,
    this.events,
    this.remote,
  );

  final ProviderContainer container;
  final _Audio audio;
  final _Recognizer recognizer;
  final LocalStore store;
  final List<LearningEvent> events;
  final FakeRemote remote;

  PlayerState get player => container.read(playerControllerProvider);

  List<LearningEvent> get scores => events
      .where((event) => event.type == LearningEventType.pronunciationScored)
      .toList();
}

Future<_Fixture> _pump(WidgetTester tester) async {
  final app = await TestApp.create();
  final audio = _Audio();
  final recognizer = _Recognizer();
  final remote = FakeRemote()..online = false;
  final sync = SyncService(app.store, remote, account: () => _uid);
  final container = ProviderContainer(
    overrides: [
      // Replace the existing override rather than overriding audio twice.
      ...app.overrides.where((value) => value.origin != audioEngineProvider),
      audioEngineProvider.overrideWithValue(audio),
      speechRecognizerProvider.overrideWithValue(recognizer),
      uidProvider.overrideWithValue(_uid),
      syncServiceProvider.overrideWithValue(sync),
    ],
  );
  final events = <LearningEvent>[];
  final subscription = container.read(eventBusProvider).stream.listen(events.add);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    // Let every old continuation finish while its controller still exists.
    audio.releaseAll();
    await tester.pump();
    await subscription.cancel();
    container.dispose();
    await app.dispose();
  });

  await tester.runAsync(() async {
    // Settle the auth stream before a test reads progressServiceProvider,
    // so its initial loading transition cannot replace the observed service.
    await container.read(authStateProvider.future);
    await app.store.get('downloads', '_');
    await container.read(songRepositoryProvider).allSongs();
    await container.read(songProgressRepositoryProvider).all();
    await container.read(vocabularyRepositoryProvider).words();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: const Scaffold(body: Text('Practice test host')),
        initialRoute: _route,
        routes: {
          _route: (_) => const PronunciationScreen(
            songId: _songId,
            initialLine: 2,
          ),
        },
      ),
    ),
  );
  await settleIo(tester);
  expect(container.read(playerControllerProvider).lyrics, isNotNull);
  return _Fixture(container, audio, recognizer, app.store, events, remote);
}

Future<_PendingSeek> _startSample(WidgetTester tester, _Fixture fixture) async {
  final previous = fixture.audio.seeks.length;
  await tester.tap(find.text('Nghe mẫu'));
  expect(
    await settleUntil(tester, () => fixture.audio.seeks.length == previous + 1),
    isTrue,
    reason: 'The UI must reach seek before the cancellation action',
  );
  final pending = fixture.audio.seeks.last;
  expect(pending.acknowledgement.isCompleted, isFalse);
  return pending;
}

void _expectTarget(WidgetTester tester, String sentence) {
  // Inspect the visible target card; the sentence list can be outside the
  // viewport/cache and is not evidence of the currently selected target.
  final target = find.descendant(
    of: find.byType(Card).first,
    matching: find.text(sentence),
  );
  expect(target, findsOneWidget);
}

void main() {
  testWidgets('changing line cancels a pending sample and permits a new one', (
    tester,
  ) async {
    final fixture = await _pump(tester);
    final old = await _startSample(tester, fixture);
    expect(old.position, fixture.player.lyrics!.lines[2].start);
    _expectTarget(tester, 'All is calm,');

    await tester.tap(find.byTooltip('Câu sau'));
    await tester.pump();
    final nextLine = fixture.player.lyrics!.lines[3];
    _expectTarget(tester, nextLine.en);
    expect(old.acknowledgement.isCompleted, isFalse);

    old.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.audio.log.where((entry) => entry == 'play'), isEmpty);
    expect(fixture.player.playing, isFalse);
    _expectTarget(tester, nextLine.en);
    expect(fixture.scores, isEmpty);
    expect(fixture.recognizer.permissionRequests, 0);

    // Positive control: cancellation must not disable the next valid sample.
    final fresh = await _startSample(tester, fixture);
    expect(fresh.position, nextLine.start);
    fresh.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.audio.log.where((entry) => entry == 'play'), hasLength(1));
    expect(fixture.player.playing, isTrue);
    expect(fixture.player.position, nextLine.start);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Back while seek is pending cannot resume the exited sample', (
    tester,
  ) async {
    final fixture = await _pump(tester);
    final pending = await _startSample(tester, fixture);

    await tester.pageBack();
    await settleIo(tester, rounds: 8);
    expect(find.byType(PronunciationScreen), findsNothing);
    expect(find.text('Practice test host'), findsOneWidget);
    expect(pending.acknowledgement.isCompleted, isFalse);
    fixture.audio.log.clear();

    pending.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.audio.log, isNot(contains('play')));
    expect(fixture.player.playing, isFalse);
    expect(find.byType(PronunciationScreen), findsNothing);
    expect(fixture.scores, isEmpty);
    expect(fixture.recognizer.permissionRequests, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late old seek cannot replace a sample for the new UI line', (
    tester,
  ) async {
    final fixture = await _pump(tester);
    final old = await _startSample(tester, fixture);
    await tester.tap(find.byTooltip('Câu sau'));
    await tester.pump();
    final nextLine = fixture.player.lyrics!.lines[3];
    final fresh = await _startSample(tester, fixture);
    expect(old.acknowledgement.isCompleted, isFalse);
    expect(fresh.position, nextLine.start);

    fresh.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.player.playing, isTrue);
    expect(fixture.player.position, nextLine.start);

    old.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.audio.log.where((entry) => entry == 'play'), hasLength(1));
    expect(fixture.player.position, nextLine.start);
    _expectTarget(tester, nextLine.en);
    expect(fixture.scores, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('microphone cancels a pending sample and result replay earns once', (
    tester,
  ) async {
    final fixture = await _pump(tester);
    // Exercise the existing provider's event-bus subscription, not a second
    // test-only implementation of the UI -> ProgressService wiring.
    final progress = fixture.container.read(progressServiceProvider);
    final awards = <XpAward>[];
    final subscription = progress.awards.listen(awards.add);
    addTearDown(subscription.cancel);
    final bus = fixture.container.read(eventBusProvider);

    final pending = await _startSample(tester, fixture);
    await tester.tap(find.byKey(const Key('mic-button')));
    await settleIo(tester);
    expect(fixture.recognizer.permissionRequests, 1);
    expect(fixture.recognizer.sessions, hasLength(1));
    expect(pending.acknowledgement.isCompleted, isFalse);
    pending.acknowledgement.complete();
    await settleIo(tester);
    expect(fixture.audio.log, isNot(contains('play')));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    final session = fixture.recognizer.sessions.single;
    const result = SpeechHeard(['all is calm'], isFinal: true);
    session.result(result);
    session.done();
    session.result(result);
    expect(await settleUntil(tester, () => awards.length == 1), isTrue);
    expect(fixture.scores, hasLength(1));
    final event = fixture.scores.single;
    expect(event.uid, _uid);
    expect(event.data, {'songId': _songId, 'lineIndex': 2, 'score': 100});
    expect(event.id, startsWith('pron:$_songId:2:'));
    expect(event.id, isNot(contains(':try:')));
    expect(awards.single.xp, 5);

    // Replay the actual UI event, without reproducing its ID-generation code.
    bus.emit(event);
    await tester.pump();
    // record serializes writes: this duplicate also drains earlier bus work.
    final duplicate = await tester.runAsync(() => progress.record(event));
    expect(duplicate, isNull);
    await tester.pump();
    final snapshot = await tester.runAsync(() => progress.snapshot());
    final pendingOps = await tester.runAsync(
      () => fixture.store.values(SyncService.pendingBox),
    );
    expect(snapshot!.totalXp, 5);
    expect(awards, hasLength(1));
    expect(
      pendingOps!.where(
        (op) => op['path'] == 'users/$_uid/xpEvents/${event.id}',
      ),
      hasLength(1),
    );
    expect(fixture.remote.writes, 0);
    expect(find.byKey(const Key('pron-score')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('pron-score'))).data, '100');
    expect(tester.takeException(), isNull);
  });
}
