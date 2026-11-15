import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The signed-in learner (or the guest in demo mode).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.isGuest = false,
    this.isAdmin = false,
    this.level,
    this.isCloud = false,
  });

  static const guestUid = 'guest';

  factory AppUser.guest() => const AppUser(
        uid: guestUid,
        email: '',
        displayName: 'Khách',
        isGuest: true,
      );

  final String uid;
  final String email;
  final String displayName;
  final bool isGuest;
  final bool isAdmin;

  /// CEFR level chosen by the placement test (null until done).
  final String? level;

  /// True when backed by Firebase Auth.
  final bool isCloud;

  /// Short public code used to add friends (section 7.10).
  String get userCode => userCodeOf(uid);

  static String userCodeOf(String uid) {
    final digest = sha1.convert(utf8.encode(uid)).bytes;
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return [for (var i = 0; i < 6; i++) alphabet[digest[i] % alphabet.length]]
        .join();
  }

  AppUser copyWith({String? displayName, String? level, bool? isAdmin}) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        isGuest: isGuest,
        isAdmin: isAdmin ?? this.isAdmin,
        level: level ?? this.level,
        isCloud: isCloud,
      );
}

/// Error shown to the user (Vietnamese message).
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
