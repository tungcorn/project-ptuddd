import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../config/app_config.dart';
import '../sync/sync_service.dart';

/// Cloud Firestore transport for [SyncService].
class FirestoreRemoteStore implements RemoteStore {
  FirestoreRemoteStore(this._db);

  final FirebaseFirestore _db;

  /// A plain write is queued by Firestore while offline. A [merge] write
  /// reads the stored document in a transaction, which needs the server:
  /// offline it fails and the op stays in the sync queue for the next try.
  @override
  Future<void> upsert(
    String path,
    Map<String, dynamic> data, {
    DocMerge? merge,
  }) {
    final ref = _db.doc(path);
    if (merge == null) return ref.set(_stamped(data));
    return _db.runTransaction<void>((tx) async {
      final stored = (await tx.get(ref)).data();
      tx.set(ref, _stamped(stored == null ? data : merge(stored, data)));
    });
  }

  static Map<String, dynamic> _stamped(Map<String, dynamic> data) => {
    ...data,
    RemoteStore.syncedAtField: FieldValue.serverTimestamp(),
  };

  /// Reads from the server only: the default `get()` falls back to the
  /// offline cache, which may miss writes from other devices. Offline, this
  /// throws (`unavailable`) instead of answering from the cache.
  ///
  /// Single-field range on [RemoteStore.syncedAtField]: covered by the
  /// automatic index, no composite index needed.
  @override
  Future<RemoteFetch> fetchChangedSince(
    String collectionPath,
    int? syncedSinceMs,
  ) async {
    Query<Map<String, dynamic>> query = _db.collection(collectionPath);
    if (syncedSinceMs != null) {
      query = query.where(
        RemoteStore.syncedAtField,
        isGreaterThanOrEqualTo: Timestamp.fromMillisecondsSinceEpoch(
          syncedSinceMs,
        ),
      );
    }
    final snap = await query.get(const GetOptions(source: Source.server));
    return RemoteFetch([
      for (final d in snap.docs) _withServerTime(d.data(), d.id),
    ], fromServer: !snap.metadata.isFromCache);
  }

  /// Document data with its id and the server write time as milliseconds
  /// (absent for documents written before it was stored).
  static Map<String, dynamic> _withServerTime(
    Map<String, dynamic> data,
    String id,
  ) {
    final doc = {...data, 'id': id};
    final at = doc.remove(RemoteStore.syncedAtField);
    if (at is Timestamp) {
      doc[RemoteStore.syncedAtField] = at.millisecondsSinceEpoch;
    }
    return doc;
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
  bool get supportsGoogle => AppConfig.googleSignInEnabled;

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
      displayName:
          (profile['displayName'] as String?) ??
          u.displayName ??
          (u.email ?? 'Người học').split('@').first,
      isAdmin: token?.claims?['admin'] == true,
      level: profile['level'] as String?,
      isCloud: true,
    );
    // Firestore queues this write while offline.
    unawaited(
      _db.doc('publicProfiles/${u.uid}').set({
        'uid': u.uid,
        'displayName': user.displayName,
        'userCode': user.userCode,
      }, SetOptions(merge: true)),
    );
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
    'invalid-credential' => 'Email hoặc mật khẩu không đúng',
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
    final error =
        AuthValidators.email(email) ??
        AuthValidators.password(password) ??
        AuthValidators.displayName(displayName);
    if (error != null) throw AuthFailure(error);
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
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
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = await _load(cred.user!);
      _set(user);
      return user;
    } on FirebaseAuthException catch (e) {
      throw _map(e);
    }
  }

  static Future<void>? _googleInitialization;

  static Future<void> _initializeGoogle() => _googleInitialization ??=
      GoogleSignIn.instance.initialize(
        serverClientId: AppConfig.googleServerClientId,
      );

  @override
  Future<AppUser> signInWithGoogle() async {
    if (!supportsGoogle) {
      throw const AuthFailure('Đăng nhập Google chưa được bật cho dự án này.');
    }
    try {
      await _initializeGoogle();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Không xác thực được với Google. Hãy thử lại.');
      }
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      final user = await _load(cred.user!);
      _set(user);
      return user;
    } on GoogleSignInException catch (e) {
      throw AuthFailure(switch (e.code) {
        GoogleSignInExceptionCode.canceled =>
          'Chưa chọn tài khoản Google. Bạn có thể thử lại.',
        GoogleSignInExceptionCode.clientConfigurationError ||
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Đăng nhập Google chưa được cấu hình đúng cho bản cài này.',
        _ => 'Không thể đăng nhập Google lúc này. Hãy thử lại.',
      });
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw const AuthFailure(
          'Tài khoản đã dùng phương thức khác. Hãy đăng nhập bằng phương thức đó.',
        );
      }
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
    final googleInitialization = _googleInitialization;
    if (googleInitialization != null) {
      try {
        await googleInitialization;
        await GoogleSignIn.instance.signOut();
      } catch (_) {
        // Firebase is already signed out; plugin cleanup must not undo it.
      }
    }
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
      await _db.doc('publicProfiles/${user.uid}').set({
        'displayName': displayName.trim(),
      }, SetOptions(merge: true));
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
