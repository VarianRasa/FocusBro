import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import '../utils/error_handler.dart';
import '../services/task_service.dart';
import '../services/analytics_service.dart';
import '../models/task_model.dart';

/// Smart notification service with AI-powered scheduling
class SmartNotificationService {
  static final SmartNotificationService _instance =
      SmartNotificationService._internal();
  factory SmartNotificationService() => _instance;
  SmartNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final TaskService _taskService = TaskService();
  final AnalyticsService _analytics = AnalyticsService();

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Notification settings
  bool _smartRemindersEnabled = true;
  bool _focusBreakReminders = true;
  bool _taskDeadlineAlerts = true;
  bool _productivityInsights = true;
  int _reminderFrequency = 2; // hours
  List<int> _quietHours = [22, 23, 0, 1, 2, 3, 4, 5, 6, 7]; // 10 PM to 7 AM

  /// Initialize the smart notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadSettings();

    // Initialize notification settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);

    // Schedule smart reminders
    await _scheduleSmartReminders();

    _isInitialized = true;
  }

  /// Load notification settings
  Future<void> _loadSettings() async {
    _smartRemindersEnabled = _prefs?.getBool('smart_reminders_enabled') ?? true;
    _focusBreakReminders = _prefs?.getBool('focus_break_reminders') ?? true;
    _taskDeadlineAlerts = _prefs?.getBool('task_deadline_alerts') ?? true;
    _productivityInsights = _prefs?.getBool('productivity_insights') ?? true;
    _reminderFrequency = _prefs?.getInt('reminder_frequency') ?? 2;

    final quietHoursJson =
        _prefs?.getString('quiet_hours') ?? jsonEncode(_quietHours);
    _quietHours = List<int>.from(jsonDecode(quietHoursJson));
  }

  /// Save notification settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('smart_reminders_enabled', _smartRemindersEnabled);
    await _prefs?.setBool('focus_break_reminders', _focusBreakReminders);
    await _prefs?.setBool('task_deadline_alerts', _taskDeadlineAlerts);
    await _prefs?.setBool('productivity_insights', _productivityInsights);
    await _prefs?.setInt('reminder_frequency', _reminderFrequency);
    await _prefs?.setString('quiet_hours', jsonEncode(_quietHours));
  }

  /// Schedule smart reminders based on user patterns
  Future<void> _scheduleSmartReminders() async {
    if (!_smartRemindersEnabled) return;

    try {
      // Cancel existing notifications
      await _notifications.cancelAll();

      // Get user's productivity patterns
      final analytics = await _analytics.getProductivityInsights();
      final focusStats = await _analytics.getFocusStatistics(days: 7);

      // Schedule focus session reminders
      await _scheduleFocusReminders(focusStats);

      // Schedule task deadline alerts
      await _scheduleTaskDeadlineAlerts();

      // Schedule productivity insights
      await _scheduleProductivityInsights(analytics);
    } catch (e) {
      ErrorHandler.logError('Failed to schedule smart reminders', e);
    }
  }

  /// Schedule focus session reminders
  Future<void> _scheduleFocusReminders(Map<String, dynamic> focusStats) async {
    if (!_focusBreakReminders) return;

    final completionRate = focusStats['completionRate'] ?? 0.0;
    final dailyAverage = focusStats['dailyAverage'] ?? 0.0;

    // Determine optimal reminder times based on user patterns
    List<int> reminderHours = [];

    if (dailyAverage < 1) {
      // Low activity users - gentle reminders
      reminderHours = [9, 14, 19]; // Morning, afternoon, evening
    } else if (dailyAverage < 3) {
      // Moderate users - regular reminders
      reminderHours = [9, 12, 15, 18]; // Every 3 hours during work day
    } else {
      // High activity users - minimal reminders
      reminderHours = [10, 16]; // Just twice a day
    }

    // Schedule reminders for the next 7 days
    for (int day = 0; day < 7; day++) {
      final targetDate = DateTime.now().add(Duration(days: day));

      for (final hour in reminderHours) {
        if (_quietHours.contains(hour)) continue;

        final scheduledDate = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
          hour,
          0,
        );

        if (scheduledDate.isAfter(DateTime.now())) {
          await _scheduleNotification(
            id: 1000 + (day * 10) + hour,
            title: _getFocusReminderTitle(completionRate),
            body: _getFocusReminderBody(dailyAverage),
            scheduledDate: scheduledDate,
            payload: 'focus_reminder',
          );
        }
      }
    }
  }

  /// Schedule task deadline alerts
  Future<void> _scheduleTaskDeadlineAlerts() async {
    if (!_taskDeadlineAlerts) return;

    final tasks = _taskService.tasks;
    final upcomingTasks = tasks
        .where((task) =>
            task.dueDate != null &&
            task.status != TaskStatus.completed &&
            task.dueDate!.isAfter(DateTime.now()))
        .toList();

    for (final task in upcomingTasks) {
      final dueDate = task.dueDate!;
      final now = DateTime.now();

      // Schedule alerts at different intervals based on priority
      List<Duration> alertIntervals = [];

      switch (task.priority) {
        case TaskPriority.urgent:
          alertIntervals = [
            const Duration(days: 3),
            const Duration(days: 1),
            const Duration(hours: 6),
            const Duration(hours: 1),
          ];
          break;
        case TaskPriority.high:
          alertIntervals = [
            const Duration(days: 2),
            const Duration(hours: 12),
            const Duration(hours: 2),
          ];
          break;
        case TaskPriority.medium:
          alertIntervals = [
            const Duration(days: 1),
            const Duration(hours: 6),
          ];
          break;
        case TaskPriority.low:
          alertIntervals = [
            const Duration(hours: 12),
          ];
          break;
      }

      for (int i = 0; i < alertIntervals.length; i++) {
        final alertTime = dueDate.subtract(alertIntervals[i]);

        if (alertTime.isAfter(now) && !_isQuietHour(alertTime)) {
          await _scheduleNotification(
            id: 2000 + task.id.hashCode + i,
            title: _getTaskAlertTitle(task, alertIntervals[i]),
            body: _getTaskAlertBody(task),
            scheduledDate: alertTime,
            payload: 'task_alert:${task.id}',
          );
        }
      }
    }
  }

  /// Schedule productivity insights
  Future<void> _scheduleProductivityInsights(
      Map<String, dynamic> analytics) async {
    if (!_productivityInsights) return;

    final score = analytics['score'] ?? 0;
    final insights = analytics['insights'] ?? [];

    // Schedule weekly productivity summary (Sundays at 6 PM)
    final now = DateTime.now();
    final nextSunday = now.add(Duration(days: 7 - now.weekday));
    final summaryTime =
        DateTime(nextSunday.year, nextSunday.month, nextSunday.day, 18, 0);

    if (!_isQuietHour(summaryTime)) {
      await _scheduleNotification(
        id: 3000,
        title: '📊 Weekly Productivity Summary',
        body: _getProductivitySummary(score, insights),
        scheduledDate: summaryTime,
        payload: 'productivity_summary',
      );
    }

    // Schedule motivational notifications based on performance
    if (score < 40) {
      // Low performers get encouragement
      await _scheduleMotivationalNotifications('encouragement');
    } else if (score > 80) {
      // High performers get achievement recognition
      await _scheduleMotivationalNotifications('achievement');
    }
  }

  /// Schedule motivational notifications
  Future<void> _scheduleMotivationalNotifications(String type) async {
    final messages = type == 'encouragement'
        ? _getEncouragementMessages()
        : _getAchievementMessages();

    for (int i = 0; i < 3; i++) {
      final scheduledDate =
          DateTime.now().add(Duration(days: i + 1, hours: 10));

      if (!_isQuietHour(scheduledDate)) {
        await _scheduleNotification(
          id: 4000 + i,
          title: messages[i]['title']!,
          body: messages[i]['body']!,
          scheduledDate: scheduledDate,
          payload: 'motivation:$type',
        );
      }
    }
  }

  /// Schedule a notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      // Convert DateTime to TZDateTime for proper timezone handling
      final tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzScheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'focusbro_smart',
            'Smart Notifications',
            channelDescription: 'AI-powered productivity notifications',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payload,
      );
    } catch (e) {
      ErrorHandler.logError('Failed to schedule notification', e);
    }
  }

  /// Check if current time is in quiet hours
  bool _isQuietHour(DateTime time) {
    return _quietHours.contains(time.hour);
  }

  /// Get focus reminder title based on completion rate
  String _getFocusReminderTitle(double completionRate) {
    if (completionRate >= 0.8) {
      return '🎯 Time for another productive session!';
    } else if (completionRate >= 0.6) {
      return '⏰ Ready to focus?';
    } else {
      return '🌱 Let\'s build your focus habit';
    }
  }

  /// Get focus reminder body based on daily average
  String _getFocusReminderBody(double dailyAverage) {
    if (dailyAverage >= 3) {
      return 'You\'re on a roll! Keep the momentum going.';
    } else if (dailyAverage >= 1) {
      return 'A quick 25-minute session can boost your productivity.';
    } else {
      return 'Start small with a 15-minute focus session.';
    }
  }

  /// Get task alert title
  String _getTaskAlertTitle(Task task, Duration timeLeft) {
    final hours = timeLeft.inHours;
    final days = timeLeft.inDays;

    if (days > 0) {
      return '📅 Task due in $days day${days > 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '⏰ Task due in $hours hour${hours > 1 ? 's' : ''}';
    } else {
      return '🚨 Task due soon!';
    }
  }

  /// Get task alert body
  String _getTaskAlertBody(Task task) {
    return '${task.title} - ${task.priority.name.toUpperCase()} priority';
  }

  /// Get productivity summary
  String _getProductivitySummary(int score, List<String> insights) {
    if (score >= 80) {
      return 'Excellent week! You scored $score/100. ${insights.isNotEmpty ? insights.first : ''}';
    } else if (score >= 60) {
      return 'Good progress this week! Score: $score/100. Keep building momentum.';
    } else {
      return 'This week: $score/100. Small steps lead to big improvements!';
    }
  }

  /// Get encouragement messages
  List<Map<String, String>> _getEncouragementMessages() => [
        {
          'title': '🌱 Every Expert Was Once a Beginner',
          'body':
              'Your focus journey is just starting. Each session builds strength.',
        },
        {
          'title': '💪 Small Steps, Big Results',
          'body': 'Even 15 minutes of focused work can make a difference.',
        },
        {
          'title': '🎯 You\'ve Got This!',
          'body': 'Consistency beats perfection. Keep showing up.',
        },
      ];

  /// Get achievement messages
  List<Map<String, String>> _getAchievementMessages() => [
        {
          'title': '🏆 Productivity Champion!',
          'body': 'Your focus skills are impressive. You\'re in the top tier!',
        },
        {
          'title': '🔥 On Fire!',
          'body': 'Your consistency is paying off. Keep up the excellent work!',
        },
        {
          'title': '⭐ Focus Master',
          'body': 'You\'ve mastered the art of deep work. Inspiring!',
        },
      ];

  // Getters and setters for settings
  bool get smartRemindersEnabled => _smartRemindersEnabled;
  bool get focusBreakReminders => _focusBreakReminders;
  bool get taskDeadlineAlerts => _taskDeadlineAlerts;
  bool get productivityInsights => _productivityInsights;
  int get reminderFrequency => _reminderFrequency;
  List<int> get quietHours => _quietHours;

  Future<void> updateSettings({
    bool? smartRemindersEnabled,
    bool? focusBreakReminders,
    bool? taskDeadlineAlerts,
    bool? productivityInsights,
    int? reminderFrequency,
    List<int>? quietHours,
  }) async {
    if (smartRemindersEnabled != null) {
      _smartRemindersEnabled = smartRemindersEnabled;
    }
    if (focusBreakReminders != null) {
      _focusBreakReminders = focusBreakReminders;
    }
    if (taskDeadlineAlerts != null) {
      _taskDeadlineAlerts = taskDeadlineAlerts;
    }
    if (productivityInsights != null) {
      _productivityInsights = productivityInsights;
    }
    if (reminderFrequency != null) {
      _reminderFrequency = reminderFrequency;
    }
    if (quietHours != null) {
      _quietHours = quietHours;
    }

    await _saveSettings();
    await _scheduleSmartReminders(); // Reschedule with new settings
  }
}
