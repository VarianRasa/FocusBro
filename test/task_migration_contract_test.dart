import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_json_schema.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/services/task_migration_contract.dart';

void main() {
  final migrationTime = DateTime.utc(2026, 1, 1, 12);

  test('legacy pipe entries become versioned canonical task JSON', () {
    final legacyEntry = jsonEncode([
      'legacy-contract-task',
      'Legacy contract task',
      'Preserve migration fields',
      'unknown-category',
      '3',
      '',
      'true',
      '2026-01-01T10:00:00.000Z',
      jsonEncode(['legacy-subtask|Nested action|true']),
      jsonEncode({
        'enabled': false,
        'reminderTime': '25',
        'repeat': true,
        'repeatInterval': '1',
        'sound': false,
        'vibration': true,
        'priority': '3',
      }),
      '1',
    ]);

    final report = TaskMigrationContract.decodePreferenceEntries(
      [legacyEntry],
      migrationTime: migrationTime,
    );
    final task = report.tasks.single;

    expect(report.hasErrors, isFalse);
    expect(task[TaskJsonSchema.versionKey], TaskJsonSchema.currentVersion);
    expect(task['priority'], 'urgent');
    expect(task['status'], 'completed');
    expect(task['category'], 'other');
    expect(task['isFavorite'], isTrue);
    expect(task['subTasks'], hasLength(1));
    expect(task['subTasks'].single['title'], 'Nested action');
    expect(task['notificationSettings']['enabled'], isFalse);
    expect(task['notificationSettings']['reminderMinutes'], 25);
    expect(task['notification_repeat_interval'], 1);
    expect(task['notification_priority'], 3);
  });

  test('canonical entries preserve rich fields and unknown extensions', () {
    final task = TaskMigrationContract.decodeEntry(
      {
        'id': 'canonical-contract-task',
        'title': 'Canonical task',
        'priority': 'high',
        'status': 'in_progress',
        'category': 'learning',
        'createdAt': '2026-01-01T10:00:00.000Z',
        'updatedAt': '2026-01-01T11:00:00.000Z',
        'tags': ['one', 'two'],
        'progress': 0.5,
        'futureField': {'enabled': true},
      },
      migrationTime: migrationTime,
    );

    expect(task[TaskJsonSchema.versionKey], TaskJsonSchema.currentVersion);
    expect(task['status'], 'inProgress');
    expect(task['tags'], ['one', 'two']);
    expect(task['progress'], 0.5);
    expect(task['futureField'], {'enabled': true});
  });

  test('duplicate IDs select newest updatedAt and report a warning', () {
    final older = {
      'id': 'duplicate-task',
      'title': 'Older value',
      'createdAt': '2026-01-01T10:00:00.000Z',
      'updatedAt': '2026-01-01T11:00:00.000Z',
    };
    final newer = {
      'id': 'duplicate-task',
      'title': 'Newer value',
      'createdAt': '2026-01-01T10:00:00.000Z',
      'updatedAt': '2026-01-01T12:00:00.000Z',
    };

    final report = TaskMigrationContract.decodePreferenceEntries(
      [jsonEncode(older), 'not-json', jsonEncode(newer)],
      migrationTime: migrationTime,
    );

    expect(report.scannedCount, 3);
    expect(report.migratedCount, 1);
    expect(report.skippedCount, 2);
    expect(report.tasks.single['title'], 'Newer value');
    expect(report.issues.map((issue) => issue.code),
        containsAll(['invalid_entry', 'duplicate_id']));
    expect(
        report.issues.any(
          (issue) => issue.severity == TaskMigrationIssueSeverity.warning,
        ),
        isTrue);
  });

  test('future schema versions are rejected', () {
    expect(
      () => TaskMigrationContract.decodeEntry({
        'schemaVersion': TaskJsonSchema.currentVersion + 1,
        'id': 'future-task',
      }),
      throwsFormatException,
    );
  });

  test('canonical Task JSON declares the migration schema version', () {
    final task = Task(
      id: 'schema-task',
      title: 'Schema task',
      createdAt: migrationTime,
      updatedAt: migrationTime,
    );

    expect(task.toJson()[TaskJsonSchema.versionKey],
        TaskJsonSchema.currentVersion);
  });
}
