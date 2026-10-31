import '../models/task_model.dart';
import '../services/task_service.dart';

/// Pure task list helpers shared by [TaskProvider].
abstract final class TaskListQueries {
  static List<Task> tasksDueToday(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return tasks.where((task) {
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      if (task.dueDate != null) {
        final taskDate = DateTime(
          task.dueDate!.year,
          task.dueDate!.month,
          task.dueDate!.day,
        );
        if (taskDate.isAtSameMomentAs(today)) {
          return true;
        }
      }

      if (task.dueDate == null &&
          (task.status == TaskStatus.todo ||
              task.status == TaskStatus.inProgress)) {
        return true;
      }

      return false;
    }).toList();
  }

  static List<Task> upcomingTasks(List<Task> tasks) {
    final now = DateTime.now();
    return tasks.where((task) {
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      if (task.dueDate == null) {
        return false;
      }

      final isInFuture = task.dueDate!.isAfter(now);
      final isNotToday = !task.isDueToday;

      return isInFuture && isNotToday;
    }).toList();
  }

  static List<Task> inProgressTasks(List<Task> tasks) {
    return tasks.where((task) => task.status == TaskStatus.inProgress).toList();
  }

  static List<Task> completedTasks(List<Task> tasks) {
    return tasks.where((task) => task.status == TaskStatus.completed).toList();
  }

  static List<Task> filterAndSort({
    required List<Task> tasks,
    required String sortBy,
    required String filterBy,
    required String searchQuery,
    TaskPriority? priorityFilter,
    TaskCategory? categoryFilter,
    required TaskService taskService,
  }) {
    var filtered = List<Task>.from(tasks);

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (task) =>
                task.title.toLowerCase().contains(query) ||
                task.description.toLowerCase().contains(query) ||
                task.tags.any((tag) => tag.toLowerCase().contains(query)),
          )
          .toList();
    }

    if (priorityFilter != null) {
      filtered =
          filtered.where((task) => task.priority == priorityFilter).toList();
    }

    if (categoryFilter != null) {
      filtered =
          filtered.where((task) => task.category == categoryFilter).toList();
    }

    if (filterBy != 'all') {
      filtered = filtered.where((task) {
        switch (filterBy) {
          case 'work':
            return task.category == TaskCategory.work;
          case 'personal':
            return task.category == TaskCategory.personal;
          case 'high':
            return task.priority == TaskPriority.high;
          case 'urgent':
            return task.priority == TaskPriority.urgent;
          default:
            return true;
        }
      }).toList();
    }

    return taskService.sortTasks(filtered, sortBy);
  }
}
