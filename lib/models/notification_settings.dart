/// Notification timing options for upcoming tasks
enum NotificationTiming {
  none('None', Duration.zero),
  fiveMinutes('5 minutes before', Duration(minutes: 5)),
  fifteenMinutes('15 minutes before', Duration(minutes: 15)),
  thirtyMinutes('30 minutes before', Duration(minutes: 30)),
  oneHour('1 hour before', Duration(hours: 1)),
  twoHours('2 hours before', Duration(hours: 2)),
  oneDay('1 day before', Duration(days: 1)),
  twoDays('2 days before', Duration(days: 2)),
  oneWeek('1 week before', Duration(days: 7));

  const NotificationTiming(this.label, this.duration);

  final String label;
  final Duration duration;
}

/// Notification settings for upcoming tasks
class TaskNotificationSettings {
  final bool isEnabled;
  final List<NotificationTiming> reminders;
  final bool showInAppNotifications;
  final bool showSystemNotifications;
  final bool playSound;
  final bool vibrate;
  final String? customMessage;

  const TaskNotificationSettings({
    this.isEnabled = false,
    this.reminders = const [],
    this.showInAppNotifications = true,
    this.showSystemNotifications = true,
    this.playSound = true,
    this.vibrate = true,
    this.customMessage,
  });

  TaskNotificationSettings copyWith({
    bool? isEnabled,
    List<NotificationTiming>? reminders,
    bool? showInAppNotifications,
    bool? showSystemNotifications,
    bool? playSound,
    bool? vibrate,
    String? customMessage,
  }) {
    return TaskNotificationSettings(
      isEnabled: isEnabled ?? this.isEnabled,
      reminders: reminders ?? this.reminders,
      showInAppNotifications:
          showInAppNotifications ?? this.showInAppNotifications,
      showSystemNotifications:
          showSystemNotifications ?? this.showSystemNotifications,
      playSound: playSound ?? this.playSound,
      vibrate: vibrate ?? this.vibrate,
      customMessage: customMessage ?? this.customMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'reminders': reminders.map((r) => r.name).toList(),
      'showInAppNotifications': showInAppNotifications,
      'showSystemNotifications': showSystemNotifications,
      'playSound': playSound,
      'vibrate': vibrate,
      'customMessage': customMessage,
    };
  }

  factory TaskNotificationSettings.fromJson(Map<String, dynamic> json) {
    return TaskNotificationSettings(
      isEnabled: json['isEnabled'] ?? false,
      reminders: (json['reminders'] as List<dynamic>?)
              ?.map((r) => NotificationTiming.values.firstWhere(
                    (timing) => timing.name == r,
                    orElse: () => NotificationTiming.none,
                  ))
              .toList() ??
          [],
      showInAppNotifications: json['showInAppNotifications'] ?? true,
      showSystemNotifications: json['showSystemNotifications'] ?? true,
      playSound: json['playSound'] ?? true,
      vibrate: json['vibrate'] ?? true,
      customMessage: json['customMessage'],
    );
  }
}

/// Filter options for upcoming tasks
enum UpcomingTaskFilter {
  all('All Tasks'),
  thisWeek('This Week'),
  nextWeek('Next Week'),
  thisMonth('This Month'),
  byCategory('By Category'),
  byPriority('By Priority'),
  needsAttention('Needs Attention');

  const UpcomingTaskFilter(this.label);

  final String label;
}

/// Sort options for upcoming tasks
enum UpcomingTaskSort {
  dueDate('Due Date'),
  priority('Priority'),
  category('Category'),
  title('Title'),
  created('Created Date'),
  progress('Progress');

  const UpcomingTaskSort(this.label);

  final String label;
}

/// Grouping options for upcoming tasks
enum UpcomingTaskGrouping {
  none('No Grouping'),
  dueDate('By Due Date'),
  category('By Category'),
  priority('By Priority'),
  urgency('By Urgency'),
  week('By Week');

  const UpcomingTaskGrouping(this.label);

  final String label;
}

/// Time range filter for upcoming tasks
class TimeRangeFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final String label;

  const TimeRangeFilter({
    this.startDate,
    this.endDate,
    required this.label,
  });

  static TimeRangeFilter get thisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return TimeRangeFilter(
      startDate: startOfWeek,
      endDate: endOfWeek,
      label: 'This Week',
    );
  }

  static TimeRangeFilter get nextWeek {
    final now = DateTime.now();
    final startOfNextWeek = now.add(Duration(days: 7 - now.weekday + 1));
    final endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));
    return TimeRangeFilter(
      startDate: startOfNextWeek,
      endDate: endOfNextWeek,
      label: 'Next Week',
    );
  }

  static TimeRangeFilter get thisMonth {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    return TimeRangeFilter(
      startDate: startOfMonth,
      endDate: endOfMonth,
      label: 'This Month',
    );
  }

  static TimeRangeFilter get nextMonth {
    final now = DateTime.now();
    final startOfNextMonth = DateTime(now.year, now.month + 1, 1);
    final endOfNextMonth = DateTime(now.year, now.month + 2, 0);
    return TimeRangeFilter(
      startDate: startOfNextMonth,
      endDate: endOfNextMonth,
      label: 'Next Month',
    );
  }

  bool containsDate(DateTime date) {
    if (startDate != null && date.isBefore(startDate!)) return false;
    if (endDate != null && date.isAfter(endDate!)) return false;
    return true;
  }
}
