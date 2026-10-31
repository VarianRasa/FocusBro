import 'base_model.dart';

class TimerPreset extends BaseModelWithTimestamps {
  final int? id;
  final String name;
  final int workDuration; // in seconds
  final int breakDuration; // in seconds
  final int totalSessions;
  final bool isBuiltIn; // true for default presets, false for user-created
  final bool isActive; // currently applied preset

  TimerPreset({
    this.id,
    required this.name,
    required this.workDuration,
    required this.breakDuration,
    required this.totalSessions,
    this.isBuiltIn = false,
    this.isActive = false,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'timer_presets';

  @override
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'work_duration': workDuration,
      'break_duration': breakDuration,
      'total_sessions': totalSessions,
      'is_built_in': isBuiltIn ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      ...baseToMap(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory TimerPreset.fromMap(Map<String, dynamic> map) {
    return TimerPreset(
      id: map['id'],
      name: map['name'],
      workDuration: map['work_duration'],
      breakDuration: map['break_duration'],
      totalSessions: map['total_sessions'],
      isBuiltIn: map['is_built_in'] == 1,
      isActive: map['is_active'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  // Create from the old Map format used in the UI
  factory TimerPreset.fromLegacyMap(Map<String, dynamic> map,
      {bool isBuiltIn = true}) {
    final now = DateTime.now();
    return TimerPreset(
      name: map['name'] as String,
      workDuration: (map['work'] as int) * 60, // convert minutes to seconds
      breakDuration: (map['break'] as int) * 60, // convert minutes to seconds
      totalSessions: map['sessions'] as int,
      isBuiltIn: isBuiltIn,
      createdAt: now,
      updatedAt: now,
    );
  }

  // Convert to the Map format used in the UI
  Map<String, dynamic> toLegacyMap() {
    return {
      'name': name,
      'work': workDuration ~/ 60, // convert seconds to minutes
      'break': breakDuration ~/ 60, // convert seconds to minutes
      'sessions': totalSessions,
    };
  }

  TimerPreset copyWith({
    int? id,
    String? name,
    int? workDuration,
    int? breakDuration,
    int? totalSessions,
    bool? isBuiltIn,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimerPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      totalSessions: totalSessions ?? this.totalSessions,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Validation methods
  bool get isValid {
    return name.trim().isNotEmpty &&
        workDuration >= 60 &&
        workDuration <= 3600 && // 1-60 minutes
        breakDuration >= 60 &&
        breakDuration <= 3600 && // 1-60 minutes
        totalSessions >= 1 &&
        totalSessions <= 20;
  }

  String? get validationError {
    if (name.trim().isEmpty) {
      return 'Preset name cannot be empty';
    }
    if (name.trim().length > 50) {
      return 'Preset name must be 50 characters or less';
    }
    if (workDuration < 60 || workDuration > 3600) {
      return 'Work duration must be between 1 and 60 minutes';
    }
    if (breakDuration < 60 || breakDuration > 3600) {
      return 'Break duration must be between 1 and 60 minutes';
    }
    if (totalSessions < 1 || totalSessions > 20) {
      return 'Total sessions must be between 1 and 20';
    }
    return null;
  }

  // Built-in presets
  static List<TimerPreset> get builtInPresets {
    final now = DateTime.now();
    return [
      TimerPreset(
        name: 'Pomodoro',
        workDuration: 25 * 60,
        breakDuration: 5 * 60,
        totalSessions: 4,
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      TimerPreset(
        name: 'Short Focus',
        workDuration: 15 * 60,
        breakDuration: 3 * 60,
        totalSessions: 6,
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      TimerPreset(
        name: 'Deep Work',
        workDuration: 45 * 60,
        breakDuration: 10 * 60,
        totalSessions: 3,
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      TimerPreset(
        name: 'Study Session',
        workDuration: 30 * 60,
        breakDuration: 5 * 60,
        totalSessions: 4,
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
      TimerPreset(
        name: 'Quick Break',
        workDuration: 10 * 60,
        breakDuration: 2 * 60,
        totalSessions: 8,
        isBuiltIn: true,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
