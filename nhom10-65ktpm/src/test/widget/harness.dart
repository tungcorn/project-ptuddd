import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/providers.dart';
import 'package:singlearn/core/services/audio_engine.dart';
import 'package:singlearn/core/services/device_services.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/ui/theme.dart';
import 'package:singlearn/features/auth/data/auth_repository.dart';
import 'package:singlearn/features/social/data/social_repository.dart';


/// Audio engine that simulates playback time without a platform plugin.
/// Call [advance] to move the clock while "playing".
class FakeAudioEngine implements AudioEngine {
  final _pos = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _dur = StreamController<Duration?>.broadcast();
  final _done = StreamController<void>.broadcast();

  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double _speed = 1;
  Duration duration = const Duration(seconds: 60);
  String? loadedSource;
  final List<String> log = [];

  @override
  Stream<Duration> get positionStream => _pos.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration?> get durationStream => _dur.stream;
  @override
  Stream<void> get completedStream => _done.stream;
  @override
  Duration get position => _position;
  @override
  bool get playing => _isPlaying;
  @override
  double get speed => _speed;

  @override
  Future<Duration?> load({
    required String id,
    required String source,
    required String title,
    required String artist,
    String? coverAsset,
  }) async {
    loadedSource = source;
    log.add('load:$id');
    _position = Duration.zero;
    _dur.add(duration);
    return duration;
  }

  @override
  Future<void> play() async {
    log.add('play');
    _isPlaying = true;
    _playing.add(true);
  }

  @override
  Future<void> pause() async {
    log.add('pause');
    _isPlaying = false;
    _playing.add(false);
  }

  @override
  Future<void> seek(Duration position) async {
    log.add('seek:${position.inMilliseconds}');
    _position = position;
    _pos.add(position);
  }

  @override
  Future<void> setSpeed(double speed) async {
    log.add('speed:$speed');
    _speed = speed;
  }

  @override
  Future<void> stop() async => pause();

  /// Moves playback forward by [d] (only while playing) and emits position.
  void advance(Duration d) {
    if (!_isPlaying) return;
    _position += d;
    if (_position >= duration) {
      _position = duration;
      _pos.add(_position);
      _done.add(null);
      return;
    }
    _pos.add(_position);
  }
}

/// Reads bundled assets straight from the project folder.
Future<String> fileAssetLoader(String path) => File(path).readAsString();

class FakeSpeechService extends SpeechService {
  final spoken = <String>[];
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stop() async {}
}

class FakeNotificationService extends NotificationService {
  final shown = <String>[];
  TimeOfDay? scheduled;
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleDailyReminder(TimeOfDay time) async => scheduled = time;
  @override
  Future<void> cancelDailyReminder() async => scheduled = null;
  @override
  Future<void> show(String title, String body, {int? id}) async => shown.add(title);
}

/// Everything a widget test needs: a temp Hive store, local auth, local
/// social, a fake audio engine and fake device services.
class TestApp {
  TestApp._(this.store, this.audio, this.auth, this.speech, this.notifications);

  final LocalStore store;
  final FakeAudioEngine audio;
  final LocalAuthRepository auth;
  final FakeSpeechService speech;
  final FakeNotificationService notifications;

  static Future<TestApp> create() async {
    final store = MemoryLocalStore();
    final auth = LocalAuthRepository(store);
    await auth.restore();
    return TestApp._(store, FakeAudioEngine(), auth, FakeSpeechService(),
        FakeNotificationService());
  }

  List<Override> get overrides => [
        localStoreProvider.overrideWithValue(store),
        audioEngineProvider.overrideWithValue(audio),
        authRepositoryProvider.overrideWithValue(auth),
        socialRepositoryProvider.overrideWithValue(LocalSocialRepository(store)),
        assetLoaderProvider.overrideWithValue(fileAssetLoader),
        speechServiceProvider.overrideWithValue(speech),
        notificationServiceProvider.overrideWithValue(notifications),
        connectivityProvider.overrideWithValue(const Stream.empty()),
      ];

  /// Signs up a learner with a level so the router lands in the app.
  Future<void> signIn({String email = 'an@test.vn', String name = 'An'}) async {
    await auth.signUp(email: email, password: 'secret1', displayName: name);
    await auth.updateProfile(level: 'A1');
  }

  /// Pumps [child] inside a ProviderScope + MaterialApp (for single screens).
  Future<ProviderContainer> pumpScreen(WidgetTester tester, Widget child) async {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        scaffoldMessengerKey: scaffoldMessengerKey,
        home: child,
      ),
    ));
    return container;
  }

  Future<void> dispose() async {}
}

/// Runs async work (Hive I/O, file reads) that fake-async pumps cannot drive.
Future<void> settleIo(WidgetTester tester, {int rounds = 6}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [condition] holds (or [maxRounds] is reached), letting real
/// async I/O progress between frames.
Future<bool> settleUntil(WidgetTester tester, bool Function() condition,
    {int maxRounds = 60}) async {
  for (var i = 0; i < maxRounds; i++) {
    if (condition()) return true;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  return condition();
}

/// In-memory [LocalStore] for widget tests: same JSON semantics as the Hive
/// store (values are encoded/decoded), but no file I/O, so it works inside
/// flutter_test's fake-async zone. Hive itself is covered by unit tests.
class MemoryLocalStore extends LocalStore {
  final _data = <String, Map<String, String>>{};
  final _watchers = <String, StreamController<void>>{};

  Map<String, String> _b(String box) => _data.putIfAbsent(box, () => {});
  void _notify(String box) => _watchers[box]?.add(null);

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final raw = _b(box)[key];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    _b(box)[key] = jsonEncode(value);
    _notify(box);
  }

  @override
  Future<void> delete(String box, String key) async {
    _b(box).remove(key);
    _notify(box);
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) async =>
      [for (final v in _b(box).values) jsonDecode(v) as Map<String, dynamic>];

  @override
  Future<Map<String, Map<String, dynamic>>> entries(String box) async => {
        for (final e in _b(box).entries) e.key: jsonDecode(e.value) as Map<String, dynamic>,
      };

  @override
  Future<void> clear(String box) async {
    _b(box).clear();
    _notify(box);
  }

  @override
  Stream<void> watch(String box) =>
      _watchers.putIfAbsent(box, StreamController<void>.broadcast).stream;

  @override
  Future<void> close() async {}
}
