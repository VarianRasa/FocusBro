import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/sync_operation.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/repositories/sync_outbox_repository.dart';
import 'package:focusbro/repositories/task_repository.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/migration_service.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await TaskService().resetForTests();
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper().deleteDatabase();
  });

  tearDown(() async {
    await TaskService().resetForTests();
  });

  test('migrates string enum values from legacy pipe tasks', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList('tasks', [
      jsonEncode([
        'legacy-pipe-task',
        'Legacy pipe task',
        'Migrated from the old task format',
        'work',
        '2',
        '',
        'false',
        '2026-01-02T12:00:00.000Z',
        '[]',
        jsonEncode({
          'enabled': true,
          'reminderTime': 30,
          'repeat': true,
          'repeatInterval': '1',
          'sound': true,
          'vibration': false,
          'priority': '2',
          'customSound': null,
        }),
        'true',
      ]),
    ]);

    expect(await MigrationService().performMigrationIfNeeded(), isTrue);

    final migratedRow = (await DatabaseHelper().getAllTasks()).single;
    expect(migratedRow['id'], 'legacy-pipe-task');
    expect(migratedRow['priority'], 2);
    expect(migratedRow['notification_reminder_minutes'], 30);
    expect(migratedRow['notification_repeat_interval'], 1);
    expect(migratedRow['notification_priority'], 2);
    expect(migratedRow['is_favorite'], 1);

    final taskService = TaskService();
    await taskService.initialize();

    expect(taskService.tasks.single.id, 'legacy-pipe-task');
    final canonicalRow = (await DatabaseHelper().getAllTasks()).single;
    expect(canonicalRow['task_json'], isA<String>());
  });

  test('migrates canonical task JSON through the same SQLite contract',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final sourceTask = Task(
      id: 'canonical-migration-task',
      title: 'Canonical migration task',
      description: 'Rich fields must survive the migration boundary',
      priority: TaskPriority.urgent,
      status: TaskStatus.inProgress,
      category: TaskCategory.learning,
      createdAt: DateTime(2026, 1, 2, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
      tags: const ['migration', 'contract'],
      estimatedFocusSessions: 2,
      completedFocusSessions: 1,
      progress: 0.5,
      subTasks: [
        SubTask(
          id: 'canonical-migration-subtask',
          title: 'Keep this nested task',
          isCompleted: true,
          createdAt: DateTime(2026, 1, 2, 8, 30),
          completedAt: DateTime(2026, 1, 2, 9),
        ),
      ],
    );
    await preferences.setStringList('tasks', [jsonEncode(sourceTask.toJson())]);

    final migration = MigrationService();
    expect(await migration.performMigrationIfNeeded(), isTrue);
    expect(migration.lastTaskMigrationReport?.migratedCount, 1);
    expect(migration.lastTaskMigrationReport?.hasErrors, isFalse);
    expect(preferences.getStringList('tasks'), hasLength(1));

    final migratedRow = (await DatabaseHelper().getAllTasks()).single;
    final migratedJson =
        jsonDecode(migratedRow['task_json'] as String) as Map<String, dynamic>;
    expect(migratedJson['schemaVersion'], 1);
    expect(migratedJson['priority'], 'urgent');
    expect(migratedJson['status'], 'inProgress');
    expect(migratedJson['tags'], containsAll(['migration', 'contract']));
    expect(migratedJson['subTasks'], hasLength(1));

    final taskService = TaskService();
    await taskService.initialize();
    expect(taskService.tasks.single.status, TaskStatus.inProgress);
    expect(taskService.tasks.single.subTasks.single.title,
        'Keep this nested task');
  });

  test('preserves existing SQLite tasks while importing preference tasks',
      () async {
    final preferences = await SharedPreferences.getInstance();
    final existingSqliteTask = Task(
      id: 'existing-sqlite-task',
      title: 'Existing SQLite task',
      createdAt: DateTime(2026, 1, 1, 8),
      updatedAt: DateTime(2026, 1, 1, 9),
    );
    final preferenceTask = Task(
      id: 'preference-task',
      title: 'Preference task',
      createdAt: DateTime(2026, 1, 2, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
    );
    await CanonicalTaskRepository().replaceAllTaskPayloads(
      [existingSqliteTask.toJson()],
      enqueue: false,
    );
    await preferences.setStringList(
      'tasks',
      [jsonEncode(preferenceTask.toJson())],
    );

    expect(await MigrationService().performMigrationIfNeeded(), isTrue);

    final migratedRows = await DatabaseHelper().getAllTasks();
    expect(migratedRows, hasLength(2));
    expect(
      migratedRows.map((row) => row['id']),
      containsAll([existingSqliteTask.id, preferenceTask.id]),
    );
  });

  test('imports remote tasks without replacing newer canonical local tasks',
      () async {
    final repository = CanonicalTaskRepository();
    final localTask = Task(
      id: 'shared-task',
      title: 'Newer local task',
      createdAt: DateTime(2026, 1, 1, 8),
      updatedAt: DateTime(2026, 1, 3, 8),
    );
    final remoteTask = Task(
      id: 'remote-task',
      title: 'Remote task',
      createdAt: DateTime(2026, 1, 2, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
    );
    final deletedTask = Task(
      id: 'deleted-task',
      title: 'Do not resurrect',
      createdAt: DateTime(2026, 1, 2, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
    );
    await repository.replaceAllTaskPayloads(
      [localTask.toJson()],
      enqueue: false,
    );
    await SyncOutboxRepository().enqueue(
      SyncOperation.create(
        entityType: 'tasks',
        entityId: deletedTask.id,
        kind: SyncOperationKind.delete,
        schemaVersion: 1,
      ),
    );

    final imported = await repository.importRemoteTaskPayloads([
      localTask.copyWith(title: 'Stale remote version').toJson(),
      remoteTask.toJson(),
      deletedTask.toJson(),
    ]);
    final savedTasks = await repository.loadAllTaskPayloads();
    final savedById = {
      for (final task in savedTasks) task['id']: task,
    };

    expect(imported.map((task) => task['id']), ['remote-task']);
    expect(savedById['shared-task']?['title'], 'Newer local task');
    expect(savedById['remote-task']?['title'], 'Remote task');
    expect(savedById.containsKey('deleted-task'), isFalse);
  });

  test('applies remote-only tasks without dropping local service state',
      () async {
    final taskService = TaskService();
    await taskService.initialize();
    final localTask = await taskService.createTask(title: 'Local task');
    final remoteTask = Task(
      id: 'remote-task',
      title: 'Remote task',
      createdAt: DateTime(2026, 1, 2, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
    );

    await taskService.applyRemoteTaskPayloads([remoteTask.toJson()]);

    expect(
      taskService.tasks.map((task) => task.id),
      containsAll([localTask.id, remoteTask.id]),
    );
  });

  test('serializes remote imports with a concurrent local task save', () async {
    final taskService = TaskService();
    await taskService.initialize();
    final remoteTasks = List.generate(
      32,
      (index) => Task(
        id: 'remote-task-$index',
        title: 'Remote task $index',
        createdAt: DateTime(2026, 1, 2, 8),
        updatedAt: DateTime(2026, 1, 2, 9),
      ).toJson(),
    );

    final importFuture = taskService.applyRemoteTaskPayloads(remoteTasks);
    final createFuture = taskService.createTask(title: 'Local concurrent task');
    final createdTask = await createFuture;
    final importedIds = await importFuture;
    final savedTasks = await CanonicalTaskRepository().loadAllTaskPayloads();

    expect(importedIds, hasLength(remoteTasks.length));
    expect(
      savedTasks.map((task) => task['id']),
      containsAll([...importedIds, createdTask.id]),
    );
  });

  test('retains invalid preference entries through migration cleanup',
      () async {
    final preferences = await SharedPreferences.getInstance();
    const invalidEntry = '{"id":';
    await preferences.setStringList('tasks', [invalidEntry]);

    final migration = MigrationService();
    expect(await migration.performMigrationIfNeeded(), isTrue);
    expect(migration.lastTaskMigrationReport?.hasErrors, isTrue);
    expect(preferences.getStringList('tasks'), [invalidEntry]);

    await migration.cleanupOldData();

    expect(preferences.getStringList('tasks'), [invalidEntry]);
  });
}
