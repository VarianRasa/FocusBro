import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/reminder_reliability_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReminderReliabilityService.instance.clearHistory();
  });

  test('records reminder history and summary counts', () async {
    final service = ReminderReliabilityService.instance;
    final scheduledFor = DateTime(2026, 1, 1, 9);

    await service.recordScheduled(
      notificationId: 1,
      type: 'task',
      title: 'Write report',
      scheduledFor: scheduledFor,
      payload: 'task_alert:task-1',
    );
    await service.recordFailed(
      notificationId: 2,
      type: 'task',
      title: 'Send invoice',
      reason: 'Permission denied',
      scheduledFor: scheduledFor,
      payload: 'task_alert:task-2',
    );
    await service.recordSnoozed(
      taskId: 'task-3',
      title: 'Read notes',
      snoozedUntil: scheduledFor,
      duration: const Duration(minutes: 30),
    );

    final summary = await service.getSummary(days: 365);
    final history = await service.getHistory();

    expect(summary.total, 3);
    expect(summary.scheduled, 1);
    expect(summary.delivered, 0);
    expect(summary.failed, 1);
    expect(summary.snoozed, 1);
    expect(summary.needsAttention, isTrue);
    expect(
        history.first.createdAt.isAfter(history.last.createdAt) ||
            history.first.createdAt.isAtSameMomentAs(history.last.createdAt),
        isTrue);
  });
}
