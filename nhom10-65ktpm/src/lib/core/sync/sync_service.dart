import 'dart:async';

import 'package:uuid/uuid.dart';

import '../storage/local_store.dart';

/// Combines the stored version of a document with an [incoming] one, e.g.
/// keeping the learning history of both devices. Must be deterministic and
/// idempotent: merging a result again with either input changes nothing.
typedef DocMerge = Map<String, dynamic> Function(
  Map<String, dynamic> current,
  Map<String, dynamic> incoming,
);

/// Remote document store used for synchronisation (Cloud Firestore in cloud
/// mode; an in-memory fake in tests).
abstract class RemoteStore {
  /// Field holding the server time of the last write of a document, set by
  /// [upsert]. Pulls page on it instead of the device clock (`updatedAt`),
  /// so a write sent late from another device is never skipped.
  static const syncedAtField = 'syncedAt';

  /// Creates or replaces the document at [path] (e.g. `users/u1/words/w1`)
  /// and stamps it with the server time under [syncedAtField].
  ///
  /// With [merge], the stored document becomes `merge(stored, data)` in one
  /// atomic step (just [data] when nothing is stored), so a device never
  /// overwrites what another device wrote without combining it.
  Future<void> upsert(
    String path,
    Map<String, dynamic> data, {
    DocMerge? merge,
  });

  /// Documents of [collectionPath] written at or after [syncedSinceMs]
  /// (server time, inclusive so documents sharing that instant are not
  /// lost); every document when it is null, including ones written before
  /// [syncedAtField] existed. Each map holds its document id under `id` and,
  /// when known, its server write time in milliseconds under [syncedAtField].
  ///
  /// [RemoteFetch.fromServer] must be false when the result was not
  /// confirmed by the server (e.g. Firestore answering from its offline
  /// cache), so callers never treat a cached answer as current data.
  Future<RemoteFetch> fetchChangedSince(
    String collectionPath,
    int? syncedSinceMs,
  );
}

/// Result of [RemoteStore.fetchChangedSince].
class RemoteFetch {
  const RemoteFetch(this.docs, {required this.fromServer});

  final List<Map<String, dynamic>> docs;

  /// True only when the server answered the query. A cached answer may miss
  /// documents written from another device.
  final bool fromServer;
}

/// Thrown by [SyncService.pull] when the remote answered from a cache
/// instead of the server: the data is not known to be current.
class StaleRemoteReadException implements Exception {
  const StaleRemoteReadException(this.collectionPath);

  final String collectionPath;

  @override
  String toString() =>
      'StaleRemoteReadException: $collectionPath was not read from the server';
}

/// Offline-first sync engine (section 6.4 of the outline):
///
/// * writes go to Hive first, then are queued in `pending_ops`;
/// * [flush] pushes queued operations in order when the network is back and
///   removes each one only after the remote write succeeded;
/// * [pull] fetches documents written to the server since the last pull (by
///   server time, see [RemoteStore.syncedAtField]) and merges them with
///   last-write-wins on `updatedAt`; deletes are `isDeleted: true` tombstones;
/// * collections given a [DocMerge] in `mergers` are combined instead of
///   replaced, both on the server when sent and locally when pulled.
///
/// One queue serves every account of the device. Given an `account` source,
/// only the signed-in account's writes are sent (see [flush]).
class SyncService {
  SyncService(
    this._store,
    this._remote, {
    String? Function()? account,
    this.writeTimeout = const Duration(seconds: 10),
    this._mergers = const {},
  }) : _session = account;

  static const pendingBox = 'pending_ops';
  static const _metaBox = 'sync_meta';

  final LocalStore _store;
  final RemoteStore? _remote;
  final _uuid = const Uuid();

  /// Live signed-in account: its uid, or null when signed out or a guest.
  /// Read before every write, so a running flush follows the session.
  /// Without it (the original API) every account is sent.
  final String? Function()? _session;

  /// How long [flush] waits for one remote write before keeping it queued
  /// and stopping. Firestore does not complete a write while offline, so
  /// without a limit one write could hold the queue for every account.
  final Duration writeTimeout;

  /// Merge rule per collection name (`words` for `users/{uid}/words/...`).
  /// Collections without one use whole-document last-write-wins.
  final Map<String, DocMerge> _mergers;

  Future<int>? _running;
  Future<int>? _next;
  String? _nextUid;

  /// Queue keys whose write timed out and is still unanswered. Later passes
  /// stop there at once instead of re-sending it or waiting again; the op
  /// leaves the queue when that write is acknowledged.
  final _unanswered = <String>{};

  bool get isEnabled => _remote != null;

  /// Signed-in account whose private writes may be sent now.
  String? get account => _session?.call();

  /// Queues a remote write of [data] to [path]. No-op in local mode.
  Future<void> enqueue(String path, Map<String, dynamic> data) async {
    if (_remote == null) return;
    final createdAt = DateTime.now().microsecondsSinceEpoch;
    // Key ordered by creation time so flush preserves write order.
    final key = '${createdAt.toString().padLeft(20, '0')}_${_uuid.v4()}';
    final author = account;
    await _store.put(pendingBox, key, {
      'path': path,
      'data': data,
      // Author of a shared-path write (an admin editing `songs/...`), so it
      // waits for that account instead of blocking the next one.
      if (author != null && ownerOf(path) == null) 'by': author,
    });
  }

  /// Merge rule of the collection holding [path] (a document or collection
  /// path), or null for last-write-wins.
  DocMerge? _mergerFor(String path, {required bool document}) {
    final parts = path.split('/');
    final index = parts.length - (document ? 2 : 1);
    return index < 0 ? null : _mergers[parts[index]];
  }

  /// Account that owns a document path: `uid` for `users/{uid}/...`, null
  /// for shared paths such as `songs/...`.
  static String? ownerOf(String path) {
    final parts = path.split('/');
    return parts.length >= 2 && parts.first == 'users' ? parts[1] : null;
  }

  /// Account a flush or count requested for [uid] works for. `send: false`
  /// means nothing may be sent: signed out, or [uid] is not the signed-in
  /// account. `uid: null` with `send: true` is the original behaviour
  /// (every account), only without an account source.
  ({bool send, String? uid}) _target(String? uid) {
    final session = _session;
    if (session == null) return (send: true, uid: uid);
    final current = session();
    if (current == null || (uid != null && uid != current)) {
      return (send: false, uid: uid);
    }
    return (send: true, uid: current);
  }

  /// Whether queued [op] may be sent for [uid] (null = every account).
  /// Shared writes queued without an author go with any account.
  static bool _sendableBy(Map<String, dynamic> op, String? uid) {
    if (uid == null) return true;
    final owner = ownerOf(op['path'] as String) ?? op['by'] as String?;
    return owner == null || owner == uid;
  }

  /// Number of queued writes [flush] would try for [uid]: by default the
  /// signed-in account (every account without an account source).
  Future<int> pendingCount({String? uid}) async {
    if (_remote == null) return 0;
    final target = _target(uid);
    if (!target.send) return 0;
    return (await _store.entries(pendingBox)).values
        .where((op) => _sendableBy(op, target.uid))
        .length;
  }

  /// Pushes pending operations. Returns how many were pushed. An op leaves
  /// the queue only after the remote confirmed it.
  ///
  /// With [uid] (by default the signed-in account), writes under another
  /// account's `users/{otherUid}/...` and shared writes made by another
  /// account are skipped and kept: the security rules would reject them.
  /// They are sent when their owner signs in again. Later writes to a
  /// skipped document wait too, so a document never gets them out of order.
  /// A flush stops before its next write when the session changes.
  ///
  /// A pass stops at the first failure or timeout so the rest keep their
  /// order, except that a rejected shared write (e.g. one queued by an admin
  /// before authors were recorded) only holds back its own document.
  ///
  /// A call made while a flush runs is not dropped: it waits for that flush,
  /// then one more pass runs for every call made meanwhile (the last [uid]
  /// given wins).
  Future<int> flush({String? uid}) {
    if (_remote == null) return Future.value(0);
    final next = _next;
    if (next != null) {
      _nextUid = uid;
      return next;
    }
    final running = _running;
    if (running == null) return _start(uid);
    _nextUid = uid;
    return _next = running.then<void>((_) {}, onError: (Object _) {}).then((_) {
      _next = null;
      return _start(_nextUid);
    });
  }

  Future<int> _start(String? uid) {
    final run = _flushOnce(uid);
    _running = run;
    run.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_running, run)) _running = null;
    });
    return run;
  }

  Future<int> _flushOnce(String? uid) async {
    final remote = _remote!;
    final target = _target(uid);
    if (!target.send) return 0;
    final ops = await _store.entries(pendingBox);
    // Documents held back in this pass, to keep per-document order.
    final held = <String>{};
    var pushed = 0;
    for (final key in ops.keys.toList()..sort()) {
      final op = ops[key]!;
      final path = op['path'] as String;
      if (held.contains(path)) continue;
      if (!_sendableBy(op, target.uid)) {
        held.add(path);
        continue;
      }
      // An earlier write of this op is still unanswered: keep the order.
      if (_unanswered.contains(key)) break;
      // Acknowledged late while this pass was running.
      if (await _store.get(pendingBox, key) == null) continue;
      // The session changed during this flush: leave the rest to its owner.
      final current = _target(uid);
      if (!current.send || current.uid != target.uid) break;
      final write = remote.upsert(
        path,
        Map<String, dynamic>.from(op['data'] as Map),
        merge: _mergerFor(path, document: true),
      );
      try {
        await write.timeout(writeTimeout);
      } on TimeoutException {
        _awaitLate(key, write);
        break;
      } catch (_) {
        if (ownerOf(path) == null) {
          held.add(path);
          continue;
        }
        break;
      }
      await _store.delete(pendingBox, key);
      pushed++;
    }
    return pushed;
  }

  /// Keeps listening to a write [flush] stopped waiting for. Once it is
  /// acknowledged the op is dequeued and the rest of the queue resumes
  /// through [flush] (merged with a running pass, for the account signed in
  /// at that moment: nothing when signed out). If it fails, the op stays for
  /// the next trigger; no retry is started here, so a failing remote cannot
  /// loop.
  void _awaitLate(String key, Future<void> write) {
    _unanswered.add(key);
    write
        .then<void>(
          (_) async {
            try {
              await _store.delete(pendingBox, key);
            } finally {
              _unanswered.remove(key);
            }
            await flush();
          },
          onError: (Object _) => _unanswered.remove(key),
        )
        // A failure here (e.g. storage closed) leaves the op queued for the
        // next trigger; it is a background continuation with no caller.
        .ignore();
  }

  /// Pulls [collectionPath] into [localBox]: last-write-wins on `updatedAt`,
  /// or the collection's [DocMerge]. Returns the number of local documents
  /// changed.
  ///
  /// The cursor is the latest server write time seen, never the device clock:
  /// a document written offline on another device carries an old `updatedAt`
  /// but a new server time, so it is fetched once it reaches the server.
  /// Documents at the cursor instant are fetched again (merging them again
  /// changes nothing), so several documents written in the same instant are
  /// not lost. The first pull of a collection with this cursor reads it whole,
  /// which also picks up documents written before server times were stored.
  ///
  /// Throws [StaleRemoteReadException] when the remote could not confirm the
  /// result with the server; nothing is merged and the cursor stays put, so
  /// a pull completes only with server data.
  Future<int> pull(String collectionPath, String localBox) async {
    final remote = _remote;
    if (remote == null) return 0;
    final metaKey = 'pull:$collectionPath';
    // `synced`: server-time cursor. An older `since` (device-clock cursor)
    // is ignored: it may have skipped documents sent late.
    final since = (await _store.get(_metaBox, metaKey))?['synced'] as int?;
    final fetch = await remote.fetchChangedSince(collectionPath, since);
    if (!fetch.fromServer) throw StaleRemoteReadException(collectionPath);
    final merge = _mergerFor(collectionPath, document: false);
    var changed = 0;
    var cursor = since ?? 0;
    for (final fetched in fetch.docs) {
      final doc = Map<String, dynamic>.from(fetched);
      final syncedAt = (doc.remove(RemoteStore.syncedAtField) as num?)?.toInt();
      if (syncedAt != null && syncedAt > cursor) cursor = syncedAt;
      final id = doc['id'] as String;
      final local = await _store.get(localBox, id);
      final next = local == null
          ? doc
          : merge == null
          ? resolve(local, doc)
          : merge(local, doc);
      if (local == null || !_sameData(next, local)) {
        await _store.put(localBox, id, next);
        changed++;
      }
    }
    await _store.put(_metaBox, metaKey, {'synced': cursor});
    return changed;
  }

  /// Deep equality of JSON-like values.
  static bool _sameData(Object? a, Object? b) {
    if (a is Map && b is Map) {
      return a.length == b.length &&
          a.keys.every((k) => b.containsKey(k) && _sameData(a[k], b[k]));
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_sameData(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
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
