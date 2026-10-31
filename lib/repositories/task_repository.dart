import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/task.dart';
import '../models/sync_operation.dart';
import '../models/task_json_schema.dart';
import '../models/task_model.dart' as active_task;
import '../services/database_helper.dart';
import '../services/task_migration_contract.dart';
import 'sync_outbox_repository.dart';

class TaskRepository extends BaseRepository<Task> {
  @override
  String get tableName => 'tasks';

  @override
  String get primaryKey => 'id';

  @override
  Task fromMap(Map<String, dynamic> map) {
    return Task.fromMap(map);
  }

  /// Get tasks by category
  Future<List<Task>> getTasksByCategory(String category) async {
    return await findWhere(
      'category = ?',
      [category],
      orderBy: 'is_completed ASC, priority DESC, due_date ASC',
    );
  }

  /// Get completed tasks
  Future<List<Task>> getCompletedTasks() async {
    return await findWhere(
      'is_completed = ?',
      [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// Get pending tasks
  Future<List<Task>> getPendingTasks() async {
    return await findWhere(
      'is_completed = ?',
      [0],
      orderBy: 'priority DESC, due_date ASC',
    );
  }

  /// Get favorite tasks
  Future<List<Task>> getFavoriteTasks() async {
    return await findWhere(
      'is_favorite = ?',
      [1],
      orderBy: 'is_completed ASC, priority DESC, due_date ASC',
    );
  }

  /// Get tasks due today
  Future<List<Task>> getTasksDueToday() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await findWhere(
      'due_date >= ? AND due_date < ? AND is_completed = ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String(), 0],
      orderBy: 'priority DESC',
    );
  }

  /// Get overdue tasks
  Future<List<Task>> getOverdueTasks() async {
    final now = DateTime.now();

    return await findWhere(
      'due_date < ? AND is_completed = ?',
      [now.toIso8601String(), 0],
      orderBy: 'due_date ASC',
    );
  }

  /// Get tasks by priority
  Future<List<Task>> getTasksByPriority(TaskPriority priority) async {
    return await findWhere(
      'priority = ?',
      [priority.index],
      orderBy: 'is_completed ASC, due_date ASC',
    );
  }

  /// Search tasks by title or description
  Future<List<Task>> searchTasks(String query) async {
    return await findWhere(
      'title LIKE ? OR description LIKE ?',
      ['%$query%', '%$query%'],
      orderBy: 'is_completed ASC, priority DESC, due_date ASC',
    );
  }

  /// Get task completion rate
  Future<double> getCompletionRate() async {
    final totalCount = await count();
    if (totalCount == 0) return 0.0;

    final completedCount = await countWhere('is_completed = ?', [1]);
    return completedCount / totalCount;
  }

  /// Get tasks statistics by category
  Future<Map<String, Map<String, int>>> getTaskStatsByCategory() async {
    final result = await rawQuery('''
      SELECT 
        category,
        SUM(CASE WHEN is_completed = 1 THEN 1 ELSE 0 END) as completed,
        SUM(CASE WHEN is_completed = 0 THEN 1 ELSE 0 END) as pending,
        COUNT(*) as total
      FROM $tableName 
      GROUP BY category
    ''');

    final stats = <String, Map<String, int>>{};
    for (final row in result) {
      stats[row['category'] as String] = {
        'completed': row['completed'] as int,
        'pending': row['pending'] as int,
        'total': row['total'] as int,
      };
    }
    return stats;
  }

  /// Get tasks statistics by priority
  Future<Map<TaskPriority, int>> getTaskStatsByPriority() async {
    final result = await rawQuery('''
      SELECT priority, COUNT(*) as count
      FROM $tableName 
      WHERE is_completed = 0
      GROUP BY priority
    ''');

    final stats = <TaskPriority, int>{};
    for (final row in result) {
      final priority = TaskPriority.values[row['priority'] as int];
      stats[priority] = row['count'] as int;
    }
    return stats;
  }

  /// Mark task as completed
  Future<int> markAsCompleted(String taskId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_completed': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Mark task as pending
  Future<int> markAsPending(String taskId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_completed': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Toggle favorite status
  Future<int> toggleFavorite(String taskId) async {
    final task = await findById(taskId);
    if (task == null) return 0;

    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_favorite': task.isFavorite ? 0 : 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [taskId],
    );
  }

  /// Delete completed tasks older than specified days
  Future<int> deleteOldCompletedTasks(int daysOld) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    final db = await _database;
    return await db.delete(
      tableName,
      where: 'is_completed = 1 AND updated_at < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

class SubtaskRepository extends BaseRepository<Subtask> {
  @override
  String get tableName => 'subtasks';

  @override
  String get primaryKey => 'id';

  @override
  Subtask fromMap(Map<String, dynamic> map) {
    return Subtask.fromMap(map);
  }

  /// Get subtasks for a specific task
  Future<List<Subtask>> getSubtasksForTask(String taskId) async {
    return await findWhere(
      'task_id = ?',
      [taskId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
  }

  /// Get completed subtasks for a task
  Future<List<Subtask>> getCompletedSubtasksForTask(String taskId) async {
    return await findWhere(
      'task_id = ? AND is_completed = ?',
      [taskId, 1],
      orderBy: 'sort_order ASC',
    );
  }

  /// Get pending subtasks for a task
  Future<List<Subtask>> getPendingSubtasksForTask(String taskId) async {
    return await findWhere(
      'task_id = ? AND is_completed = ?',
      [taskId, 0],
      orderBy: 'sort_order ASC',
    );
  }

  /// Mark subtask as completed
  Future<int> markAsCompleted(String subtaskId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_completed': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
  }

  /// Mark subtask as pending
  Future<int> markAsPending(String subtaskId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_completed': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [subtaskId],
    );
  }

  /// Delete all subtasks for a task
  Future<int> deleteSubtasksForTask(String taskId) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: 'task_id = ?',
      whereArgs: [taskId],
    );
  }

  /// Update sort order for subtasks
  Future<void> updateSortOrder(List<String> subtaskIds) async {
    final db = await _database;
    final batch = db.batch();

    for (int i = 0; i < subtaskIds.length; i++) {
      batch.update(
        tableName,
        {
          'sort_order': i,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [subtaskIds[i]],
      );
    }

    await batch.commit();
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

typedef CanonicalTaskDatabaseProvider = Future<Database> Function();

/// SQLite repository for the active task model and versioned JSON payload.
class CanonicalTaskRepository {
  CanonicalTaskRepository({
    CanonicalTaskDatabaseProvider? databaseProvider,
    SyncOutboxRepository? outboxRepository,
  })  : _databaseProvider =
            databaseProvider ?? (() => DatabaseHelper().database),
        _outboxRepository = outboxRepository ?? SyncOutboxRepository();

  final CanonicalTaskDatabaseProvider _databaseProvider;
  final SyncOutboxRepository _outboxRepository;

  static const Set<String> _legacySqlFields = {
    'created_at',
    'due_date',
    'is_completed',
    'is_favorite',
    'notification_custom_sound',
    'notification_enabled',
    'notification_priority',
    'notification_reminder_minutes',
    'notification_repeat',
    'notification_repeat_interval',
    'notification_settings',
    'notification_sound',
    'notification_vibration',
    'sort_order',
    'updated_at',
  };
  static const List<String> _notificationRepeatIntervals = [
    'none',
    'daily',
    'weekly',
    'monthly',
  ];
  static const List<String> _notificationPriorities = [
    'low',
    'medium',
    'high',
    'urgent',
  ];

  Future<List<Map<String, dynamic>>> loadAllTaskPayloads() async {
    final database = await _databaseProvider();
    return _readTaskPayloads(database);
  }

  /// Replaces the canonical task set atomically and optionally queues changes.
  ///
  /// Migration calls this with [enqueue] false so copying existing local data
  /// does not bind it to an account or bypass first-sign-in reconciliation.
  Future<List<Map<String, dynamic>>> replaceAllTaskPayloads(
    Iterable<Map<String, dynamic>> taskPayloads, {
    bool enqueue = true,
  }) async {
    final desiredById = <String, Map<String, dynamic>>{};
    for (final source in taskPayloads) {
      final task = _normalizeCanonicalTask(source);
      final id = task['id'] as String;
      if (desiredById.containsKey(id)) {
        throw ArgumentError('Duplicate canonical task ID: $id');
      }
      desiredById[id] = task;
    }

    final database = await _databaseProvider();
    await database.transaction((transaction) async {
      final existingTasks = await _readTaskPayloads(transaction);
      final existingById = {
        for (final task in existingTasks) task['id'] as String: task,
      };

      for (final existing in existingTasks) {
        final id = existing['id'] as String;
        if (desiredById.containsKey(id)) continue;

        await transaction.delete(
          'subtasks',
          where: 'task_id = ?',
          whereArgs: [id],
        );
        await transaction.delete('tasks', where: 'id = ?', whereArgs: [id]);
        if (enqueue) {
          await _outboxRepository.enqueueInTransaction(
            transaction,
            SyncOperation.create(
              entityType: 'tasks',
              entityId: id,
              kind: SyncOperationKind.delete,
              schemaVersion: TaskJsonSchema.currentVersion,
            ),
          );
        }
      }

      for (final task in desiredById.values) {
        final id = task['id'] as String;
        final previous = existingById[id];
        final changed =
            previous == null || _stableJson(previous) != _stableJson(task);

        await _writeTask(transaction, task);
        if (enqueue && changed) {
          await _outboxRepository.enqueueInTransaction(
            transaction,
            SyncOperation.create(
              entityType: 'tasks',
              entityId: id,
              kind: SyncOperationKind.upsert,
              schemaVersion: TaskJsonSchema.currentVersion,
              payload: task,
            ),
          );
        }
      }
    });

    final persisted = await loadAllTaskPayloads();
    final persistedById = {
      for (final task in persisted) task['id'] as String: task,
    };
    if (persistedById.length != desiredById.length) {
      throw StateError('Canonical task migration verification failed.');
    }
    for (final entry in desiredById.entries) {
      final saved = persistedById[entry.key];
      if (saved == null) {
        throw StateError('Canonical task migration omitted a task.');
      }
      final keys = {...entry.value.keys, ...saved.keys};
      final differingFields = keys
          .where(
              (key) => _stableJson(entry.value[key]) != _stableJson(saved[key]))
          .toList();
      if (differingFields.isNotEmpty) {
        throw StateError(
          'Canonical task migration verification differed in: '
          '${differingFields.join(', ')}.',
        );
      }
    }
    return persisted;
  }

  /// Imports cloud tasks without replacing local records or local mutations.
  Future<List<Map<String, dynamic>>> importRemoteTaskPayloads(
    Iterable<Map<String, dynamic>> taskPayloads,
  ) async {
    final remoteById = <String, Map<String, dynamic>>{};
    for (final source in taskPayloads) {
      final task = _normalizeCanonicalTask(source);
      final id = task['id'] as String;
      if (remoteById.containsKey(id)) {
        throw ArgumentError('Duplicate remote task ID: $id');
      }
      remoteById[id] = task;
    }

    final database = await _databaseProvider();
    final imported = <Map<String, dynamic>>[];
    await database.transaction((transaction) async {
      for (final task in remoteById.values) {
        final id = task['id'] as String;
        final localRows = await transaction.query(
          'tasks',
          columns: const ['id'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (localRows.isNotEmpty) continue;

        final localMutations = await transaction.query(
          SyncOutboxRepository.tableName,
          columns: const ['operation_id'],
          where: 'entity_type = ? AND entity_id = ? AND '
              '(operation_kind = ? OR status IN (?, ?, ?))',
          whereArgs: [
            'tasks',
            id,
            SyncOperationKind.delete.name,
            SyncOperationState.pending.name,
            SyncOperationState.inProgress.name,
            SyncOperationState.failed.name,
          ],
          limit: 1,
        );
        if (localMutations.isNotEmpty) continue;

        await _writeTask(transaction, task);
        imported.add(task);
      }
    });
    return imported;
  }

  Future<List<Map<String, dynamic>>> _readTaskPayloads(
    DatabaseExecutor executor,
  ) async {
    final taskRows = await executor.query(
      'tasks',
      orderBy: 'sort_order ASC, created_at ASC, id ASC',
    );
    final subtaskRows = await executor.query(
      'subtasks',
      orderBy: 'sort_order ASC, created_at ASC, id ASC',
    );
    final subtasksByTaskId = <String, List<Map<String, dynamic>>>{};
    for (final subtask in subtaskRows) {
      final taskId = subtask['task_id'] as String;
      subtasksByTaskId.putIfAbsent(taskId, () => []).add(subtask);
    }

    return taskRows.map((row) {
      final taskJson = row['task_json'] as String?;
      Map<String, dynamic> canonicalPayload = {};
      if (taskJson != null) {
        final decoded = jsonDecode(taskJson);
        if (decoded is! Map) {
          throw const FormatException('Stored task_json must be an object.');
        }
        canonicalPayload = Map<String, dynamic>.from(decoded);
      }

      final legacyColumns = Map<String, dynamic>.from(row)..remove('task_json');
      final combined = <String, dynamic>{
        ...legacyColumns,
        ...canonicalPayload,
      };
      if (!canonicalPayload.containsKey('subTasks') &&
          !canonicalPayload.containsKey('subtasks')) {
        combined['subTasks'] =
            subtasksByTaskId[row['id'] as String] ?? <Map<String, dynamic>>[];
      }
      return _normalizeCanonicalTask(combined);
    }).toList();
  }

  Map<String, dynamic> _normalizeCanonicalTask(Map<String, dynamic> source) {
    final task = TaskMigrationContract.normalizeCanonicalMap(source)
      ..removeWhere((key, _) => _legacySqlFields.contains(key));
    final subtasks = task['subTasks'];
    if (subtasks is List) {
      task['subTasks'] = subtasks.map((value) {
        if (value is! Map) return value;
        return Map<String, dynamic>.from(value)
          ..removeWhere((key, _) => _legacySqlFields.contains(key));
      }).toList();
    }
    return task;
  }

  Future<void> _writeTask(
    DatabaseExecutor executor,
    Map<String, dynamic> task,
  ) async {
    final id = task['id'] as String;
    final priorityName = task['priority'] as String;
    final priorityIndex = active_task.TaskPriority.values.indexWhere(
      (priority) => priority.name == priorityName,
    );
    final status = task['status'] as String;
    final notificationSettings =
        Map<String, dynamic>.from(task['notificationSettings'] as Map);
    final repeatInterval = _notificationRepeatIntervals.indexOf(
      notificationSettings['repeatInterval'] as String,
    );
    final notificationPriority = _notificationPriorities.indexOf(
      notificationSettings['priority'] as String,
    );
    await executor.insert(
      'tasks',
      {
        'id': id,
        'task_json': jsonEncode(task),
        'title': task['title'],
        'description': task['description'],
        'category': task['category'],
        'priority': priorityIndex < 0
            ? active_task.TaskPriority.medium.index
            : priorityIndex,
        'due_date': task['dueDate'],
        'is_completed': status == 'completed' ? 1 : 0,
        'is_favorite': task['isFavorite'] == true ? 1 : 0,
        'sort_order': task['sortOrder'] ?? 0,
        'notification_enabled': notificationSettings['enabled'] == true ? 1 : 0,
        'notification_reminder_minutes':
            notificationSettings['reminderMinutes'] ?? 60,
        'notification_repeat': notificationSettings['repeat'] == true ? 1 : 0,
        'notification_repeat_interval': repeatInterval < 0 ? 0 : repeatInterval,
        'notification_sound': notificationSettings['sound'] == true ? 1 : 0,
        'notification_vibration':
            notificationSettings['vibration'] == true ? 1 : 0,
        'notification_priority':
            notificationPriority < 0 ? 2 : notificationPriority,
        'notification_custom_sound': notificationSettings['customSound'],
        'created_at': task['createdAt'],
        'updated_at': task['updatedAt'],
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await executor.delete('subtasks', where: 'task_id = ?', whereArgs: [id]);

    final subtasks = task['subTasks'];
    if (subtasks is! List) return;
    for (var index = 0; index < subtasks.length; index++) {
      final subtask = Map<String, dynamic>.from(subtasks[index] as Map);
      final createdAt = subtask['createdAt'] as String;
      await executor.insert('subtasks', {
        'id': subtask['id'],
        'task_id': id,
        'title': subtask['title'],
        'is_completed': subtask['isCompleted'] == true ? 1 : 0,
        'sort_order': index,
        'created_at': createdAt,
        'updated_at':
            subtask['updatedAt'] ?? subtask['completedAt'] ?? createdAt,
      });
    }
  }

  String _stableJson(Object? value) => jsonEncode(_sortJson(value));

  Object? _sortJson(Object? value) {
    if (value is Map) {
      final entries = value.entries.toList()
        ..sort((left, right) =>
            left.key.toString().compareTo(right.key.toString()));
      return {
        for (final entry in entries)
          entry.key.toString(): _sortJson(entry.value),
      };
    }
    if (value is List) return value.map(_sortJson).toList();
    return value;
  }
}
