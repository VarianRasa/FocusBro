import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:focusbro/models/session_notification_data.dart';
import 'package:focusbro/services/session_notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const notificationsChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({
      'follow_up_delay_minutes': 1,
    });
    calls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });

    await SessionNotificationService().initialize();
    calls.clear();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationsChannel, null);
  });

  testWidgets('follow-up notification is scheduled without blocking',
      (tester) async {
    try {
      const data = SessionNotificationData(
        sessionType: 'work',
        sessionNumber: 1,
        totalSessions: 4,
        duration: 1500,
        isAllSessionsComplete: false,
        totalFocusTime: 1500,
        currentStreak: 1,
      );

      final notificationFuture =
          SessionNotificationService().showSessionCompleteNotification(data);
      await tester.pump();

      expect(calls.map((call) => call.method), contains('show'));
      expect(calls.map((call) => call.method), contains('zonedSchedule'));

      await notificationFuture;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
