import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../sync/sync_service.dart';

/// Cloud Firestore transport for [SyncService].
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._db);

  final FirebaseFirestore _db;

  @override
  Future<void> upsert(String path, Map<String, dynamic> data) =>
      _db.doc(path).set(data);

  @override
  Future<List<Map<String, dynamic>>> fetchUpdatedSince(
    String collectionPath,
    int sinceMs,
  ) async {
    final snap = await _db
        .collection(collectionPath)
        .where('updatedAt', isGreaterThan: sinceMs)
        .get();
    return [
      for (final d in snap.docs) {...d.data(), 'id': d.id},
    ];
  }
}

/// Firebase Authentication (email/password, Google, password reset) with the
/// profile stored in `users/{uid}` and the admin role read from the `admin`
/// custom claim (section 8.3).
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _controller = StreamController<AppUser?>.broadcast();
  StreamSubscription<User?>? _sub;
  AppUser? _current;
  bool _guest = false;

  @override
  AppUser? get current => _current;

  @override
  bool get supportsGoogle => true;

  @override
  bool get supportsPasswordReset => true;

  @override
  Stream<AppUser?> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  void _set(AppUser? u) {
    _current = u;
    _controller.add(u);
  }

  Future<AppUser> _load(User u) async {
    IdTokenResult? token;
    Map<String, dynamic> profile = const {};
    try {
      token = await u.getIdTokenResult();
      profile = (await _db.doc('users/${u.uid}').get()).data() ?? const {};
    } on FirebaseException catch (_) {
      // Offline: continue with cached auth data; profile syncs later.
    }
    final user = AppUser(
      uid: u.uid,
      email: u.email ?? '',
      displayName: (profile['displayName'] as String?) ??
          u.displayName ??
          (u.email ?? 'Người học').split('@').first,
      isAdmin: token?.claims?['admin'] == true,
      level: profile['level'] as String?,
      isCloud: true,
    );
    // Firestore queues this write while offline.
    unawaited(_db.doc('publicProfiles/${u.uid}').set({
      'uid': u.uid,
      'displayName': user.displayName,
      'email': user.email.toLowerCase(),
      'userCode': user.userCode,
    }, SetOptions(merge: true)));
    return user;
  }

  @override
  Future<void> restore() async {
    _sub ??= _auth.authStateChanges().listen((u) async {
      if (u == null) {
        if (!_guest) _set(null);
      } else {
        _guest = false;
        _set(await _load(u));
      }
    });
    final u = _auth.currentUser;
    _set(u == null ? null : await _load(u));
  }

  AuthFailure _map(FirebaseAuthException e) => AuthFailure(switch (e.code) {
        'email-already-in-use' => 'Email này đã được đăng ký',
        'invalid-email' => 'Email không hợp lệ',
        'weak-password' => 'Mật khẩu quá yếu',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Email hoặc mật khẩu không đúng',
        'network-request-failed' => 'Không có kết nối mạng',
        'too-many-requests' => 'Thử lại sau ít phút',
        _ => 'Lỗi xác thực: ${e.code}',
      });

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final error = AuthValidators.email(email) ??
        AuthValidators.password(password) ??
        AuthValidators.displayName(displayName);
    if (error != null) throw AuthFailure(error);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user!.updateDisplayName(displayName.trim());
      await _db.doc('users/${cred.user!.uid}').set({
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
      final user = await _load(cred.user!);
      _set(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final user = await _load(cred.user!);
      _set(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      final cred = await _auth.signInWithProvider(GoogleAuthProvider());
      final user = await _load(cred.user!);
      _set(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    final err = AuthValidators.email(email);
    if (err != null) throw AuthFailure(err);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<AppUser> continueAsGuest() async {
    _guest = true;
    final user = AppUser.guest();
    _set(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _guest = false;
    await _auth.signOut();
    _set(null);
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? level}) async {
    final user = _current;
    if (user == null) throw const AuthFailure('Chưa đăng nhập');
    if (user.isGuest) {
      final next = user.copyWith(level: level);
      _set(next);
      return next;
    }
    if (displayName != null) {
      final err = AuthValidators.displayName(displayName);
      if (err != null) throw AuthFailure(err);
    }
    await _db.doc('users/${user.uid}').set({
      'displayName': ?displayName?.trim(),
      'level': ?level,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
    if (displayName != null) {
      await _db.doc('publicProfiles/${user.uid}').set(
          {'displayName': displayName.trim()}, SetOptions(merge: true));
    }
    final next = user.copyWith(displayName: displayName?.trim(), level: level);
    _set(next);
    return next;
  }
}

/// Uploads admin media (audio, cover, LRC) to Firebase Storage and returns
/// the download URL.
class CloudMediaUploader {
  CloudMediaUploader(this._storage);

  final FirebaseStorage _storage;

  Future<String> upload(String localPath, String remotePath) async {
    final ref = _storage.ref(remotePath);
    await ref.putFile(File(localPath));
    return ref.getDownloadURL();
  }
}

/// Registers this device for FCM pushes (challenge invites/results sent by
/// the `notifyChallenge` Cloud Function) by storing the token in
/// `users/{uid}.fcmTokens`.
class CloudMessaging {
  static Future<void> register(String uid) async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = messaging.onRegistered.first;
    await messaging.register();
    final value = await token.timeout(const Duration(seconds: 20));
    await FirebaseFirestore.instance.doc('users/$uid').set({
      'fcmTokens': FieldValue.arrayUnion([value]),
    }, SetOptions(merge: true));
  }
}
