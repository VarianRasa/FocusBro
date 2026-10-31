import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_model.dart';

/// Persists the task currently linked to a focus session.
class TaskActiveFocusStore {
  static const String storageKey = 'active_focus_task_id';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(storageKey);
  }

  Future<void> save(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, taskId);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }

  String? validateAgainstTasks(String? taskId, List<Task> tasks) {
    if (taskId == null) return null;

    final isValid = tasks.any(
      (task) =>
          task.id == taskId &&
          task.status != TaskStatus.completed &&
          task.status != TaskStatus.cancelled,
    );

    if (!isValid) {
      unawaited(clear());
      return null;
    }

    return taskId;
  }
}
