import 'package:flutter_test/flutter_test.dart';

import 'package:focusbro/services/release_hardening_service.dart';

void main() {
  group('ReleaseHardeningService Firebase observability check', () {
    test('requires Firebase and observability initialization', () {
      final check = ReleaseHardeningService.buildFirebaseObservabilityCheck({
        'observability_initialized': false,
        'firebase_initialized': false,
        'analytics_enabled': false,
        'crash_reporting_enabled': false,
        'project_id': 'not_available',
      });

      expect(check.id, 'firebase_observability');
      expect(check.severity, ReleaseCheckSeverity.actionRequired);
      expect(check.message, contains('not initialized'));
    });

    test('warns when Firebase is ready but collection toggles are disabled',
        () {
      final check = ReleaseHardeningService.buildFirebaseObservabilityCheck({
        'observability_initialized': true,
        'firebase_initialized': true,
        'analytics_enabled': false,
        'crash_reporting_enabled': false,
        'project_id': 'focusbro-test',
      });

      expect(check.severity, ReleaseCheckSeverity.warning);
      expect(check.message, contains('focusbro-test'));
      expect(check.message, contains('disabled'));
    });

    test('passes when Firebase Analytics and Crashlytics are enabled', () {
      final check = ReleaseHardeningService.buildFirebaseObservabilityCheck({
        'observability_initialized': true,
        'firebase_initialized': true,
        'analytics_enabled': true,
        'crash_reporting_enabled': true,
        'project_id': 'focusbro-test',
      });

      expect(check.severity, ReleaseCheckSeverity.pass);
      expect(check.action, contains('test event'));
    });
  });
}
