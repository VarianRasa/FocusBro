import 'package:flutter/material.dart';
import 'base_model.dart';

/// Enum for different types of goals
enum GoalType {
  dailyFocusTime,
  weeklySessions,
  monthlyStreak,
  totalSessions,
  completionRate,
  custom,
}

/// Enum for goal frequency
enum GoalFrequency {
  daily,
  weekly,
  monthly,
  yearly,
  oneTime,
}

/// Enum for goal status
enum GoalStatus {
  active,
  completed,
  paused,
  cancelled,
}

/// Extension for GoalType to provide display properties
extension GoalTypeExtension on GoalType {
  String get displayName {
    switch (this) {
      case GoalType.dailyFocusTime:
        return 'Daily Focus Time';
      case GoalType.weeklySessions:
        return 'Weekly Sessions';
      case GoalType.monthlyStreak:
        return 'Monthly Streak';
      case GoalType.totalSessions:
        return 'Total Sessions';
      case GoalType.completionRate:
        return 'Completion Rate';
      case GoalType.custom:
        return 'Custom Goal';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalType.dailyFocusTime:
        return Icons.access_time;
      case GoalType.weeklySessions:
        return Icons.repeat;
      case GoalType.monthlyStreak:
        return Icons.local_fire_department;
      case GoalType.totalSessions:
        return Icons.timer;
      case GoalType.completionRate:
        return Icons.check_circle;
      case GoalType.custom:
        return Icons.flag;
    }
  }

  Color get color {
    switch (this) {
      case GoalType.dailyFocusTime:
        return Colors.green;
      case GoalType.weeklySessions:
        return Colors.blue;
      case GoalType.monthlyStreak:
        return Colors.orange;
      case GoalType.totalSessions:
        return Colors.purple;
      case GoalType.completionRate:
        return Colors.teal;
      case GoalType.custom:
        return Colors.indigo;
    }
  }

  String get unit {
    switch (this) {
      case GoalType.dailyFocusTime:
        return 'hours';
      case GoalType.weeklySessions:
        return 'sessions';
      case GoalType.monthlyStreak:
        return 'days';
      case GoalType.totalSessions:
        return 'sessions';
      case GoalType.completionRate:
        return '%';
      case GoalType.custom:
        return '';
    }
  }
}

/// Extension for GoalFrequency
extension GoalFrequencyExtension on GoalFrequency {
  String get displayName {
    switch (this) {
      case GoalFrequency.daily:
        return 'Daily';
      case GoalFrequency.weekly:
        return 'Weekly';
      case GoalFrequency.monthly:
        return 'Monthly';
      case GoalFrequency.yearly:
        return 'Yearly';
      case GoalFrequency.oneTime:
        return 'One Time';
    }
  }
}

/// Extension for GoalStatus
extension GoalStatusExtension on GoalStatus {
  String get displayName {
    switch (this) {
      case GoalStatus.active:
        return 'Active';
      case GoalStatus.completed:
        return 'Completed';
      case GoalStatus.paused:
        return 'Paused';
      case GoalStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case GoalStatus.active:
        return Colors.blue;
      case GoalStatus.completed:
        return Colors.green;
      case GoalStatus.paused:
        return Colors.orange;
      case GoalStatus.cancelled:
        return Colors.red;
    }
  }
}

/// Main Goal model
class Goal extends BaseModel {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final GoalFrequency frequency;
  final GoalStatus status;
  final double targetValue;
  final double currentValue;
  final String? customUnit;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? completedAt;
  final bool isArchived;
  final Map<String, dynamic>? metadata;

  Goal({
    required this.id,
    required this.title,
    this.description = '',
    required this.type,
    this.frequency = GoalFrequency.daily,
    this.status = GoalStatus.active,
    required this.targetValue,
    this.currentValue = 0.0,
    this.customUnit,
    required this.createdAt,
    required this.updatedAt,
    this.startDate,
    this.endDate,
    this.completedAt,
    this.isArchived = false,
    this.metadata,
  });

  /// Calculate progress percentage (0.0 to 1.0)
  double get progress {
    if (targetValue <= 0) return 0.0;
    final progressValue = (currentValue / targetValue).clamp(0.0, 1.0);
    return progressValue;
  }

  /// Get progress percentage as integer (0 to 100)
  int get progressPercentage => (progress * 100).round();

  /// Check if goal is completed
  bool get isCompleted => currentValue >= targetValue;

  /// Get display unit
  String get displayUnit => customUnit ?? type.unit;

  /// Get remaining value to reach target
  double get remainingValue =>
      (targetValue - currentValue).clamp(0.0, double.infinity);

  @override
  String get tableName => 'goals';

  /// Get formatted current value
  String get formattedCurrentValue {
    if (type == GoalType.dailyFocusTime) {
      final hours = (currentValue).floor();
      final minutes = ((currentValue - hours) * 60).round();
      return '${hours}h ${minutes}m';
    }
    return currentValue.toStringAsFixed(
        currentValue.truncateToDouble() == currentValue ? 0 : 1);
  }

  /// Get formatted target value
  String get formattedTargetValue {
    if (type == GoalType.dailyFocusTime) {
      final hours = (targetValue).floor();
      final minutes = ((targetValue - hours) * 60).round();
      return '${hours}h ${minutes}m';
    }
    return targetValue
        .toStringAsFixed(targetValue.truncateToDouble() == targetValue ? 0 : 1);
  }

  /// Create a copy with updated values
  Goal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    GoalFrequency? frequency,
    GoalStatus? status,
    double? targetValue,
    double? currentValue,
    String? customUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? completedAt,
    bool? isArchived,
    Map<String, dynamic>? metadata,
  }) {
    return Goal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      frequency: frequency ?? this.frequency,
      status: status ?? this.status,
      targetValue: targetValue ?? this.targetValue,
      currentValue: currentValue ?? this.currentValue,
      customUnit: customUnit ?? this.customUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      completedAt: completedAt ?? this.completedAt,
      isArchived: isArchived ?? this.isArchived,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return toMap();
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'frequency': frequency.name,
      'status': status.name,
      'targetValue': targetValue,
      'currentValue': currentValue,
      'customUnit': customUnit,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'isArchived': isArchived ? 1 : 0, // Convert boolean to integer for SQLite
      'metadata': metadata?.toString(), // Convert to string for SQLite
    };
  }

  /// Create from JSON
  factory Goal.fromJson(Map<String, dynamic> json) {
    return Goal(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: GoalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => GoalType.custom,
      ),
      frequency: GoalFrequency.values.firstWhere(
        (e) => e.name == json['frequency'],
        orElse: () => GoalFrequency.daily,
      ),
      status: GoalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => GoalStatus.active,
      ),
      targetValue: (json['targetValue'] as num).toDouble(),
      currentValue: (json['currentValue'] as num?)?.toDouble() ?? 0.0,
      customUnit: json['customUnit'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      isArchived: (json['isArchived'] is int)
          ? (json['isArchived'] as int) == 1
          : (json['isArchived'] as bool? ?? false),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'Goal(id: $id, title: $title, type: $type, progress: $progressPercentage%)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Goal && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
