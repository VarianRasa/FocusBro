import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_model.dart';
import '../repositories/task_repository.dart';
import '../services/database_helper.dart';
import 'task_migration_contract.dart';
import '../utils/error_handler.dart';
import '../utils/cache_manager.dart';

/// Task management service with advanced features
class TaskService {
  static final TaskService _instance = TaskService._internal();
  factory TaskService() => _instance;
  TaskService._internal();

  final CacheManager _cache = CacheManager();
  SharedPreferences? _prefs;
  final CanonicalTaskRepository _taskRepository = CanonicalTaskRepository();

  List<Task> _tasks = [];
  List<Task> _persistedTasks = [];
  List<TaskMigrationIssue> _migrationIssues = [];
  bool _isInitialized = false;
  StreamController<List<Task>> _tasksController =
      StreamController<List<Task>>.broadcast();
  Future<void> _taskPersistenceQueue = Future<void>.value();

  // Cache keys
  static const String _tasksKey = 'tasks';
  static const String _taskStatsKey = 'task_stats';

  /// Initialize task service with robust error handling
  Future<void> initialize() async {
    try {
      debugPrint('TaskService: Starting initialization...');

      _prefs = await SharedPreferences.getInstance();
      debugPrint('TaskService: SharedPreferences initialized');

      await _loadTasks();
      _isInitialized = true;
      debugPrint(
          'TaskService: Tasks loaded successfully, count: ${_tasks.length}');

      // Emit initial tasks to stream
      _tasksController.add(List.from(_tasks));
      debugPrint('TaskService: Initial task stream emitted');
    } catch (e) {
      _isInitialized = false;
      debugPrint('TaskService: Initialization failed: $e');
      ErrorHandler.logError('TaskService initialization failed', e);
      throw Exception('Failed to initialize TaskService: ${e.toString()}');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) await initialize();
  }

  /// Get tasks stream
  Stream<List<Task>> get tasksStream => _tasksController.stream;

  /// Get all tasks
  List<Task> get tasks => List.unmodifiable(_tasks);

  /// Issues found while copying legacy preference entries into SQLite.
  List<TaskMigrationIssue> get migrationIssues =>
      List.unmodifiable(_migrationIssues);

  /// Load tasks from storage
  Future<void> _loadTasks() async {
    try {
      final preferenceEntries = _prefs?.getStringList(_tasksKey) ?? [];
      final sqliteTasks = await _taskRepository.loadAllTaskPayloads();
      final migrationBatch = TaskMigrationContract.decodePreferenceEntries(
        [
          ...sqliteTasks.map(jsonEncode),
          ...preferenceEntries,
        ],
      );
      _migrationIssues = migrationBatch.issues;

      // Keep the old preference source until every valid payload is copied and
      // read back from SQLite without loss.
      final persistedPayloads = await _taskRepository.replaceAllTaskPayloads(
        migrationBatch.tasks,
        enqueue: false,
      );
      final hasMigrationErrors = migrationBatch.issues.any(
        (issue) => issue.severity == TaskMigrationIssueSeverity.error,
      );
      if (preferenceEntries.isNotEmpty && !hasMigrationErrors) {
        await _prefs?.remove(_tasksKey);
      }

      _tasks = persistedPayloads.map(Task.fromJson).toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      _persistedTasks = List<Task>.of(_tasks);
      _cache.invalidateCache(_taskStatsKey);
      _cache.setMemoryCache(
        _tasksKey,
        _tasks.map((task) => task.toJson()).toList(),
        ttl: const Duration(minutes: 30),
      );
      _tasksController.add(List<Task>.of(_tasks));
    } catch (e) {
      ErrorHandler.logError('Failed to load or migrate tasks', e);
      rethrow;
    }
  }

  /// Save tasks to storage
  Future<void> _saveTasks() {
    return _withTaskPersistenceLock(() async {
      final previousTasks = List<Task>.of(_persistedTasks);
      final taskSnapshot = List<Task>.of(_tasks);
      try {
        final persistedPayloads = await _taskRepository.replaceAllTaskPayloads(
          taskSnapshot.map((task) => task.toJson()),
        );
        _persistedTasks = persistedPayloads.map(Task.fromJson).toList()
          ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
        _cache.invalidateCache(_taskStatsKey);

        _cache.setMemoryCache(
          _tasksKey,
          _tasks.map((task) => task.toJson()).toList(),
          ttl: const Duration(minutes: 30),
        );
      } catch (e) {
        ErrorHandler.logError('Failed to save tasks', e);
        if (_matchesTaskSnapshot(taskSnapshot)) _tasks = previousTasks;
        throw Exception('Failed to save tasks');
      }
    });
  }

  Future<T> _withTaskPersistenceLock<T>(Future<T> Function() action) {
    final previous = _taskPersistenceQueue;
    final release = Completer<void>();
    _taskPersistenceQueue = release.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        release.complete();
      }
    });
  }

  bool _matchesTaskSnapshot(List<Task> snapshot) {
    if (_tasks.length != snapshot.length) return false;
    for (var index = 0; index < snapshot.length; index++) {
      if (!identical(_tasks[index], snapshot[index])) return false;
    }
    return true;
  }

  /// Imports remote-only tasks without replacing newer local task state.
  Future<Set<String>> applyRemoteTaskPayloads(
    Iterable<Map<String, dynamic>> taskPayloads,
  ) async {
    await _ensureInitialized();
    return _withTaskPersistenceLock(() async {
      final importedPayloads =
          await _taskRepository.importRemoteTaskPayloads(taskPayloads);
      if (importedPayloads.isEmpty) return <String>{};

      final existingIds = _tasks.map((task) => task.id).toSet();
      _tasks.addAll(
        importedPayloads
            .where((payload) => !existingIds.contains(payload['id']))
            .map(Task.fromJson),
      );
      _tasks.sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      _persistedTasks = (await _taskRepository.loadAllTaskPayloads())
          .map(Task.fromJson)
          .toList()
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      _cache.invalidateCache(_taskStatsKey);
      _cache.setMemoryCache(
        _tasksKey,
        _tasks.map((task) => task.toJson()).toList(),
        ttl: const Duration(minutes: 30),
      );
      if (!_tasksController.isClosed) {
        _tasksController.add(List<Task>.of(_tasks));
      }
      return importedPayloads.map((payload) => payload['id'] as String).toSet();
    });
  }

  /// Create a new task with enhanced stream updates
  Future<Task> createTask({
    required String title,
    String description = '',
    TaskPriority priority = TaskPriority.medium,
    TaskCategory category = TaskCategory.other,
    DateTime? dueDate,
    List<String> tags = const [],
    int estimatedFocusSessions = 1,
    bool isRecurring = false,
    String? recurringPattern,
  }) async {
    try {
      await _ensureInitialized();
      debugPrint('TaskService: Creating task with title: "$title"');

      final now = DateTime.now();
      // Assign sortOrder based on current task count to ensure new tasks appear at the end
      final nextSortOrder = _tasks.isEmpty
          ? 0
          : _tasks.map((t) => t.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

      final task = Task(
        id: now.microsecondsSinceEpoch.toString(),
        title: title,
        description: description,
        priority: priority,
        category: category,
        createdAt: now,
        updatedAt: now,
        dueDate: dueDate,
        tags: tags,
        estimatedFocusSessions: estimatedFocusSessions,
        isRecurring: isRecurring,
        recurringPattern: recurringPattern,
        sortOrder: nextSortOrder,
      );

      _tasks.add(task);
      debugPrint(
          'TaskService: Task added to list, total tasks: ${_tasks.length}');

      await _saveTasks();
      debugPrint('TaskService: Task saved to storage');

      // Invalidate cache to force refresh
      _cache.invalidateCache(_taskStatsKey);

      // Emit stream update with a copy to ensure proper notification
      _tasksController.add(List.from(_tasks));
      debugPrint('TaskService: Stream update emitted');

      return task;
    } catch (e) {
      debugPrint('TaskService: Failed to create task: $e');
      ErrorHandler.logError('Failed to create task', e);
      throw Exception('Failed to create task');
    }
  }

  /// Update an existing task
  Future<Task> updateTask(Task updatedTask) async {
    try {
      await _ensureInitialized();
      final index = _tasks.indexWhere((task) => task.id == updatedTask.id);
      if (index == -1) {
        throw Exception('Task not found');
      }

      final existingTask = _tasks[index];
      final existingSubtasks = {
        for (final subtask in existingTask.subTasks) subtask.id: subtask,
      };
      final updatedSubtasks = updatedTask.subTasks.map((subtask) {
        final previous = existingSubtasks[subtask.id];
        return subtask.copyWith(
          extraFields: {
            ...?previous?.extraFields,
            ...subtask.extraFields,
          },
        );
      }).toList();
      final taskWithUpdatedFields = updatedTask.copyWith(
        updatedAt: DateTime.now(), // Set the updated timestamp
        extraFields: {
          ...existingTask.extraFields,
          ...updatedTask.extraFields,
        },
        subTasks: updatedSubtasks,
      );

      _tasks[index] = taskWithUpdatedFields;
      await _saveTasks();

      // Emit stream update
      _tasksController.add(List.from(_tasks));

      return taskWithUpdatedFields;
    } catch (e) {
      ErrorHandler.logError('Failed to update task', e);
      throw Exception('Failed to update task');
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _ensureInitialized();
      _tasks.removeWhere((task) => task.id == taskId);
      await _saveTasks();

      // Emit stream update
      _tasksController.add(List.from(_tasks));
    } catch (e) {
      ErrorHandler.logError('Failed to delete task', e);
      throw Exception('Failed to delete task');
    }
  }

  /// Complete a task
  Future<Task> completeTask(String taskId) async {
    try {
      await _ensureInitialized();
      final task = _tasks.firstWhere((t) => t.id == taskId);
      final now = DateTime.now();
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        completedAt: now,
        updatedAt: now,
        progress: 1.0,
      );

      return await updateTask(completedTask);
    } catch (e) {
      ErrorHandler.logError('Failed to complete task', e);
      throw Exception('Failed to complete task');
    }
  }

  /// Add focus session to task
  Future<Task> addFocusSession(String taskId, Duration sessionDuration) async {
    try {
      await _ensureInitialized();
      final task = _tasks.firstWhere((t) => t.id == taskId);
      final now = DateTime.now();
      final updatedTask = task.copyWith(
        completedFocusSessions: task.completedFocusSessions + 1,
        totalFocusTime: task.totalFocusTime + sessionDuration,
        lastFocusSession: now,
        updatedAt: now,
      );

      return await updateTask(updatedTask);
    } catch (e) {
      ErrorHandler.logError('Failed to add focus session', e);
      throw Exception('Failed to add focus session');
    }
  }

  /// Add subtask to task
  Future<Task> addSubTask(String taskId, String subTaskTitle) async {
    try {
      await _ensureInitialized();
      final task = _tasks.firstWhere((t) => t.id == taskId);
      final now = DateTime.now();
      final subTask = SubTask(
        id: now.microsecondsSinceEpoch.toString(),
        title: subTaskTitle,
        createdAt: now,
      );

      final updatedSubTasks = [...task.subTasks, subTask];
      final updatedTask = task.copyWith(subTasks: updatedSubTasks);

      return await updateTask(updatedTask);
    } catch (e) {
      ErrorHandler.logError('Failed to add subtask', e);
      throw Exception('Failed to add subtask');
    }
  }

  /// Toggle subtask completion
  Future<Task> toggleSubTask(String taskId, String subTaskId) async {
    try {
      await _ensureInitialized();
      final task = _tasks.firstWhere((t) => t.id == taskId);
      final updatedSubTasks = task.subTasks.map((subTask) {
        if (subTask.id == subTaskId) {
          return subTask.copyWith(
            isCompleted: !subTask.isCompleted,
            completedAt: !subTask.isCompleted ? DateTime.now() : null,
          );
        }
        return subTask;
      }).toList();

      final updatedTask = task.copyWith(subTasks: updatedSubTasks);
      return await updateTask(updatedTask);
    } catch (e) {
      ErrorHandler.logError('Failed to toggle subtask', e);
      throw Exception('Failed to toggle subtask');
    }
  }

  /// Get tasks by status
  List<Task> getTasksByStatus(TaskStatus status) {
    return _tasks.where((task) => task.status == status).toList();
  }

  /// Get tasks by category
  List<Task> getTasksByCategory(TaskCategory category) {
    return _tasks.where((task) => task.category == category).toList();
  }

  /// Get tasks by priority
  List<Task> getTasksByPriority(TaskPriority priority) {
    return _tasks.where((task) => task.priority == priority).toList();
  }

  /// Get overdue tasks
  List<Task> getOverdueTasks() {
    return _tasks.where((task) => task.isOverdue).toList();
  }

  /// Get tasks due today
  List<Task> getTasksDueToday() {
    return _tasks.where((task) => task.isDueToday).toList();
  }

  /// Get tasks due this week
  List<Task> getTasksDueThisWeek() {
    return _tasks.where((task) => task.isDueThisWeek).toList();
  }

  /// Search tasks
  List<Task> searchTasks(String query) {
    if (query.isEmpty) return _tasks;

    final lowercaseQuery = query.toLowerCase();
    return _tasks.where((task) {
      return task.title.toLowerCase().contains(lowercaseQuery) ||
          task.description.toLowerCase().contains(lowercaseQuery) ||
          task.tags.any((tag) => tag.toLowerCase().contains(lowercaseQuery));
    }).toList();
  }

  /// Get task statistics
  Future<Map<String, dynamic>> getTaskStatistics() async {
    try {
      // Check cache first
      final cachedStats = _cache.getMemoryCache(_taskStatsKey);
      if (cachedStats != null) {
        return cachedStats as Map<String, dynamic>;
      }

      final totalTasks = _tasks.length;
      final completedTasks =
          _tasks.where((t) => t.status == TaskStatus.completed).length;
      final inProgressTasks =
          _tasks.where((t) => t.status == TaskStatus.inProgress).length;
      final overdueTasks = _tasks.where((t) => t.isOverdue).length;
      final dueToday = _tasks.where((t) => t.isDueToday).length;

      final totalFocusTime = _tasks.fold<Duration>(
        Duration.zero,
        (total, task) => total + task.totalFocusTime,
      );

      final totalFocusSessions = _tasks.fold<int>(
        0,
        (total, task) => total + task.completedFocusSessions,
      );

      final averageProgress = totalTasks > 0
          ? _tasks.fold<double>(0, (total, task) => total + task.progress) /
              totalTasks
          : 0.0;

      final stats = {
        'totalTasks': totalTasks,
        'completedTasks': completedTasks,
        'inProgressTasks': inProgressTasks,
        'overdueTasks': overdueTasks,
        'dueToday': dueToday,
        'completionRate': totalTasks > 0 ? completedTasks / totalTasks : 0.0,
        'totalFocusTime': totalFocusTime.inMinutes,
        'totalFocusSessions': totalFocusSessions,
        'averageProgress': averageProgress,
        'tasksByCategory': _getTasksByCategory(),
        'tasksByPriority': _getTasksByPriority(),
      };

      // Cache the statistics
      _cache.setMemoryCache(_taskStatsKey, stats,
          ttl: const Duration(minutes: 5));

      return stats;
    } catch (e) {
      ErrorHandler.logError('Failed to get task statistics', e);
      return {};
    }
  }

  /// Get tasks grouped by category
  Map<String, int> _getTasksByCategory() {
    final categoryCount = <String, int>{};
    for (final category in TaskCategory.values) {
      categoryCount[category.displayName] =
          _tasks.where((task) => task.category == category).length;
    }
    return categoryCount;
  }

  /// Get tasks grouped by priority
  Map<String, int> _getTasksByPriority() {
    final priorityCount = <String, int>{};
    for (final priority in TaskPriority.values) {
      priorityCount[priority.displayName] =
          _tasks.where((task) => task.priority == priority).length;
    }
    return priorityCount;
  }

  /// Reorder tasks by updating their sort order
  Future<void> reorderTasks(List<Task> reorderedTasks) async {
    try {
      await _ensureInitialized();
      debugPrint('TaskService: Reordering ${reorderedTasks.length} tasks');

      // Update sort order for each task
      for (int i = 0; i < reorderedTasks.length; i++) {
        final task = reorderedTasks[i];
        final updatedTask = task.copyWith(
          sortOrder: i,
          updatedAt: DateTime.now(),
        );

        // Update the task in the list
        final index = _tasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _tasks[index] = updatedTask;
        }
      }

      // Re-sort the _tasks list to match the new order
      _tasks.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

      // Save to storage
      await _saveTasks();

      // Emit stream update
      _tasksController.add(List.from(_tasks));

      debugPrint('TaskService: Task reordering completed successfully');
    } catch (e) {
      ErrorHandler.logError('Failed to reorder tasks', e);
      throw Exception('Failed to reorder tasks');
    }
  }

  /// Sort tasks by various criteria
  List<Task> sortTasks(List<Task> tasks, String sortBy) {
    switch (sortBy) {
      case 'dueDate':
        return tasks
          ..sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            return a.dueDate!.compareTo(b.dueDate!);
          });
      case 'priority':
        return tasks
          ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case 'created':
        return tasks..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case 'alphabetical':
        return tasks..sort((a, b) => a.title.compareTo(b.title));
      case 'progress':
        return tasks..sort((a, b) => b.progress.compareTo(a.progress));
      case 'custom':
        // Sort by custom order (sort_order field)
        return tasks..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      default:
        return tasks;
    }
  }

  /// Export tasks to JSON
  Future<String> exportTasks() async {
    try {
      await _ensureInitialized();
      final exportData = {
        'tasks': _tasks.map((task) => task.toJson()).toList(),
        'exportDate': DateTime.now().toIso8601String(),
        'version': '1.0',
      };

      return jsonEncode(exportData);
    } catch (e) {
      ErrorHandler.logError('Failed to export tasks', e);
      throw Exception('Failed to export tasks');
    }
  }

  /// Recreates the legacy preference source if an app rollback is required.
  Future<void> restoreLegacyPreferencesForRollback() async {
    final payloads = await _taskRepository.loadAllTaskPayloads();
    _prefs ??= await SharedPreferences.getInstance();
    final existingEntries =
        _prefs?.getStringList(_tasksKey) ?? const <String>[];
    final invalidEntries = existingEntries.where((entry) {
      return TaskMigrationContract.decodePreferenceEntries([entry]).hasErrors;
    });
    await _prefs!.setStringList(
      _tasksKey,
      [
        ...payloads.map(jsonEncode),
        ...invalidEntries,
      ],
    );
  }

  /// Import tasks from JSON
  Future<void> importTasks(String jsonData) async {
    try {
      await _ensureInitialized();
      final data = jsonDecode(jsonData);
      final importedTasks =
          (data['tasks'] as List).map((json) => Task.fromJson(json)).toList();

      // Add imported tasks to existing tasks
      _tasks.addAll(importedTasks);
      await _saveTasks();
    } catch (e) {
      ErrorHandler.logError('Failed to import tasks', e);
      throw Exception('Failed to import tasks');
    }
  }

  /// Clear all tasks
  Future<void> clearAllTasks() async {
    try {
      await _ensureInitialized();
      _tasks.clear();
      await _saveTasks();
      _cache.invalidateCache(_taskStatsKey);
    } catch (e) {
      ErrorHandler.logError('Failed to clear tasks', e);
      throw Exception('Failed to clear tasks');
    }
  }

  /// Dispose resources
  void dispose() {
    _tasksController.close();
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    _isInitialized = false;
    _prefs = null;
    _tasks = [];
    _persistedTasks = [];
    _migrationIssues = [];
    await _cache.clearCache(_tasksKey);
    await _cache.clearCache(_taskStatsKey);
    await DatabaseHelper().close();
    await DatabaseHelper().deleteDatabase();
    if (!_tasksController.isClosed) await _tasksController.close();
    _tasksController = StreamController<List<Task>>.broadcast();
    _taskPersistenceQueue = Future<void>.value();
  }
}
