import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/features/player/presentation/player_controller.dart';
import 'package:singlearn/features/songs/domain/song.dart';

import '../widget/harness.dart' show FakeAudioEngine, MemoryLocalStore;

/// Applies the seek and emits its position immediately, but lets tests delay
/// the platform acknowledgement independently of newer playback events.
class _DelayedSeekEngine extends FakeAudioEngine {
  bool delaySeeks = false;
  final pendingSeeks = <Completer<void>>[];

  @override
  Future<void> seek(Duration position) async {
    await super.seek(position);
    if (delaySeeks) {
      final pending = Completer<void>();
      pendingSeeks.add(pending);
      await pending.future;
    }
  }
}

Song _song(String id) => Song(
  id: id,
  title: id,
  artist: 'Test fixture',
  level: 'A1',
  topics: const [],
  genre: 'folk',
  durationMs: 60000,
  audio: 'assets/audio/$id.mp3',
  lrcText:
      '[00:00.00]First line\n[00:10.00]Second line\n'
      '[00:30.00]Third line',
);

void main() {
  late _DelayedSeekEngine audio;
  late ProviderContainer container;
  late PlayerController player;
  late bool disposed;

  setUp(() async {
    disposed = false;
    audio = _DelayedSeekEngine();
    container = ProviderContainer(
      overrides: [
        localStoreProvider.overrideWithValue(MemoryLocalStore()),
        audioEngineProvider.overrideWithValue(audio),
        uidProvider.overrideWithValue('player-test'),
      ],
    );
    player = container.read(playerControllerProvider.notifier);
    await player.open(_song('first'));
  });

  tearDown(() async {
    // Drain released continuations before disposing their providers.
    for (final pending in audio.pendingSeeks) {
      if (!pending.isCompleted) pending.complete();
    }
    await pumpEventQueue();
    if (!disposed) container.dispose();
  });

  PlayerState state() => container.read(playerControllerProvider);

  test('play/pause toggles do not reload the current song', () async {
    audio.log.clear();
    await player.togglePlay();
    expect(state().playing, isTrue);
    await player.togglePlay();
    expect(state().playing, isFalse);
    expect(audio.log, ['play', 'pause']);
  });

  test('current segment waits for seek, then plays and ends once', () async {
    audio.delaySeeks = true;
    audio.log.clear();
    var ended = 0;
    final segment = player.playSegment(
      const Duration(seconds: 15),
      const Duration(seconds: 20),
      onEnd: () => ended++,
    );
    await pumpEventQueue();
    expect(audio.log, ['seek:15000']);
    expect(state().playing, isFalse);

    audio.pendingSeeks.single.complete();
    await segment;
    await pumpEventQueue();
    expect(audio.log, ['seek:15000', 'play']);
    expect(state().playing, isTrue);
    expect(state().position, const Duration(seconds: 15));

    audio.advance(const Duration(seconds: 6));
    await pumpEventQueue();
    expect(state().playing, isFalse);
    expect(ended, 1);
    audio.delaySeeks = false;
    await audio.seek(const Duration(seconds: 22));
    await pumpEventQueue();
    expect(ended, 1);
  });

  test(
    'cancel during segment seek cannot resume playback or call onEnd',
    () async {
      audio.delaySeeks = true;
      audio.log.clear();
      var ended = 0;
      final segment = player.playLine(1, onEnd: () => ended++);
      await pumpEventQueue();

      player.cancelSegment();
      await player.pause();
      audio.pendingSeeks.single.complete();
      await segment;
      await pumpEventQueue();
      expect(audio.log, isNot(contains('play')));
      expect(state().playing, isFalse);

      // Cancelling a segment must not leave its endpoint on normal playback.
      await player.play();
      audio.advance(const Duration(seconds: 25));
      await pumpEventQueue();
      expect(ended, 0);
      expect(state().playing, isTrue);
    },
  );

  test(
    'a replaced segment cannot rewind, replay or run its old callback',
    () async {
      audio.delaySeeks = true;
      audio.log.clear();
      final ended = <String>[];
      final first = player.playSegment(
        const Duration(seconds: 15),
        const Duration(seconds: 20),
        onEnd: () => ended.add('first'),
      );
      await pumpEventQueue();
      final second = player.playSegment(
        const Duration(seconds: 35),
        const Duration(seconds: 40),
        onEnd: () => ended.add('second'),
      );
      await pumpEventQueue();

      audio.pendingSeeks[1].complete();
      await second;
      audio.pendingSeeks[0].complete();
      await first;
      await pumpEventQueue();
      expect(state().position, const Duration(seconds: 35));
      expect(audio.log.where((entry) => entry == 'play'), hasLength(1));
      expect(ended, isEmpty);

      audio.advance(const Duration(seconds: 6));
      await pumpEventQueue();
      expect(state().playing, isFalse);
      expect(ended, ['second']);
    },
  );

  for (final next in [_song('second'), _song('first').copyWith(updatedAt: 1)]) {
    test(
      'segment seek cannot resume after loading ${next.id}/${next.updatedAt}',
      () async {
        audio.delaySeeks = true;
        var ended = 0;
        final segment = player.playLine(1, onEnd: () => ended++);
        await pumpEventQueue();
        await player.open(next);
        audio.log.clear();

        audio.pendingSeeks.single.complete();
        await segment;
        await pumpEventQueue();
        expect(state().song!.id, next.id);
        expect(state().song!.updatedAt, next.updatedAt);
        expect(state().position, Duration.zero);
        expect(state().playing, isFalse);
        expect(audio.log, isNot(contains('play')));
        expect(ended, 0);
      },
    );
  }

  test('disposing the player abandons a pending segment seek', () async {
    audio.delaySeeks = true;
    audio.log.clear();
    final segment = player.playLine(1);
    await pumpEventQueue();
    container.dispose();
    disposed = true;
    final completion = expectLater(segment, completes);

    audio.pendingSeeks.single.complete();
    await completion;
    expect(audio.log, isNot(contains('play')));
  });

  test('seek clamps to track bounds and updates the active lyric', () async {
    await player.seek(const Duration(seconds: -2));
    expect(state().position, Duration.zero);
    expect(audio.position, Duration.zero);

    await player.seek(const Duration(seconds: 15));
    expect(state().position, const Duration(seconds: 15));
    expect(state().currentLine, 1);

    await player.seek(const Duration(seconds: 90));
    expect(state().position, const Duration(seconds: 60));
    expect(audio.position, const Duration(seconds: 60));
    expect(state().currentLine, 2);
  });

  test('late seek acknowledgement cannot undo a newer seek', () async {
    audio.delaySeeks = true;
    final first = player.seek(const Duration(seconds: 15));
    await pumpEventQueue();
    final second = player.seek(const Duration(seconds: 35));
    await pumpEventQueue();
    expect(audio.pendingSeeks, hasLength(2));

    audio.pendingSeeks[1].complete();
    await second;
    expect(state().position, const Duration(seconds: 35));
    expect(state().currentLine, 2);

    audio.pendingSeeks[0].complete();
    await first;
    expect(audio.position, const Duration(seconds: 35));
    expect(
      state().position,
      audio.position,
      reason: 'an old acknowledgement must not rewind the UI/lyrics',
    );
    expect(state().currentLine, 2);
  });

  test(
    'late seek acknowledgement cannot change the next song position',
    () async {
      audio.delaySeeks = true;
      final oldSeek = player.seek(const Duration(seconds: 35));
      await pumpEventQueue();
      expect(audio.pendingSeeks, hasLength(1));

      await player.open(_song('second'), autoplay: true);
      expect(state().song!.id, 'second');
      expect(state().position, Duration.zero);
      expect(state().playing, isTrue);

      audio.pendingSeeks.single.complete();
      await oldSeek;
      expect(audio.position, Duration.zero);
      expect(
        state().position,
        audio.position,
        reason: 'the previous song seek must not overwrite the new session',
      );
      expect(state().currentLine, 0);
      expect(state().playing, isTrue);
    },
  );

  test(
    'late seek acknowledgement is ignored after reloading a song revision',
    () async {
      audio.delaySeeks = true;
      final oldSeek = player.seek(const Duration(seconds: 35));
      await pumpEventQueue();

      await player.open(_song('first').copyWith(updatedAt: 1));
      expect(state().song!.updatedAt, 1);
      expect(state().position, Duration.zero);

      audio.pendingSeeks.single.complete();
      await oldSeek;
      expect(state().position, Duration.zero);
      expect(state().currentLine, 0);
    },
  );
}
