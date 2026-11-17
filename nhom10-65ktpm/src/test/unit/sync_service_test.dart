import 'package:flutter_test/flutter_test.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';

import '../helpers.dart';

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
