import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:focusbro/firebase_options.dart';

class FirebaseEmulatorConfig {
  static const bool useEmulators =
      bool.fromEnvironment('USE_FIREBASE_EMULATORS');
  static const String _hostOverride =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST');
  static const int authPort = int.fromEnvironment(
    'FIREBASE_AUTH_EMULATOR_PORT',
    defaultValue: 9099,
  );
  static const int firestorePort = int.fromEnvironment(
    'FIRESTORE_EMULATOR_PORT',
    defaultValue: 8080,
  );
  static const int storagePort = int.fromEnvironment(
    'FIREBASE_STORAGE_EMULATOR_PORT',
    defaultValue: 9199,
  );
  static bool _firebaseReady = false;

  static bool get isFirebaseReady => _firebaseReady;

  static String get host {
    final override = _hostOverride.trim();
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  static Future<void> initialize() async {
    _firebaseReady = false;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      await configureIfEnabled();
      _firebaseReady = true;
    } catch (_) {
      _firebaseReady = false;
      rethrow;
    }
  }

  static Future<bool> configureIfEnabled() async {
    if (!useEmulators) return false;

    await FirebaseAuth.instance.useAuthEmulator(host, authPort);
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    FirebaseStorage.instance.useStorageEmulator(host, storagePort);

    debugPrint(
      'Firebase emulators enabled: Auth $host:$authPort, '
      'Firestore $host:$firestorePort, Storage $host:$storagePort',
    );
    return true;
  }
}
