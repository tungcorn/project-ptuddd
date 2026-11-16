import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// What the player needs from the platform audio stack. The real
/// implementation is [AudioServiceEngine]; widget tests use a fake.
abstract class AudioEngine {
  Stream<Duration> get positionStream;
  Stream<bool> get playingStream;
  Stream<Duration?> get durationStream;

  /// Emits when the current track plays to the end.
  Stream<void> get completedStream;

  Duration get position;
  bool get playing;
  double get speed;

  /// Loads a track. [source] is an asset path (`assets/...`), local file path
  /// or http(s) URL.
  Future<Duration?> load({
    required String id,
    required String source,
    required String title,
    required String artist,
    String? coverAsset,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);
  Future<void> stop();
}

/// just_audio wrapped in an audio_service handler: background playback,
/// media notification and lock-screen controls (section 7.4).
class SingLearnAudioHandler extends BaseAudioHandler with SeekHandler {
  SingLearnAudioHandler() {
    _player.playbackEventStream.listen(_broadcast);
    _player.playingStream.listen((_) => _broadcast(null));
  }

  final AudioPlayer _player = AudioPlayer();

  AudioPlayer get player => _player;

  void _broadcast(PlaybackEvent? _) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.fastForward,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
    ));
  }

  Future<void> setItem(MediaItem item) async => mediaItem.add(item);

  @override
  Future<void> play() async {
    // just_audio's play() only completes when playback stops; never block
    // callers (UI, segment playback) on it.
    unawaited(_player.play().catchError((Object _) {}));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Future<void> rewind() =>
      _player.seek(_player.position - const Duration(seconds: 5));

  @override
  Future<void> fastForward() =>
      _player.seek(_player.position + const Duration(seconds: 5));

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }
}

class AudioServiceEngine implements AudioEngine {
  AudioServiceEngine._(this._handler);

  final SingLearnAudioHandler _handler;

  static Future<AudioServiceEngine> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    final handler = await AudioService.init(
      builder: SingLearnAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.gr10.singlearn.playback',
        androidNotificationChannelName: 'Phát nhạc SingLearn',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
      ),
    );
    return AudioServiceEngine._(handler);
  }

  AudioPlayer get _p => _handler.player;

  @override
  Stream<Duration> get positionStream => _p.positionStream;

  @override
  Stream<bool> get playingStream => _p.playingStream;

  @override
  Stream<Duration?> get durationStream => _p.durationStream;

  @override
  Stream<void> get completedStream => _p.processingStateStream
      .where((s) => s == ProcessingState.completed)
      .map((_) {});

  @override
  Duration get position => _p.position;

  @override
  bool get playing => _p.playing;

  @override
  double get speed => _p.speed;

  Future<Uri?> _artUri(String? coverAsset) async {
    if (coverAsset == null || kIsWeb) return null;
    if (coverAsset.startsWith('http')) return Uri.parse(coverAsset);
    if (!coverAsset.startsWith('assets/')) return Uri.file(coverAsset);
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/art_${coverAsset.split('/').last}');
      if (!await file.exists()) {
        final data = await rootBundle.load(coverAsset);
        await file.writeAsBytes(data.buffer.asUint8List());
      }
      return Uri.file(file.path);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Duration?> load({
    required String id,
    required String source,
    required String title,
    required String artist,
    String? coverAsset,
  }) async {
    final AudioSource audio;
    if (source.startsWith('assets/') && kIsWeb) {
      // On the web just_audio would read the whole asset and pass it as a
      // base64 data: URL (several MB per song), which stalls when switching
      // songs. Let the browser stream the bundled file by URL instead.
      audio = AudioSource.uri(Uri.base.resolve('assets/$source'));
    } else if (source.startsWith('assets/')) {
      audio = AudioSource.asset(source);
    } else if (source.startsWith('http')) {
      audio = AudioSource.uri(Uri.parse(source));
    } else {
      audio = AudioSource.file(source);
    }
    if (kIsWeb) {
      // just_audio 0.10 on the web reuses its cached playlist player, so a
      // second setAudioSource() keeps playing the previous song. Stopping
      // releases the platform player and the next load starts clean.
      await _p.stop();
    }
    final duration = await _p.setAudioSource(audio);
    await _handler.setItem(MediaItem(
      id: id,
      title: title,
      artist: artist,
      duration: duration,
      artUri: await _artUri(coverAsset),
    ));
    return duration;
  }

  @override
  Future<void> play() => _handler.play();

  @override
  Future<void> pause() => _handler.pause();

  @override
  Future<void> seek(Duration position) => _handler.seek(position);

  @override
  Future<void> setSpeed(double speed) => _handler.setSpeed(speed);

  @override
  Future<void> stop() => _p.stop();
}
