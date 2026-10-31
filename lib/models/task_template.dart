import 'package:flutter/material.dart';
import 'task_model.dart';

/// Represents a task template for quick task creation
class TaskTemplate {
  final String id;
  final String name;
  final String description;
  final TaskPriority priority;
  final TaskCategory category;
  final List<String> tags;
  final int estimatedFocusSessions;
  final Duration? estimatedDuration;
  final IconData icon;
  final Color color;
  final bool isBuiltIn;
  final DateTime createdAt;

  const TaskTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.priority,
    required this.category,
    required this.tags,
    required this.estimatedFocusSessions,
    this.estimatedDuration,
    required this.icon,
    required this.color,
    required this.isBuiltIn,
    required this.createdAt,
  });

  /// Create a task from this template
  Task createTask({
    DateTime? dueDate,
    String? customTitle,
    String? customDescription,
  }) {
    final now = DateTime.now();
    return Task(
      id: now.millisecondsSinceEpoch.toString(),
      title: customTitle ?? name,
      description: customDescription ?? description,
      priority: priority,
      category: category,
      createdAt: now,
      updatedAt: now,
      dueDate: dueDate,
      tags: List.from(tags),
      estimatedFocusSessions: estimatedFocusSessions,
    );
  }

  /// Copy with modifications
  TaskTemplate copyWith({
    String? id,
    String? name,
    String? description,
    TaskPriority? priority,
    TaskCategory? category,
    List<String>? tags,
    int? estimatedFocusSessions,
    Duration? estimatedDuration,
    IconData? icon,
    Color? color,
    bool? isBuiltIn,
    DateTime? createdAt,
  }) {
    return TaskTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      estimatedFocusSessions:
          estimatedFocusSessions ?? this.estimatedFocusSessions,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'priority': priority.name,
      'category': category.name,
      'tags': tags,
      'estimatedFocusSessions': estimatedFocusSessions,
      'estimatedDuration': estimatedDuration?.inMinutes,
      'iconCodePoint': icon.codePoint,
      'colorValue': color.toARGB32(),
      'isBuiltIn': isBuiltIn,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory TaskTemplate.fromJson(Map<String, dynamic> json) {
    return TaskTemplate(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      category: TaskCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TaskCategory.other,
      ),
      tags: List<String>.from(json['tags'] ?? []),
      estimatedFocusSessions: json['estimatedFocusSessions'] ?? 1,
      estimatedDuration: json['estimatedDuration'] != null
          ? Duration(minutes: json['estimatedDuration'])
          : null,
      icon: IconData(
        json['iconCodePoint'] ?? Icons.task.codePoint,
        fontFamily: 'MaterialIcons',
      ),
      color: Color(json['colorValue'] ?? Colors.blue.toARGB32()),
      isBuiltIn: json['isBuiltIn'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTemplate &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'TaskTemplate(id: $id, name: $name)';
}

/// Built-in task templates
class BuiltInTaskTemplates {
  static final List<TaskTemplate> templates = [
    TaskTemplate(
      id: 'daily_standup',
      name: 'Daily Standup',
      description: 'Attend daily team standup meeting',
      priority: TaskPriority.medium,
      category: TaskCategory.work,
      tags: ['meeting', 'standup', 'team'],
      estimatedFocusSessions: 1,
      estimatedDuration: const Duration(minutes: 15),
      icon: Icons.groups,
      color: Colors.blue,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    TaskTemplate(
      id: 'code_review',
      name: 'Code Review',
      description: 'Review pull requests and provide feedback',
      priority: TaskPriority.high,
      category: TaskCategory.work,
      tags: ['code', 'review', 'development'],
      estimatedFocusSessions: 2,
      estimatedDuration: const Duration(minutes: 45),
      icon: Icons.code,
      color: Colors.green,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    TaskTemplate(
      id: 'exercise_session',
      name: 'Exercise Session',
      description: 'Complete daily workout routine',
      priority: TaskPriority.medium,
      category: TaskCategory.health,
      tags: ['exercise', 'health', 'fitness'],
      estimatedFocusSessions: 2,
      estimatedDuration: const Duration(minutes: 60),
      icon: Icons.fitness_center,
      color: Colors.orange,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    TaskTemplate(
      id: 'learning_session',
      name: 'Learning Session',
      description: 'Study new technology or skill',
      priority: TaskPriority.medium,
      category: TaskCategory.learning,
      tags: ['learning', 'study', 'skill'],
      estimatedFocusSessions: 3,
      estimatedDuration: const Duration(minutes: 90),
      icon: Icons.school,
      color: Colors.purple,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    TaskTemplate(
      id: 'email_processing',
      name: 'Email Processing',
      description: 'Process and respond to emails',
      priority: TaskPriority.low,
      category: TaskCategory.work,
      tags: ['email', 'communication', 'admin'],
      estimatedFocusSessions: 1,
      estimatedDuration: const Duration(minutes: 30),
      icon: Icons.email,
      color: Colors.teal,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
    TaskTemplate(
      id: 'meal_prep',
      name: 'Meal Preparation',
      description: 'Prepare healthy meals for the day',
      priority: TaskPriority.medium,
      category: TaskCategory.personal,
      tags: ['meal', 'health', 'preparation'],
      estimatedFocusSessions: 2,
      estimatedDuration: const Duration(minutes: 45),
      icon: Icons.restaurant,
      color: Colors.amber,
      isBuiltIn: true,
      createdAt: DateTime.now(),
    ),
  ];
}
