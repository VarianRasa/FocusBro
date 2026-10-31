import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/services/backup_service.dart';
import 'package:focusbro/services/cloud_sync_service.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:focusbro/utils/cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    CacheManager.disableExpirationTimers = true;
    await CacheManager().clearAllCache();
    await DatabaseHelper().deleteDatabase();
    await TaskService().resetForTests();
  });

  tearDown(() async {
    await CloudSyncService().signOut();
    await TaskService().resetForTests();
    await DatabaseHelper().close();
    CacheManager().cancelAllExpirationTimers();
    CacheManager.disableExpirationTimers = false;
  });

  test('TaskService-created tasks are visible to SQLite backup and sync source',
      () async {
    final service = TaskService();
    await service.initialize();

    final created = await service.createTask(
      title: 'Canonical persistence task',
      description: 'Created through the UI task service',
    );

    final databaseTasks = await DatabaseHelper().getAllTasks();
    final databaseTask = databaseTasks.singleWhere(
      (task) => task['id'] == created.id,
    );

    expect(
      databaseTasks.map((task) => task['id']),
      contains(created.id),
      reason: 'BackupService and CloudSyncService read tasks from SQLite.',
    );
    expect(databaseTask['task_json'], isA<String>());
    expect(jsonDecode(databaseTask['task_json'] as String)['title'],
        'Canonical persistence task');
  });

  test('legacy SharedPreferences tasks migrate into SQLite canonical storage',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final legacyTask = Task(
      id: 'legacy-task-1',
      title: 'Legacy preferences task',
      description: 'Stored before SQLite became canonical',
      priority: TaskPriority.high,
      status: TaskStatus.inProgress,
      category: TaskCategory.learning,
      createdAt: DateTime(2026, 1, 1, 8),
      updatedAt: DateTime(2026, 1, 1, 9),
      tags: const ['migration'],
      subTasks: [
        SubTask(
          id: 'legacy-subtask-1',
          title: 'Keep subtask',
          isCompleted: true,
          createdAt: DateTime(2026, 1, 1, 8, 30),
          completedAt: DateTime(2026, 1, 1, 9),
        ),
      ],
      sortOrder: 7,
    );
    await prefs.setStringList('tasks', [jsonEncode(legacyTask.toJson())]);

    final service = TaskService();
    await service.initialize();

    expect(service.tasks.map((task) => task.id), contains(legacyTask.id));
    expect(service.tasks.single.subTasks.single.title, 'Keep subtask');
    expect(prefs.getStringList('tasks'), isNull);

    final databaseTasks = await DatabaseHelper().getAllTasks();
    final migratedRow = databaseTasks.singleWhere(
      (task) => task['id'] == legacyTask.id,
    );
    final migratedJson =
        jsonDecode(migratedRow['task_json'] as String) as Map<String, dynamic>;
    expect(migratedJson['tags'], contains('migration'));
    expect(migratedJson['subTasks'], isNotEmpty);
  });

  test(
      'backup includes TaskService-created tasks from SQLite canonical storage',
      () async {
    final service = TaskService();
    await service.initialize();
    final created = await service.createTask(
      title: 'Backup canonical task',
      description: 'Backup should read this from SQLite',
    );
    await service.addSubTask(created.id, 'Backup subtask');

    final backup = await BackupService.instance.createBackup();
    expect(backup.success, isTrue);
    expect(backup.filePath, isNotNull);

    final backupData = jsonDecode(
      await File(backup.filePath!).readAsString(),
    ) as Map<String, dynamic>;
    final data = backupData['data'] as Map<String, dynamic>;
    final tasks = (data['tasks'] as List).whereType<Map>().toList();
    final backedUpTask = tasks.singleWhere(
      (task) => task['id'] == created.id,
    );
    final backedUpJson =
        jsonDecode(backedUpTask['task_json'] as String) as Map<String, dynamic>;

    expect(backedUpJson['title'], 'Backup canonical task');
    expect(backedUpJson['subTasks'], isNotEmpty);
  });

  test('backup preserves complete task_json metadata from SQLite', () async {
    final service = TaskService();
    await service.initialize();
    final created = await service.createTask(
      title: 'Complete backup task',
      description: 'Every rich task field should survive backup',
      priority: TaskPriority.urgent,
      category: TaskCategory.work,
      tags: const ['deep-work', 'backup'],
      estimatedFocusSessions: 2,
      isRecurring: true,
      recurringPattern: 'weekly',
    );
    final withSubtask = await service.addSubTask(created.id, 'Nested action');
    await service.toggleSubTask(withSubtask.id, withSubtask.subTasks.single.id);
    await service.addFocusSession(created.id, const Duration(minutes: 25));

    final backup = await BackupService.instance.createBackup();
    final backupData = jsonDecode(
      await File(backup.filePath!).readAsString(),
    ) as Map<String, dynamic>;
    final data = backupData['data'] as Map<String, dynamic>;
    final tasks = (data['tasks'] as List).whereType<Map>().toList();
    final backedUpTask = tasks.singleWhere((task) => task['id'] == created.id);
    final taskJson =
        jsonDecode(backedUpTask['task_json'] as String) as Map<String, dynamic>;

    expect(taskJson['tags'], containsAll(['deep-work', 'backup']));
    expect(taskJson['subTasks'], hasLength(1));
    expect(taskJson['isRecurring'], isTrue);
    expect(taskJson['recurringPattern'], 'weekly');
    expect(taskJson['completedFocusSessions'], 1);
    expect(taskJson['totalFocusTime'], 1500);
    expect(taskJson['lastFocusSession'], isA<String>());
    expect(taskJson['progress'], greaterThan(0));
  });

  test('version 7 task rows upgrade and become canonical task_json on load',
      () async {
    await DatabaseHelper().close();
    await DatabaseHelper().deleteDatabase();
    await _createLegacyVersion7TaskDatabase();

    final upgradedRows = await DatabaseHelper().getAllTasks();
    expect(upgradedRows.single['task_json'], isNull);

    final service = TaskService();
    await service.initialize();

    final task = service.tasks.singleWhere((task) => task.id == 'legacy-db-1');
    expect(task.title, 'Legacy DB Task');
    expect(task.subTasks.single.title, 'Legacy DB Subtask');

    final canonicalRows = await DatabaseHelper().getAllTasks();
    final taskJson = jsonDecode(canonicalRows.single['task_json'] as String)
        as Map<String, dynamic>;
    expect(taskJson['title'], 'Legacy DB Task');
    expect(taskJson['subTasks'], isNotEmpty);
  });

  test('restore accepts legacy task backup rows without task_json', () async {
    final file = await _writeBackupFile({
      'tasks': [_legacyTaskRow(id: 'legacy-backup-1')],
      'subtasks': [
        _legacySubtaskRow(
          id: 'legacy-backup-subtask-1',
          taskId: 'legacy-backup-1',
        ),
      ],
    });

    final result = await BackupService.instance.restoreFromBackup(
      filePath: file.path,
    );
    expect(result.success, isTrue);

    final rows = await DatabaseHelper().getAllTasks();
    final restored =
        rows.singleWhere((task) => task['id'] == 'legacy-backup-1');
    final taskJson =
        jsonDecode(restored['task_json'] as String) as Map<String, dynamic>;
    expect(taskJson['title'], 'Legacy Backup Task');
    expect(taskJson['subTasks'], hasLength(1));

    final service = TaskService();
    await service.initialize();
    expect(service.tasks.single.subTasks.single.title, 'Legacy Backup Subtask');
  });

  test('restore replaces tasks without fatal duplication', () async {
    final service = TaskService();
    await service.initialize();
    final created = await service.createTask(
      title: 'Restore canonical task',
      description: 'Restore should keep one copy',
    );

    final backup = await BackupService.instance.createBackup();
    expect(backup.success, isTrue);
    expect(backup.filePath, isNotNull);

    final firstRestore = await BackupService.instance.restoreFromBackup(
      filePath: backup.filePath,
    );
    final secondRestore = await BackupService.instance.restoreFromBackup(
      filePath: backup.filePath,
    );

    expect(firstRestore.success, isTrue);
    expect(secondRestore.success, isTrue);

    final databaseTasks = await DatabaseHelper().getAllTasks();
    expect(
      databaseTasks.where((task) => task['id'] == created.id),
      hasLength(1),
    );

    await service.initialize();
    expect(service.tasks.where((task) => task.id == created.id), hasLength(1));
  });

  test('restore keeps a newer local task over an older backup conflict',
      () async {
    await DatabaseHelper().insertTask(
      _taskJson(
        id: 'restore-conflict',
        title: 'Local newer task',
        updatedAt: DateTime(2026, 1, 3, 9),
        tags: const ['local'],
      ),
    );
    final file = await _writeBackupFile({
      'tasks': [
        _taskJson(
          id: 'restore-conflict',
          title: 'Backup older task',
          updatedAt: DateTime(2026, 1, 2, 9),
          tags: const ['backup'],
        ),
      ],
    });

    final result = await BackupService.instance.restoreFromBackup(
      filePath: file.path,
    );

    expect(result.success, isTrue);
    final row = (await DatabaseHelper().getAllTasks()).singleWhere(
      (task) => task['id'] == 'restore-conflict',
    );
    final taskJson = jsonDecode(row['task_json'] as String);
    expect(taskJson['title'], 'Local newer task');
    expect(taskJson['tags'], contains('local'));
  });

  test('restore applies a newer backup task over an older local conflict',
      () async {
    await DatabaseHelper().insertTask(
      _taskJson(
        id: 'restore-conflict',
        title: 'Local older task',
        updatedAt: DateTime(2026, 1, 2, 9),
        tags: const ['local'],
      ),
    );
    final file = await _writeBackupFile({
      'tasks': [
        _taskJson(
          id: 'restore-conflict',
          title: 'Backup newer task',
          updatedAt: DateTime(2026, 1, 3, 9),
          tags: const ['backup'],
        ),
      ],
    });

    final result = await BackupService.instance.restoreFromBackup(
      filePath: file.path,
    );

    expect(result.success, isTrue);
    final row = (await DatabaseHelper().getAllTasks()).singleWhere(
      (task) => task['id'] == 'restore-conflict',
    );
    final taskJson = jsonDecode(row['task_json'] as String);
    expect(taskJson['title'], 'Backup newer task');
    expect(taskJson['tags'], contains('backup'));
  });

  test(
      'local cloud sync snapshots TaskService tasks from SQLite canonical source',
      () async {
    final service = TaskService();
    await service.initialize();
    await service.createTask(
      title: 'Cloud canonical task',
      description: 'Cloud sync should read this from SQLite',
    );

    final cloudSync = CloudSyncService();
    await cloudSync.initialize();
    await cloudSync.configureBackend(
      provider: CloudSyncBackendProvider.localSnapshot,
    );

    expect(await cloudSync.signIn('focusbro-test@example.com', 'password'),
        isTrue);

    final snapshotCounts = await cloudSync.getCloudSnapshotCounts();
    expect(snapshotCounts['tasks'], 1);
    final cloudTask = await _singleCloudTask();
    final taskJson =
        jsonDecode(cloudTask['task_json'] as String) as Map<String, dynamic>;
    expect(taskJson['title'], 'Cloud canonical task');
  });

  test('cloud sync propagates a local task deletion to the local snapshot',
      () async {
    final taskService = TaskService();
    await taskService.initialize();
    final created = await taskService.createTask(
      title: 'Delete from cloud snapshot',
    );

    final cloudSync = await _authenticatedLocalCloudSync();
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect((await cloudSync.getCloudSnapshotCounts())['tasks'], 1);

    await taskService.deleteTask(created.id);

    expect(await cloudSync.forceSyncNow(), isTrue);
    expect((await cloudSync.getCloudSnapshotCounts())['tasks'], 0);
  });

  test('cloud sync applies a remote task deletion after a baseline sync',
      () async {
    await _seedCloudTasks([
      _taskJson(
        id: 'remote-delete',
        title: 'Remote task to delete',
        updatedAt: DateTime(2026, 1, 2, 12),
      ),
    ]);

    final cloudSync = await _authenticatedLocalCloudSync();
    expect(await cloudSync.forceSyncNow(), isTrue);
    expect(
      (await DatabaseHelper().getAllTasks()).map((task) => task['id']),
      contains('remote-delete'),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cloud_tasks_snapshot_v1',
      jsonEncode({
        'updatedAt': DateTime(2026, 1, 3).toIso8601String(),
        'userId': 'local-sync-test-user',
        'items': <Map<String, dynamic>>[],
      }),
    );

    expect(await cloudSync.forceSyncNow(), isTrue);
    expect(
      (await DatabaseHelper().getAllTasks()).any(
        (task) => task['id'] == 'remote-delete',
      ),
      isFalse,
    );
  });

  test('cloud sync keeps local newer task when remote snapshot is older',
      () async {
    await DatabaseHelper().insertTask(
      _taskJson(
        id: 'cloud-conflict',
        title: 'Local newer cloud task',
        updatedAt: DateTime(2026, 1, 3, 12),
      ),
    );
    await _seedCloudTasks([
      _taskJson(
        id: 'cloud-conflict',
        title: 'Remote older cloud task',
        updatedAt: DateTime(2026, 1, 2, 12),
      ),
    ]);

    final cloudSync = await _authenticatedLocalCloudSync();
    expect(await cloudSync.forceSyncNow(), isTrue);

    final row = (await DatabaseHelper().getAllTasks()).singleWhere(
      (task) => task['id'] == 'cloud-conflict',
    );
    final localJson = jsonDecode(row['task_json'] as String);
    final cloudJson = jsonDecode(
      (await _singleCloudTask())['task_json'] as String,
    );
    expect(localJson['title'], 'Local newer cloud task');
    expect(cloudJson['title'], 'Local newer cloud task');
  });

  test('cloud sync downloads remote newer task over older local task',
      () async {
    await DatabaseHelper().insertTask(
      _taskJson(
        id: 'cloud-conflict',
        title: 'Local older cloud task',
        updatedAt: DateTime(2026, 1, 2, 12),
      ),
    );
    await _seedCloudTasks([
      {
        'task_json': jsonEncode(
          _taskJson(
            id: 'cloud-conflict',
            title: 'Remote newer cloud task',
            updatedAt: DateTime(2026, 1, 3, 12),
          ),
        ),
      },
    ]);

    final cloudSync = await _authenticatedLocalCloudSync();
    expect(await cloudSync.forceSyncNow(), isTrue);

    final row = (await DatabaseHelper().getAllTasks()).singleWhere(
      (task) => task['id'] == 'cloud-conflict',
    );
    final localJson = jsonDecode(row['task_json'] as String);
    expect(localJson['title'], 'Remote newer cloud task');
  });

  test('cloud sync without auth exits safely without touching task data',
      () async {
    await DatabaseHelper().insertTask(
      _taskJson(
        id: 'no-auth-task',
        title: 'No auth local task',
        updatedAt: DateTime(2026, 1, 2, 12),
      ),
    );

    final cloudSync = CloudSyncService();
    await cloudSync.initialize();

    expect(cloudSync.isAuthenticated, isFalse);
    expect(await cloudSync.forceSyncNow(), isFalse);
    expect((await DatabaseHelper().getAllTasks()).single['id'], 'no-auth-task');
    expect((await cloudSync.getCloudSnapshotCounts())['tasks'], 0);
  });
}

Map<String, dynamic> _taskJson({
  required String id,
  required String title,
  required DateTime updatedAt,
  List<String> tags = const [],
}) {
  return Task(
    id: id,
    title: title,
    description: '$title description',
    priority: TaskPriority.high,
    status: TaskStatus.inProgress,
    category: TaskCategory.work,
    createdAt: DateTime(2026, 1, 1, 9),
    updatedAt: updatedAt,
    dueDate: DateTime(2026, 1, 5, 9),
    subTasks: [
      SubTask(
        id: '$id-subtask',
        title: '$title subtask',
        createdAt: DateTime(2026, 1, 1, 10),
      ),
    ],
    tags: tags,
    estimatedFocusSessions: 3,
    completedFocusSessions: 1,
    totalFocusTime: const Duration(minutes: 25),
    isRecurring: true,
    recurringPattern: 'weekly',
    lastFocusSession: DateTime(2026, 1, 1, 11),
    progress: 0.5,
    sortOrder: 2,
  ).toJson();
}

Map<String, dynamic> _legacyTaskRow({required String id}) {
  return {
    'id': id,
    'title': 'Legacy Backup Task',
    'description': 'Legacy row without task_json',
    'category': 'work',
    'priority': 2,
    'due_date': DateTime(2026, 1, 4).toIso8601String(),
    'is_completed': 0,
    'is_favorite': 0,
    'sort_order': 3,
    'notification_enabled': 1,
    'notification_reminder_minutes': 60,
    'notification_repeat': 0,
    'notification_repeat_interval': 0,
    'notification_sound': 1,
    'notification_vibration': 1,
    'notification_priority': 2,
    'notification_custom_sound': null,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 2).toIso8601String(),
  };
}

Map<String, dynamic> _legacySubtaskRow({
  required String id,
  required String taskId,
}) {
  return {
    'id': id,
    'task_id': taskId,
    'title': 'Legacy Backup Subtask',
    'is_completed': 1,
    'sort_order': 0,
    'created_at': DateTime(2026, 1, 1).toIso8601String(),
    'updated_at': DateTime(2026, 1, 2).toIso8601String(),
  };
}

Future<File> _writeBackupFile(Map<String, dynamic> data) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'focusbro_task_restore_${DateTime.now().microsecondsSinceEpoch}.json',
  );
  await file.writeAsString(
    jsonEncode({
      'version': 1,
      'created_at': DateTime(2026, 1, 10).toIso8601String(),
      'data': data,
    }),
  );
  return file;
}

Future<void> _createLegacyVersion7TaskDatabase() async {
  final directory = await getApplicationDocumentsDirectory();
  final path = p.join(directory.path, 'focusbro.db');
  await sqflite.deleteDatabase(path);

  final db = await sqflite.openDatabase(
    path,
    version: 7,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE tasks (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          description TEXT,
          category TEXT NOT NULL,
          priority INTEGER NOT NULL DEFAULT 1,
          due_date TEXT,
          is_completed BOOLEAN NOT NULL DEFAULT 0,
          is_favorite BOOLEAN NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          notification_enabled BOOLEAN NOT NULL DEFAULT 1,
          notification_reminder_minutes INTEGER NOT NULL DEFAULT 60,
          notification_repeat BOOLEAN NOT NULL DEFAULT 0,
          notification_repeat_interval INTEGER NOT NULL DEFAULT 0,
          notification_sound BOOLEAN NOT NULL DEFAULT 1,
          notification_vibration BOOLEAN NOT NULL DEFAULT 1,
          notification_priority INTEGER NOT NULL DEFAULT 2,
          notification_custom_sound TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE subtasks (
          id TEXT PRIMARY KEY,
          task_id TEXT NOT NULL,
          title TEXT NOT NULL,
          is_completed BOOLEAN NOT NULL DEFAULT 0,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
        )
      ''');
    },
  );
  await db.insert('tasks', {
    ..._legacyTaskRow(id: 'legacy-db-1'),
    'title': 'Legacy DB Task',
  });
  await db.insert('subtasks', {
    ..._legacySubtaskRow(id: 'legacy-db-subtask-1', taskId: 'legacy-db-1'),
    'title': 'Legacy DB Subtask',
  });
  await db.close();
}

Future<CloudSyncService> _authenticatedLocalCloudSync() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('user_id', 'local-sync-test-user');
  await prefs.setString(
    'cloud_sync_backend_provider',
    CloudSyncBackendProvider.localSnapshot.name,
  );
  final cloudSync = CloudSyncService();
  await cloudSync.initialize();
  return cloudSync;
}

Future<void> _seedCloudTasks(List<Map<String, dynamic>> tasks) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    'cloud_tasks_snapshot_v1',
    jsonEncode({
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
      'userId': 'local-sync-test-user',
      'items': tasks,
    }),
  );
}

Future<Map<String, dynamic>> _singleCloudTask() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('cloud_tasks_snapshot_v1');
  final snapshot = jsonDecode(raw!) as Map<String, dynamic>;
  final items = (snapshot['items'] as List).whereType<Map>().toList();
  return Map<String, dynamic>.from(items.single);
}
