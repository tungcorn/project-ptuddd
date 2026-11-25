import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/songs/data/song_progress_repository.dart';
import 'package:singlearn/features/vocabulary/data/vocabulary_repository.dart';
import 'package:singlearn/features/vocabulary/domain/saved_word.dart';
import 'package:singlearn/features/vocabulary/domain/sm2.dart';

import '../helpers.dart';

/// Regression tests for issue #20: pulls never skip data another device sent
/// late, and a device never erases learning history it had not downloaded.

const _mergers = <String, DocMerge>{
  'words': SavedWord.mergeJson,
  'songProgress': SongProgress.mergeJson,
};

WordContext ctx(int line) => WordContext(
  songId: 'twinkle',
  songTitle: 'Twinkle',
  lineIndex: line,
  line: 'line $line',
  startMs: line * 1000,
  endMs: line * 1000 + 900,
);

/// Card learnt on another device: [reviews] reviews, scheduled at [dueAt].
Map<String, dynamic> studiedStar({
  int reviews = 5,
  int updatedAt = 100,
  DateTime? dueAt,
  bool deleted = false,
  List<int> lines = const [0],
}) => SavedWord(
  id: 'star',
  word: 'star',
  ipa: '/stɑː/',
  pos: 'noun',
  meaning: 'ngôi sao',
  contexts: [for (final l in lines) ctx(l)],
  sm2: Sm2State(
    easeFactor: 2.6,
    intervalDays: 15,
    repetitions: reviews,
    dueAt: dueAt ?? DateTime(2026, 12, 10),
  ),
  reviewCount: reviews,
  lapses: 1,
  createdAt: 10,
  updatedAt: updatedAt,
  isDeleted: deleted,
).toJson();

void main() {
  late LocalStore store;
  late FakeRemote remote;
  late SyncService sync;

  setUp(() async {
    store = await openTestStore();
    remote = FakeRemote();
    sync = SyncService(store, remote, mergers: _mergers);
  });

  tearDown(() => closeTestStore(store));

  Map<String, dynamic> event(String id, int updatedAt) => {
    'id': id,
    'xp': 10,
    'updatedAt': updatedAt,
  };

  group('pull cursor on server time', () {
    test('a write sent late from another device is not skipped', () async {
      // Device B studies online with its clock ahead of the server; this
      // device downloads it.
      remote.write(
        'users/u/xpEvents/b1',
        event('b1', remote.serverTime + 5000),
      );
      expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);

      // Device C learnt earlier offline (old device clock) and reaches the
      // server only now. A cursor on `updatedAt` would skip it.
      remote.write('users/u/xpEvents/c1', event('c1', 100));
      expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);
      expect((await store.get('ledger', 'c1'))!['xp'], 10);
      expect(
        (await store.get(
          'ledger',
          'c1',
        ))!.containsKey(RemoteStore.syncedAtField),
        isFalse,
        reason: 'server time is sync metadata, not learning data',
      );
    });

    test(
      'documents written in the same server instant are all pulled',
      () async {
        remote.freezeClock = true;
        remote.write('users/u/xpEvents/a', event('a', 1));
        remote.write('users/u/xpEvents/b', event('b', 2));
        expect(await sync.pull('users/u/xpEvents', 'ledger'), 2);

        // Same instant as the cursor, committed after the previous pull.
        remote.write('users/u/xpEvents/c', event('c', 3));
        expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);
        expect(await store.get('ledger', 'c'), isNotNull);
      },
    );

    test('pulling again changes nothing and never duplicates XP', () async {
      for (var i = 0; i < 3; i++) {
        remote.write('users/u/xpEvents/e$i', event('e$i', i));
      }
      expect(await sync.pull('users/u/xpEvents', 'ledger'), 3);
      expect(await sync.pull('users/u/xpEvents', 'ledger'), 0);
      expect(await sync.pull('users/u/xpEvents', 'ledger'), 0);
      final ledger = await store.values('ledger');
      expect(ledger, hasLength(3));
      expect(ledger.fold<int>(0, (s, e) => s + (e['xp'] as int)), 30);
    });

    test(
      'the first pull after the update repairs an old device-clock cursor',
      () async {
        // Written before server times existed; an old cursor (500, device
        // clock) had skipped it.
        remote.docs['users/u/xpEvents/legacy'] = event('legacy', 100);
        await store.put('sync_meta', 'pull:users/u/xpEvents', {'since': 500});

        expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);
        expect(await store.get('ledger', 'legacy'), isNotNull);

        // From then on only documents written since are read.
        remote.write('users/u/xpEvents/new', event('new', 1));
        expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);
        expect(await sync.pull('users/u/xpEvents', 'ledger'), 0);
      },
    );

    test(
      'an answer from the cache leaves the server cursor in place',
      () async {
        remote.write('users/u/xpEvents/a', event('a', 1));
        await sync.pull('users/u/xpEvents', 'ledger');
        remote.offlineCache = Map.of(remote.docs);
        remote.write('users/u/xpEvents/late', event('late', 0));
        remote.online = false;
        await expectLater(
          sync.pull('users/u/xpEvents', 'ledger'),
          throwsA(isA<StaleRemoteReadException>()),
        );
        remote.online = true;
        expect(await sync.pull('users/u/xpEvents', 'ledger'), 1);
        expect(await store.get('ledger', 'late'), isNotNull);
      },
    );
  });

  group('learning state is merged, not overwritten', () {
    final now = DateTime(2026, 11, 23, 20);

    VocabularyRepository words() => VocabularyRepository(
      store: store,
      sync: sync,
      bus: AppEventBus(),
      uid: 'u',
      clock: () => now,
    );

    test('a card saved on a new device before its first download keeps the '
        'cloud review history', () async {
      remote.write('users/u/words/star', studiedStar(lines: [0, 1]));

      // New install, nothing downloaded yet: saving "star" creates a card.
      final repo = words();
      await repo.save(
        lemma: 'Star',
        ipa: '/stɑː/',
        pos: 'noun',
        meaning: 'ngôi sao',
        context: ctx(7),
      );
      expect((await repo.byId('star'))!.reviewCount, 0);
      expect(await sync.flush(), 1);

      final cloud = SavedWord.fromJson(remote.docs['users/u/words/star']!);
      expect(cloud.reviewCount, 5, reason: 'history not reset');
      expect(cloud.sm2.intervalDays, 15);
      expect(cloud.sm2.dueAt, DateTime(2026, 12, 10));
      expect(cloud.contexts.map((c) => c.lineIndex), [0, 1, 7]);
      expect(cloud.createdAt, 10);
      expect(cloud.updatedAt, now.millisecondsSinceEpoch);

      expect(await sync.pull('users/u/words', 'words_u'), 1);
      final local = (await repo.byId('star'))!;
      expect(local.reviewCount, 5);
      expect(local.contexts.map((c) => c.lineIndex), [0, 1, 7]);
      expect(await sync.pull('users/u/words', 'words_u'), 0);
    });

    test('pulling merges into a card that still has unsent changes', () async {
      final repo = words();
      remote.online = false;
      await repo.save(
        lemma: 'star',
        ipa: '',
        pos: '',
        meaning: 'ngôi sao',
        context: ctx(3),
      );
      remote.online = true;
      remote.write('users/u/words/star', studiedStar());

      expect(await sync.pull('users/u/words', 'words_u'), 1);
      final local = (await repo.byId('star'))!;
      expect(local.reviewCount, 5);
      expect(local.contexts.map((c) => c.lineIndex), [
        0,
        3,
      ], reason: 'the unsent context stays visible');
      expect(await sync.pendingCount(), 1, reason: 'still to be sent');
    });

    test('a later delete or restore wins as a whole', () {
      final deleted = studiedStar(deleted: true, updatedAt: 200);
      final active = studiedStar(reviews: 9, updatedAt: 150);
      for (final merged in [
        SavedWord.mergeJson(deleted, active),
        SavedWord.mergeJson(active, deleted),
      ]) {
        expect(SavedWord.fromJson(merged).isDeleted, isTrue);
      }
      final restored = studiedStar(reviews: 0, updatedAt: 300);
      final merged = SavedWord.fromJson(SavedWord.mergeJson(deleted, restored));
      expect(merged.isDeleted, isFalse);
      expect(merged.reviewCount, 0, reason: 'a restore starts a new schedule');
    });

    test('the word merge is order-independent and idempotent', () {
      final a = studiedStar(reviews: 3, updatedAt: 120, lines: [0, 2]);
      final b = studiedStar(
        reviews: 3,
        updatedAt: 120,
        lines: [5],
        dueAt: DateTime(2026, 12, 1),
      );
      final ab = SavedWord.mergeJson(a, b);
      final ba = SavedWord.mergeJson(b, a);
      expect(
        SavedWord.fromJson(ab).sm2.dueAt,
        SavedWord.fromJson(ba).sm2.dueAt,
      );
      expect(
        SavedWord.fromJson(ab).contexts.map((c) => c.key).toSet(),
        SavedWord.fromJson(ba).contexts.map((c) => c.key).toSet(),
      );
      expect(SavedWord.mergeJson(ab, a), ab);
      expect(SavedWord.mergeJson(ab, b), ab);
    });

    test('song progress made before the first download does not lower the '
        'cloud progress', () async {
      remote.write('users/u/songProgress/twinkle', {
        'id': 'twinkle',
        'listens': 50,
        'bestExerciseScore': 90,
        'bestPronunciationScore': 70,
        'lineBestScores': {'0': 80, '1': 60},
        'favorite': true,
        'lastStudiedAt': 100,
        'updatedAt': 100,
      });
      final repo = SongProgressRepository(store, sync, 'u');
      await repo.recordListen('twinkle');
      await repo.recordPronunciation('twinkle', 1, 75, lineCount: 2);
      expect(await sync.flush(), 2);

      final cloud = SongProgress.fromJson(
        remote.docs['users/u/songProgress/twinkle']!,
      );
      expect(cloud.listens, 50);
      expect(cloud.bestExerciseScore, 90);
      expect(cloud.bestPronunciationScore, 70);
      expect(cloud.lineBestScores, {0: 80, 1: 75});
      expect(
        cloud.favorite,
        isTrue,
        reason: 'a new install never toggled it: the cloud choice stays',
      );
      expect(cloud.lastStudiedAt, greaterThan(100));

      await repo.pull();
      expect((await repo.get('twinkle')).listens, 50);
      expect(await sync.pull('users/u/songProgress', 'song_progress_u'), 0);
    });

    test('the latest favorite toggle wins', () {
      final on = {'id': 's', 'favorite': true, 'favoriteAt': 5, 'updatedAt': 9};
      final off = {
        'id': 's',
        'favorite': false,
        'favoriteAt': 7,
        'updatedAt': 1,
      };
      for (final merged in [
        SongProgress.mergeJson(on, off),
        SongProgress.mergeJson(off, on),
      ]) {
        expect(SongProgress.fromJson(merged).favorite, isFalse);
      }
    });

    test('the song progress merge is order-independent and idempotent', () {
      final a = {
        'id': 's',
        'listens': 4,
        'lineBestScores': {'0': 50},
        'favorite': true,
        'updatedAt': 10,
      };
      final b = {
        'id': 's',
        'listens': 2,
        'lineBestScores': {'1': 40},
        'favorite': false,
        'updatedAt': 10,
      };
      final ab = SongProgress.mergeJson(a, b);
      expect(ab, SongProgress.mergeJson(b, a));
      expect(SongProgress.mergeJson(ab, a), ab);
      expect(
        SongProgress.fromJson(ab).favorite,
        isTrue,
        reason: 'same instant: set on either side',
      );
    });
  });

  test('collections without a merge rule keep last-write-wins', () async {
    remote.write('users/u/badges/first', {'v': 'cloud', 'updatedAt': 50});
    await sync.enqueue('users/u/badges/first', {'v': 'local', 'updatedAt': 60});
    expect(await sync.flush(), 1);
    expect(remote.docs['users/u/badges/first'], {
      'v': 'local',
      'updatedAt': 60,
    });
  });
}
