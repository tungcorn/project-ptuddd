import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/local_store.dart';
import '../domain/app_user.dart';

/// Authentication + profile (M4). Two implementations: [LocalAuthRepository]
/// for demo/local mode and `FirebaseAuthRepository` for cloud mode.
abstract class AuthRepository {
  /// Emits the current user (null = signed out) on every change.
  Stream<AppUser?> watch();

  AppUser? get current;

  Future<void> restore();

  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AppUser> signIn({required String email, required String password});

  /// Google sign-in. Only available in cloud mode.
  Future<AppUser> signInWithGoogle();

  bool get supportsGoogle;

  bool get supportsPasswordReset;

  /// Sends a password-reset e-mail.
  Future<void> sendPasswordReset(String email);

  Future<AppUser> continueAsGuest();

  Future<void> signOut();

  Future<AppUser> updateProfile({String? displayName, String? level});
}

/// Shared validation used by both implementations and the forms.
class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
    if (!_email.hasMatch(v.trim())) return 'Email không hợp lệ';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  static String? displayName(String? v) {
    if (v == null || v.trim().length < 2) return 'Tên tối thiểu 2 ký tự';
    if (v.trim().length > 40) return 'Tên tối đa 40 ký tự';
    return null;
  }
}

/// On-device accounts for demo mode. Passwords are stored as salted,
/// iterated SHA-256 hashes (never in clear text). Data stays on the device;
/// the first account created on a device (or an e-mail listed in
/// `SINGLEARN_LOCAL_ADMINS`) is the local content admin.
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._store);

  static const accountsBox = 'local_accounts';
  static const _sessionBox = 'session';
  static const _hashRounds = 10000;

  final LocalStore _store;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  AppUser? get current => _current;

  @override
  Stream<AppUser?> watch() async* {
    yield _current;
    yield* _controller.stream;
  }

  void _set(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  bool get supportsGoogle => false;

  @override
  bool get supportsPasswordReset => false;

  static String hashPassword(String password, String salt) {
    List<int> bytes = utf8.encode('$salt:$password');
    for (var i = 0; i < _hashRounds; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return base64Encode(bytes);
  }

  static String _newSalt() {
    final r = Random.secure();
    return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  AppUser _toUser(Map<String, dynamic> a) => AppUser(
        uid: a['uid'] as String,
        email: a['email'] as String,
        displayName: a['displayName'] as String,
        isAdmin: (a['isAdmin'] as bool? ?? false) ||
            AppConfig.localAdminEmails.contains(a['email']),
        level: a['level'] as String?,
      );

  @override
  Future<void> restore() async {
    final session = await _store.get(_sessionBox, 'current');
    if (session == null) return _set(null);
    if (session['guest'] == true) return _set(AppUser.guest());
    final email = session['email'] as String?;
    final account = email == null ? null : await _store.get(accountsBox, email);
    _set(account == null ? null : _toUser(account));
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final key = email.trim().toLowerCase();
    final error = AuthValidators.email(key) ??
        AuthValidators.password(password) ??
        AuthValidators.displayName(displayName);
    if (error != null) throw AuthFailure(error);
    if (await _store.get(accountsBox, key) != null) {
      throw const AuthFailure('Email này đã được đăng ký');
    }
    final isFirst = (await _store.entries(accountsBox)).isEmpty;
    final salt = _newSalt();
    final account = {
      'uid': 'local-${const Uuid().v4()}',
      'email': key,
      'displayName': displayName.trim(),
      'salt': salt,
      'hash': hashPassword(password, salt),
      'isAdmin': isFirst,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    await _store.put(accountsBox, key, account);
    await _store.put(_sessionBox, 'current', {'email': key});
    final user = _toUser(account);
    _set(user);
    return user;
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    final key = email.trim().toLowerCase();
    final account = await _store.get(accountsBox, key);
    if (account == null ||
        hashPassword(password, account['salt'] as String) != account['hash']) {
      throw const AuthFailure('Email hoặc mật khẩu không đúng');
    }
    await _store.put(_sessionBox, 'current', {'email': key});
    final user = _toUser(account);
    _set(user);
    return user;
  }

  @override
  Future<AppUser> signInWithGoogle() async => throw const AuthFailure(
        'Đăng nhập Google cần cấu hình Firebase (chế độ đám mây).',
      );

  @override
  Future<void> sendPasswordReset(String email) async => throw const AuthFailure(
        'Chế độ demo không gửi được email. Hãy cấu hình Firebase để dùng '
        'chức năng quên mật khẩu.',
      );

  @override
  Future<AppUser> continueAsGuest() async {
    await _store.put(_sessionBox, 'current', {'guest': true});
    final user = AppUser.guest();
    _set(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    await _store.delete(_sessionBox, 'current');
    _set(null);
  }

  @override
  Future<AppUser> updateProfile({String? displayName, String? level}) async {
    final user = _current;
    if (user == null) throw const AuthFailure('Chưa đăng nhập');
    if (displayName != null) {
      final err = AuthValidators.displayName(displayName);
      if (err != null) throw AuthFailure(err);
    }
    if (user.isGuest) {
      final next = user.copyWith(level: level);
      _set(next);
      return next;
    }
    final account = (await _store.get(accountsBox, user.email))!;
    if (displayName != null) account['displayName'] = displayName.trim();
    if (level != null) account['level'] = level;
    await _store.put(accountsBox, user.email, account);
    final next = _toUser(account);
    _set(next);
    return next;
  }

  /// All local accounts (public fields only) – used by local-mode social
  /// features to find friends on the same device.
  Future<List<AppUser>> localAccounts() async => [
        for (final a in await _store.values(accountsBox)) _toUser(a),
      ];
}
