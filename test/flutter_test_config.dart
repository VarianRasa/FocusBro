import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final testStorageDirectory = Directory(
    '.dart_tool/test_storage/${Isolate.current.hashCode}',
  );
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<dynamic> returnNull(MethodCall _) async => null;

  messenger.allMessagesHandler = (channel, handler, message) {
    if (handler != null) return handler(message);
    if (channel == 'xyz.luan/audioplayers.global/events' ||
        channel.startsWith('xyz.luan/audioplayers/events/')) {
      return Future.value(
        const StandardMethodCodec().encodeSuccessEnvelope(null),
      );
    }
    return null;
  };

  for (final channelName in const [
    'xyz.luan/audioplayers.global',
    'xyz.luan/audioplayers',
    'flutter_tts',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(channelName), returnNull);
  }

  messenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/permissions/methods'),
    (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
        case 'checkServiceStatus':
          return 0;
        case 'requestPermissions':
          return <int, int>{};
        case 'openAppSettings':
        case 'shouldShowRequestPermissionRationale':
          return false;
        default:
          return null;
      }
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/local_auth'),
    (call) async {
      switch (call.method) {
        case 'getAvailableBiometrics':
          return <String>[];
        case 'authenticate':
        case 'stopAuthentication':
          return false;
        default:
          return null;
      }
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async {
      switch (call.method) {
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getTemporaryDirectory':
          await testStorageDirectory.create(recursive: true);
          return testStorageDirectory.path;
        default:
          return null;
      }
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/package_info'),
    (call) async => switch (call.method) {
      'getAll' => {
          'appName': 'FocusBro',
          'packageName': 'com.example.focusbro',
          'version': '1.0.0',
          'buildNumber': '1',
          'buildSignature': '',
          'installerStore': null,
        },
      _ => null,
    },
  );

  messenger.setMockMethodCallHandler(
    const MethodChannel('github.com/aaassseee/screen_brightness'),
    (call) async => switch (call.method) {
      'getScreenBrightness' || 'getSystemScreenBrightness' => 1.0,
      _ => null,
    },
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({'show_onboarding': false});
    SecureStorageService.instance.setBackendForTesting(
      InMemorySecureStorageBackend(),
    );
  });

  await testMain();
}
