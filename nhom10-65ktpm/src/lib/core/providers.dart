import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/domain/app_user.dart';
import '../features/progress/data/progress_service.dart';
import '../features/settings/data/settings_repository.dart';
import '../features/social/data/social_repository.dart';
import '../features/social/domain/social_models.dart';
import '../features/songs/data/song_progress_repository.dart';
import '../features/songs/data/song_repository.dart';
import '../features/songs/domain/song.dart';
import '../features/vocabulary/data/vocabulary_repository.dart';
import '../features/vocabulary/domain/dictionary.dart';
import '../features/vocabulary/domain/saved_word.dart';
import 'cloud/firebase_services.dart';
import 'events/app_event_bus.dart';
import 'services/audio_engine.dart';
import 'services/device_services.dart';
import 'storage/local_store.dart';
import 'sync/sync_service.dart';

// ---------------------------------------------------------------------------
// Infrastructure (overridden in main.dart / tests)
// ---------------------------------------------------------------------------

final localStoreProvider =
    Provider<LocalStore>((ref) => throw UnimplementedError('override'));
final remoteStoreProvider = Provider<RemoteStore?>((ref) => null);
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => throw UnimplementedError('override'));
final socialRepositoryProvider =
    Provider<SocialRepository>((ref) => throw UnimplementedError('override'));
final audioEngineProvider =
    Provider<AudioEngine>((ref) => throw UnimplementedError('override'));
final mediaUploaderProvider = Provider<CloudMediaUploader?>((ref) => null);
final assetLoaderProvider =
    Provider<AssetStringLoader>((ref) => rootBundle.loadString);

final syncServiceProvider = Provider<SyncService>((ref) => SyncService(
    ref.watch(localStoreProvider), ref.watch(remoteStoreProvider)));

final eventBusProvider = Provider<AppEventBus>((ref) {
  final bus = AppEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final speechServiceProvider = Provider<SpeechService>((ref) => SpeechService());
final translationServiceProvider = Provider<TranslationService>((ref) {
  final s = TranslationService();
  ref.onDispose(s.dispose);
  return s;
});
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
final connectivityProvider = Provider<Stream<List<ConnectivityResult>>>(
    (ref) => Connectivity().onConnectivityChanged);
final downloadServiceProvider = Provider<DownloadService>(
    (ref) => DownloadService(ref.watch(localStoreProvider)));

/// Re-runs [load] initially and every time [changes] fires.
Stream<T> liveQuery<T>(Stream<void> changes, Future<T> Function() load) async* {
  // Listen before the first result is yielded. An offscreen tab can pause
  // the query at that yield; delaying the subscription until afterwards
  // would lose storage changes made while the learner is on another screen.
  final pending = StreamController<void>();
  final subscription = changes.listen(
    pending.add,
    onError: pending.addError,
    onDone: pending.close,
  );
  pending.add(null);
  try {
    await for (final _ in pending.stream) {
      yield await load();
    }
  } finally {
    await subscription.cancel();
    await pending.close();
  }
}

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AppUser?>(
    (ref) => ref.watch(authRepositoryProvider).watch());

final currentUserProvider =
    Provider<AppUser?>((ref) => ref.watch(authStateProvider).value);

final uidProvider = Provider<String>(
    (ref) => ref.watch(currentUserProvider)?.uid ?? AppUser.guestUid);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

final settingsRepositoryProvider = Provider<SettingsRepository>(
    (ref) => SettingsRepository(ref.watch(localStoreProvider)));

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    ref.watch(settingsRepositoryProvider).load().then((s) => state = s);
    return const AppSettings();
  }

  Future<void> update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

// ---------------------------------------------------------------------------
// Songs (M1)
// ---------------------------------------------------------------------------

final songRepositoryProvider = Provider<SongRepository>((ref) => SongRepository(
      store: ref.watch(localStoreProvider),
      sync: ref.watch(syncServiceProvider),
      loadAsset: ref.watch(assetLoaderProvider),
    ));

final songsProvider = StreamProvider<List<Song>>((ref) {
  final repo = ref.watch(songRepositoryProvider);
  return liveQuery(ref.watch(localStoreProvider).watch(SongRepository.cacheBox),
      repo.visibleSongs);
});

final allSongsProvider = StreamProvider<List<Song>>((ref) {
  final repo = ref.watch(songRepositoryProvider);
  return liveQuery(
      ref.watch(localStoreProvider).watch(SongRepository.cacheBox), repo.allSongs);
});

final songByIdProvider = FutureProvider.family<Song?, String>((ref, id) async {
  final songs = await ref.watch(allSongsProvider.future);
  return songs.where((s) => s.id == id).firstOrNull;
});

final lyricsProvider = FutureProvider.family<SongLyrics, String>((ref, id) async {
  final song = await ref.watch(songByIdProvider(id).future);
  if (song == null) throw StateError('Không tìm thấy bài hát');
  return ref.watch(songRepositoryProvider).lyrics(song);
});

final songProgressRepositoryProvider = Provider<SongProgressRepository>((ref) =>
    SongProgressRepository(ref.watch(localStoreProvider),
        ref.watch(syncServiceProvider), ref.watch(uidProvider)));

final songProgressProvider = StreamProvider<Map<String, SongProgress>>((ref) {
  final repo = ref.watch(songProgressRepositoryProvider);
  return liveQuery(repo.watch(), repo.all);
});

final downloadedSongsProvider = StreamProvider<Set<String>>((ref) {
  final d = ref.watch(downloadServiceProvider);
  return liveQuery(d.watch(), d.downloadedIds);
});

// ---------------------------------------------------------------------------
// Vocabulary (M2)
// ---------------------------------------------------------------------------

final dictionaryProvider = FutureProvider<SongDictionary>((ref) async =>
    SongDictionary.fromJsonString(await ref
        .watch(assetLoaderProvider)('assets/content/dictionary.json')));

final vocabularyRepositoryProvider =
    Provider<VocabularyRepository>((ref) => VocabularyRepository(
          store: ref.watch(localStoreProvider),
          sync: ref.watch(syncServiceProvider),
          bus: ref.watch(eventBusProvider),
          uid: ref.watch(uidProvider),
        ));

final savedWordsProvider = StreamProvider<List<SavedWord>>((ref) {
  final repo = ref.watch(vocabularyRepositoryProvider);
  return liveQuery(repo.watch(), repo.words);
});

final dueWordsProvider = StreamProvider<List<SavedWord>>((ref) {
  final repo = ref.watch(vocabularyRepositoryProvider);
  return liveQuery(repo.watch(), repo.due);
});

// ---------------------------------------------------------------------------
// Progress (M4)
// ---------------------------------------------------------------------------

final progressServiceProvider = Provider<ProgressService>((ref) {
  final user = ref.watch(currentUserProvider);
  final social = ref.watch(socialRepositoryProvider);
  final service = ProgressService(
    store: ref.watch(localStoreProvider),
    sync: ref.watch(syncServiceProvider),
    uid: ref.watch(uidProvider),
    onPublicProfileChanged: user == null || user.isGuest
        ? null
        : (snap) => social.upsertProfile(PublicProfile(
              uid: user.uid,
              displayName: user.displayName,
              userCode: user.userCode,
              email: user.email,
              xp: snap.totalXp,
              weekXp: snap.weekXp,
              weekKey: weekKeyOf(DateTime.now()),
              level: snap.level.level,
              streak: snap.streak,
            )),
  );
  final sub = ref.watch(eventBusProvider).stream.listen(service.record);
  ref.onDispose(() {
    sub.cancel();
    service.dispose();
  });
  return service;
});

final progressSnapshotProvider = StreamProvider<ProgressSnapshot>((ref) {
  final service = ref.watch(progressServiceProvider);
  return liveQuery(service.watch(), service.snapshot);
});

// ---------------------------------------------------------------------------
// Social (M4 / M3 challenge)
// ---------------------------------------------------------------------------

final socialVersionProvider = StreamProvider<int>((ref) async* {
  final uid = ref.watch(uidProvider);
  var v = 0;
  yield v;
  await for (final _ in ref.watch(socialRepositoryProvider).changes(uid)) {
    yield ++v;
  }
});

final friendshipsProvider = FutureProvider<List<Friendship>>((ref) async {
  ref.watch(socialVersionProvider);
  return ref.watch(socialRepositoryProvider).friendships(ref.watch(uidProvider));
});

final challengesProvider = FutureProvider<List<Challenge>>((ref) async {
  ref.watch(socialVersionProvider);
  return ref.watch(socialRepositoryProvider).challenges(ref.watch(uidProvider));
});

final leaderboardProvider = FutureProvider<List<PublicProfile>>((ref) async {
  ref.watch(socialVersionProvider);
  ref.watch(progressSnapshotProvider);
  return ref
      .watch(socialRepositoryProvider)
      .leaderboard(ref.watch(uidProvider), DateTime.now());
});

final publicProfileProvider =
    FutureProvider.family<PublicProfile?, String>((ref, uid) async {
  ref.watch(socialVersionProvider);
  return ref.watch(socialRepositoryProvider).profile(uid);
});

/// Shows a SnackBar from anywhere (XP awards, errors).
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void showMessage(String text) {
  scaffoldMessengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
