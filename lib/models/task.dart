import 'dart:convert';
import 'base_model.dart';

enum TaskPriority { low, medium, high }

enum NotificationPriority { low, medium, high, urgent }

enum RepeatInterval { none, daily, weekly, monthly }

class NotificationSettings {
  final bool enabled;
  final int reminderMinutes;
  final bool repeat;
  final RepeatInterval repeatInterval;
  final bool sound;
  final bool vibration;
  final NotificationPriority priority;
  final String? customSound;
  final List<int> additionalReminderMinutes;

  const NotificationSettings({
    this.enabled = true,
    this.reminderMinutes = 60,
    this.repeat = false,
    this.repeatInterval = RepeatInterval.daily,
    this.sound = true,
    this.vibration = true,
    this.priority = NotificationPriority.high,
    this.customSound,
    this.additionalReminderMinutes = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'reminder_minutes': reminderMinutes,
      'repeat': repeat,
      'repeat_interval': repeatInterval.index,
      'sound': sound,
      'vibration': vibration,
      'priority': priority.index,
      'custom_sound': customSound,
      'additional_reminder_minutes': jsonEncode(additionalReminderMinutes),
    };
  }

  factory NotificationSettings.fromMap(Map<String, dynamic> map) {
    return NotificationSettings(
      enabled: map['enabled'] == 1,
      reminderMinutes: map['reminder_minutes'] ?? 60,
      repeat: map['repeat'] == 1,
      repeatInterval: RepeatInterval.values[map['repeat_interval'] ?? 0],
      sound: map['sound'] == 1,
      vibration: map['vibration'] == 1,
      priority: NotificationPriority.values[map['priority'] ?? 2],
      customSound: map['custom_sound'],
      additionalReminderMinutes: map['additional_reminder_minutes'] != null
          ? List<int>.from(jsonDecode(map['additional_reminder_minutes']))
          : [],
    );
  }

  NotificationSettings copyWith({
    bool? enabled,
    int? reminderMinutes,
    bool? repeat,
    RepeatInterval? repeatInterval,
    bool? sound,
    bool? vibration,
    NotificationPriority? priority,
    String? customSound,
    List<int>? additionalReminderMinutes,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      repeat: repeat ?? this.repeat,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      priority: priority ?? this.priority,
      customSound: customSound ?? this.customSound,
      additionalReminderMinutes:
          additionalReminderMinutes ?? this.additionalReminderMinutes,
    );
  }
}

class Task extends BaseModelWithTimestamps {
  final String id;
  final String title;
  final String description;
  final String category;
  final TaskPriority priority;
  final DateTime? dueDate;
  final bool isCompleted;
  final bool isFavorite;
  final NotificationSettings notificationSettings;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.isCompleted = false,
    this.isFavorite = false,
    NotificationSettings? notificationSettings,
    required DateTime createdAt,
    required DateTime updatedAt,
  })  : notificationSettings =
            notificationSettings ?? const NotificationSettings(),
        super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'tasks';

  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> toMap() {
    final notificationMap = notificationSettings.toMap();
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'priority': priority.index,
      'due_date': dueDate?.toIso8601String(),
      'is_completed': isCompleted ? 1 : 0,
      'is_favorite': isFavorite ? 1 : 0,
      'notification_enabled': notificationMap['enabled'] ? 1 : 0,
      'notification_reminder_minutes': notificationMap['reminder_minutes'],
      'notification_repeat': notificationMap['repeat'] ? 1 : 0,
      'notification_repeat_interval': notificationMap['repeat_interval'],
      'notification_sound': notificationMap['sound'] ? 1 : 0,
      'notification_vibration': notificationMap['vibration'] ? 1 : 0,
      'notification_priority': notificationMap['priority'],
      'notification_custom_sound': notificationMap['custom_sound'],
      ...baseToMap(),
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final notificationSettings = NotificationSettings.fromMap({
      'enabled': map['notification_enabled'],
      'reminder_minutes': map['notification_reminder_minutes'],
      'repeat': map['notification_repeat'],
      'repeat_interval': map['notification_repeat_interval'],
      'sound': map['notification_sound'],
      'vibration': map['notification_vibration'],
      'priority': map['notification_priority'],
      'custom_sound': map['notification_custom_sound'],
      'additional_reminder_minutes': map['additional_reminder_minutes'],
    });

    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'] ?? '',
      category: map['category'],
      priority: TaskPriority.values[map['priority'] ?? 1],
      dueDate: map['due_date'] != null ? DateTime.parse(map['due_date']) : null,
      isCompleted: map['is_completed'] == 1,
      isFavorite: map['is_favorite'] == 1,
      notificationSettings: notificationSettings,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    bool? isFavorite,
    NotificationSettings? notificationSettings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      isFavorite: isFavorite ?? this.isFavorite,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class Subtask extends BaseModelWithTimestamps {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    this.isCompleted = false,
    this.sortOrder = 0,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'subtasks';

  @override
  String get primaryKey => 'id';

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'task_id': taskId,
      'title': title,
      'is_completed': isCompleted ? 1 : 0,
      'sort_order': sortOrder,
      ...baseToMap(),
    };
  }

  factory Subtask.fromMap(Map<String, dynamic> map) {
    return Subtask(
      id: map['id'],
      taskId: map['task_id'],
      title: map['title'],
      isCompleted: map['is_completed'] == 1,
      sortOrder: map['sort_order'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  Subtask copyWith({
    String? id,
    String? taskId,
    String? title,
    bool? isCompleted,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subtask(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
