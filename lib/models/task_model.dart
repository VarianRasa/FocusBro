import 'package:flutter/material.dart';

import 'task_json_schema.dart';

const Object _copyWithUnset = Object();

/// Task priority levels
enum TaskPriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
      case TaskPriority.urgent:
        return 'Urgent';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.blue;
      case TaskPriority.high:
        return Colors.orange;
      case TaskPriority.urgent:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
      case TaskPriority.urgent:
        return Icons.priority_high;
    }
  }
}

/// Task status
enum TaskStatus {
  todo,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case TaskStatus.todo:
        return 'To Do';
      case TaskStatus.inProgress:
        return 'In Progress';
      case TaskStatus.completed:
        return 'Completed';
      case TaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.todo:
        return Colors.grey;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
      case TaskStatus.cancelled:
        return Colors.red;
    }
  }
}

/// Task category
enum TaskCategory {
  work,
  personal,
  health,
  learning,
  shopping,
  other;

  String get displayName {
    switch (this) {
      case TaskCategory.work:
        return 'Work';
      case TaskCategory.personal:
        return 'Personal';
      case TaskCategory.health:
        return 'Health';
      case TaskCategory.learning:
        return 'Learning';
      case TaskCategory.shopping:
        return 'Shopping';
      case TaskCategory.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskCategory.work:
        return Icons.work;
      case TaskCategory.personal:
        return Icons.person;
      case TaskCategory.health:
        return Icons.favorite;
      case TaskCategory.learning:
        return Icons.school;
      case TaskCategory.shopping:
        return Icons.shopping_cart;
      case TaskCategory.other:
        return Icons.category;
    }
  }

  Color get color {
    switch (this) {
      case TaskCategory.work:
        return Colors.blue;
      case TaskCategory.personal:
        return Colors.green;
      case TaskCategory.health:
        return Colors.red;
      case TaskCategory.learning:
        return Colors.purple;
      case TaskCategory.shopping:
        return Colors.orange;
      case TaskCategory.other:
        return Colors.grey;
    }
  }
}

/// Task Urgency enumeration for upcoming tasks
enum TaskUrgency {
  none('None', Color(0xFF9E9E9E)),
  low('Low', Color(0xFF4CAF50)),
  medium('Medium', Color(0xFFFF9800)),
  high('High', Color(0xFFFF5722)),
  critical('Critical', Color(0xFFF44336)),
  overdue('Overdue', Color(0xFF9C27B0));

  const TaskUrgency(this.label, this.color);

  final String label;
  final Color color;
}

/// Subtask model
class SubTask {
  final String id;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? completedAt;
  final Map<String, dynamic> extraFields;

  SubTask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdAt,
    this.completedAt,
    Map<String, dynamic> extraFields = const {},
  }) : extraFields = Map<String, dynamic>.unmodifiable(extraFields);

  SubTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    DateTime? createdAt,
    Object? completedAt = _copyWithUnset,
    Map<String, dynamic>? extraFields,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _copyWithUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...extraFields,
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SubTask.fromJson(Map<String, dynamic> json) {
    return SubTask(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      extraFields: {
        for (final entry in json.entries)
          if (!_knownSubTaskJsonKeys.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  static const Set<String> _knownSubTaskJsonKeys = {
    'id',
    'title',
    'isCompleted',
    'createdAt',
    'completedAt',
  };
}

/// Main Task model
class Task {
  final String id;
  final String title;
  final String description;
  final TaskPriority priority;
  final TaskStatus status;
  final TaskCategory category;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final List<SubTask> subTasks;
  final List<String> tags;
  final int estimatedFocusSessions;
  final int completedFocusSessions;
  final Duration totalFocusTime;
  final bool isRecurring;
  final String? recurringPattern;
  final DateTime? lastFocusSession;
  final double progress;
  final int sortOrder;
  final Map<String, dynamic> extraFields;

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = TaskPriority.medium,
    this.status = TaskStatus.todo,
    this.category = TaskCategory.other,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.completedAt,
    this.subTasks = const [],
    this.tags = const [],
    this.estimatedFocusSessions = 1,
    this.completedFocusSessions = 0,
    this.totalFocusTime = Duration.zero,
    this.isRecurring = false,
    this.recurringPattern,
    this.lastFocusSession,
    this.progress = 0.0,
    this.sortOrder = 0,
    Map<String, dynamic> extraFields = const {},
  }) : extraFields = Map<String, dynamic>.unmodifiable(extraFields);

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskPriority? priority,
    TaskStatus? status,
    TaskCategory? category,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? dueDate = _copyWithUnset,
    Object? completedAt = _copyWithUnset,
    List<SubTask>? subTasks,
    List<String>? tags,
    int? estimatedFocusSessions,
    int? completedFocusSessions,
    Duration? totalFocusTime,
    bool? isRecurring,
    Object? recurringPattern = _copyWithUnset,
    Object? lastFocusSession = _copyWithUnset,
    double? progress,
    int? sortOrder,
    Map<String, dynamic>? extraFields,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: identical(dueDate, _copyWithUnset)
          ? this.dueDate
          : dueDate as DateTime?,
      completedAt: identical(completedAt, _copyWithUnset)
          ? this.completedAt
          : completedAt as DateTime?,
      subTasks: subTasks ?? this.subTasks,
      tags: tags ?? this.tags,
      estimatedFocusSessions:
          estimatedFocusSessions ?? this.estimatedFocusSessions,
      completedFocusSessions:
          completedFocusSessions ?? this.completedFocusSessions,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
      isRecurring: isRecurring ?? this.isRecurring,
      recurringPattern: identical(recurringPattern, _copyWithUnset)
          ? this.recurringPattern
          : recurringPattern as String?,
      lastFocusSession: identical(lastFocusSession, _copyWithUnset)
          ? this.lastFocusSession
          : lastFocusSession as DateTime?,
      progress: progress ?? this.progress,
      sortOrder: sortOrder ?? this.sortOrder,
      extraFields: extraFields ?? this.extraFields,
    );
  }

  /// Calculate task progress based on subtasks and focus sessions
  double calculateProgress() {
    if (subTasks.isEmpty && estimatedFocusSessions == 0) {
      return status == TaskStatus.completed ? 1.0 : 0.0;
    }

    double subTaskProgress = 0.0;
    double focusProgress = 0.0;

    if (subTasks.isNotEmpty) {
      final completedSubTasks = subTasks.where((st) => st.isCompleted).length;
      subTaskProgress = completedSubTasks / subTasks.length;
    }

    if (estimatedFocusSessions > 0) {
      focusProgress =
          (completedFocusSessions / estimatedFocusSessions).clamp(0.0, 1.0);
    }

    // Weight subtasks and focus sessions equally if both exist
    if (subTasks.isNotEmpty && estimatedFocusSessions > 0) {
      return (subTaskProgress + focusProgress) / 2;
    } else if (subTasks.isNotEmpty) {
      return subTaskProgress;
    } else {
      return focusProgress;
    }
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || status == TaskStatus.completed) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Check if task is due today
  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    return taskDate.isAtSameMomentAs(today);
  }

  /// Check if task is due this week
  bool get isDueThisWeek {
    if (dueDate == null) return false;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));
    return dueDate!.isAfter(weekStart) && dueDate!.isBefore(weekEnd);
  }

  /// Get time until due date
  String get timeUntilDue {
    if (dueDate == null) return '';

    final now = DateTime.now();
    final difference = dueDate!.difference(now);

    if (difference.isNegative) {
      final overdue = now.difference(dueDate!);
      if (overdue.inDays > 0) {
        return '${overdue.inDays} days overdue';
      } else if (overdue.inHours > 0) {
        return '${overdue.inHours} hours overdue';
      } else {
        return '${overdue.inMinutes} minutes overdue';
      }
    } else {
      if (difference.inDays > 0) {
        return '${difference.inDays} days left';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours left';
      } else {
        return '${difference.inMinutes} minutes left';
      }
    }
  }

  /// Get enhanced time until due date for upcoming tasks
  String get enhancedTimeUntilDue {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final difference = dueDate!.difference(now);

    if (difference.isNegative) {
      final overdue = now.difference(dueDate!);
      if (overdue.inDays > 0) {
        return 'Overdue by ${overdue.inDays} day${overdue.inDays > 1 ? 's' : ''}';
      } else if (overdue.inHours > 0) {
        return 'Overdue by ${overdue.inHours} hour${overdue.inHours > 1 ? 's' : ''}';
      } else {
        return 'Overdue by ${overdue.inMinutes} minute${overdue.inMinutes > 1 ? 's' : ''}';
      }
    } else {
      if (difference.inDays > 7) {
        final weeks = (difference.inDays / 7).floor();
        final remainingDays = difference.inDays % 7;
        if (remainingDays == 0) {
          return 'Due in $weeks week${weeks > 1 ? 's' : ''}';
        } else {
          return 'Due in ${weeks}w ${remainingDays}d';
        }
      } else if (difference.inDays > 0) {
        return 'Due in ${difference.inDays} day${difference.inDays > 1 ? 's' : ''}';
      } else if (difference.inHours > 0) {
        return 'Due in ${difference.inHours} hour${difference.inHours > 1 ? 's' : ''}';
      } else if (difference.inMinutes > 0) {
        return 'Due in ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
      } else {
        return 'Due now';
      }
    }
  }

  /// Get relative due date description for upcoming tasks
  String get relativeDueDate {
    if (dueDate == null) return 'No due date';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final difference = taskDate.difference(today).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference <= 7) {
      return 'This week';
    } else if (difference <= 14) {
      return 'Next week';
    } else if (difference <= 30) {
      return 'This month';
    } else {
      return 'Later';
    }
  }

  /// Get urgency level based on due date proximity
  TaskUrgency get urgencyLevel {
    if (dueDate == null) return TaskUrgency.none;
    if (isOverdue) return TaskUrgency.overdue;

    final now = DateTime.now();
    final difference = dueDate!.difference(now);

    if (difference.inHours <= 2) {
      return TaskUrgency.critical;
    } else if (difference.inHours <= 24) {
      return TaskUrgency.high;
    } else if (difference.inDays <= 3) {
      return TaskUrgency.medium;
    } else if (difference.inDays <= 7) {
      return TaskUrgency.low;
    } else {
      return TaskUrgency.none;
    }
  }

  /// Check if task is approaching deadline (within 24 hours)
  bool get isApproachingDeadline {
    if (dueDate == null || isOverdue) return false;
    final now = DateTime.now();
    final difference = dueDate!.difference(now);
    return difference.inHours <= 24;
  }

  /// Check if task needs attention (overdue or approaching deadline)
  bool get needsAttention {
    return isOverdue || isApproachingDeadline;
  }

  /// Get formatted due date string
  String get formattedDueDate {
    if (dueDate == null) return 'No due date';
    return '${dueDate!.day}/${dueDate!.month}/${dueDate!.year}';
  }

  /// Get formatted created at string
  String get formattedCreatedAt {
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Alias for subTasks to maintain compatibility
  List<SubTask> get subtasks => subTasks;

  Map<String, dynamic> toJson() {
    return {
      ...extraFields,
      'schemaVersion': TaskJsonSchema.currentVersion,
      'id': id,
      'title': title,
      'description': description,
      'priority': priority.name,
      'status': status.name,
      'category': category.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'subTasks': subTasks.map((st) => st.toJson()).toList(),
      'tags': tags,
      'estimatedFocusSessions': estimatedFocusSessions,
      'completedFocusSessions': completedFocusSessions,
      'totalFocusTime': totalFocusTime.inSeconds,
      'isRecurring': isRecurring,
      'recurringPattern': recurringPattern,
      'lastFocusSession': lastFocusSession?.toIso8601String(),
      'progress': progress,
      'sortOrder': sortOrder,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TaskStatus.todo,
      ),
      category: TaskCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TaskCategory.other,
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.parse(json[
              'createdAt']), // Fallback to createdAt for backward compatibility
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      subTasks: (json['subTasks'] as List<dynamic>?)
              ?.map((st) => SubTask.fromJson(st))
              .toList() ??
          [],
      tags: List<String>.from(json['tags'] ?? []),
      estimatedFocusSessions: json['estimatedFocusSessions'] ?? 1,
      completedFocusSessions: json['completedFocusSessions'] ?? 0,
      totalFocusTime: Duration(seconds: json['totalFocusTime'] ?? 0),
      isRecurring: json['isRecurring'] ?? false,
      recurringPattern: json['recurringPattern'],
      lastFocusSession: json['lastFocusSession'] != null
          ? DateTime.parse(json['lastFocusSession'])
          : null,
      progress: json['progress']?.toDouble() ?? 0.0,
      sortOrder: json['sortOrder'] ?? 0,
      extraFields: {
        for (final entry in json.entries)
          if (!_knownTaskJsonKeys.contains(entry.key)) entry.key: entry.value,
      },
    );
  }

  static const Set<String> _knownTaskJsonKeys = {
    'schemaVersion',
    'id',
    'title',
    'description',
    'priority',
    'status',
    'category',
    'createdAt',
    'updatedAt',
    'dueDate',
    'completedAt',
    'subTasks',
    'tags',
    'estimatedFocusSessions',
    'completedFocusSessions',
    'totalFocusTime',
    'isRecurring',
    'recurringPattern',
    'lastFocusSession',
    'progress',
    'sortOrder',
  };
}
