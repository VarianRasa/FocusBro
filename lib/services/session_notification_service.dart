import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_notification_data.dart';
import '../utils/session_notification_messages.dart';
import '../utils/error_handler.dart';

/// Enhanced notification service for session completion
class SessionNotificationService extends ChangeNotifier {
  static final SessionNotificationService _instance =
      SessionNotificationService._internal();
  factory SessionNotificationService() => _instance;
  SessionNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  // Notification IDs
  static const int _sessionCompleteId = 1001;
  static const int _achievementId = 1002;
  static const int _streakId = 1003;
  static const int _followUpId = 1004;

  // Channel IDs
  static const String _sessionChannelId = 'session_complete';
  static const String _achievementChannelId = 'achievements';
  static const String _motivationChannelId = 'motivation';

  // Settings
  bool _sessionNotificationsEnabled = true;
  bool _achievementNotificationsEnabled = true;
  bool _motivationalNotificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _notificationSound = 'default';
  int _followUpDelayMinutes = 5;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get sessionNotificationsEnabled => _sessionNotificationsEnabled;
  bool get achievementNotificationsEnabled => _achievementNotificationsEnabled;
  bool get motivationalNotificationsEnabled =>
      _motivationalNotificationsEnabled;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get notificationSound => _notificationSound;
  int get followUpDelayMinutes => _followUpDelayMinutes;

  /// Initialize the session notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      await _initializeNotifications();
      _isInitialized = true;
    } catch (e) {
      ErrorHandler.logError(
          'Failed to initialize SessionNotificationService', e);
    }
  }

  /// Initialize notification settings
  Future<void> _initializeNotifications() async {
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
    await _createNotificationChannels();
  }

  /// Create notification channels
  Future<void> _createNotificationChannels() async {
    const sessionChannel = AndroidNotificationChannel(
      _sessionChannelId,
      'Session Completion',
      description: 'Notifications for completed focus sessions',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const achievementChannel = AndroidNotificationChannel(
      _achievementChannelId,
      'Achievements',
      description: 'Achievement unlock notifications',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    const motivationChannel = AndroidNotificationChannel(
      _motivationChannelId,
      'Motivation',
      description: 'Motivational and follow-up notifications',
      importance: Importance.defaultImportance,
      enableVibration: false,
      playSound: false,
    );

    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(sessionChannel);
      await androidPlugin.createNotificationChannel(achievementChannel);
      await androidPlugin.createNotificationChannel(motivationChannel);
    }
  }

  /// Handle notification response
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      final data = jsonDecode(payload);
      final action = data['action'] as String?;

      switch (action) {
        case 'start_next':
          _handleStartNextSession();
          break;
        case 'view_stats':
          _handleViewStats();
          break;
        case 'take_break':
          _handleTakeBreak();
          break;
        case 'celebrate':
          _handleCelebrate();
          break;
        default:
          break;
      }
    } catch (e) {
      ErrorHandler.logError('Failed to handle notification response', e);
    }
  }

  /// Show session completion notification
  Future<void> showSessionCompleteNotification(
      SessionNotificationData data) async {
    if (!_isInitialized || !_sessionNotificationsEnabled) return;

    try {
      final title = SessionNotificationMessages.getNotificationTitle(data);
      final body = SessionNotificationMessages.getNotificationBody(data);

      // Add streak message if applicable
      String finalBody = body;
      if (data.currentStreak > 1) {
        final streakMessage =
            SessionNotificationMessages.getStreakMessage(data.currentStreak);
        finalBody += '\n$streakMessage';
      }

      // Add achievement message if applicable
      if (data.hasAchievements && data.achievements.isNotEmpty) {
        final achievementMessage =
            SessionNotificationMessages.getAchievementMessage(
                data.achievements);
        finalBody += '\n$achievementMessage';
      }

      final androidDetails = AndroidNotificationDetails(
        _sessionChannelId,
        'Session Completion',
        channelDescription: 'Notifications for completed focus sessions',
        importance: Importance.high,
        priority: Priority.high,
        enableVibration: _vibrationEnabled,
        playSound: _soundEnabled,
        icon: '@mipmap/ic_launcher',
        actions: _buildNotificationActions(data),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final payload = jsonEncode({
        'type': 'session_complete',
        'data': data.toJson(),
      });

      await _notifications.show(
        _sessionCompleteId,
        title,
        finalBody,
        details,
        payload: payload,
      );

      // Schedule follow-up notification if enabled
      if (_motivationalNotificationsEnabled && !data.isAllSessionsComplete) {
        await _scheduleFollowUpNotification(data);
      }
    } catch (e) {
      ErrorHandler.logError('Failed to show session complete notification', e);
    }
  }

  /// Build notification actions based on session data
  List<AndroidNotificationAction> _buildNotificationActions(
      SessionNotificationData data) {
    final actions = <AndroidNotificationAction>[];

    if (data.isAllSessionsComplete) {
      actions.addAll([
        const AndroidNotificationAction(
          'view_stats',
          'View Stats',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_stats'),
        ),
        const AndroidNotificationAction(
          'celebrate',
          'Celebrate',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_celebration'),
        ),
      ]);
    } else {
      if (data.isWorkSession) {
        actions.add(
          const AndroidNotificationAction(
            'take_break',
            'Take Break',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_break'),
          ),
        );
      } else {
        actions.add(
          const AndroidNotificationAction(
            'start_next',
            'Start Next',
            icon: DrawableResourceAndroidBitmap('@drawable/ic_play'),
          ),
        );
      }

      actions.add(
        const AndroidNotificationAction(
          'view_stats',
          'View Stats',
          icon: DrawableResourceAndroidBitmap('@drawable/ic_stats'),
        ),
      );
    }

    return actions;
  }

  /// Schedule follow-up motivational notification
  Future<void> _scheduleFollowUpNotification(
      SessionNotificationData data) async {
    if (!_motivationalNotificationsEnabled) return;

    try {
      final followUpTime =
          DateTime.now().add(Duration(minutes: _followUpDelayMinutes));
      final suggestion =
          SessionNotificationMessages.getNextSessionSuggestion(data);
      final greeting = SessionNotificationMessages.getTimeBasedGreeting();

      const androidDetails = AndroidNotificationDetails(
        _motivationChannelId,
        'Motivation',
        channelDescription: 'Motivational and follow-up notifications',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        enableVibration: false,
        playSound: false,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: false,
        presentSound: false,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Note: For simplicity, showing immediate notification instead of scheduling
      // In production, you might want to use proper scheduling
      await Future.delayed(Duration(minutes: _followUpDelayMinutes), () async {
        await _notifications.show(
          _followUpId,
          '$greeting! 🌟',
          suggestion,
          details,
        );
      });
    } catch (e) {
      ErrorHandler.logError('Failed to schedule follow-up notification', e);
    }
  }

  /// Load notification settings
  Future<void> _loadSettings() async {
    _sessionNotificationsEnabled =
        _prefs?.getBool('session_notifications_enabled') ?? true;
    _achievementNotificationsEnabled =
        _prefs?.getBool('achievement_notifications_enabled') ?? true;
    _motivationalNotificationsEnabled =
        _prefs?.getBool('motivational_notifications_enabled') ?? true;
    _soundEnabled = _prefs?.getBool('notification_sound_enabled') ?? true;
    _vibrationEnabled =
        _prefs?.getBool('notification_vibration_enabled') ?? true;
    _notificationSound = _prefs?.getString('notification_sound') ?? 'default';
    _followUpDelayMinutes = _prefs?.getInt('follow_up_delay_minutes') ?? 5;
  }

  /// Save notification settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool(
        'session_notifications_enabled', _sessionNotificationsEnabled);
    await _prefs?.setBool(
        'achievement_notifications_enabled', _achievementNotificationsEnabled);
    await _prefs?.setBool('motivational_notifications_enabled',
        _motivationalNotificationsEnabled);
    await _prefs?.setBool('notification_sound_enabled', _soundEnabled);
    await _prefs?.setBool('notification_vibration_enabled', _vibrationEnabled);
    await _prefs?.setString('notification_sound', _notificationSound);
    await _prefs?.setInt('follow_up_delay_minutes', _followUpDelayMinutes);
  }

  // Action handlers
  void _handleStartNextSession() {
    // This will be handled by the main app
    debugPrint('Start next session action triggered');
  }

  void _handleViewStats() {
    // This will be handled by the main app
    debugPrint('View stats action triggered');
  }

  void _handleTakeBreak() {
    // This will be handled by the main app
    debugPrint('Take break action triggered');
  }

  void _handleCelebrate() {
    // This will be handled by the main app
    debugPrint('Celebrate action triggered');
  }

  /// Update notification settings
  Future<void> updateSettings({
    bool? sessionNotificationsEnabled,
    bool? achievementNotificationsEnabled,
    bool? motivationalNotificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? notificationSound,
    int? followUpDelayMinutes,
  }) async {
    if (sessionNotificationsEnabled != null) {
      _sessionNotificationsEnabled = sessionNotificationsEnabled;
    }
    if (achievementNotificationsEnabled != null) {
      _achievementNotificationsEnabled = achievementNotificationsEnabled;
    }
    if (motivationalNotificationsEnabled != null) {
      _motivationalNotificationsEnabled = motivationalNotificationsEnabled;
    }
    if (soundEnabled != null) {
      _soundEnabled = soundEnabled;
    }
    if (vibrationEnabled != null) {
      _vibrationEnabled = vibrationEnabled;
    }
    if (notificationSound != null) {
      _notificationSound = notificationSound;
    }
    if (followUpDelayMinutes != null) {
      _followUpDelayMinutes = followUpDelayMinutes.clamp(1, 60);
    }

    await _saveSettings();
    notifyListeners();
  }

  /// Cancel all session notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Dispose resources
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}
