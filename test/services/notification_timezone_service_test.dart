import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/notification_timezone_service.dart';

void main() {
  test('converts a local DateTime without prior timezone setup', () {
    final scheduledAt = DateTime(2026, 6, 9, 9, 30);

    final zoned = NotificationTimezoneService.fromLocal(scheduledAt);

    expect(zoned.millisecondsSinceEpoch, scheduledAt.millisecondsSinceEpoch);
  });
}
