import 'package:flutter_test/flutter_test.dart';

import 'package:focusbro/services/firebase_observability_service.dart';

void main() {
  group('FirebaseObservabilityService sanitization', () {
    test('normalizes event names to Firebase-safe snake case', () {
      expect(
        FirebaseObservabilityService.normalizeEventNameForTesting(
          'Cloud Sync Completed!',
        ),
        'cloud_sync_completed',
      );
      expect(
        FirebaseObservabilityService.normalizeEventNameForTesting(
          '123 Backup Restore Completed With A Very Long Event Name',
        ),
        'event_123_backup_restore_completed_with',
      );
    });

    test('removes null and sensitive parameter keys', () {
      final sanitized =
          FirebaseObservabilityService.sanitizeParametersForTesting({
        'provider': 'firebase',
        'email': 'person@example.com',
        'password': 'secret',
        'task_title': 'private task',
        'note_content': 'private note',
        'file_path': 'C:/Users/MP2N2/secret.json',
        'item_count': null,
        'duration_ms': 45,
      });

      expect(sanitized, {
        'provider': 'firebase',
        'duration_ms': 45,
      });
    });

    test('keeps only Firebase-supported primitive parameter values', () {
      final sanitized =
          FirebaseObservabilityService.sanitizeParametersForTesting({
        'status': true,
        'duration_ms': 15,
        'ratio': 0.75,
        'feature': 'cloud_sync',
        'nested': {'unsafe': true},
        'items': [1, 2, 3],
        '123 odd key': 'normalized',
      });

      expect(sanitized, {
        'status': 1,
        'duration_ms': 15,
        'ratio': 0.75,
        'feature': 'cloud_sync',
        'param_123_odd_key': 'normalized',
      });
    });
  });
}
