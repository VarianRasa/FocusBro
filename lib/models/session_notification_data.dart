/// Data model for session completion notifications
class SessionNotificationData {
  final String sessionType; // 'work' or 'break'
  final int sessionNumber;
  final int totalSessions;
  final int duration; // in seconds
  final bool isAllSessionsComplete;
  final int totalFocusTime; // total time focused today
  final int currentStreak;
  final bool hasAchievements;
  final List<String> achievements;

  const SessionNotificationData({
    required this.sessionType,
    required this.sessionNumber,
    required this.totalSessions,
    required this.duration,
    required this.isAllSessionsComplete,
    required this.totalFocusTime,
    required this.currentStreak,
    this.hasAchievements = false,
    this.achievements = const [],
  });

  /// Get formatted duration string
  String get formattedDuration {
    final minutes = duration ~/ 60;
    return '${minutes}m';
  }

  /// Get total focus time in hours and minutes
  String get formattedTotalTime {
    final hours = totalFocusTime ~/ 3600;
    final minutes = (totalFocusTime % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Get session progress string
  String get sessionProgress => '$sessionNumber/$totalSessions';

  /// Check if this is a work session
  bool get isWorkSession => sessionType == 'work';

  /// Check if this is a break session
  bool get isBreakSession => sessionType == 'break';

  /// Get completion percentage
  double get completionPercentage => sessionNumber / totalSessions;

  Map<String, dynamic> toJson() {
    return {
      'sessionType': sessionType,
      'sessionNumber': sessionNumber,
      'totalSessions': totalSessions,
      'duration': duration,
      'isAllSessionsComplete': isAllSessionsComplete,
      'totalFocusTime': totalFocusTime,
      'currentStreak': currentStreak,
      'hasAchievements': hasAchievements,
      'achievements': achievements,
    };
  }

  factory SessionNotificationData.fromJson(Map<String, dynamic> json) {
    return SessionNotificationData(
      sessionType: json['sessionType'] ?? 'work',
      sessionNumber: json['sessionNumber'] ?? 1,
      totalSessions: json['totalSessions'] ?? 4,
      duration: json['duration'] ?? 1500,
      isAllSessionsComplete: json['isAllSessionsComplete'] ?? false,
      totalFocusTime: json['totalFocusTime'] ?? 0,
      currentStreak: json['currentStreak'] ?? 0,
      hasAchievements: json['hasAchievements'] ?? false,
      achievements: List<String>.from(json['achievements'] ?? []),
    );
  }
}

/// Notification action types for session completion
enum SessionNotificationAction {
  startNext('start_next', 'Start Next Session'),
  viewStats('view_stats', 'View Statistics'),
  takeBreak('take_break', 'Take Break'),
  celebrate('celebrate', 'Celebrate'),
  dismiss('dismiss', 'Dismiss');

  const SessionNotificationAction(this.id, this.label);

  final String id;
  final String label;
}

/// Notification priority levels
enum SessionNotificationPriority {
  low('low', 'Low Priority'),
  normal('normal', 'Normal Priority'),
  high('high', 'High Priority'),
  urgent('urgent', 'Urgent Priority');

  const SessionNotificationPriority(this.id, this.label);

  final String id;
  final String label;
}
