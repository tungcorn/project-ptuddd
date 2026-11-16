import 'dart:async';

import 'package:uuid/uuid.dart';

import '../storage/local_store.dart';

/// Remote document store used for synchronisation (Cloud Firestore in cloud
/// mode; an in-memory fake in tests).
abstract class RemoteStore {
  /// Creates or replaces the document at [path] (e.g. `users/u1/words/w1`).
  Future<void> upsert(String path, Map<String, dynamic> data);

  /// Documents of [collectionPath] whose `updatedAt` is greater than
  /// [sinceMs]. Each map must contain its document id under `id`.
  Future<List<Map<String, dynamic>>> fetchUpdatedSince(
    String collectionPath,
    int sinceMs,
  );
}

/// Offline-first sync engine (section 6.4 of the outline):
///
/// * writes go to Hive first, then are queued in `pending_ops`;
/// * [flush] pushes queued operations in order when the network is back and
///   removes each one only after the remote write succeeded;
/// * [pull] fetches documents changed since the last pull and merges them with
///   last-write-wins on `updatedAt`; deletes are `isDeleted: true` tombstones.
class SyncService {
  SyncService(this._store, this._remote);

  static const pendingBox = 'pending_ops';
  static const _metaBox = 'sync_meta';

  final LocalStore _store;
  final RemoteStore? _remote;
  final _uuid = const Uuid();
  bool _flushing = false;

  bool get isEnabled => _remote != null;

  /// Queues a remote write of [data] to [path]. No-op in local mode.
  Future<void> enqueue(String path, Map<String, dynamic> data) async {
    if (_remote == null) return;
    final createdAt = DateTime.now().microsecondsSinceEpoch;
    // Key ordered by creation time so flush preserves write order.
    final key = '${createdAt.toString().padLeft(20, '0')}_${_uuid.v4()}';
    await _store.put(pendingBox, key, {'path': path, 'data': data});
  }

  Future<int> pendingCount() async =>
      (await _store.entries(pendingBox)).length;

  /// Pushes pending operations. Returns how many were pushed. Stops at the
  /// first failure so ordering is preserved; the rest stay queued.
  Future<int> flush() async {
    final remote = _remote;
    if (remote == null || _flushing) return 0;
    _flushing = true;
    var pushed = 0;
    try {
      final ops = await _store.entries(pendingBox);
      final keys = ops.keys.toList()..sort();
      for (final key in keys) {
        final op = ops[key]!;
        try {
          await remote.upsert(
            op['path'] as String,
            Map<String, dynamic>.from(op['data'] as Map),
          );
        } catch (_) {
          break;
        }
        await _store.delete(pendingBox, key);
        pushed++;
      }
    } finally {
      _flushing = false;
    }
    return pushed;
  }

  /// Pulls [collectionPath] into [localBox] using last-write-wins.
  /// Returns the number of local documents changed.
  Future<int> pull(String collectionPath, String localBox) async {
    final remote = _remote;
    if (remote == null) return 0;
    final metaKey = 'pull:$collectionPath';
    final since =
        ((await _store.get(_metaBox, metaKey))?['since'] as int?) ?? 0;
    final docs = await remote.fetchUpdatedSince(collectionPath, since);
    var changed = 0;
    var maxSeen = since;
    for (final doc in docs) {
      final id = doc['id'] as String;
      final remoteAt = (doc['updatedAt'] as num?)?.toInt() ?? 0;
      if (remoteAt > maxSeen) maxSeen = remoteAt;
      final local = await _store.get(localBox, id);
      final localAt = (local?['updatedAt'] as num?)?.toInt() ?? -1;
      if (remoteAt > localAt) {
        await _store.put(localBox, id, doc);
        changed++;
      }
    }
    await _store.put(_metaBox, metaKey, {'since': maxSeen});
    return changed;
  }

  /// Merge helper exposed for tests and repositories: returns the winner of
  /// two versions of the same document under last-write-wins.
  static Map<String, dynamic> resolve(
    Map<String, dynamic>? local,
    Map<String, dynamic> remote,
  ) {
    if (local == null) return remote;
    final l = (local['updatedAt'] as num?)?.toInt() ?? 0;
    final r = (remote['updatedAt'] as num?)?.toInt() ?? 0;
    return r > l ? remote : local;
  }
}
