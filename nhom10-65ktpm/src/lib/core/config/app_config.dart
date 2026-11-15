import 'package:firebase_core/firebase_core.dart';

/// Build-time configuration.
///
/// Firebase is optional. When the `FIREBASE_*` values are passed with
/// `--dart-define` (or `--dart-define-from-file=firebase.env.json`, a file that
/// is ignored by Git), the app runs in **cloud mode**: Firebase Auth,
/// Firestore sync, Storage and Messaging. Without them it runs in **demo /
/// local mode**: every feature works on-device with local accounts and the
/// bundled song library, as required by section 3.3 of the project outline.
class AppConfig {
  const AppConfig._();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const String _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// Comma separated list of e-mails treated as content admins in local mode
  /// (cloud mode uses the `admin` custom claim instead).
  static const String _localAdmins =
      String.fromEnvironment('SINGLEARN_LOCAL_ADMINS');

  static bool get isFirebaseConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: _apiKey,
        appId: _appId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );

  static Set<String> get localAdminEmails => _localAdmins
      .split(',')
      .map((e) => e.trim().toLowerCase())
      .where((e) => e.isNotEmpty)
      .toSet();
}
