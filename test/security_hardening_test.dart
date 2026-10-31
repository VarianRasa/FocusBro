import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/services/backup_service.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/secure_storage_service.dart';
import 'package:focusbro/services/voice_notes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemorySecureStorageBackend secureStorage;

  setUp(() async {
    secureStorage = InMemorySecureStorageBackend();
    SecureStorageService.instance.setBackendForTesting(secureStorage);
    SharedPreferences.setMockInitialValues({});
    await AppLockService.instance.resetForTesting();
    await CloudSyncService().resetForTesting();
    await VoiceNotesService().resetForTesting();
    await DatabaseHelper().deleteDatabase();
  });

  test('set PIN stores a versioned salted hash instead of plain SHA-256',
      () async {
    final service = AppLockService.instance;
    await service.initialize();

    expect(await service.setPIN('123456'), isTrue);

    final storedHash = await _storedPinHash();
    expect(storedHash, isNot(_legacySha256('123456')));

    final decoded = jsonDecode(storedHash) as Map<String, dynamic>;
    expect(decoded['version'], 2);
    expect(decoded['algorithm'], 'pbkdf2_sha256');
    expect(decoded['salt'], isA<String>());
    expect(decoded['hash'], isA<String>());
    expect(decoded['iterations'], isA<int>());
  });

  test('salted PIN hashes differ for the same PIN', () async {
    final service = AppLockService.instance;
    await service.initialize();

    expect(await service.setPIN('123456'), isTrue);
    final firstHash = await _storedPinHash();

    expect(await service.setPIN('123456'), isTrue);
    final secondHash = await _storedPinHash();

    expect(firstHash, isNot(secondHash));
    expect(
        jsonDecode(firstHash)['salt'], isNot(jsonDecode(secondHash)['salt']));
    expect(service.verifyPIN('123456'), isTrue);
  });

  test('wrong PIN still fails against the new hash format', () async {
    final service = AppLockService.instance;
    await service.initialize();
    expect(await service.setPIN('654321'), isTrue);

    expect(service.verifyPIN('000000'), isFalse);
    expect(await service.unlockWithPIN('000000'), isFalse);
    expect(await service.unlockWithPIN('654321'), isTrue);
  });

  test('legacy SHA-256 PIN verifies once and migrates on unlock', () async {
    await _seedLegacyPin('246810');

    final service = AppLockService.instance;
    await service.initialize();

    expect(service.verifyPIN('246810'), isTrue);
    expect(service.verifyPIN('135790'), isFalse);
    expect(await service.unlockWithPIN('246810'), isTrue);

    final migratedHash = await _storedPinHash();
    expect(migratedHash, isNot(_legacySha256('246810')));
    expect(jsonDecode(migratedHash)['version'], 2);
  });

  test('cloud sync API key migrates from SharedPreferences to secure storage',
      () async {
    SharedPreferences.setMockInitialValues({
      'cloud_sync_backend_provider': 'custom',
      'cloud_sync_backend_endpoint': 'https://sync.example.test',
      'cloud_sync_backend_api_key': 'legacy-custom-token',
    });

    final service = CloudSyncService();
    await service.resetForTesting();
    await service.initialize();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cloud_sync_backend_api_key'), isNull);
    expect(
      await secureStorage.read(key: 'cloud_sync_backend_api_key'),
      'legacy-custom-token',
    );

    final readiness = await service.getBackendReadiness();
    expect(readiness.remoteBackendConfigured, isFalse);
    expect(readiness.missingItems, contains('Custom backend sync adapter'));
    expect(service.isRemoteBackendConfigured, isFalse);
  });

  test('cloud sync configureBackend stores new API key outside preferences',
      () async {
    final service = CloudSyncService();
    await service.initialize();

    await service.configureBackend(
      provider: CloudSyncBackendProvider.custom,
      endpoint: 'https://sync.example.test',
      apiKey: 'new-custom-token',
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('cloud_sync_backend_api_key'), isNull);
    expect(
      await secureStorage.read(key: 'cloud_sync_backend_api_key'),
      'new-custom-token',
    );
  });

  test('voice transcription API key migrates to secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'voice_transcription_backend_endpoint': 'https://voice.example.test',
      'voice_transcription_backend_api_key': 'legacy-voice-token',
    });

    final service = VoiceNotesService();
    await service.resetForTesting();

    final status = await service.getTranscriptionBackendStatus();
    final prefs = await SharedPreferences.getInstance();

    expect(status['configured'], isTrue);
    expect(status['hasApiKey'], isTrue);
    expect(prefs.getString('voice_transcription_backend_api_key'), isNull);
    expect(
      await secureStorage.read(key: 'voice_transcription_backend_api_key'),
      'legacy-voice-token',
    );
  });

  test('backup excludes sensitive SharedPreferences credentials', () async {
    SharedPreferences.setMockInitialValues({
      'safe_preference': 'keep-me',
      'cloud_sync_backend_api_key': 'do-not-export-cloud',
      'voice_transcription_backend_api_key': 'do-not-export-voice',
      'custom_auth_token': 'do-not-export-token',
      'hashed_pin': _legacySha256('123456'),
    });

    final result = await BackupService.instance.createBackup();
    expect(result.success, isTrue);
    addTearDown(() async {
      final path = result.filePath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    });

    final raw = await File(result.filePath!).readAsString();
    final backup = jsonDecode(raw) as Map<String, dynamic>;
    final data = backup['data'] as Map<String, dynamic>;
    final preferences =
        Map<String, dynamic>.from(data['shared_preferences'] as Map);

    expect(preferences['safe_preference'], 'keep-me');
    expect(preferences.containsKey('cloud_sync_backend_api_key'), isFalse);
    expect(preferences.containsKey('voice_transcription_backend_api_key'),
        isFalse);
    expect(preferences.containsKey('custom_auth_token'), isFalse);
    expect(preferences.containsKey('hashed_pin'), isFalse);
    expect(raw, isNot(contains('do-not-export-cloud')));
    expect(raw, isNot(contains('do-not-export-voice')));
    expect(raw, isNot(contains('do-not-export-token')));
  });
}

Future<String> _storedPinHash() async {
  final db = await DatabaseHelper().database;
  final rows = await db.query(
    'app_lock_settings',
    columns: ['hashed_pin'],
    where: 'id = ?',
    whereArgs: [1],
  );
  return rows.single['hashed_pin'] as String;
}

String _legacySha256(String pin) {
  return sha256.convert(utf8.encode(pin)).toString();
}

Future<void> _seedLegacyPin(String pin) async {
  final db = await DatabaseHelper().database;
  await db.update(
    'app_lock_settings',
    {
      'is_app_lock_enabled': 1,
      'lock_method': 'pin',
      'hashed_pin': _legacySha256(pin),
      'pin_length': pin.length,
      'lock_timeout_minutes': 5,
    },
    where: 'id = ?',
    whereArgs: [1],
  );
}
