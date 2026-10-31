import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/screen_brightness_service.dart';
import 'package:focusbro/services/notification_blocking_service.dart';
import 'package:focusbro/services/social_media_blocking_service.dart';
import 'package:focusbro/services/focus_mode_service.dart';

void main() {
  group('Focus Mode Services Tests', () {
    group('ScreenBrightnessService Tests', () {
      late ScreenBrightnessService service;

      setUp(() {
        service = ScreenBrightnessService();
      });

      test('should initialize successfully', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should have default settings', () async {
        await service.initialize();
        expect(service.autoDimEnabled, isTrue);
        expect(service.isDimmed, isFalse);
        expect(service.dimmedBrightness, equals(0.2));
      });

      test('should update dimmed brightness', () async {
        await service.initialize();
        await service.setDimmedBrightness(0.3);
        expect(service.dimmedBrightness, equals(0.3));
      });

      test('should toggle auto-dim setting', () async {
        await service.initialize();
        await service.setAutoDimEnabled(false);
        expect(service.autoDimEnabled, isFalse);
      });

      test('should provide brightness status', () async {
        await service.initialize();
        final status = service.getBrightnessStatus();
        expect(status['isDimmed'], isFalse);
        expect(status['autoDimEnabled'], isTrue);
        expect(status['dimmedBrightness'], equals(0.2));
      });

      test('should format brightness percentage correctly', () {
        expect(service.getBrightnessPercentage(0.5), equals('50%'));
        expect(service.getBrightnessPercentage(0.2), equals('20%'));
        expect(service.getBrightnessPercentage(1.0), equals('100%'));
      });
    });

    group('NotificationBlockingService Tests', () {
      late NotificationBlockingService service;

      setUp(() {
        service = NotificationBlockingService();
      });

      test('should initialize successfully', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should have default settings', () async {
        await service.initialize();
        expect(service.doNotDisturbEnabled, isTrue);
        expect(service.isBlocking, isFalse);
        expect(service.blockedApps.isNotEmpty, isTrue);
      });

      test('should manage blocked apps list', () async {
        await service.initialize();
        final initialCount = service.blockedApps.length;

        await service.addBlockedApp('com.test.app');
        expect(service.blockedApps.length, equals(initialCount + 1));
        expect(service.blockedApps.contains('com.test.app'), isTrue);

        await service.removeBlockedApp('com.test.app');
        expect(service.blockedApps.length, equals(initialCount));
        expect(service.blockedApps.contains('com.test.app'), isFalse);
      });

      test('should toggle Do Not Disturb setting', () async {
        await service.initialize();
        await service.setDoNotDisturbEnabled(false);
        expect(service.doNotDisturbEnabled, isFalse);
      });

      test('should provide blocking status', () async {
        await service.initialize();
        final status = service.getBlockingStatus();
        expect(status['isBlocking'], isFalse);
        expect(status['doNotDisturbEnabled'], isTrue);
        expect(status['blockedAppsCount'], greaterThan(0));
      });

      test('should provide friendly app names', () async {
        await service.initialize();
        final appNames = service.getBlockedAppNames();
        expect(appNames['com.whatsapp'], equals('WhatsApp'));
        expect(appNames['com.instagram.android'], equals('Instagram'));
        expect(appNames['com.facebook.katana'], equals('Facebook'));
      });
    });

    group('SocialMediaBlockingService Tests', () {
      late SocialMediaBlockingService service;

      setUp(() {
        service = SocialMediaBlockingService();
      });

      test('should initialize successfully', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should have default settings', () async {
        await service.initialize();
        expect(service.blockApps, isTrue);
        expect(service.blockWebsites, isTrue);
        expect(service.showBlockingOverlay, isTrue);
        expect(service.isBlocking, isFalse);
      });

      test('should manage blocked social apps', () async {
        await service.initialize();
        final initialCount = service.blockedSocialApps.length;

        await service.addBlockedApp('com.test.social');
        expect(service.blockedSocialApps.length, equals(initialCount + 1));
        expect(service.blockedSocialApps.contains('com.test.social'), isTrue);

        await service.removeBlockedApp('com.test.social');
        expect(service.blockedSocialApps.length, equals(initialCount));
        expect(service.blockedSocialApps.contains('com.test.social'), isFalse);
      });

      test('should manage blocked websites', () async {
        await service.initialize();
        final initialCount = service.blockedWebsites.length;

        await service.addBlockedWebsite('test.com');
        expect(service.blockedWebsites.length, equals(initialCount + 1));
        expect(service.blockedWebsites.contains('test.com'), isTrue);

        await service.removeBlockedWebsite('test.com');
        expect(service.blockedWebsites.length, equals(initialCount));
        expect(service.blockedWebsites.contains('test.com'), isFalse);
      });

      test('should detect blocked websites', () async {
        await service.initialize();

        // Test default blocked sites
        expect(service.isWebsiteBlocked('https://facebook.com/test'),
            isFalse); // Not blocking yet

        // Enable blocking
        await service.enableBlocking();
        expect(service.isWebsiteBlocked('https://facebook.com/test'), isTrue);
        expect(service.isWebsiteBlocked('https://instagram.com/test'), isTrue);
        expect(service.isWebsiteBlocked('https://google.com/test'), isFalse);
      });

      test('should toggle blocking settings', () async {
        await service.initialize();

        await service.setAppBlockingEnabled(false);
        expect(service.blockApps, isFalse);

        await service.setWebsiteBlockingEnabled(false);
        expect(service.blockWebsites, isFalse);

        await service.setOverlayEnabled(false);
        expect(service.showBlockingOverlay, isFalse);
      });

      test('should provide blocking status', () async {
        await service.initialize();
        final status = service.getBlockingStatus();
        expect(status['isBlocking'], isFalse);
        expect(status['blockApps'], isTrue);
        expect(status['blockWebsites'], isTrue);
        expect(status['blockedAppsCount'], greaterThan(0));
        expect(status['blockedWebsitesCount'], greaterThan(0));
      });

      test('should provide website blocking message', () {
        final message =
            service.getWebsiteBlockingMessage('https://facebook.com');
        expect(message.contains('blocked during focus sessions'), isTrue);
        expect(message.contains('Stay focused!'), isTrue);
      });
    });

    group('FocusModeService Tests', () {
      late FocusModeService service;

      setUp(() {
        service = FocusModeService();
      });

      test('should initialize successfully', () async {
        await service.initialize();
        expect(service.isInitialized, isTrue);
      });

      test('should have default settings', () async {
        await service.initialize();
        expect(service.enableScreenDimming, isTrue);
        expect(service.enableNotificationBlocking, isTrue);
        expect(service.enableSocialMediaBlocking, isFalse);
        expect(service.autoEnableOnFocusStart, isTrue);
        expect(service.showFocusModeIndicator, isTrue);
        expect(service.isFocusModeActive, isFalse);
      });

      test('should provide access to individual services', () async {
        await service.initialize();
        expect(service.brightnessService, isNotNull);
        expect(service.notificationService, isNotNull);
        expect(service.socialMediaService, isNotNull);
      });

      test('should toggle focus mode settings', () async {
        await service.initialize();

        await service.setScreenDimmingEnabled(false);
        expect(service.enableScreenDimming, isFalse);

        await service.setNotificationBlockingEnabled(false);
        expect(service.enableNotificationBlocking, isFalse);

        await service.setSocialMediaBlockingEnabled(true);
        expect(service.enableSocialMediaBlocking, isTrue);

        await service.setAutoEnableOnFocusStart(false);
        expect(service.autoEnableOnFocusStart, isFalse);

        await service.setShowFocusModeIndicator(false);
        expect(service.showFocusModeIndicator, isFalse);
      });

      test('should provide comprehensive status', () async {
        await service.initialize();
        final status = service.getFocusModeStatus();

        expect(status['isActive'], isFalse);
        expect(status['enableScreenDimming'], isTrue);
        expect(status['enableNotificationBlocking'], isTrue);
        expect(status['enableSocialMediaBlocking'], isFalse);
        expect(status['brightness'], isNotNull);
        expect(status['notifications'], isNotNull);
        expect(status['socialMedia'], isNotNull);
      });

      test('should provide focus mode summary', () async {
        await service.initialize();

        String summary = service.getFocusModeSummary();
        expect(summary, equals('Focus mode is disabled'));

        // Note: Actual enabling would require platform-specific implementations
        // This test verifies the summary logic
      });

      test('should track active features', () async {
        await service.initialize();

        List<String> activeFeatures = service.getActiveFeatures();
        expect(activeFeatures,
            isEmpty); // No features active when focus mode is off
      });
    });

    group('Integration Tests', () {
      test('should coordinate all services together', () async {
        final focusModeService = FocusModeService();
        await focusModeService.initialize();

        // Verify all services are accessible
        expect(focusModeService.brightnessService.isInitialized, isTrue);
        expect(focusModeService.notificationService.isInitialized, isTrue);
        expect(focusModeService.socialMediaService.isInitialized, isTrue);

        // Test settings coordination
        await focusModeService.setScreenDimmingEnabled(true);
        await focusModeService.setNotificationBlockingEnabled(true);
        await focusModeService.setSocialMediaBlockingEnabled(false);

        final status = focusModeService.getFocusModeStatus();
        expect(status['enableScreenDimming'], isTrue);
        expect(status['enableNotificationBlocking'], isTrue);
        expect(status['enableSocialMediaBlocking'], isFalse);
      });
    });
  });
}
