import 'base_model.dart';

class FocusSession extends BaseModelWithTimestamps {
  final int? id;
  final DateTime sessionDate;
  final int workDuration;
  final int breakDuration;
  final int totalDuration;
  final String sessionType;
  final bool completed;

  FocusSession({
    this.id,
    required this.sessionDate,
    required this.workDuration,
    required this.breakDuration,
    required this.totalDuration,
    this.sessionType = 'work',
    this.completed = true,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : super(createdAt: createdAt, updatedAt: updatedAt);

  @override
  String get tableName => 'focus_sessions';

  @override
  Map<String, dynamic> toMap() {
    final map = {
      'session_date': sessionDate.toIso8601String(),
      'work_duration': workDuration,
      'break_duration': breakDuration,
      'total_duration': totalDuration,
      'session_type': sessionType,
      'completed': completed ? 1 : 0,
      ...baseToMap(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory FocusSession.fromMap(Map<String, dynamic> map) {
    return FocusSession(
      id: map['id'],
      sessionDate: DateTime.parse(map['session_date']),
      workDuration: map['work_duration'],
      breakDuration: map['break_duration'],
      totalDuration: map['total_duration'],
      sessionType: map['session_type'] ?? 'work',
      completed: map['completed'] == 1,
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  FocusSession copyWith({
    int? id,
    DateTime? sessionDate,
    int? workDuration,
    int? breakDuration,
    int? totalDuration,
    String? sessionType,
    bool? completed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FocusSession(
      id: id ?? this.id,
      sessionDate: sessionDate ?? this.sessionDate,
      workDuration: workDuration ?? this.workDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      totalDuration: totalDuration ?? this.totalDuration,
      sessionType: sessionType ?? this.sessionType,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class FocusStatistics extends BaseModel {
  final int? id;
  final int currentStreak;
  final int longestStreak;
  final int totalFocusTime;
  final int totalSessions;
  final DateTime? lastFocusDate;
  final int averageSessionLength;
  final DateTime? bestDayDate;
  final int bestDayDuration;
  final DateTime updatedAt;

  FocusStatistics({
    this.id,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalFocusTime,
    required this.totalSessions,
    this.lastFocusDate,
    required this.averageSessionLength,
    this.bestDayDate,
    required this.bestDayDuration,
    required this.updatedAt,
  });

  @override
  String get tableName => 'focus_statistics';

  @override
  Map<String, dynamic> toMap() {
    final map = {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_focus_time': totalFocusTime,
      'total_sessions': totalSessions,
      'last_focus_date': lastFocusDate?.toIso8601String(),
      'average_session_length': averageSessionLength,
      'best_day_date': bestDayDate?.toIso8601String(),
      'best_day_duration': bestDayDuration,
      'updated_at': updatedAt.toIso8601String(),
    };

    if (id != null) {
      map['id'] = id;
    }

    return map;
  }

  factory FocusStatistics.fromMap(Map<String, dynamic> map) {
    return FocusStatistics(
      id: map['id'],
      currentStreak: map['current_streak'] ?? 0,
      longestStreak: map['longest_streak'] ?? 0,
      totalFocusTime: map['total_focus_time'] ?? 0,
      totalSessions: map['total_sessions'] ?? 0,
      lastFocusDate: map['last_focus_date'] != null
          ? DateTime.parse(map['last_focus_date'])
          : null,
      averageSessionLength: map['average_session_length'] ?? 0,
      bestDayDate: map['best_day_date'] != null
          ? DateTime.parse(map['best_day_date'])
          : null,
      bestDayDuration: map['best_day_duration'] ?? 0,
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }

  FocusStatistics copyWith({
    int? id,
    int? currentStreak,
    int? longestStreak,
    int? totalFocusTime,
    int? totalSessions,
    DateTime? lastFocusDate,
    int? averageSessionLength,
    DateTime? bestDayDate,
    int? bestDayDuration,
    DateTime? updatedAt,
  }) {
    return FocusStatistics(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalFocusTime: totalFocusTime ?? this.totalFocusTime,
      totalSessions: totalSessions ?? this.totalSessions,
      lastFocusDate: lastFocusDate ?? this.lastFocusDate,
      averageSessionLength: averageSessionLength ?? this.averageSessionLength,
      bestDayDate: bestDayDate ?? this.bestDayDate,
      bestDayDuration: bestDayDuration ?? this.bestDayDuration,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
