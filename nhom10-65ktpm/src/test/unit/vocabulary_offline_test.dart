import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/progress/data/progress_service.dart';
import 'package:singlearn/features/vocabulary/data/vocabulary_repository.dart';
import 'package:singlearn/features/vocabulary/domain/saved_word.dart';
import 'package:singlearn/features/vocabulary/domain/sm2.dart';

import '../helpers.dart';

/// Regression tests for issue #3 (M2): the deck and its SM-2 schedule survive
/// an app restart, and offline/retry never loses or duplicates a write.

WordContext ctx(int line) => WordContext(
      songId: 'twinkle',
      songTitle: 'Twinkle',
      lineIndex: line,
      line: 'Twinkle, twinkle, little star,',
      startMs: line * 1000,
      endMs: line * 1000 + 900,
    );

/// Remote that accepts [okWrites] writes, then fails like a dropped network.
class FlakyRemote extends FakeRemote {
  FlakyRemote(this.okWrites);

  int okWrites;

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) async {
    if (okWrites <= 0) throw const SocketException('connection reset');
    okWrites--;
    await super.upsert(path, data);
  }
}

void main() {
  final now = DateTime(2026, 11, 18, 20);

  Future<SaveWordOutcome> saveStar(VocabularyRepository repo, int line) =>
      repo.save(
        lemma: 'Star',
        ipa: '/stɑː/',
        pos: 'noun',
        meaning: 'ngôi sao',
        context: ctx(line),
      );

  test('words, contexts, SM-2 schedule and pending ops survive a restart',
      () async {
    final dir = await Directory.systemTemp.createTemp('singlearn_restart_');
    Hive.init(dir.path);
    var store = LocalStore();
    final remote = FakeRemote()..online = false;
    var repo = VocabularyRepository(
      store: store,
      sync: SyncService(store, remote),
      bus: AppEventBus(),
      uid: 'u1',
      clock: () => now,
    );
    await saveStar(repo, 0);
    await saveStar(repo, 4);
    final before = await repo.review('star', ReviewGrade.good);
    final pendingBefore = await SyncService(store, remote).pendingCount();
    expect(pendingBefore, 3, reason: 'create + context + review, offline');

    // Simulate closing the app: every Hive box is closed.
    await store.close();
    await Hive.close();

    Hive.init(dir.path);
    store = LocalStore();
    final sync = SyncService(store, remote);
    repo = VocabularyRepository(
      store: store,
      sync: sync,
      bus: AppEventBus(),
      uid: 'u1',
      clock: () => now,
    );
    final after = (await repo.byId('star'))!;
    expect(after.toJson(), before.toJson());
    expect(after.contexts.length, 2);
    expect(after.sm2.intervalDays, 1);
    expect(await repo.due(), isEmpty, reason: 'still scheduled for tomorrow');
    expect(await sync.pendingCount(), pendingBefore,
        reason: 'offline queue is persisted too');

    remote.online = true;
    expect(await sync.flush(), pendingBefore);
    expect(remote.docs['users/u1/words/star'], before.toJson());

    await closeTestStore(store);
  });

  group('offline -> retry', () {
    late LocalStore store;
    late AppEventBus bus;

    setUp(() async {
      store = await openTestStore();
      bus = AppEventBus();
    });
    tearDown(() => closeTestStore(store));

    test('retries keep every write once and XP is not awarded twice',
        () async {
      final remote = FakeRemote()..online = false;
      final sync = SyncService(store, remote);
      final repo = VocabularyRepository(
          store: store, sync: sync, bus: bus, uid: 'u1', clock: () => now);
      final progress =
          ProgressService(store: store, sync: sync, uid: 'u1', clock: () => now);
      // Keep the Future of every record() call so the test waits for the
      // XP writes themselves instead of sleeping a fixed time.
      final recording = <Future<int?>>[];
      bus.stream.listen((e) => recording.add(progress.record(e)));
      Future<void> settle(int events) async {
        // Broadcast events are delivered asynchronously: let them arrive.
        await Future<void>.delayed(Duration.zero);
        expect(recording, hasLength(events));
        await Future.wait(recording);
      }

      expect(await saveStar(repo, 0), SaveWordOutcome.created);
      expect(await saveStar(repo, 0), SaveWordOutcome.alreadySaved);
      expect(await saveStar(repo, 4), SaveWordOutcome.contextAdded);
      await repo.review('star', ReviewGrade.good);
      await settle(3); // created + contextAdded + review; duplicate emits none
      final queued = await sync.pendingCount();

      // Several failed attempts while offline lose nothing.
      for (var i = 0; i < 3; i++) {
        expect(await sync.flush(), 0);
      }
      expect(await sync.pendingCount(), queued);
      expect(remote.writes, 0);

      remote.online = true;
      expect(await sync.flush(), queued);
      expect(await sync.pendingCount(), 0);
      expect(await sync.flush(), 0, reason: 'nothing is sent twice');
      expect(remote.writes, queued);

      final card = remote.docs['users/u1/words/star']!;
      expect((card['contexts'] as List).length, 2);
      expect(card['reviewCount'], 1);
      expect(
        remote.docs.keys.where((k) => k.startsWith('users/u1/words/')),
        ['users/u1/words/star'],
        reason: 'one card per lemma',
      );
      expect((await progress.snapshot()).totalXp, 10 + 5,
          reason: 'save XP once + one correct review');
    });

    test('a connection drop mid-flush resends only the unsent ops', () async {
      final remote = FlakyRemote(1);
      final sync = SyncService(store, remote);
      final repo = VocabularyRepository(
          store: store, sync: sync, bus: bus, uid: 'u1', clock: () => now);

      await saveStar(repo, 0);
      await saveStar(repo, 4);
      await repo.review('star', ReviewGrade.good);
      expect(await sync.pendingCount(), 3);

      expect(await sync.flush(), 1, reason: 'stops at the dropped write');
      expect(await sync.pendingCount(), 2);

      remote.okWrites = 100;
      expect(await sync.flush(), 2);
      expect(remote.writes, 3, reason: 'the first op is not resent');
      final card = remote.docs['users/u1/words/star']!;
      expect(card['reviewCount'], 1, reason: 'last write applied last');
      expect((card['contexts'] as List).length, 2);
    });
  });
}
