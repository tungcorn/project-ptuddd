import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';

import '../helpers.dart';

/// Fake Firestore that, like the security rules, only lets the signed-in
/// user write under `users/{uid}/...`.
class SessionRemote extends FakeRemote {
  String? signedIn;
  int rejected = 0;

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) async {
    final parts = path.split('/');
    if (parts.first == 'users' && parts[1] != signedIn) {
      rejected++;
      throw StateError('permission-denied: $path');
    }
    await super.upsert(path, data);
  }
}

void main() {
  late LocalStore store;
  late FakeRemote remote;
  late SyncService sync;

  setUp(() async {
    store = await openTestStore();
    remote = FakeRemote();
    sync = SyncService(store, remote);
  });
  tearDown(() => closeTestStore(store));

  test('local mode (no remote) never queues', () async {
    final local = SyncService(store, null);
    await local.enqueue('a/b', {'x': 1});
    expect(await local.pendingCount(), 0);
    expect(await local.flush(), 0);
  });

  test('ops queue while offline and flush in order when online', () async {
    remote.online = false;
    await sync.enqueue('users/u/words/a', {'v': 1, 'updatedAt': 1});
    await sync.enqueue('users/u/words/a', {'v': 2, 'updatedAt': 2});
    await sync.enqueue('users/u/words/b', {'v': 3, 'updatedAt': 3});
    expect(await sync.flush(), 0);
    expect(await sync.pendingCount(), 3);

    remote.online = true;
    expect(await sync.flush(), 3);
    expect(await sync.pendingCount(), 0);
    expect(remote.docs['users/u/words/a']!['v'], 2,
        reason: 'last write applied last');
  });

  test('pull merges with last-write-wins and remembers the cursor', () async {
    await store.put('words_u', 'a', {'id': 'a', 'v': 'local-new', 'updatedAt': 50});
    await store.put('words_u', 'b', {'id': 'b', 'v': 'local-old', 'updatedAt': 10});
    remote.docs['users/u/words/a'] = {'v': 'remote-old', 'updatedAt': 40};
    remote.docs['users/u/words/b'] = {'v': 'remote-new', 'updatedAt': 20};
    remote.docs['users/u/words/c'] = {
      'v': 'remote-only',
      'updatedAt': 30,
      'isDeleted': true,
    };

    expect(await sync.pull('users/u/words', 'words_u'), 2);
    expect((await store.get('words_u', 'a'))!['v'], 'local-new');
    expect((await store.get('words_u', 'b'))!['v'], 'remote-new');
    expect((await store.get('words_u', 'c'))!['isDeleted'], true,
        reason: 'tombstones sync');

    expect(await sync.pull('users/u/words', 'words_u'), 0);
  });

  test('a pull answered from the offline cache fails and changes nothing',
      () async {
    remote.docs['users/u/words/a'] = {'v': 'server-old', 'updatedAt': 10};
    expect(await sync.pull('users/u/words', 'words_u'), 1);
    // Another device writes newer data; this device only has its cache.
    remote.offlineCache = {
      'users/u/words/a': {'v': 'cached', 'updatedAt': 20},
    };
    remote.docs['users/u/words/a'] = {'v': 'server-new', 'updatedAt': 30};
    remote.online = false;

    await expectLater(
      sync.pull('users/u/words', 'words_u'),
      throwsA(isA<StaleRemoteReadException>()),
    );
    expect((await store.get('words_u', 'a'))!['v'], 'server-old',
        reason: 'cached documents are not merged');

    remote.online = true;
    expect(await sync.pull('users/u/words', 'words_u'), 1,
        reason: 'the cursor did not move past the unseen server write');
    expect((await store.get('words_u', 'a'))!['v'], 'server-new');
  });

  group('queue shared by several accounts on one device', () {
    late SessionRemote cloud;
    late SyncService shared;

    setUp(() {
      cloud = SessionRemote();
      shared = SyncService(store, cloud);
    });

    test('ownerOf reads the uid from users/{uid}/... paths', () {
      expect(SyncService.ownerOf('users/a/words/star'), 'a');
      expect(SyncService.ownerOf('users/a'), 'a');
      expect(SyncService.ownerOf('songs/twinkle'), isNull);
    });

    test('A queue does not block B and is never sent under B', () async {
      // A saves offline, then signs out with ops still queued.
      cloud.online = false;
      await shared.enqueue('users/a/words/star', {'v': 'a1', 'updatedAt': 1});
      await shared.enqueue('users/a/words/sky', {'v': 'a2', 'updatedAt': 2});
      cloud.online = true;
      cloud.signedIn = 'b';
      await shared.enqueue('users/b/words/boat', {'v': 'b1', 'updatedAt': 3});
      await shared.enqueue('songs/twinkle', {'v': 's', 'updatedAt': 4});

      expect(await shared.pendingCount(uid: 'b'), 2);
      expect(await shared.flush(uid: 'b'), 2);
      expect(cloud.docs.keys,
          unorderedEquals(['users/b/words/boat', 'songs/twinkle']));
      expect(cloud.rejected, 0, reason: 'A ops are not even attempted');
      expect(await shared.pendingCount(uid: 'b'), 0);
      expect(await shared.pendingCount(uid: 'a'), 2, reason: 'A ops kept');
      expect(await shared.pendingCount(), 2);
    });

    test('A signs back in and its queue resumes in order', () async {
      cloud.online = false;
      await shared.enqueue('users/a/words/star', {'v': 1, 'updatedAt': 1});
      await shared.enqueue('users/a/words/star', {'v': 2, 'updatedAt': 2});
      cloud.online = true;
      cloud.signedIn = 'b';
      await shared.enqueue('users/b/words/boat', {'v': 'b', 'updatedAt': 3});
      expect(await shared.flush(uid: 'b'), 1);

      cloud.signedIn = 'a';
      expect(await shared.flush(uid: 'a'), 2);
      expect(cloud.docs['users/a/words/star']!['v'], 2);
      expect(await shared.pendingCount(), 0);
    });

    test('without a uid flush keeps the old all-accounts behaviour', () async {
      await shared.enqueue('users/a/words/star', {'v': 1, 'updatedAt': 1});
      await shared.enqueue('users/b/words/boat', {'v': 2, 'updatedAt': 2});
      cloud.signedIn = 'b';
      expect(await shared.flush(), 0, reason: 'stops at the rejected A op');
      expect(await shared.pendingCount(), 2, reason: 'nothing is dropped');
    });
  });

  test('resolve picks the newer version', () {
    expect(
      SyncService.resolve({'updatedAt': 2, 'v': 'l'}, {'updatedAt': 1, 'v': 'r'})['v'],
      'l',
    );
    expect(
      SyncService.resolve({'updatedAt': 1, 'v': 'l'}, {'updatedAt': 2, 'v': 'r'})['v'],
      'r',
    );
    expect(SyncService.resolve(null, {'v': 'r'})['v'], 'r');
  });
}
