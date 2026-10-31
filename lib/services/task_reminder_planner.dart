import '../models/task_model.dart';

class TaskReminderPlanner {
  const TaskReminderPlanner._();

  static Duration suggestedLeadTime(Task task) {
    switch (task.priority) {
      case TaskPriority.urgent:
        return const Duration(hours: 1);
      case TaskPriority.high:
        return const Duration(hours: 2);
      case TaskPriority.medium:
        return const Duration(hours: 6);
      case TaskPriority.low:
        return const Duration(hours: 12);
    }
  }

  static DateTime snoozedDueDate(
    Task task,
    Duration duration, {
    DateTime? now,
  }) {
    final baseTime = now ?? DateTime.now();
    return baseTime.add(duration);
  }

  static TaskReminderDigest buildOverdueDigest(
    List<Task> tasks, {
    DateTime? now,
    int limit = 5,
  }) {
    final reference = now ?? DateTime.now();
    final openTasks = tasks
        .where((task) =>
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.cancelled)
        .toList();

    final overdue = openTasks
        .where(
            (task) => task.dueDate != null && task.dueDate!.isBefore(reference))
        .toList()
      ..sort(_compareReminderPriority);

    final todayStart = DateTime(reference.year, reference.month, reference.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final dueToday = openTasks
        .where((task) =>
            task.dueDate != null &&
            !task.dueDate!.isBefore(todayStart) &&
            task.dueDate!.isBefore(tomorrowStart))
        .length;

    final upcoming = openTasks
        .where(
            (task) => task.dueDate != null && task.dueDate!.isAfter(reference))
        .length;

    final urgentOverdue = overdue
        .where((task) =>
            task.priority == TaskPriority.urgent ||
            task.priority == TaskPriority.high)
        .length;

    return TaskReminderDigest(
      overdueCount: overdue.length,
      urgentOverdueCount: urgentOverdue,
      dueTodayCount: dueToday,
      upcomingCount: upcoming,
      topOverdueTasks: overdue.take(limit).toList(),
      generatedAt: reference,
    );
  }

  static int _compareReminderPriority(Task a, Task b) {
    final priorityScore = b.priority.index.compareTo(a.priority.index);
    if (priorityScore != 0) return priorityScore;

    final aDue = a.dueDate ?? DateTime(9999);
    final bDue = b.dueDate ?? DateTime(9999);
    return aDue.compareTo(bDue);
  }
}

class TaskReminderDigest {
  final int overdueCount;
  final int urgentOverdueCount;
  final int dueTodayCount;
  final int upcomingCount;
  final List<Task> topOverdueTasks;
  final DateTime generatedAt;

  const TaskReminderDigest({
    required this.overdueCount,
    required this.urgentOverdueCount,
    required this.dueTodayCount,
    required this.upcomingCount,
    required this.topOverdueTasks,
    required this.generatedAt,
  });

  bool get hasOverdueTasks => overdueCount > 0;

  String get title {
    if (overdueCount == 0) return 'No overdue tasks';
    if (urgentOverdueCount > 0) {
      return '$urgentOverdueCount high-priority overdue task${urgentOverdueCount == 1 ? '' : 's'}';
    }
    return '$overdueCount overdue task${overdueCount == 1 ? '' : 's'}';
  }

  String get summary {
    if (overdueCount == 0) {
      return dueTodayCount == 0
          ? 'Your task queue is clear for today.'
          : '$dueTodayCount task${dueTodayCount == 1 ? '' : 's'} due today.';
    }

    final todayText = dueTodayCount == 0
        ? 'No additional tasks due today.'
        : '$dueTodayCount more due today.';
    return '$overdueCount overdue. $todayText';
  }

  String get suggestedAction {
    if (overdueCount == 0) return 'Keep today focused.';
    if (urgentOverdueCount > 0) {
      return 'Handle the highest-priority overdue task first or snooze it deliberately.';
    }
    return 'Review overdue tasks and snooze anything that is no longer actionable today.';
  }
}
