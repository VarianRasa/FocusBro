import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/notification_blocking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const permissionsChannel =
      MethodChannel('flutter.baseflow.com/permissions/methods');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, null);
  });

  test('startup checks Android notification access without requesting it',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});

    var statusCheckCount = 0;
    var requestCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissionsChannel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          statusCheckCount++;
          return 0;
        case 'requestPermissions':
          requestCount++;
          return <int, int>{};
        default:
          return null;
      }
    });

    await NotificationBlockingService().initialize();

    expect(statusCheckCount, greaterThan(0));
    expect(requestCount, 0);
  });
}
