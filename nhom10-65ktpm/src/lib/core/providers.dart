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
import 'sync/account_sync.dart';
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

final syncServiceProvider = Provider<SyncService>((ref) {
  AuthRepository? auth;
  return SyncService(
    ref.watch(localStoreProvider),
    ref.watch(remoteStoreProvider),
    // The queue follows the session (issue #3/#5): only the signed-in
    // account's writes are sent, nothing when signed out or a guest. Read
    // from the auth repository at each write, not from a derived provider,
    // so it changes together with the session.
    account: () {
      final repo = auth ??= ref.read(authRepositoryProvider);
      final user = repo!.current;
      return user == null || user.isGuest ? null : user.uid;
    },
  );
});

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
  final service = ProgressService(
    store: ref.watch(localStoreProvider),
    sync: ref.watch(syncServiceProvider),
    uid: ref.watch(uidProvider),
    // Published only once this account's cloud data was downloaded in this
    // session, so a fresh install does not overwrite its XP with zero.
    onPublicProfileChanged: user == null || user.isGuest
        ? null
        : (snap) async {
            try {
              if (ref.read(accountSyncProvider).isReconciled(user.uid)) {
                _publishProfile(ref, user, snap);
              }
            } catch (e) {
              // Provider rebuilt for another session meanwhile.
              debugPrint('Profile update skipped: $e');
            }
          },
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

/// Shared sync routine of every trigger (issue #20): send, then download
/// the signed-in account's data, then publish its public profile.
final Provider<AccountSync> accountSyncProvider = Provider<AccountSync>((ref) {
  String? signedIn() {
    final user = ref.read(authRepositoryProvider).current;
    return user == null || user.isGuest ? null : user.uid;
  }

  return AccountSync(
    sync: ref.watch(syncServiceProvider),
    account: signedIn,
    pull: (uid) async {
      // Repositories follow the session through providers, which may lag
      // the auth repository for a moment: never pull into another account.
      final words = ref.read(vocabularyRepositoryProvider);
      final songs = ref.read(songProgressRepositoryProvider);
      final progress = ref.read(progressServiceProvider);
      if (words.uid != uid || songs.uid != uid || progress.uid != uid) {
        throw StateError('Phiên đăng nhập vừa thay đổi');
      }
      await words.pull();
      await songs.pull();
      await progress.pull();
      await ref.read(songRepositoryProvider).pullRemote();
    },
    publishProfile: (uid) {
      final user = ref.read(authRepositoryProvider).current;
      final progress = ref.read(progressServiceProvider);
      if (user == null || user.uid != uid || progress.uid != uid) return;
      unawaited(progress
          .snapshot()
          .then((snap) => _publishProfile(ref, user, snap))
          .catchError((Object e) => debugPrint('Profile update deferred: $e')));
    },
  );
});

/// Writes the public profile without waiting for the server: Firestore keeps
/// the write while offline and never completes it until online, so awaiting
/// it would hold up XP recording or sign-in.
void _publishProfile(Ref ref, AppUser user, ProgressSnapshot snap) {
  unawaited(ref
      .read(socialRepositoryProvider)
      .upsertProfile(PublicProfile(
        uid: user.uid,
        displayName: user.displayName,
        userCode: user.userCode,
        email: user.email,
        xp: snap.totalXp,
        weekXp: snap.weekXp,
        weekKey: weekKeyOf(DateTime.now()),
        level: snap.level.level,
        streak: snap.streak,
      ))
      .catchError((Object e) => debugPrint('Profile update deferred: $e')));
}

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
