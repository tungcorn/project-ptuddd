import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import 'core/cloud/firebase_services.dart';
import 'core/config/app_config.dart';
import 'core/providers.dart';
import 'core/services/audio_engine.dart';
import 'core/storage/local_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/social/data/social_repository.dart';
import 'singlearn_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await bootstrap());
}

/// Initializes storage, audio and (optionally) Firebase and returns the root
/// widget. Shared by `main` and the on-device integration tests.
Future<Widget> bootstrap() async {
  await Hive.initFlutter('singlearn');
  final store = LocalStore();
  final audio = await AudioServiceEngine.init();

  final overrides = <Override>[
    localStoreProvider.overrideWithValue(store),
    audioEngineProvider.overrideWithValue(audio),
  ];

  AuthRepository auth;
  if (AppConfig.isFirebaseConfigured) {
    // Cloud mode: Firebase Auth + Firestore sync + Storage uploads.
    await Firebase.initializeApp(options: AppConfig.firebaseOptions);
    final db = FirebaseFirestore.instance;
    auth = FirebaseAuthRepository(FirebaseAuth.instance, db);
    overrides.addAll([
      remoteStoreProvider.overrideWithValue(FirestoreRemoteStore(db)),
      socialRepositoryProvider.overrideWithValue(FirestoreSocialRepository(db)),
      mediaUploaderProvider
          .overrideWithValue(CloudMediaUploader(FirebaseStorage.instance)),
    ]);
  } else {
    // Demo / local mode: everything stays on the device.
    auth = LocalAuthRepository(store);
    overrides.add(
        socialRepositoryProvider.overrideWithValue(LocalSocialRepository(store)));
  }
  overrides.add(authRepositoryProvider.overrideWithValue(auth));
  // Restore the previous session before the first frame (bounded so a slow
  // network in cloud mode cannot block start-up).
  await auth.restore().timeout(const Duration(seconds: 6), onTimeout: () {});

  return ProviderScope(overrides: overrides, child: const SingLearnApp());
}
