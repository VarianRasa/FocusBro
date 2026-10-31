import '../models/task_model.dart';
import '../models/notification_settings.dart';

/// Service for managing upcoming tasks with advanced filtering, sorting, and grouping
class UpcomingTaskService {
  /// Filter upcoming tasks based on various criteria
  static List<Task> filterTasks(
    List<Task> tasks, {
    UpcomingTaskFilter filter = UpcomingTaskFilter.all,
    TaskCategory? category,
    TaskPriority? priority,
    TimeRangeFilter? timeRange,
    String? searchQuery,
    bool onlyNeedsAttention = false,
  }) {
    List<Task> filtered = tasks.where((task) {
      // Basic upcoming task criteria
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      if (task.dueDate == null) return false;

      final now = DateTime.now();
      final isInFuture = task.dueDate!.isAfter(now);
      final isNotToday = !task.isDueToday;

      if (!isInFuture || !isNotToday) return false;

      return true;
    }).toList();

    // Apply specific filters
    switch (filter) {
      case UpcomingTaskFilter.thisWeek:
        filtered = filtered.where((task) => task.isDueThisWeek).toList();
        break;
      case UpcomingTaskFilter.nextWeek:
        final nextWeekRange = TimeRangeFilter.nextWeek;
        filtered = filtered
            .where((task) =>
                task.dueDate != null &&
                nextWeekRange.containsDate(task.dueDate!))
            .toList();
        break;
      case UpcomingTaskFilter.thisMonth:
        final thisMonthRange = TimeRangeFilter.thisMonth;
        filtered = filtered
            .where((task) =>
                task.dueDate != null &&
                thisMonthRange.containsDate(task.dueDate!))
            .toList();
        break;
      case UpcomingTaskFilter.needsAttention:
        filtered = filtered.where((task) => task.needsAttention).toList();
        break;
      case UpcomingTaskFilter.byCategory:
        if (category != null) {
          filtered =
              filtered.where((task) => task.category == category).toList();
        }
        break;
      case UpcomingTaskFilter.byPriority:
        if (priority != null) {
          filtered =
              filtered.where((task) => task.priority == priority).toList();
        }
        break;
      case UpcomingTaskFilter.all:
        break;
    }

    // Apply time range filter
    if (timeRange != null) {
      filtered = filtered
          .where((task) =>
              task.dueDate != null && timeRange.containsDate(task.dueDate!))
          .toList();
    }

    // Apply search query
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where((task) =>
              task.title.toLowerCase().contains(query) ||
              task.description.toLowerCase().contains(query) ||
              task.tags.any((tag) => tag.toLowerCase().contains(query)))
          .toList();
    }

    // Apply needs attention filter
    if (onlyNeedsAttention) {
      filtered = filtered.where((task) => task.needsAttention).toList();
    }

    return filtered;
  }

  /// Sort upcoming tasks based on specified criteria
  static List<Task> sortTasks(
    List<Task> tasks,
    UpcomingTaskSort sortBy, {
    bool ascending = true,
  }) {
    List<Task> sorted = List.from(tasks);

    switch (sortBy) {
      case UpcomingTaskSort.dueDate:
        sorted.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return ascending ? 1 : -1;
          if (b.dueDate == null) return ascending ? -1 : 1;
          return ascending
              ? a.dueDate!.compareTo(b.dueDate!)
              : b.dueDate!.compareTo(a.dueDate!);
        });
        break;
      case UpcomingTaskSort.priority:
        sorted.sort((a, b) {
          final priorityOrder = {
            TaskPriority.urgent: 4,
            TaskPriority.high: 3,
            TaskPriority.medium: 2,
            TaskPriority.low: 1,
          };
          final aValue = priorityOrder[a.priority] ?? 0;
          final bValue = priorityOrder[b.priority] ?? 0;
          return ascending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        });
        break;
      case UpcomingTaskSort.category:
        sorted.sort((a, b) {
          final comparison =
              a.category.displayName.compareTo(b.category.displayName);
          return ascending ? comparison : -comparison;
        });
        break;
      case UpcomingTaskSort.title:
        sorted.sort((a, b) {
          final comparison =
              a.title.toLowerCase().compareTo(b.title.toLowerCase());
          return ascending ? comparison : -comparison;
        });
        break;
      case UpcomingTaskSort.created:
        sorted.sort((a, b) {
          final comparison = a.createdAt.compareTo(b.createdAt);
          return ascending ? comparison : -comparison;
        });
        break;
      case UpcomingTaskSort.progress:
        sorted.sort((a, b) {
          final comparison = a.progress.compareTo(b.progress);
          return ascending ? comparison : -comparison;
        });
        break;
    }

    return sorted;
  }

  /// Group upcoming tasks based on specified criteria
  static Map<String, List<Task>> groupTasks(
    List<Task> tasks,
    UpcomingTaskGrouping groupBy,
  ) {
    Map<String, List<Task>> grouped = {};

    switch (groupBy) {
      case UpcomingTaskGrouping.dueDate:
        for (final task in tasks) {
          final key = task.relativeDueDate;
          grouped[key] = (grouped[key] ?? [])..add(task);
        }
        break;
      case UpcomingTaskGrouping.category:
        for (final task in tasks) {
          final key = task.category.displayName;
          grouped[key] = (grouped[key] ?? [])..add(task);
        }
        break;
      case UpcomingTaskGrouping.priority:
        for (final task in tasks) {
          final key = task.priority.displayName;
          grouped[key] = (grouped[key] ?? [])..add(task);
        }
        break;
      case UpcomingTaskGrouping.urgency:
        for (final task in tasks) {
          final key = task.urgencyLevel.label;
          grouped[key] = (grouped[key] ?? [])..add(task);
        }
        break;
      case UpcomingTaskGrouping.week:
        for (final task in tasks) {
          if (task.dueDate == null) continue;
          final weekStart =
              task.dueDate!.subtract(Duration(days: task.dueDate!.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          final key =
              'Week of ${_formatDate(weekStart)} - ${_formatDate(weekEnd)}';
          grouped[key] = (grouped[key] ?? [])..add(task);
        }
        break;
      case UpcomingTaskGrouping.none:
        grouped['All Tasks'] = tasks;
        break;
    }

    return grouped;
  }

  /// Get upcoming task statistics
  static Map<String, dynamic> getUpcomingTaskStats(List<Task> tasks) {
    final filtered = filterTasks(tasks);

    final byUrgency = <TaskUrgency, int>{};
    final byCategory = <TaskCategory, int>{};
    final byPriority = <TaskPriority, int>{};

    int needsAttentionCount = 0;
    int thisWeekCount = 0;
    int nextWeekCount = 0;
    double averageProgress = 0.0;

    for (final task in filtered) {
      // Count by urgency
      final urgency = task.urgencyLevel;
      byUrgency[urgency] = (byUrgency[urgency] ?? 0) + 1;

      // Count by category
      byCategory[task.category] = (byCategory[task.category] ?? 0) + 1;

      // Count by priority
      byPriority[task.priority] = (byPriority[task.priority] ?? 0) + 1;

      // Count special categories
      if (task.needsAttention) needsAttentionCount++;
      if (task.isDueThisWeek) thisWeekCount++;

      // Check next week
      final nextWeekRange = TimeRangeFilter.nextWeek;
      if (task.dueDate != null && nextWeekRange.containsDate(task.dueDate!)) {
        nextWeekCount++;
      }

      // Add to average progress
      averageProgress += task.progress;
    }

    if (filtered.isNotEmpty) {
      averageProgress /= filtered.length;
    }

    return {
      'total': filtered.length,
      'needsAttention': needsAttentionCount,
      'thisWeek': thisWeekCount,
      'nextWeek': nextWeekCount,
      'averageProgress': averageProgress,
      'byUrgency': byUrgency,
      'byCategory': byCategory,
      'byPriority': byPriority,
    };
  }

  /// Helper method to format date
  static String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  /// Get suggested actions for upcoming tasks
  static List<String> getSuggestedActions(List<Task> tasks) {
    final suggestions = <String>[];
    final stats = getUpcomingTaskStats(tasks);

    final needsAttention = stats['needsAttention'] as int;
    final thisWeek = stats['thisWeek'] as int;
    final averageProgress = stats['averageProgress'] as double;

    if (needsAttention > 0) {
      suggestions.add(
          '$needsAttention task${needsAttention > 1 ? 's' : ''} need${needsAttention == 1 ? 's' : ''} immediate attention');
    }

    if (thisWeek > 5) {
      suggestions
          .add('Heavy workload this week - consider rescheduling some tasks');
    }

    if (averageProgress < 0.1) {
      suggestions.add('Consider starting some tasks early to make progress');
    }

    return suggestions;
  }
}
