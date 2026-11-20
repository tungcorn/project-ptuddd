import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:singlearn/core/events/app_event_bus.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';
import 'package:singlearn/features/progress/data/progress_service.dart';

import '../helpers.dart';

void main() {
  const uid = 'm3-u1';
  // Existing M3 event contract: a daily key for passing attempts, a distinct
  // :try: key for a failed attempt. No XP/schema changes are introduced here.
  const dailyId = 'pron:silent-night:2:2026-11-20';
  final now = DateTime(2026, 11, 20, 12);
  late Directory directory;
  late LocalStore store;
  late FakeRemote remote;
  late SyncService sync;
  late ProgressService progress;

  void openServices() {
    Hive.init(directory.path);
    store = LocalStore();
    sync = SyncService(store, remote);
    progress = ProgressService(
        store: store, sync: sync, uid: uid, clock: () => now);
  }

  LearningEvent attempt(String id, int score) => LearningEvent(
        id: id,
        type: LearningEventType.pronunciationScored,
        uid: uid,
        at: now,
        data: {'songId': 'silent-night', 'lineIndex': 2, 'score': score},
      );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('singlearn_m3_ledger_');
    remote = FakeRemote()..online = false;
    openServices();
  });

  tearDown(() async {
    await progress.dispose();
    await closeTestStore(store);
  });

  test('concurrent passing attempts queue and award the daily event once',
      () async {
    final awards = await Future.wait([
      progress.record(attempt(dailyId, 70)),
      progress.record(attempt(dailyId, 100)),
      progress.record(attempt(dailyId, 90)),
    ]);

    expect(awards, [5, null, null]);
    expect((await progress.snapshot()).totalXp, 5);
    final ledger = await store.entries('xp_ledger_$uid');
    expect(ledger.keys, [dailyId]);
    expect(ledger[dailyId]!['data']['score'], 70);
    expect(await sync.pendingCount(uid: uid), 1);
  });

  test('a failed attempt does not consume the later passing daily award',
      () async {
    const failedId = '$dailyId:try:1';
    expect(await progress.record(attempt(failedId, 69)), 0);
    expect(await progress.record(attempt(dailyId, 70)), 5);
    expect(await progress.record(attempt(dailyId, 100)), isNull);

    expect((await progress.snapshot()).totalXp, 5);
    final ledger = await store.entries('xp_ledger_$uid');
    expect(ledger.keys, unorderedEquals([failedId, dailyId]));
    expect(ledger[failedId]!['xp'], 0);
    expect(await sync.pendingCount(uid: uid), 2);
  });

  test('reopening Hive preserves the award and pending offline operation',
      () async {
    expect(await progress.record(attempt(dailyId, 85)), 5);
    expect(await sync.flush(uid: uid), 0);
    expect(remote.writes, 0);
    expect(await sync.pendingCount(uid: uid), 1);

    await progress.dispose();
    await closeTestStore(store);
    openServices();

    expect(await progress.record(attempt(dailyId, 100)), isNull);
    expect((await progress.snapshot()).totalXp, 5);
    expect((await store.entries('xp_ledger_$uid')).keys, [dailyId]);
    expect(await sync.pendingCount(uid: uid), 1);

    remote.online = true;
    expect(await sync.flush(uid: uid), 1);
    expect(remote.writes, 1);
    expect(remote.docs.keys, ['users/$uid/xpEvents/$dailyId']);
    expect(remote.docs.values.single['xp'], 5);
    expect(remote.docs.values.single['data']['score'], 85);
    expect(await sync.pendingCount(uid: uid), 0);
    expect(await sync.flush(uid: uid), 0);
    expect(remote.writes, 1);
  });
}
