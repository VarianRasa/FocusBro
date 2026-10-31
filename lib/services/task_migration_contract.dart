import 'dart:convert';

import '../models/task_json_schema.dart';

enum TaskMigrationSource { legacyPipe, canonicalJson }

enum TaskMigrationIssueSeverity { warning, error }

class TaskMigrationIssue {
  const TaskMigrationIssue({
    required this.source,
    required this.index,
    required this.code,
    required this.message,
    this.severity = TaskMigrationIssueSeverity.error,
  });

  final TaskMigrationSource source;
  final int index;
  final String code;
  final String message;
  final TaskMigrationIssueSeverity severity;

  Map<String, dynamic> toJson() {
    return {
      'source': source.name,
      'index': index,
      'code': code,
      'message': message,
      'severity': severity.name,
    };
  }
}

class TaskMigrationBatch {
  const TaskMigrationBatch({
    required this.scannedCount,
    required this.tasks,
    required this.issues,
  });

  final int scannedCount;
  final List<Map<String, dynamic>> tasks;
  final List<TaskMigrationIssue> issues;

  int get migratedCount => tasks.length;

  int get skippedCount => scannedCount - migratedCount;

  bool get hasErrors => issues.any(
        (issue) => issue.severity == TaskMigrationIssueSeverity.error,
      );

  Map<String, dynamic> toJson() {
    return {
      'scannedCount': scannedCount,
      'migratedCount': migratedCount,
      'skippedCount': skippedCount,
      'issues': issues.map((issue) => issue.toJson()).toList(),
    };
  }
}

class TaskMigrationContract {
  static const int currentVersion = TaskJsonSchema.currentVersion;

  static TaskMigrationBatch decodePreferenceEntries(
    Iterable<String> entries, {
    DateTime? migrationTime,
  }) {
    final referenceTime = migrationTime ?? DateTime.now();
    final tasksById = <String, Map<String, dynamic>>{};
    final issues = <TaskMigrationIssue>[];
    var scannedCount = 0;

    for (final rawEntry in entries) {
      final entryIndex = scannedCount++;
      try {
        final decoded = jsonDecode(rawEntry);
        final source = decoded is List
            ? TaskMigrationSource.legacyPipe
            : TaskMigrationSource.canonicalJson;
        final canonicalTask = decodeEntry(
          decoded,
          migrationTime: referenceTime,
        );
        final taskId = canonicalTask['id'] as String;
        final previousTask = tasksById[taskId];

        if (previousTask == null) {
          tasksById[taskId] = canonicalTask;
          continue;
        }

        final previousUpdatedAt = DateTime.parse(
          previousTask['updatedAt'] as String,
        );
        final candidateUpdatedAt = DateTime.parse(
          canonicalTask['updatedAt'] as String,
        );
        if (!candidateUpdatedAt.isBefore(previousUpdatedAt)) {
          tasksById[taskId] = canonicalTask;
        }
        issues.add(
          TaskMigrationIssue(
            source: source,
            index: entryIndex,
            code: 'duplicate_id',
            message: 'Duplicate task ID resolved using the newest updatedAt.',
            severity: TaskMigrationIssueSeverity.warning,
          ),
        );
      } catch (error) {
        issues.add(
          TaskMigrationIssue(
            source: _sourceForRawEntry(rawEntry),
            index: entryIndex,
            code: 'invalid_entry',
            message: error.toString(),
          ),
        );
      }
    }

    return TaskMigrationBatch(
      scannedCount: scannedCount,
      tasks: List.unmodifiable(tasksById.values),
      issues: List.unmodifiable(issues),
    );
  }

  static Map<String, dynamic> decodeEntry(
    dynamic decoded, {
    DateTime? migrationTime,
  }) {
    final referenceTime = migrationTime ?? DateTime.now();
    if (decoded is Map) {
      return normalizeCanonicalMap(
        Map<String, dynamic>.from(decoded),
        migrationTime: referenceTime,
      );
    }
    if (decoded is List) {
      return _decodeLegacyPipe(
        decoded,
        migrationTime: referenceTime,
      );
    }
    throw const FormatException('Task entry must be a JSON object or array.');
  }

  static Map<String, dynamic> normalizeCanonicalMap(
    Map<String, dynamic> raw, {
    DateTime? migrationTime,
  }) {
    final referenceTime = migrationTime ?? DateTime.now();
    final incomingVersion = _intValue(
      raw[TaskJsonSchema.versionKey],
      fallback: 0,
    );
    if (incomingVersion > currentVersion) {
      throw FormatException(
        'Unsupported task schema version: $incomingVersion.',
      );
    }

    final taskId = _requiredString(raw['id'], fieldName: 'id');
    final title = _stringValue(raw['title'], fallback: 'Untitled Task');
    final description = _stringValue(raw['description'], fallback: '');
    final createdAt = _dateString(
      raw['createdAt'] ?? raw['created_at'],
      referenceTime,
    );
    final updatedAt = _dateString(
      raw['updatedAt'] ?? raw['updated_at'],
      DateTime.parse(createdAt),
    );
    final normalizedStatus = _normalizeStatus(
      raw['status'] ??
          (_parseBool(raw['isCompleted'] ?? raw['is_completed'])
              ? 'completed'
              : 'todo'),
    );
    final completedAt = _nullableDateString(
          raw['completedAt'] ?? raw['completed_at'],
        ) ??
        (normalizedStatus == 'completed' ? updatedAt : null);
    final notificationSettings = _normalizeNotificationSettings(raw);
    final isFavorite = _parseBool(raw['isFavorite'] ?? raw['is_favorite']);
    final normalizedSubtasks = _normalizeSubtasks(
      raw['subTasks'] ?? raw['subtasks'],
      taskId: taskId,
      referenceTime: referenceTime,
    );

    return {
      ...raw,
      TaskJsonSchema.versionKey: currentVersion,
      'id': taskId,
      'title': title,
      'description': description,
      'priority': _normalizePriority(raw['priority']),
      'status': normalizedStatus,
      'category': _normalizeCategory(raw['category']),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'dueDate': _nullableDateString(raw['dueDate'] ?? raw['due_date']),
      'completedAt': completedAt,
      'subTasks': normalizedSubtasks,
      'tags': _stringList(raw['tags']),
      'estimatedFocusSessions': _intValue(
        raw['estimatedFocusSessions'],
        fallback: 1,
      ),
      'completedFocusSessions': _intValue(raw['completedFocusSessions']),
      'totalFocusTime': _intValue(raw['totalFocusTime']),
      'isRecurring': _parseBool(raw['isRecurring']),
      'recurringPattern': _nullableString(raw['recurringPattern']),
      'lastFocusSession': _nullableDateString(raw['lastFocusSession']),
      'progress': _doubleValue(
        raw['progress'],
        fallback: normalizedStatus == 'completed' ? 1 : 0,
      ),
      'sortOrder': _intValue(raw['sortOrder'] ?? raw['sort_order']),
      'isFavorite': isFavorite,
      'is_favorite': isFavorite ? 1 : 0,
      'notificationSettings': notificationSettings,
      'notification_enabled': notificationSettings['enabled'] == true ? 1 : 0,
      'notification_reminder_minutes': notificationSettings['reminderMinutes'],
      'notification_repeat': notificationSettings['repeat'] == true ? 1 : 0,
      'notification_repeat_interval': _enumIndex(
        notificationSettings['repeatInterval'],
        const ['none', 'daily', 'weekly', 'monthly'],
      ),
      'notification_sound': notificationSettings['sound'] == true ? 1 : 0,
      'notification_vibration':
          notificationSettings['vibration'] == true ? 1 : 0,
      'notification_priority': _enumIndex(
        notificationSettings['priority'],
        const ['low', 'medium', 'high', 'urgent'],
      ),
      'notification_custom_sound': notificationSettings['customSound'],
    };
  }

  static Map<String, dynamic> _decodeLegacyPipe(
    List<dynamic> parts, {
    required DateTime migrationTime,
  }) {
    if (parts.length < 8) {
      throw const FormatException('Legacy task entry has too few fields.');
    }

    final rawSubtasks = parts.length > 8 ? _decodeJsonValue(parts[8]) : null;
    final rawNotification = parts.length > 9 ? _decodeJsonMap(parts[9]) : null;

    return normalizeCanonicalMap(
      {
        'id': parts[0],
        'title': parts[1],
        'description': parts[2],
        'category': parts[3],
        'priority': parts[4],
        'dueDate': parts[5],
        'isCompleted': parts[6],
        'status': _parseBool(parts[6]) ? 'completed' : 'todo',
        'createdAt': parts[7],
        'updatedAt': parts[7],
        'subTasks': rawSubtasks,
        'notificationSettings': rawNotification,
        'isFavorite': parts.length > 10 ? parts[10] : false,
      },
      migrationTime: migrationTime,
    );
  }

  static Map<String, dynamic> _normalizeNotificationSettings(
    Map<String, dynamic> task,
  ) {
    final rawSettings = task['notificationSettings'] is Map
        ? Map<String, dynamic>.from(task['notificationSettings'] as Map)
        : task['notification_settings'] is Map
            ? Map<String, dynamic>.from(task['notification_settings'] as Map)
            : <String, dynamic>{};
    final repeatIntervals = const ['none', 'daily', 'weekly', 'monthly'];
    final priorities = const ['low', 'medium', 'high', 'urgent'];
    final repeatInterval = _enumName(
      rawSettings['repeatInterval'] ??
          rawSettings['repeat_interval'] ??
          task['notification_repeat_interval'],
      repeatIntervals,
      'daily',
    );
    final priority = _enumName(
      rawSettings['priority'] ?? task['notification_priority'],
      priorities,
      'high',
    );

    return {
      ...rawSettings,
      'enabled': _parseBool(
        rawSettings['enabled'] ?? task['notification_enabled'],
        fallback: true,
      ),
      'reminderMinutes': _intValue(
        rawSettings['reminderMinutes'] ??
            rawSettings['reminderTime'] ??
            rawSettings['reminder_minutes'] ??
            task['notification_reminder_minutes'],
        fallback: 60,
      ),
      'repeat': _parseBool(
        rawSettings['repeat'] ?? task['notification_repeat'],
      ),
      'repeatInterval': repeatInterval,
      'sound': _parseBool(
        rawSettings['sound'] ?? task['notification_sound'],
        fallback: true,
      ),
      'vibration': _parseBool(
        rawSettings['vibration'] ?? task['notification_vibration'],
        fallback: true,
      ),
      'priority': priority,
      'customSound': _nullableString(
        rawSettings['customSound'] ??
            rawSettings['custom_sound'] ??
            task['notification_custom_sound'],
      ),
      'additionalReminderMinutes': _intList(
        _decodeJsonValue(
          rawSettings['additionalReminderMinutes'] ??
              rawSettings['additional_reminder_minutes'],
        ),
      ),
    };
  }

  static List<Map<String, dynamic>> _normalizeSubtasks(
    dynamic rawSubtasks, {
    required String taskId,
    required DateTime referenceTime,
  }) {
    final decodedSubtasks = _decodeJsonValue(rawSubtasks);
    if (decodedSubtasks is! List) return [];

    final normalized = <Map<String, dynamic>>[];
    for (var index = 0; index < decodedSubtasks.length; index++) {
      final rawSubtask = decodedSubtasks[index];
      Map<String, dynamic> subtask;
      if (rawSubtask is Map) {
        subtask = Map<String, dynamic>.from(rawSubtask);
      } else if (rawSubtask is String) {
        final parts = rawSubtask.split('|');
        if (parts.length < 3) continue;
        subtask = {
          'id': parts[0],
          'title': parts.sublist(1, parts.length - 1).join('|'),
          'isCompleted': parts.last,
        };
      } else {
        continue;
      }

      final createdAt = _dateString(
        subtask['createdAt'] ?? subtask['created_at'],
        referenceTime,
      );
      final isCompleted = _parseBool(
        subtask['isCompleted'] ?? subtask['is_completed'],
      );
      final completedAt = _nullableDateString(
            subtask['completedAt'] ?? subtask['completed_at'],
          ) ??
          (isCompleted ? createdAt : null);
      normalized.add({
        ...subtask,
        'id': _stringValue(
          subtask['id'],
          fallback: '${taskId}_subtask_$index',
        ),
        'title': _stringValue(subtask['title'], fallback: 'Untitled Subtask'),
        'isCompleted': isCompleted,
        'createdAt': createdAt,
        'completedAt': completedAt,
        'updatedAt': _dateString(
          subtask['updatedAt'] ?? subtask['updated_at'],
          DateTime.parse(completedAt ?? createdAt),
        ),
      });
    }
    return normalized;
  }

  static String _normalizePriority(dynamic value) {
    return _enumName(
      value,
      const ['low', 'medium', 'high', 'urgent'],
      'medium',
    );
  }

  static String _normalizeCategory(dynamic value) {
    return _enumName(
      value,
      const ['work', 'personal', 'health', 'learning', 'shopping', 'other'],
      'other',
    );
  }

  static String _normalizeStatus(dynamic value) {
    return _enumName(
      value,
      const ['todo', 'inProgress', 'completed', 'cancelled'],
      'todo',
    );
  }

  static String _enumName(
    dynamic value,
    List<String> names,
    String fallback,
  ) {
    final numericValue = int.tryParse(value?.toString().trim() ?? '');
    if (numericValue != null &&
        numericValue >= 0 &&
        numericValue < names.length) {
      return names[numericValue];
    }

    final normalized = _token(value);
    for (final name in names) {
      if (_token(name) == normalized) return name;
    }
    return fallback;
  }

  static int _enumIndex(dynamic value, List<String> names) {
    final name = _enumName(value, names, names.first);
    return names.indexOf(name);
  }

  static String _token(dynamic value) {
    return value
            ?.toString()
            .trim()
            .toLowerCase()
            .replaceAll('_', '')
            .replaceAll('-', '')
            .replaceAll(' ', '') ??
        '';
  }

  static String _requiredString(dynamic value, {required String fieldName}) {
    final normalized = value?.toString().trim() ?? '';
    if (normalized.isEmpty) {
      throw FormatException('Task $fieldName is required.');
    }
    return normalized;
  }

  static String _stringValue(dynamic value, {required String fallback}) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _nullableString(dynamic value) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static String _dateString(dynamic value, DateTime fallback) {
    return (_parseDate(value) ?? fallback).toIso8601String();
  }

  static String? _nullableDateString(dynamic value) {
    return _parseDate(value)?.toIso8601String();
  }

  static int _intValue(dynamic value, {int fallback = 0}) {
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static double _doubleValue(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().trim() ?? '') ?? fallback;
  }

  static bool _parseBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch (value?.toString().trim().toLowerCase()) {
      case 'true':
      case 'yes':
      case '1':
        return true;
      case 'false':
      case 'no':
      case '0':
        return false;
      default:
        return fallback;
    }
  }

  static List<int> _intList(dynamic value) {
    final decoded = _decodeJsonValue(value);
    if (decoded is! List) return [];
    return decoded.map((item) => _intValue(item)).toList();
  }

  static List<String> _stringList(dynamic value) {
    final decoded = _decodeJsonValue(value);
    if (decoded is List) {
      return decoded
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final normalized = decoded?.toString().trim() ?? '';
    if (normalized.isEmpty) return [];
    return normalized
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static dynamic _decodeJsonValue(dynamic value) {
    if (value is! String || value.trim().isEmpty) return value;
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  static Map<String, dynamic>? _decodeJsonMap(dynamic value) {
    final decoded = _decodeJsonValue(value);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  static TaskMigrationSource _sourceForRawEntry(String rawEntry) {
    try {
      return jsonDecode(rawEntry) is List
          ? TaskMigrationSource.legacyPipe
          : TaskMigrationSource.canonicalJson;
    } catch (_) {
      return TaskMigrationSource.canonicalJson;
    }
  }
}
