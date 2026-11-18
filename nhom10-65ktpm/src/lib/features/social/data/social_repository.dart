import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/storage/local_store.dart';
import '../domain/social_models.dart';

/// Friends, challenges and leaderboard (M4 + M3 challenge results).
abstract class SocialRepository {
  Future<void> upsertProfile(PublicProfile profile);

  Future<PublicProfile?> profile(String uid);

  /// Finds a user by e-mail or 6-character user code.
  Future<PublicProfile?> find(String query);

  Future<List<Friendship>> friendships(String uid);

  Future<void> sendFriendRequest(String fromUid, String toUid);

  Future<void> respondFriendRequest(String uid, String otherUid, {required bool accept});

  Future<void> removeFriend(String uid, String otherUid);

  Future<void> saveChallenge(Challenge challenge);

  Future<List<Challenge>> challenges(String uid);

  /// Emits when friendships or challenges of [uid] may have changed.
  Stream<void> changes(String uid);

  /// Current-week ranking of [uid] and accepted friends, highest XP first.
  Future<List<PublicProfile>> leaderboard(String uid, DateTime now) async {
    final ids = {
      uid,
      for (final f in await friendships(uid))
        if (f.status == FriendStatus.accepted) f.other(uid),
    };
    final profiles = <PublicProfile>[];
    for (final id in ids) {
      final p = await profile(id);
      if (p != null) profiles.add(p);
    }
    profiles.sort((a, b) {
      final c = b.weekXpAt(now).compareTo(a.weekXpAt(now));
      return c != 0 ? c : a.displayName.compareTo(b.displayName);
    });
    return profiles;
  }
}

/// Validates a friend request before it is stored.
String? friendRequestError(String fromUid, PublicProfile? target, List<Friendship> existing) {
  if (target == null) return 'Không tìm thấy người dùng';
  if (target.uid == fromUid) return 'Không thể tự kết bạn với chính mình';
  final f = existing.where((f) => f.members.contains(target.uid));
  if (f.isNotEmpty) {
    return f.first.status == FriendStatus.accepted
        ? 'Hai bạn đã là bạn bè'
        : 'Đã có lời mời kết bạn đang chờ';
  }
  return null;
}

/// Local mode: profiles, friendships and challenges are shared between the
/// accounts on this device (Hive boxes not scoped by uid), so two learners
/// can befriend and challenge each other on one phone without a server.
class LocalSocialRepository extends SocialRepository {
  LocalSocialRepository(this._store);

  static const _profiles = 'public_profiles';
  static const _friends = 'friendships';
  static const _challenges = 'challenges';

  final LocalStore _store;

  @override
  Future<void> upsertProfile(PublicProfile profile) =>
      _store.put(_profiles, profile.uid, profile.toJson());

  @override
  Future<PublicProfile?> profile(String uid) async {
    final j = await _store.get(_profiles, uid);
    return j == null ? null : PublicProfile.fromJson(j);
  }

  @override
  Future<PublicProfile?> find(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final j in await _store.values(_profiles)) {
      final p = PublicProfile.fromJson(j);
      if (p.email.toLowerCase() == q || p.userCode.toLowerCase() == q) return p;
    }
    return null;
  }

  @override
  Future<List<Friendship>> friendships(String uid) async => [
        for (final j in await _store.values(_friends))
          if ((j['members'] as List).contains(uid)) Friendship.fromJson(j),
      ];

  @override
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    final err = friendRequestError(fromUid, await profile(toUid), await friendships(fromUid));
    if (err != null) throw StateError(err);
    final f = Friendship(
      members: [fromUid, toUid]..sort(),
      requestedBy: fromUid,
      status: FriendStatus.pending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _store.put(_friends, f.id, f.toJson());
  }

  @override
  Future<void> respondFriendRequest(String uid, String otherUid, {required bool accept}) async {
    final id = Friendship.idOf(uid, otherUid);
    final j = await _store.get(_friends, id);
    if (j == null) return;
    final f = Friendship.fromJson(j);
    if (f.requestedBy == uid) throw StateError('Không thể tự chấp nhận lời mời của mình');
    if (!accept) return _store.delete(_friends, id);
    await _store.put(_friends, id, {
      ...j,
      'status': FriendStatus.accepted.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> removeFriend(String uid, String otherUid) =>
      _store.delete(_friends, Friendship.idOf(uid, otherUid));

  @override
  Future<void> saveChallenge(Challenge challenge) =>
      _store.put(_challenges, challenge.id, challenge.toJson());

  @override
  Future<List<Challenge>> challenges(String uid) async => [
        for (final j in await _store.values(_challenges))
          if (j['fromUid'] == uid || j['toUid'] == uid) Challenge.fromJson(j),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Stream<void> changes(String uid) {
    final c = StreamController<void>.broadcast();
    final subs = [
      _store.watch(_friends).listen((_) => c.add(null)),
      _store.watch(_challenges).listen((_) => c.add(null)),
    ];
    c.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };
    return c.stream;
  }
}

/// Cloud mode: Firestore collections `publicProfiles`, `friendships`,
/// `challenges` (see `firebase/firestore.rules`).
class FirestoreSocialRepository extends SocialRepository {
  FirestoreSocialRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> upsertProfile(PublicProfile profile) => _db
      .doc('publicProfiles/${profile.uid}')
      .set(profile.toCloudJson(), SetOptions(merge: true));

  @override
  Future<PublicProfile?> profile(String uid) async {
    final d = await _db.doc('publicProfiles/$uid').get();
    return d.exists ? PublicProfile.fromJson({...d.data()!, 'uid': d.id}) : null;
  }

  @override
  Future<PublicProfile?> find(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    if (q.contains('@')) {
      throw StateError('Chế độ Firebase chỉ tìm bạn bằng mã 6 ký tự để bảo vệ email.');
    }
    final snap = await _db
        .collection('publicProfiles')
        .where('userCode', isEqualTo: q.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return PublicProfile.fromJson({...d.data(), 'uid': d.id});
  }

  @override
  Future<List<Friendship>> friendships(String uid) async {
    final snap = await _db
        .collection('friendships')
        .where('members', arrayContains: uid)
        .get();
    return [for (final d in snap.docs) Friendship.fromJson(d.data())];
  }

  @override
  Future<void> sendFriendRequest(String fromUid, String toUid) async {
    final err = friendRequestError(fromUid, await profile(toUid), await friendships(fromUid));
    if (err != null) throw StateError(err);
    final f = Friendship(
      members: [fromUid, toUid]..sort(),
      requestedBy: fromUid,
      status: FriendStatus.pending,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _db.doc('friendships/${f.id}').set(f.toJson());
  }

  @override
  Future<void> respondFriendRequest(String uid, String otherUid, {required bool accept}) async {
    final ref = _db.doc('friendships/${Friendship.idOf(uid, otherUid)}');
    if (!accept) return ref.delete();
    await ref.update({
      'status': FriendStatus.accepted.name,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> removeFriend(String uid, String otherUid) =>
      _db.doc('friendships/${Friendship.idOf(uid, otherUid)}').delete();

  @override
  Future<void> saveChallenge(Challenge challenge) =>
      _db.doc('challenges/${challenge.id}').set(challenge.toJson());

  @override
  Future<List<Challenge>> challenges(String uid) async {
    final snap = await _db
        .collection('challenges')
        .where('members', arrayContains: uid)
        .get();
    return [for (final d in snap.docs) Challenge.fromJson(d.data())]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Stream<void> changes(String uid) {
    final c = StreamController<void>.broadcast();
    final subs = [
      _db
          .collection('friendships')
          .where('members', arrayContains: uid)
          .snapshots()
          .listen((_) => c.add(null)),
      _db
          .collection('challenges')
          .where('members', arrayContains: uid)
          .snapshots()
          .listen((_) => c.add(null)),
    ];
    c.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };
    return c.stream;
  }
}

String newChallengeId() => const Uuid().v4();
