import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/firebase_emulator_config.dart';

void main() {
  group('Firebase local configuration', () {
    test('selects the FocusBro Firebase project locally', () {
      final config = _readJsonObject('.firebaserc');
      final projects = _objectAt(config, 'projects');

      expect(projects['default'], 'focusbro-35cd2');
    });

    test('points Firestore to local rules, indexes, and emulators', () {
      final config = _readJsonObject('firebase.json');
      final firestore = _objectAt(config, 'firestore');
      final emulators = _objectAt(config, 'emulators');
      final authEmulator = _objectAt(emulators, 'auth');
      final firestoreEmulator = _objectAt(emulators, 'firestore');
      final storageEmulator = _objectAt(emulators, 'storage');
      final uiEmulator = _objectAt(emulators, 'ui');

      expect(firestore['rules'], 'firestore.rules');
      expect(firestore['indexes'], 'firestore.indexes.json');
      expect(authEmulator['port'], 9099);
      expect(firestoreEmulator['port'], 8080);
      expect(storageEmulator['port'], 9199);
      expect(uiEmulator['enabled'], isTrue);
      expect(uiEmulator['port'], 4000);
      expect(FirebaseEmulatorConfig.authPort, authEmulator['port']);
      expect(
        FirebaseEmulatorConfig.firestorePort,
        firestoreEmulator['port'],
      );
      expect(FirebaseEmulatorConfig.storagePort, storageEmulator['port']);
    });

    test('keeps Firestore rules owner scoped and deny-by-default', () {
      final rules = File('firestore.rules').readAsStringSync();

      expect(rules, contains('match /users/{uid}'));
      expect(rules, contains('request.auth.uid == uid'));
      expect(rules, contains('match /sync/v1/{collection}/{recordId}'));
      expect(rules, contains('function supportedCollection'));
      expect(rules, contains('function validRecord(recordId)'));
      expect(rules, contains("request.resource.data.entityId == recordId"));
      expect(rules, contains('allow delete: if false'));
      expect(rules, isNot(contains("'files'")));
      expect(rules, contains('match /{document=**}'));
      expect(rules, contains('allow read, write: if false'));
    });

    test('keeps Firestore indexes JSON valid and minimal', () {
      final indexes = _readJsonObject('firestore.indexes.json');

      expect(indexes['indexes'], isA<List<dynamic>>());
      expect(indexes['fieldOverrides'], isA<List<dynamic>>());
    });
  });
}

Map<String, dynamic> _readJsonObject(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return Map<String, dynamic>.from(decoded as Map);
}

Map<String, dynamic> _objectAt(Map<String, dynamic> parent, String key) {
  return Map<String, dynamic>.from(parent[key] as Map);
}
