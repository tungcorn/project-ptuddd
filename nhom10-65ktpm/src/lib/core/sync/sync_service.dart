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
///
/// One queue serves every account of the device. Given an `account` source,
/// only the signed-in account's writes are sent (see [flush]).
class SyncService {
  SyncService(
    this._store,
    this._remote, {
    String? Function()? account,
    this.writeTimeout = const Duration(seconds: 10),
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
