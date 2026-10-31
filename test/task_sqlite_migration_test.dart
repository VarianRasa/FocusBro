import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/repositories/sync_outbox_repository.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TaskService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = TaskService();
    await service.resetForTests();
  });

  tearDown(() async {
    await service.resetForTests();
  });

  test('preference migration preserves fields and removes source after verify',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final legacyTask = {
      'schemaVersion': 1,
      'id': 'pref-task-1',
      'title': 'Preference task',
      'description': 'Keep every field',
      'priority': 'high',
      'status': 'inProgress',
      'category': 'learning',
      'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'updatedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
      'dueDate': null,
      'completedAt': null,
      'subTasks': [
        {
          'id': 'pref-subtask-1',
          'title': 'Keep this subtask',
          'isCompleted': true,
          'createdAt': DateTime.utc(2026, 1, 1, 1).toIso8601String(),
          'completedAt': DateTime.utc(2026, 1, 1, 2).toIso8601String(),
          'futureSubtaskField': 'preserve',
        },
      ],
      'tags': ['migration'],
      'estimatedFocusSessions': 3,
      'completedFocusSessions': 1,
      'totalFocusTime': 1500,
      'isRecurring': true,
      'recurringPattern': 'weekly',
      'lastFocusSession': null,
      'progress': 0.25,
      'sortOrder': 4,
      'isFavorite': true,
      'notificationSettings': {
        'enabled': false,
        'reminderMinutes': 15,
        'repeat': true,
        'repeatInterval': 'weekly',
        'sound': false,
        'vibration': true,
        'priority': 'urgent',
        'customSound': 'bell',
        'futureSetting': 'preserve',
      },
      'futureTaskField': {'keep': true},
    };
    final rawSource = jsonEncode(legacyTask);
    await prefs.setStringList('tasks', [rawSource]);

    await service.initialize();

    expect(prefs.getStringList('tasks'), isNull);
    expect(service.tasks.single.id, 'pref-task-1');
    expect(service.tasks.single.isRecurring, isTrue);
    expect(service.tasks.single.subTasks.single.id, 'pref-subtask-1');

    final db = await DatabaseHelper().database;
    final row = (await db.query('tasks')).single;
    final savedTask =
        jsonDecode(row['task_json'] as String) as Map<String, dynamic>;
    final savedSubtask =
        (savedTask['subTasks'] as List).single as Map<String, dynamic>;
    expect(savedTask['futureTaskField'], {'keep': true});
    expect(savedTask['isFavorite'], isTrue);
    expect(
      (savedTask['notificationSettings'] as Map)['reminderMinutes'],
      15,
    );
    expect(
      (savedTask['notificationSettings'] as Map)['futureSetting'],
      'preserve',
    );
    expect(savedSubtask['futureSubtaskField'], 'preserve');
    expect(row['is_favorite'], 1);
    expect(row['notification_enabled'], 0);
    expect(await SyncOutboxRepository().getPendingOperations(), isEmpty);
  });

  test('legacy SQLite rows become canonical without losing bridge fields',
      () async {
    final db = await DatabaseHelper().database;
    final createdAt = DateTime.utc(2026, 2, 1).toIso8601String();
    final updatedAt = DateTime.utc(2026, 2, 2).toIso8601String();
    await db.insert('tasks', {
      'id': 'sqlite-task-1',
      'title': 'Legacy database task',
      'description': 'Keep existing values',
      'category': 'work',
      'priority': TaskPriority.urgent.index,
      'due_date': DateTime.utc(2026, 2, 5).toIso8601String(),
      'is_completed': 0,
      'is_favorite': 1,
      'sort_order': 9,
      'notification_enabled': 0,
      'notification_reminder_minutes': 10,
      'notification_repeat': 1,
      'notification_repeat_interval': 2,
      'notification_sound': 0,
      'notification_vibration': 1,
      'notification_priority': TaskPriority.urgent.index,
      'notification_custom_sound': 'chime',
      'created_at': createdAt,
      'updated_at': updatedAt,
    });
    await db.insert('subtasks', {
      'id': 'sqlite-subtask-1',
      'task_id': 'sqlite-task-1',
      'title': 'Legacy subtask',
      'is_completed': 1,
      'sort_order': 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    });

    await service.initialize();

    expect(service.tasks.single.id, 'sqlite-task-1');
    expect(service.tasks.single.priority, TaskPriority.urgent);
    expect(service.tasks.single.subTasks.single.id, 'sqlite-subtask-1');
    final migratedRow = (await db.query('tasks')).single;
    final payload =
        jsonDecode(migratedRow['task_json'] as String) as Map<String, dynamic>;
    expect(payload['isFavorite'], isTrue);
    expect((payload['notificationSettings'] as Map)['enabled'], isFalse);
    expect((payload['notificationSettings'] as Map)['customSound'], 'chime');
    expect(await SyncOutboxRepository().getPendingOperations(), isEmpty);
  });

  test('CRUD mutation and outbox write are atomic and account-unbound',
      () async {
    await service.initialize();
    final task = await service.createTask(title: 'Atomic task');

    final db = await DatabaseHelper().database;
    var outboxRows = await db.query(SyncOutboxRepository.tableName);
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['account_uid'], isNull);
    expect(outboxRows.single['entity_id'], task.id);

    await service.addFocusSession(task.id, const Duration(minutes: 25));
    expect(service.tasks.single.completedFocusSessions, 1);
    expect(service.tasks.single.progress, 0);
    outboxRows = await db.query(SyncOutboxRepository.tableName);
    expect(outboxRows, hasLength(2));

    await service.deleteTask(task.id);
    outboxRows = await db.query(
      SyncOutboxRepository.tableName,
      where: 'operation_kind = ?',
      whereArgs: ['delete'],
    );
    expect(outboxRows, hasLength(1));
    expect(outboxRows.single['deleted_at'], isNotNull);
    expect(outboxRows.single['account_uid'], isNull);
  });

  test('rollback can regenerate the legacy preference snapshot', () async {
    await service.initialize();
    final task = await service.createTask(title: 'Rollback task');
    await service.restoreLegacyPreferencesForRollback();

    final prefs = await SharedPreferences.getInstance();
    final snapshot = prefs.getStringList('tasks');
    expect(snapshot, hasLength(1));
    final restored = jsonDecode(snapshot!.single) as Map<String, dynamic>;
    expect(restored['id'], task.id);
    expect(restored['schemaVersion'], 1);
    expect((await DatabaseHelper().getAllTasks()), hasLength(1));
  });

  test('rollback keeps invalid legacy preference entries', () async {
    final prefs = await SharedPreferences.getInstance();
    const invalidEntry = '{"schemaVersion":99,"id":"future-task"}';
    await prefs.setStringList('tasks', [invalidEntry]);

    await service.initialize();
    final task =
        await service.createTask(title: 'Rollback with invalid source');
    await service.restoreLegacyPreferencesForRollback();

    final snapshot = prefs.getStringList('tasks');
    expect(snapshot, hasLength(2));
    expect(snapshot, contains(invalidEntry));
    final canonicalSnapshot = snapshot!
        .map((entry) => jsonDecode(entry))
        .whereType<Map<String, dynamic>>()
        .singleWhere((entry) => entry['id'] == task.id);
    expect(canonicalSnapshot['schemaVersion'], 1);
    expect((await DatabaseHelper().getAllTasks()), hasLength(1));
  });

  test('version 6 schema upgrade retains legacy task rows', () async {
    final directory = await Directory.systemTemp.createTemp(
      'focusbro-task-schema-test-',
    );
    final path = p.join(directory.path, 'legacy.db');
    final legacy = await sqflite.openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL
          )
        ''');
        await db.insert('tasks', {
          'id': 'version-6-task',
          'title': 'Must survive schema upgrade',
        });
      },
    );
    await legacy.close();

    final upgraded = await sqflite.openDatabase(
      path,
      version: 7,
      onUpgrade: DatabaseHelper.upgradeForTesting,
    );
    final rows = await upgraded.query('tasks');
    final columns = await upgraded.rawQuery('PRAGMA table_info(tasks)');
    await upgraded.close();
    await sqflite.databaseFactory.deleteDatabase(path);
    await directory.delete(recursive: true);

    expect(rows.single['id'], 'version-6-task');
    expect(rows.single['title'], 'Must survive schema upgrade');
    expect(rows.single['task_json'], isNull);
    expect(columns.map((column) => column['name']), contains('task_json'));
  });

  test('invalid preference payload remains available for recovery', () async {
    final prefs = await SharedPreferences.getInstance();
    const invalidEntry = '{"schemaVersion":99,"id":"future-task"}';
    await prefs.setStringList('tasks', [invalidEntry]);

    await service.initialize();

    expect(prefs.getStringList('tasks'), [invalidEntry]);
    expect(service.migrationIssues, isNotEmpty);
    expect(service.tasks, isEmpty);
  });
}
