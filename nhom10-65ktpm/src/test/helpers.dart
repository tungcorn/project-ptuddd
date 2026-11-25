import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:singlearn/core/storage/local_store.dart';
import 'package:singlearn/core/sync/sync_service.dart';

/// Opens Hive in a fresh temporary directory for each test.
Future<LocalStore> openTestStore() async {
  final dir = await Directory.systemTemp.createTemp('singlearn_test_');
  Hive.init(dir.path);
  return LocalStore();
}

Future<void> closeTestStore(LocalStore store) async {
  await store.close();
  await Hive.close();
}

/// In-memory Firestore stand-in that can be switched offline.
///
/// Server write times are kept apart from [docs] (like Firestore field
/// metadata) so tests can compare documents with what the app wrote. A
/// document put straight into [docs] has no server time: it stands for one
/// written before server times were stored.
class FakeRemote implements RemoteStore {
  final Map<String, Map<String, dynamic>> docs = {};

  /// Server write time (ms) of each document written through [upsert].
  final Map<String, int> syncedAt = {};

  /// Server clock in ms, advanced by one for every write unless [freezeClock]
  /// is set (several writes in the same instant).
  int serverTime = 1000;
  bool freezeClock = false;

  bool online = true;
  int writes = 0;

  /// Like Firestore's default read while offline: when set and [online] is
  /// false, queries succeed from this (possibly outdated) cache, reported as
  /// not confirmed by the server.
  Map<String, Map<String, dynamic>>? offlineCache;

  @override
  Future<void> upsert(
    String path,
    Map<String, dynamic> data, {
    DocMerge? merge,
  }) async {
    if (!online) throw const SocketException('offline');
    write(path, data, merge: merge);
  }

  /// A write that reached the server, e.g. from another device.
  void write(String path, Map<String, dynamic> data, {DocMerge? merge}) {
    writes++;
    final stored = docs[path];
    final next = merge == null || stored == null
        ? data
        : merge(Map<String, dynamic>.from(stored), data);
    docs[path] = Map<String, dynamic>.from(next);
    if (!freezeClock) serverTime++;
    syncedAt[path] = serverTime;
  }

  @override
  Future<RemoteFetch> fetchChangedSince(
    String collectionPath,
    int? syncedSinceMs,
  ) async {
    final cache = offlineCache;
    if (!online && cache == null) throw const SocketException('offline');
    final source = online ? docs : cache!;
    return RemoteFetch([
      for (final e in source.entries)
        if (e.key.startsWith('$collectionPath/') &&
            !e.key.substring(collectionPath.length + 1).contains('/') &&
            (syncedSinceMs == null || (syncedAt[e.key] ?? -1) >= syncedSinceMs))
          {
            ...e.value,
            'id': e.key.split('/').last,
            if (syncedAt[e.key] != null)
              RemoteStore.syncedAtField: syncedAt[e.key],
          },
    ], fromServer: online);
  }
}
