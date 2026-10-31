import 'dart:math';
import '../models/session_notification_data.dart';

/// Utility class for generating motivational session completion messages
class SessionNotificationMessages {
  static final Random _random = Random();

  /// Get notification title for session completion
  static String getNotificationTitle(SessionNotificationData data) {
    if (data.isAllSessionsComplete) {
      return _getAllSessionsCompleteTitle(data);
    } else if (data.isWorkSession) {
      return _getWorkSessionCompleteTitle(data);
    } else {
      return _getBreakSessionCompleteTitle(data);
    }
  }

  /// Get notification body for session completion
  static String getNotificationBody(SessionNotificationData data) {
    if (data.isAllSessionsComplete) {
      return _getAllSessionsCompleteBody(data);
    } else if (data.isWorkSession) {
      return _getWorkSessionCompleteBody(data);
    } else {
      return _getBreakSessionCompleteBody(data);
    }
  }

  /// Get motivational message based on streak
  static String getStreakMessage(int streak) {
    if (streak >= 30) {
      return _getRandomMessage(_streakMaster);
    } else if (streak >= 14) {
      return _getRandomMessage(_streakExpert);
    } else if (streak >= 7) {
      return _getRandomMessage(_streakIntermediate);
    } else if (streak >= 3) {
      return _getRandomMessage(_streakBeginner);
    } else {
      return _getRandomMessage(_streakStarter);
    }
  }

  /// Get achievement celebration message
  static String getAchievementMessage(List<String> achievements) {
    if (achievements.isEmpty) return '';

    if (achievements.length == 1) {
      return '🏆 Achievement Unlocked: ${achievements.first}!';
    } else {
      return '🏆 ${achievements.length} New Achievements Unlocked!';
    }
  }

  // Private helper methods
  static String _getAllSessionsCompleteTitle(SessionNotificationData data) {
    final titles = [
      '🎉 All Sessions Complete!',
      '✅ Focus Cycle Finished!',
      '🏆 Mission Accomplished!',
      '🌟 Great Work Today!',
      '💪 You Did It!',
    ];
    return _getRandomMessage(titles);
  }

  static String _getAllSessionsCompleteBody(SessionNotificationData data) {
    final messages = [
      'Completed ${data.totalSessions} sessions (${data.formattedTotalTime}). You\'re on fire! 🔥',
      'Amazing focus! ${data.sessionProgress} sessions done in ${data.formattedTotalTime}. Take a well-deserved break! 🌟',
      'Productivity champion! ${data.formattedTotalTime} of focused work completed. You earned this victory! 🏆',
      'Focus master! ${data.totalSessions} sessions conquered. Your dedication is inspiring! 💪',
      'Outstanding work! ${data.formattedTotalTime} of pure focus. Time to celebrate your success! 🎉',
    ];
    return _getRandomMessage(messages);
  }

  static String _getWorkSessionCompleteTitle(SessionNotificationData data) {
    final titles = [
      '✅ Work Session Complete!',
      '🎯 Focus Session Done!',
      '💪 Great Focus!',
      '🌟 Session Finished!',
      '🔥 Well Done!',
    ];
    return _getRandomMessage(titles);
  }

  static String _getWorkSessionCompleteBody(SessionNotificationData data) {
    final messages = [
      'Session ${data.sessionProgress} complete (${data.formattedDuration}). Time for a break! 🌿',
      'Focused for ${data.formattedDuration}! Progress: ${data.sessionProgress}. Keep it up! 💪',
      'Great work! ${data.formattedDuration} of focused effort. You\'re ${(data.completionPercentage * 100).round()}% done! 🎯',
      'Session done! ${data.formattedDuration} of productivity. ${data.totalSessions - data.sessionNumber} more to go! 🚀',
      'Excellent focus! ${data.formattedDuration} completed. You\'re building great habits! 🌟',
    ];
    return _getRandomMessage(messages);
  }

  static String _getBreakSessionCompleteTitle(SessionNotificationData data) {
    final titles = [
      '🌿 Break Time Over!',
      '⚡ Ready to Focus?',
      '🔄 Back to Work!',
      '💪 Let\'s Continue!',
      '🎯 Next Session!',
    ];
    return _getRandomMessage(titles);
  }

  static String _getBreakSessionCompleteBody(SessionNotificationData data) {
    final messages = [
      'Break complete! Ready for session ${data.sessionNumber + 1}? Let\'s maintain the momentum! 🚀',
      'Refreshed and ready! Time for focused work. You\'ve got this! 💪',
      'Break over! Your mind is recharged. Let\'s tackle the next session! ⚡',
      'Well rested! Session ${data.sessionNumber + 1} awaits. Keep up the great work! 🌟',
      'Energy restored! Ready to dive back into focused work? 🎯',
    ];
    return _getRandomMessage(messages);
  }

  static String _getRandomMessage(List<String> messages) {
    return messages[_random.nextInt(messages.length)];
  }

  // Streak-based motivational messages
  static final List<String> _streakStarter = [
    'Great start! Keep building your focus habit! 🌱',
    'Every journey begins with a single step! 👣',
    'You\'re on the right track! Stay consistent! ⭐',
  ];

  static final List<String> _streakBeginner = [
    'Consistency is key! You\'re building momentum! 🔥',
    'Great progress! Your focus habit is forming! 💪',
    'Keep it up! You\'re developing discipline! 🎯',
  ];

  static final List<String> _streakIntermediate = [
    'One week strong! You\'re a focus champion! 🏆',
    'Impressive dedication! Your consistency pays off! 🌟',
    'Week-long streak! You\'re mastering focus! 💎',
  ];

  static final List<String> _streakExpert = [
    'Two weeks of excellence! You\'re unstoppable! 🚀',
    'Focus master in the making! Outstanding commitment! 👑',
    'Your discipline is inspiring! Keep soaring! 🦅',
  ];

  static final List<String> _streakMaster = [
    'Focus legend! 30+ days of pure dedication! 🏆👑',
    'Unbreakable focus! You\'re an inspiration! 🌟💎',
    'Master of concentration! Your consistency is legendary! 🔥🚀',
  ];

  /// Get next session suggestion message
  static String getNextSessionSuggestion(SessionNotificationData data) {
    if (data.isAllSessionsComplete) {
      return 'Take a longer break or start a new focus cycle when ready!';
    } else if (data.isWorkSession) {
      return 'Time for a refreshing break! Your mind needs rest to stay sharp.';
    } else {
      return 'Ready for the next focus session? Let\'s maintain the momentum!';
    }
  }

  /// Get time-based greeting
  static String getTimeBasedGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    } else if (hour < 17) {
      return 'Good afternoon';
    } else {
      return 'Good evening';
    }
  }
}
