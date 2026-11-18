import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/events/app_event_bus.dart';
import '../../../core/providers.dart';
import '../../songs/domain/lrc_parser.dart';
import '../../songs/domain/song.dart';

/// Player state shared by the player screen, mini player and exercises.
class PlayerState {
  const PlayerState({
    this.song,
    this.lyrics,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.playing = false,
    this.loading = false,
    this.speed = 1.0,
    this.loopLine,
    this.loopA,
    this.loopB,
    this.error,
  });

  final Song? song;
  final SongLyrics? lyrics;
  final Duration position;
  final Duration duration;
  final bool playing;
  final bool loading;
  final double speed;

  /// Index of the line being repeated, if "repeat line" is on.
  final int? loopLine;

  /// A–B loop markers.
  final Duration? loopA;
  final Duration? loopB;
  final String? error;

  int get currentLine => lyrics == null
      ? -1
      : LrcParser.activeIndex(lyrics!.starts, position);

  bool get hasAbLoop => loopA != null && loopB != null;

  PlayerState copyWith({
    Song? song,
    SongLyrics? lyrics,
    Duration? position,
    Duration? duration,
    bool? playing,
    bool? loading,
    double? speed,
    int? Function()? loopLine,
    Duration? Function()? loopA,
    Duration? Function()? loopB,
    String? Function()? error,
  }) =>
      PlayerState(
        song: song ?? this.song,
        lyrics: lyrics ?? this.lyrics,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        playing: playing ?? this.playing,
        loading: loading ?? this.loading,
        speed: speed ?? this.speed,
        loopLine: loopLine != null ? loopLine() : this.loopLine,
        loopA: loopA != null ? loopA() : this.loopA,
        loopB: loopB != null ? loopB() : this.loopB,
        error: error != null ? error() : this.error,
      );
}

/// Playback logic (M1): loading songs, lyric sync, seek by line, speed,
/// repeat-one-line, A–B loop, segment playback for exercises, and listening
/// time reporting to the progress module.
class PlayerController extends Notifier<PlayerState> {
  final _subs = <StreamSubscription<dynamic>>[];

  /// When set, playback pauses once the position reaches this point
  /// (exercises: "pause after each line"), then [_onSegmentEnd] runs.
  Duration? _stopAt;
  void Function()? _onSegmentEnd;

  // Listening-time tracking.
  DateTime? _playStartedAt;
  int _listenedMs = 0;
  bool _completed = false;
  int _session = 0;
  int _seekRequest = 0;

  @override
  PlayerState build() {
    final engine = ref.watch(audioEngineProvider);
    _subs
      ..add(engine.positionStream.listen(_onPosition))
      ..add(engine.playingStream.listen(_onPlaying))
      ..add(engine.durationStream.listen((d) {
        if (d != null) state = state.copyWith(duration: d);
      }))
      ..add(engine.completedStream.listen((_) {
        _completed = true;
        _flushListening();
        engine.pause();
        engine.seek(Duration.zero);
      }));
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
    });
    return const PlayerState();
  }

  void _onPlaying(bool playing) {
    if (playing) {
      _playStartedAt ??= DateTime.now();
    } else if (_playStartedAt != null) {
      _listenedMs += DateTime.now().difference(_playStartedAt!).inMilliseconds;
      _playStartedAt = null;
    }
    state = state.copyWith(playing: playing);
  }

  void _onPosition(Duration pos) {
    final engine = ref.read(audioEngineProvider);
    final stopAt = _stopAt;
    if (stopAt != null && pos >= stopAt) {
      _stopAt = null;
      engine.pause();
      final cb = _onSegmentEnd;
      _onSegmentEnd = null;
      state = state.copyWith(position: pos);
      cb?.call();
      return;
    }
    final lyrics = state.lyrics;
    final loopLine = state.loopLine;
    if (lyrics != null && loopLine != null && loopLine < lyrics.lines.length) {
      final line = lyrics.lines[loopLine];
      if (pos >= line.end || pos < line.start - const Duration(milliseconds: 300)) {
        engine.seek(line.start);
        state = state.copyWith(position: line.start);
        return;
      }
    }
    if (state.hasAbLoop && pos >= state.loopB!) {
      engine.seek(state.loopA!);
      state = state.copyWith(position: state.loopA);
      return;
    }
    state = state.copyWith(position: pos);
  }

  /// Opens [song] (no-op if already loaded). Uses the downloaded file when
  /// the song was saved for offline listening.
  Future<void> open(Song song, {bool autoplay = false}) async {
    if (state.song?.id == song.id && state.song?.updatedAt == song.updatedAt && state.error == null) {
      if (autoplay) await play();
      return;
    }
    _flushListening();
    _stopAt = null;
    _onSegmentEnd = null;
    final session = ++_session;
    // Stop the previous song right away so it does not keep playing while
    // the new one loads.
    final engine = ref.read(audioEngineProvider);
    state = PlayerState(song: song, loading: true, speed: state.speed);
    try {
      await engine.pause();
    } catch (_) {}
    try {
      final lyrics = await ref.read(songRepositoryProvider).lyrics(song);
      final local = await ref.read(downloadServiceProvider).localPath(song.id);
      if (session != _session) return;
      final duration = await engine.load(
        id: song.id,
        source: local ?? song.audio,
        title: song.title,
        artist: song.artist,
        coverAsset: song.cover,
      );
      await engine.setSpeed(state.speed);
      if (session != _session) return;
      state = state.copyWith(
        lyrics: lyrics,
        loading: false,
        duration: duration ?? song.duration,
      );
      if (autoplay) await play();
    } catch (e) {
      if (session != _session) return;
      state = state.copyWith(
        loading: false,
        error: () => 'Không phát được bài hát. Kiểm tra kết nối mạng hoặc tệp nhạc. ($e)',
      );
    }
  }

  Future<void> play() => ref.read(audioEngineProvider).play();

  Future<void> pause() => ref.read(audioEngineProvider).pause();

  Future<void> togglePlay() => state.playing ? pause() : play();

  Future<void> seek(Duration to) async {
    final session = _session;
    final request = ++_seekRequest;
    final clamped = to < Duration.zero
        ? Duration.zero
        : (state.duration > Duration.zero && to > state.duration ? state.duration : to);
    await ref.read(audioEngineProvider).seek(clamped);
    // Platform acknowledgements can arrive after another seek or track load.
    // Only the current request may update this session's UI/lyric position.
    if (session != _session || request != _seekRequest) return;
    state = state.copyWith(position: clamped);
  }

  /// Tap on a lyric line: jump to it (and move the repeat-line loop there).
  Future<void> seekToLine(int index) async {
    final lyrics = state.lyrics;
    if (lyrics == null || index < 0 || index >= lyrics.lines.length) return;
    if (state.loopLine != null) state = state.copyWith(loopLine: () => index);
    await seek(lyrics.lines[index].start);
  }

  Future<void> setSpeed(double speed) async {
    await ref.read(audioEngineProvider).setSpeed(speed);
    state = state.copyWith(speed: speed);
  }

  /// Repeat the current line on/off.
  void toggleLoopLine() {
    if (state.loopLine != null) {
      state = state.copyWith(loopLine: () => null);
    } else {
      final idx = state.currentLine < 0 ? 0 : state.currentLine;
      state = state.copyWith(loopLine: () => idx, loopA: () => null, loopB: () => null);
    }
  }

  /// A–B loop: first tap sets A, second sets B (must be after A), third
  /// clears. Returns a message to show the user.
  String tapAbLoop() {
    final pos = state.position;
    if (state.loopA == null) {
      state = state.copyWith(loopA: () => pos, loopLine: () => null);
      return 'Đã đặt điểm A. Nhấn lần nữa để đặt điểm B.';
    } else if (state.loopB == null) {
      if (pos <= state.loopA! + const Duration(milliseconds: 500)) {
        return 'Điểm B phải sau điểm A ít nhất 0,5 giây';
      }
      state = state.copyWith(loopB: () => pos);
      return 'Đang lặp đoạn A–B';
    } else {
      clearAbLoop();
      return 'Đã tắt lặp A–B';
    }
  }

  void clearAbLoop() =>
      state = state.copyWith(loopA: () => null, loopB: () => null);

  /// Plays [start]..[end] once and calls [onEnd] when the segment finishes.
  Future<void> playSegment(Duration start, Duration end, {void Function()? onEnd}) async {
    state = state.copyWith(loopLine: () => null, loopA: () => null, loopB: () => null);
    _stopAt = end;
    _onSegmentEnd = onEnd;
    await ref.read(audioEngineProvider).seek(start);
    state = state.copyWith(position: start);
    await play();
  }

  /// Plays one lyric line once (used by "nghe lại câu", flashcards, exercises).
  Future<void> playLine(int index, {void Function()? onEnd}) async {
    final lyrics = state.lyrics;
    if (lyrics == null || index < 0 || index >= lyrics.lines.length) return;
    final line = lyrics.lines[index];
    await playSegment(line.start, line.end, onEnd: onEnd);
  }

  void cancelSegment() {
    _stopAt = null;
    _onSegmentEnd = null;
  }

  /// Reports accumulated listening time (once per song session).
  void _flushListening() {
    if (_playStartedAt != null) {
      _listenedMs += DateTime.now().difference(_playStartedAt!).inMilliseconds;
      _playStartedAt = DateTime.now();
    }
    final song = state.song;
    final seconds = _listenedMs ~/ 1000;
    // Admin sync previews (`__preview` ids) are not learning activity.
    if (song != null && !song.id.contains('__preview') && (seconds >= 5 || _completed)) {
      final uid = ref.read(uidProvider);
      ref.read(eventBusProvider).emit(LearningEvent(
            id: 'listen:${song.id}:${DateTime.now().millisecondsSinceEpoch}',
            type: LearningEventType.songListened,
            uid: uid,
            data: {'songId': song.id, 'seconds': seconds, 'completed': _completed},
          ));
      if (_completed || seconds >= 30) {
        ref.read(songProgressRepositoryProvider).recordListen(song.id);
      }
    }
    _listenedMs = 0;
    _completed = false;
  }

  /// Called when the app goes to background or the player screen closes so
  /// statistics include the time listened so far.
  void reportListening() => _flushListening();
}

final playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
