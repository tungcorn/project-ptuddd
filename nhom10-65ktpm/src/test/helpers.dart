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
class FakeRemote implements RemoteStore {
  final Map<String, Map<String, dynamic>> docs = {};
  bool online = true;
  int writes = 0;

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) async {
    if (!online) throw const SocketException('offline');
    writes++;
    docs[path] = Map<String, dynamic>.from(data);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUpdatedSince(
    String collectionPath,
    int sinceMs,
  ) async {
    if (!online) throw const SocketException('offline');
    return [
      for (final e in docs.entries)
        if (e.key.startsWith('$collectionPath/') &&
            !e.key.substring(collectionPath.length + 1).contains('/') &&
            ((e.value['updatedAt'] as num?) ?? 0) > sinceMs)
          {...e.value, 'id': e.key.split('/').last},
    ];
  }
}
