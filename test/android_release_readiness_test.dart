import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readProjectFile(String path) => File(path).readAsStringSync();

String _firstMatch(String text, RegExp pattern, String label) {
  final match = pattern.firstMatch(text);
  if (match == null) {
    fail('Unable to find $label in Android configuration.');
  }
  return match.group(1)!;
}

void main() {
  group('Android release readiness configuration', () {
    test('applicationId matches namespace and Firebase Android package', () {
      final buildGradle = _readProjectFile('android/app/build.gradle');
      final googleServices = jsonDecode(
        _readProjectFile('android/app/google-services.json'),
      ) as Map<String, dynamic>;
      final firebaseOptions = _readProjectFile('lib/firebase_options.dart');

      final namespace = _firstMatch(
        buildGradle,
        RegExp(r'''namespace\s*=?\s*["']([^"']+)["']'''),
        'namespace',
      );
      final applicationId = _firstMatch(
        buildGradle,
        RegExp(r'''applicationId\s*=?\s*["']([^"']+)["']'''),
        'applicationId',
      );
      final androidFirebaseBlock = _firstMatch(
        firebaseOptions,
        RegExp(
          r'static const FirebaseOptions android = FirebaseOptions\(([\s\S]*?)\);',
        ),
        'Android Firebase options',
      );
      final firebaseAndroidAppId = _firstMatch(
        androidFirebaseBlock,
        RegExp(r'''appId:\s*["']([^"']+)["']'''),
        'Android Firebase appId',
      );

      final clients = googleServices['client'] as List<dynamic>;
      final androidPackages = clients
          .map((client) => (client as Map<String, dynamic>)['client_info'])
          .whereType<Map<String, dynamic>>()
          .map((clientInfo) => clientInfo['android_client_info'])
          .whereType<Map<String, dynamic>>()
          .map((androidInfo) => androidInfo['package_name'])
          .whereType<String>()
          .toSet();
      final googleServicesAppIds = clients
          .map((client) => (client as Map<String, dynamic>)['client_info'])
          .whereType<Map<String, dynamic>>()
          .map((clientInfo) => clientInfo['mobilesdk_app_id'])
          .whereType<String>()
          .toSet();

      expect(namespace, applicationId);
      expect(androidPackages, contains(applicationId));
      expect(googleServicesAppIds, contains(firebaseAndroidAppId));
    });

    test('release signing uses key.properties and never debug signing', () {
      final buildGradle = _readProjectFile('android/app/build.gradle');
      final gitignore = _readProjectFile('.gitignore');

      expect(buildGradle, contains("rootProject.file('key.properties')"));
      expect(buildGradle, contains('hasReleaseSigningConfig'));
      expect(
          buildGradle, isNot(contains('signingConfig signingConfigs.debug')));
      expect(
        buildGradle,
        isNot(contains('signingConfig = signingConfigs.debug')),
      );
      expect(gitignore, contains('/android/key.properties'));
      expect(gitignore, contains('/android/app/*.jks'));
    });
  });
}
