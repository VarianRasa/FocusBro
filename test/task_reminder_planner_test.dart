import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/services/task_reminder_planner.dart';

void main() {
  group('TaskReminderPlanner', () {
    test('suggestedLeadTime follows task priority', () {
      expect(
        TaskReminderPlanner.suggestedLeadTime(
          _task(
            id: 'urgent',
            title: 'Urgent',
            priority: TaskPriority.urgent,
          ),
        ),
        const Duration(hours: 1),
      );
      expect(
        TaskReminderPlanner.suggestedLeadTime(
          _task(id: 'low', title: 'Low', priority: TaskPriority.low),
        ),
        const Duration(hours: 12),
      );
    });

    test('buildOverdueDigest prioritizes urgent overdue open tasks', () {
      final now = DateTime(2026, 5, 7, 10);
      final digest = TaskReminderPlanner.buildOverdueDigest(
        [
          _task(
            id: 'low-old',
            title: 'Low old',
            priority: TaskPriority.low,
            dueDate: now.subtract(const Duration(days: 3)),
          ),
          _task(
            id: 'urgent-recent',
            title: 'Urgent recent',
            priority: TaskPriority.urgent,
            dueDate: now.subtract(const Duration(hours: 2)),
          ),
          _task(
            id: 'closed',
            title: 'Closed urgent',
            priority: TaskPriority.urgent,
            status: TaskStatus.completed,
            dueDate: now.subtract(const Duration(days: 1)),
          ),
        ],
        now: now,
      );

      expect(digest.overdueCount, 2);
      expect(digest.urgentOverdueCount, 1);
      expect(digest.topOverdueTasks.first.id, 'urgent-recent');
      expect(digest.title, '1 high-priority overdue task');
    });

    test('buildOverdueDigest counts today and upcoming tasks', () {
      final now = DateTime(2026, 5, 7, 10);
      final digest = TaskReminderPlanner.buildOverdueDigest(
        [
          _task(
            id: 'today',
            title: 'Due today',
            dueDate: DateTime(2026, 5, 7, 18),
          ),
          _task(
            id: 'tomorrow',
            title: 'Due tomorrow',
            dueDate: DateTime(2026, 5, 8, 9),
          ),
        ],
        now: now,
      );

      expect(digest.overdueCount, 0);
      expect(digest.dueTodayCount, 1);
      expect(digest.upcomingCount, 2);
      expect(digest.summary, '1 task due today.');
    });

    test('snoozedDueDate moves the due date from the current time', () {
      final now = DateTime(2026, 5, 7, 10);
      final task = _task(
        id: 'overdue',
        title: 'Overdue',
        dueDate: now.subtract(const Duration(days: 1)),
      );

      final snoozed = TaskReminderPlanner.snoozedDueDate(
        task,
        const Duration(days: 1, hours: 2),
        now: now,
      );

      expect(snoozed, DateTime(2026, 5, 8, 12));
    });
  });
}

Task _task({
  required String id,
  required String title,
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.todo,
  DateTime? dueDate,
}) {
  final createdAt = DateTime(2026, 5, 1);
  return Task(
    id: id,
    title: title,
    priority: priority,
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
    dueDate: dueDate,
  );
}
