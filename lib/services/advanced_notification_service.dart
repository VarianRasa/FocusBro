import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Advanced notification service with rich notifications and actions
class AdvancedNotificationService {
  static final AdvancedNotificationService _instance =
      AdvancedNotificationService._internal();
  factory AdvancedNotificationService() => _instance;
  AdvancedNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  SharedPreferences? _prefs;

  // Notification channels
  static const String _focusChannelId = 'focus_notifications';
  static const String _breakChannelId = 'break_notifications';
  static const String _reminderChannelId = 'reminder_notifications';
  static const String _achievementChannelId = 'achievement_notifications';

  // Notification IDs
  static const int _focusNotificationId = 1000;
  static const int _breakNotificationId = 1001;
  static const int _reminderNotificationId = 1002;
  static const int _achievementNotificationId = 1003;

  // Action IDs
  static const String _pauseActionId = 'pause_timer';
  static const String _resumeActionId = 'resume_timer';
  static const String _skipActionId = 'skip_session';
  static const String _extendActionId = 'extend_session';
  static const String _startBreakActionId = 'start_break';

  bool _isInitialized = false;
  Function(String)? _onNotificationAction;

  /// Initialize the notification service
  Future<void> initialize({Function(String)? onNotificationAction}) async {
    if (_isInitialized) return;

    _onNotificationAction = onNotificationAction;
    _prefs = await SharedPreferences.getInstance();

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

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channels for Android
    if (Platform.isAndroid) {
      await _createNotificationChannels();
    }

    // Request permissions
    await _requestPermissions();

    _isInitialized = true;
  }

  /// Create notification channels for Android
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Focus session channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _focusChannelId,
        'Focus Sessions',
        description: 'Notifications for focus session status',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    // Break session channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _breakChannelId,
        'Break Sessions',
        description: 'Notifications for break session status',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      ),
    );

    // Reminder channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _reminderChannelId,
        'Reminders',
        description: 'Focus session reminders and alerts',
        importance: Importance.defaultImportance,
        enableVibration: false,
        playSound: true,
      ),
    );

    // Achievement channel
    await androidPlugin.createNotificationChannel(
      const AndroidNotificationChannel(
        _achievementChannelId,
        'Achievements',
        description: 'Achievement and milestone notifications',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
      ),
    );
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.requestNotificationsPermission() ?? false;
    } else if (Platform.isIOS) {
      final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await iosPlugin?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  /// Handle notification responses
  void _onNotificationResponse(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId != null && _onNotificationAction != null) {
      _onNotificationAction!(actionId);
    }
  }

  /// Show focus session started notification
  Future<void> showFocusSessionStarted({
    required int durationMinutes,
    required int sessionNumber,
    required int totalSessions,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _focusChannelId,
      'Focus Sessions',
      channelDescription: 'Focus session notifications',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      actions: [
        AndroidNotificationAction(
          _pauseActionId,
          'Pause',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_pause'),
        ),
        AndroidNotificationAction(
          _skipActionId,
          'Skip',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_skip'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _focusNotificationId,
      'Focus Session $sessionNumber/$totalSessions',
      'Stay focused for $durationMinutes minutes',
      details,
    );
  }

  /// Update focus session progress
  Future<void> updateFocusSessionProgress({
    required int remainingSeconds,
    required int totalSeconds,
    required int sessionNumber,
    required int totalSessions,
  }) async {
    final progress =
        ((totalSeconds - remainingSeconds) / totalSeconds * 100).round();
    final remainingMinutes = (remainingSeconds / 60).ceil();

    final androidDetails = AndroidNotificationDetails(
      _focusChannelId,
      'Focus Sessions',
      channelDescription: 'Focus session notifications',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      actions: const [
        AndroidNotificationAction(
          _pauseActionId,
          'Pause',
        ),
        AndroidNotificationAction(
          _skipActionId,
          'Skip',
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: true,
      presentSound: false,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _focusNotificationId,
      'Focus Session $sessionNumber/$totalSessions',
      '$remainingMinutes minutes remaining',
      details,
    );
  }

  /// Show focus session completed notification
  Future<void> showFocusSessionCompleted({
    required int sessionNumber,
    required int totalSessions,
    required int breakDurationMinutes,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _focusChannelId,
      'Focus Sessions',
      channelDescription: 'Focus session notifications',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          _startBreakActionId,
          'Start Break',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_break'),
        ),
        AndroidNotificationAction(
          _extendActionId,
          'Extend Session',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_extend'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _focusNotificationId,
      'Focus Session Complete! 🎉',
      'Great job! Time for a $breakDurationMinutes minute break.',
      details,
    );
  }

  /// Show break session started notification
  Future<void> showBreakSessionStarted({
    required int durationMinutes,
    required bool isLongBreak,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _breakChannelId,
      'Break Sessions',
      channelDescription: 'Break session notifications',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          _skipActionId,
          'Skip Break',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_skip'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final breakType = isLongBreak ? 'Long Break' : 'Break';
    await _notifications.show(
      _breakNotificationId,
      '$breakType Time ☕',
      'Relax for $durationMinutes minutes',
      details,
    );
  }

  /// Show break session completed notification
  Future<void> showBreakSessionCompleted() async {
    const androidDetails = AndroidNotificationDetails(
      _breakChannelId,
      'Break Sessions',
      channelDescription: 'Break session notifications',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      actions: [
        AndroidNotificationAction(
          _resumeActionId,
          'Start Focus',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_play'),
        ),
      ],
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _breakNotificationId,
      'Break Complete! 💪',
      'Ready to get back to work?',
      details,
    );
  }

  /// Show achievement notification
  Future<void> showAchievementUnlocked({
    required String title,
    required String description,
    required String icon,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Achievements',
      channelDescription: 'Achievement notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _achievementNotificationId,
      'Achievement Unlocked! 🏆',
      '$title - $description',
      details,
    );
  }

  /// Show daily reminder notification
  Future<void> showDailyReminder({
    required String message,
    required DateTime scheduledTime,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _reminderChannelId,
      'Reminders',
      channelDescription: 'Daily reminders',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      _reminderNotificationId,
      'Focus Reminder 🎯',
      message,
      details,
    );
  }

  /// Show streak milestone notification
  Future<void> showStreakMilestone({
    required int streakDays,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      _achievementChannelId,
      'Achievements',
      channelDescription: 'Streak milestones',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      autoCancel: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    String message;
    if (streakDays == 7) {
      message = 'One week of consistent focus! 🔥';
    } else if (streakDays == 30) {
      message = 'One month streak! You\'re unstoppable! 🚀';
    } else if (streakDays == 100) {
      message = '100 days! You\'re a focus master! 👑';
    } else {
      message = '$streakDays days of focused work! Keep it up! 💪';
    }

    await _notifications.show(
      _achievementNotificationId,
      'Streak Milestone! 🔥',
      message,
      details,
    );
  }

  /// Cancel focus session notification
  Future<void> cancelFocusSessionNotification() async {
    await _notifications.cancel(_focusNotificationId);
  }

  /// Cancel break session notification
  Future<void> cancelBreakSessionNotification() async {
    await _notifications.cancel(_breakNotificationId);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Schedule daily reminder
  Future<void> scheduleDailyReminder({
    required TimeOfDay time,
    required String message,
  }) async {
    // Cancel existing reminder
    await _notifications.cancel(_reminderNotificationId);

    // Schedule new reminder
    final now = DateTime.now();
    var scheduledDate = DateTime(
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has passed today, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await showDailyReminder(
      message: message,
      scheduledTime: scheduledDate,
    );

    // Save reminder settings
    await _prefs?.setInt('reminder_hour', time.hour);
    await _prefs?.setInt('reminder_minute', time.minute);
    await _prefs?.setString('reminder_message', message);
    await _prefs?.setBool('reminder_enabled', true);
  }

  /// Cancel daily reminder
  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(_reminderNotificationId);
    await _prefs?.setBool('reminder_enabled', false);
  }

  /// Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin =
          _notifications.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true; // iOS handles this at the system level
  }

  /// Get notification settings
  Future<Map<String, dynamic>> getNotificationSettings() async {
    return {
      'reminder_enabled': _prefs?.getBool('reminder_enabled') ?? false,
      'reminder_hour': _prefs?.getInt('reminder_hour') ?? 9,
      'reminder_minute': _prefs?.getInt('reminder_minute') ?? 0,
      'reminder_message': _prefs?.getString('reminder_message') ??
          'Time to focus! Start your productive day.',
    };
  }

  /// Dispose resources
  void dispose() {
    // Clean up if needed
  }
}
