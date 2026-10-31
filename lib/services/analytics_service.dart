import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/cache_manager.dart';
import '../repositories/focus_repository.dart';
import '../services/task_service.dart';

/// Analytics service for tracking user behavior and providing insights
class AnalyticsService extends ChangeNotifier {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  static AnalyticsService get instance => _instance;
  AnalyticsService._internal();

  SharedPreferences? _prefs;
  final CacheManager _cache = CacheManager();
  final FocusSessionRepository _focusRepo = FocusSessionRepository();
  final TaskService _taskService = TaskService();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _packageInfo;

  // Privacy control variables
  bool _isInitialized = false;
  bool _analyticsEnabled = false;
  bool _performanceTrackingEnabled = false;
  bool _usageStatisticsEnabled = false;
  bool _productivityMetricsEnabled = false;
  bool _crashReportingEnabled = false;
  bool _dataCollectionEnabled = false;

  List<Map<String, dynamic>> _eventQueue = [];
  Map<String, dynamic> _sessionData = {};
  DateTime? _sessionStartTime;

  // Getters for privacy controls
  bool get isInitialized => _isInitialized;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get performanceTrackingEnabled => _performanceTrackingEnabled;
  bool get usageStatisticsEnabled => _usageStatisticsEnabled;
  bool get productivityMetricsEnabled => _productivityMetricsEnabled;
  bool get crashReportingEnabled => _crashReportingEnabled;
  bool get dataCollectionEnabled => _dataCollectionEnabled;
  Map<String, dynamic> get sessionData => Map.from(_sessionData);
  int get queuedEventsCount => _eventQueue.length;

  /// Initialize analytics service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('AnalyticsService: Starting initialization...');

      _prefs = await SharedPreferences.getInstance();
      _packageInfo = await PackageInfo.fromPlatform();
      await _loadPrivacySettings();
      await _initializeSession();

      _isInitialized = true;
      debugPrint('AnalyticsService: Initialization completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('AnalyticsService: Initialization failed: $e');
    }
  }

  /// Load privacy settings
  Future<void> _loadPrivacySettings() async {
    _analyticsEnabled = _prefs?.getBool('analytics_enabled') ?? false;
    _performanceTrackingEnabled =
        _prefs?.getBool('performance_tracking_enabled') ?? false;
    _usageStatisticsEnabled =
        _prefs?.getBool('usage_statistics_enabled') ?? false;
    _productivityMetricsEnabled =
        _prefs?.getBool('productivity_metrics_enabled') ?? false;
    _crashReportingEnabled =
        _prefs?.getBool('crash_reporting_enabled') ?? false;
    _dataCollectionEnabled =
        _prefs?.getBool('data_collection_enabled') ?? false;
  }

  /// Save privacy settings
  Future<void> _savePrivacySettings() async {
    await _prefs?.setBool('analytics_enabled', _analyticsEnabled);
    await _prefs?.setBool(
        'performance_tracking_enabled', _performanceTrackingEnabled);
    await _prefs?.setBool('usage_statistics_enabled', _usageStatisticsEnabled);
    await _prefs?.setBool(
        'productivity_metrics_enabled', _productivityMetricsEnabled);
    await _prefs?.setBool('crash_reporting_enabled', _crashReportingEnabled);
    await _prefs?.setBool('data_collection_enabled', _dataCollectionEnabled);
  }

  /// Initialize analytics session
  Future<void> _initializeSession() async {
    _sessionStartTime = DateTime.now();
    _sessionData = {
      'session_id': _generateSessionId(),
      'start_time': _sessionStartTime!.toIso8601String(),
      'app_version': _packageInfo?.version ?? 'unknown',
      'build_number': _packageInfo?.buildNumber ?? 'unknown',
      'platform': Platform.operatingSystem,
      'device_info': await _getDeviceInfo(),
    };
  }

  /// Generate unique session ID
  String _generateSessionId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get device information for analytics
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final info = <String, dynamic>{};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'platform': 'Android',
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'platform': 'iOS',
          'version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
        });
      }

      return info;
    } catch (e) {
      debugPrint('AnalyticsService: Error getting device info: $e');
      return {'error': 'Unable to get device info'};
    }
  }

  /// Privacy Control Methods

  /// Enable analytics
  Future<void> enableAnalytics() async {
    _analyticsEnabled = true;
    await _savePrivacySettings();
    await _trackPrivacyEvent('analytics_enabled');
    notifyListeners();
    debugPrint('AnalyticsService: Analytics enabled');
  }

  /// Disable analytics
  Future<void> disableAnalytics() async {
    await _trackPrivacyEvent('analytics_disabled');
    _analyticsEnabled = false;
    await _savePrivacySettings();
    await _clearAnalyticsData();
    notifyListeners();
    debugPrint('AnalyticsService: Analytics disabled');
  }

  /// Enable performance tracking
  Future<void> enablePerformanceTracking() async {
    _performanceTrackingEnabled = true;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Disable performance tracking
  Future<void> disablePerformanceTracking() async {
    _performanceTrackingEnabled = false;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Enable usage statistics
  Future<void> enableUsageStatistics() async {
    _usageStatisticsEnabled = true;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Disable usage statistics
  Future<void> disableUsageStatistics() async {
    _usageStatisticsEnabled = false;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Enable productivity metrics
  Future<void> enableProductivityMetrics() async {
    _productivityMetricsEnabled = true;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Disable productivity metrics
  Future<void> disableProductivityMetrics() async {
    _productivityMetricsEnabled = false;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Enable crash reporting
  Future<void> enableCrashReporting() async {
    _crashReportingEnabled = true;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Disable crash reporting
  Future<void> disableCrashReporting() async {
    _crashReportingEnabled = false;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Enable data collection
  Future<void> enableDataCollection() async {
    _dataCollectionEnabled = true;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Disable data collection
  Future<void> disableDataCollection() async {
    _dataCollectionEnabled = false;
    await _savePrivacySettings();
    notifyListeners();
  }

  /// Track privacy-related events
  Future<void> _trackPrivacyEvent(String eventName) async {
    final event = {
      'event_name': eventName,
      'timestamp': DateTime.now().toIso8601String(),
      'session_id': _sessionData['session_id'],
    };

    _eventQueue.add(event);
    await _storeEventLocally(event);
  }

  /// Store event locally
  Future<void> _storeEventLocally(Map<String, dynamic> event) async {
    try {
      final eventsJson = _prefs?.getString('analytics_events') ?? '[]';
      final events = List<Map<String, dynamic>>.from(jsonDecode(eventsJson));

      events.add(event);

      // Keep only last 1000 events
      if (events.length > 1000) {
        events.removeRange(0, events.length - 1000);
      }

      await _prefs?.setString('analytics_events', jsonEncode(events));
    } catch (e) {
      debugPrint('AnalyticsService: Error storing event locally: $e');
    }
  }

  /// Clear analytics data
  Future<void> _clearAnalyticsData() async {
    await _prefs?.remove('analytics_events');
    _eventQueue.clear();
    debugPrint('AnalyticsService: Analytics data cleared');
  }

  /// Get analytics summary
  Future<AnalyticsSummary> getAnalyticsSummary() async {
    try {
      final eventsJson = _prefs?.getString('analytics_events') ?? '[]';
      final events = List<Map<String, dynamic>>.from(jsonDecode(eventsJson));

      final now = DateTime.now();
      final last7Days = now.subtract(const Duration(days: 7));
      final last30Days = now.subtract(const Duration(days: 30));

      final recentEvents = events.where((event) {
        final eventTime = DateTime.parse(event['timestamp']);
        return eventTime.isAfter(last7Days);
      }).toList();

      final monthlyEvents = events.where((event) {
        final eventTime = DateTime.parse(event['timestamp']);
        return eventTime.isAfter(last30Days);
      }).toList();

      return AnalyticsSummary(
        totalEvents: events.length,
        eventsLast7Days: recentEvents.length,
        eventsLast30Days: monthlyEvents.length,
        sessionCount: _getUniqueSessionCount(events),
        averageSessionLength: _getAverageSessionLength(events),
        topEvents: _getTopEvents(recentEvents),
      );
    } catch (e) {
      debugPrint('AnalyticsService: Error getting analytics summary: $e');
      return AnalyticsSummary.empty();
    }
  }

  /// Get unique session count
  int _getUniqueSessionCount(List<Map<String, dynamic>> events) {
    final sessionIds = events.map((e) => e['session_id']).toSet();
    return sessionIds.length;
  }

  /// Get average session length
  double _getAverageSessionLength(List<Map<String, dynamic>> events) {
    // Simplified calculation - in real implementation, track session end times
    return 15.5; // minutes
  }

  /// Get top events
  Map<String, int> _getTopEvents(List<Map<String, dynamic>> events) {
    final eventCounts = <String, int>{};
    for (final event in events) {
      final eventName = event['event_name'] as String;
      eventCounts[eventName] = (eventCounts[eventName] ?? 0) + 1;
    }

    final sortedEntries = eventCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(sortedEntries.take(5));
  }

  /// Track focus session completion
  Future<void> trackFocusSession({
    required int duration,
    required bool completed,
    required String sessionType, // 'work', 'break', 'long_break'
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!_analyticsEnabled || !_productivityMetricsEnabled) return;

    final sessionData = {
      'duration': duration,
      'completed': completed,
      'sessionType': sessionType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'date': DateTime.now().toIso8601String().split('T')[0],
    };

    await _saveEvent('focus_session', sessionData);
    await _updateDailyStats(sessionData);
    await _updateWeeklyStats(sessionData);
    await _updateMonthlyStats(sessionData);
  }

  /// Track app usage
  Future<void> trackAppUsage({
    required String screen,
    required Duration timeSpent,
  }) async {
    final usageData = {
      'screen': screen,
      'timeSpent': timeSpent.inSeconds,
      'timestamp': DateTime.now().toIso8601String(),
      'date': DateTime.now().toIso8601String().split('T')[0],
    };

    await _saveEvent('app_usage', usageData);
  }

  /// Track feature usage
  Future<void> trackFeatureUsage(String feature,
      {Map<String, dynamic>? metadata}) async {
    final featureData = {
      'feature': feature,
      'timestamp': DateTime.now().toIso8601String(),
      'metadata': metadata ?? {},
    };

    await _saveEvent('feature_usage', featureData);
  }

  /// Track user preferences
  Future<void> trackPreferenceChange(String preference, dynamic value) async {
    final preferenceData = {
      'preference': preference,
      'value': value,
      'timestamp': DateTime.now().toIso8601String(),
    };

    await _saveEvent('preference_change', preferenceData);
  }

  /// Get focus session statistics
  Future<Map<String, dynamic>> getFocusStatistics({int? days}) async {
    final cacheKey = 'focus_stats_${days ?? 'all'}';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      // Get real focus sessions from database
      final DateTime endDate = DateTime.now();
      final DateTime startDate = days != null
          ? endDate.subtract(Duration(days: days))
          : DateTime(2020); // Far back date for all sessions

      final focusSessions =
          await _focusRepo.getSessionsInDateRange(startDate, endDate);

      // Convert to legacy format for compatibility
      final sessions = focusSessions
          .map((session) => {
                'duration': session.workDuration,
                'completed': session.completed,
                'sessionType': session.sessionType,
                'startTime': session.sessionDate.toIso8601String(),
                'endTime': session.sessionDate
                    .add(Duration(seconds: session.totalDuration))
                    .toIso8601String(),
                'date': session.sessionDate.toIso8601String().split('T')[0],
              })
          .toList();

      final stats = _calculateFocusStats(sessions);
      _cache.setMemoryCache(cacheKey, stats, ttl: const Duration(minutes: 5));

      return stats;
    } catch (e) {
      // Fallback to stored events if database fails
      final sessions = await _getEvents('focus_session', days: days);
      final stats = _calculateFocusStats(sessions);
      _cache.setMemoryCache(cacheKey, stats, ttl: const Duration(minutes: 5));
      return stats;
    }
  }

  /// Get productivity insights
  Future<Map<String, dynamic>> getProductivityInsights() async {
    const cacheKey = 'productivity_insights';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      // Get real data from both focus sessions and tasks
      final focusStats = await getFocusStatistics(days: 30);
      final taskStats = await _taskService.getTaskStatistics();

      final insights =
          _calculateEnhancedProductivityInsights(focusStats, taskStats);

      _cache.setMemoryCache(cacheKey, insights, ttl: const Duration(hours: 1));
      return insights;
    } catch (e) {
      // Fallback to legacy method
      final sessions = await _getEvents('focus_session', days: 30);
      final insights = _calculateProductivityInsights(sessions);

      _cache.setMemoryCache(cacheKey, insights, ttl: const Duration(hours: 1));
      return insights;
    }
  }

  /// Get usage patterns
  Future<Map<String, dynamic>> getUsagePatterns() async {
    const cacheKey = 'usage_patterns';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    final appUsage = await _getEvents('app_usage', days: 30);
    final patterns = _calculateUsagePatterns(appUsage);

    _cache.setMemoryCache(cacheKey, patterns, ttl: const Duration(hours: 1));
    return patterns;
  }

  /// Get streak information
  Future<Map<String, dynamic>> getStreakInfo() async {
    const cacheKey = 'streak_info';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      // Get real focus sessions from database for the last year
      final DateTime endDate = DateTime.now();
      final DateTime startDate = endDate.subtract(const Duration(days: 365));

      final focusSessions =
          await _focusRepo.getSessionsInDateRange(startDate, endDate);

      // Convert to legacy format for compatibility
      final sessions = focusSessions
          .map((session) => {
                'duration': session.workDuration,
                'completed': session.completed,
                'sessionType': session.sessionType,
                'startTime': session.sessionDate.toIso8601String(),
                'endTime': session.sessionDate
                    .add(Duration(seconds: session.totalDuration))
                    .toIso8601String(),
                'date': session.sessionDate.toIso8601String().split('T')[0],
              })
          .toList();

      final streakInfo = _calculateStreakInfo(sessions);
      _cache.setMemoryCache(cacheKey, streakInfo,
          ttl: const Duration(minutes: 30));
      return streakInfo;
    } catch (e) {
      // Fallback to stored events if database fails
      final sessions = await _getEvents('focus_session', days: 365);
      final streakInfo = _calculateStreakInfo(sessions);
      _cache.setMemoryCache(cacheKey, streakInfo,
          ttl: const Duration(minutes: 30));
      return streakInfo;
    }
  }

  /// Get weekly summary
  Future<Map<String, dynamic>> getWeeklySummary() async {
    const cacheKey = 'weekly_summary';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      // Get real focus sessions from database for the last 7 days
      final DateTime endDate = DateTime.now();
      final DateTime startDate = endDate.subtract(const Duration(days: 7));

      final focusSessions =
          await _focusRepo.getSessionsInDateRange(startDate, endDate);

      // Convert to legacy format for compatibility
      final sessions = focusSessions
          .map((session) => {
                'duration': session.workDuration,
                'completed': session.completed,
                'sessionType': session.sessionType,
                'startTime': session.sessionDate.toIso8601String(),
                'endTime': session.sessionDate
                    .add(Duration(seconds: session.totalDuration))
                    .toIso8601String(),
                'date': session.sessionDate.toIso8601String().split('T')[0],
              })
          .toList();

      final summary = _calculateWeeklySummary(sessions);
      _cache.setMemoryCache(cacheKey, summary, ttl: const Duration(hours: 1));
      return summary;
    } catch (e) {
      // Fallback to stored events if database fails
      final sessions = await _getEvents('focus_session', days: 7);
      final summary = _calculateWeeklySummary(sessions);
      _cache.setMemoryCache(cacheKey, summary, ttl: const Duration(hours: 1));
      return summary;
    }
  }

  /// Save event to storage
  Future<void> _saveEvent(String eventType, Map<String, dynamic> data) async {
    _prefs ??= await SharedPreferences.getInstance();

    final events = await _getEvents(eventType);
    events.add(data);

    // Keep only last 1000 events per type
    if (events.length > 1000) {
      events.removeRange(0, events.length - 1000);
    }

    await _prefs!.setString('analytics_$eventType', jsonEncode(events));

    // Invalidate related caches
    _cache.invalidateCache('focus_stats_all');
    _cache.invalidateCache('focus_stats_7');
    _cache.invalidateCache('focus_stats_30');
    _cache.invalidateCache('productivity_insights');
    _cache.invalidateCache('usage_patterns');
    _cache.invalidateCache('streak_info');
    _cache.invalidateCache('weekly_summary');
  }

  /// Get events from storage
  Future<List<Map<String, dynamic>>> _getEvents(String eventType,
      {int? days}) async {
    _prefs ??= await SharedPreferences.getInstance();

    final eventsJson = _prefs!.getString('analytics_$eventType');
    if (eventsJson == null) return [];

    try {
      final events =
          (jsonDecode(eventsJson) as List).cast<Map<String, dynamic>>();

      if (days == null) return events;

      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      return events.where((event) {
        final eventDate =
            DateTime.parse(event['timestamp'] ?? event['startTime'] ?? '');
        return eventDate.isAfter(cutoffDate);
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Calculate focus session statistics
  Map<String, dynamic> _calculateFocusStats(
      List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return {
        'totalSessions': 0,
        'completedSessions': 0,
        'totalFocusTime': 0,
        'averageSessionLength': 0,
        'completionRate': 0.0,
        'dailyAverage': 0.0,
        'longestSession': 0,
        'shortestSession': 0,
      };
    }

    final completedSessions =
        sessions.where((s) => s['completed'] == true).toList();
    final totalFocusTime = completedSessions.fold<int>(
        0, (sum, s) => sum + (s['duration'] as int));
    final durations =
        completedSessions.map((s) => s['duration'] as int).toList();

    final uniqueDays = sessions.map((s) => s['date']).toSet().length;

    return {
      'totalSessions': sessions.length,
      'completedSessions': completedSessions.length,
      'totalFocusTime': totalFocusTime,
      'averageSessionLength': completedSessions.isNotEmpty
          ? totalFocusTime / completedSessions.length
          : 0,
      'completionRate': sessions.isNotEmpty
          ? completedSessions.length / sessions.length
          : 0.0,
      'dailyAverage':
          uniqueDays > 0 ? completedSessions.length / uniqueDays : 0.0,
      'longestSession': durations.isNotEmpty ? durations.reduce(max) : 0,
      'shortestSession': durations.isNotEmpty ? durations.reduce(min) : 0,
    };
  }

  /// Calculate enhanced productivity insights with task data
  Map<String, dynamic> _calculateEnhancedProductivityInsights(
      Map<String, dynamic> focusStats, Map<String, dynamic> taskStats) {
    final insights = <String>[];
    final completionRate = focusStats['completionRate'] ?? 0.0;
    final totalFocusTime = focusStats['totalFocusTime'] ?? 0;
    final taskCompletionRate = taskStats['completionRate'] ?? 0.0;
    final totalTasks = taskStats['totalTasks'] ?? 0;
    final completedTasks = taskStats['completedTasks'] ?? 0;

    // Calculate productivity score (0-100)
    int productivityScore = 0;

    // Focus session completion (40% of score)
    productivityScore += (completionRate * 40).round() as int;

    // Task completion (40% of score)
    productivityScore += (taskCompletionRate * 40).round() as int;

    // Consistency bonus (20% of score)
    final dailyAverage = focusStats['dailyAverage'] ?? 0.0;
    if (dailyAverage >= 3) {
      productivityScore += 20;
    } else if (dailyAverage >= 2) {
      productivityScore += 15;
    } else if (dailyAverage >= 1) {
      productivityScore += 10;
    }

    // Generate insights based on data
    if (completionRate >= 0.8) {
      insights.add(
          '🎯 Excellent focus! You complete ${(completionRate * 100).round()}% of your sessions.');
    } else if (completionRate >= 0.6) {
      insights.add('📈 Good focus consistency. Try to complete more sessions.');
    } else {
      insights.add('⏰ Consider shorter sessions to improve completion rate.');
    }

    if (taskCompletionRate >= 0.8) {
      insights.add(
          '✅ Great task management! You\'re completing tasks efficiently.');
    } else if (totalTasks > 0) {
      insights
          .add('📋 Focus on completing existing tasks before adding new ones.');
    }

    if (totalFocusTime > 7200) {
      // 2+ hours
      insights.add(
          '🔥 Impressive focus time! You\'re building strong concentration habits.');
    } else if (totalFocusTime > 3600) {
      // 1+ hour
      insights.add('⭐ Good focus time! Try to increase your daily sessions.');
    } else {
      insights.add(
          '🌱 Start with small focus sessions and gradually increase duration.');
    }

    return {
      'insights': insights,
      'score': productivityScore,
      'focusCompletionRate': completionRate,
      'taskCompletionRate': taskCompletionRate,
      'totalFocusTime': totalFocusTime,
      'totalTasks': totalTasks,
      'completedTasks': completedTasks,
      'recommendation': _getProductivityRecommendation(productivityScore),
    };
  }

  /// Get productivity recommendation based on score
  String _getProductivityRecommendation(int score) {
    if (score >= 80) {
      return '🏆 Excellent! You\'re in the top productivity tier. Keep up the great work!';
    } else if (score >= 60) {
      return '🎯 Good progress! Focus on consistency to reach the next level.';
    } else if (score >= 40) {
      return '📈 You\'re building momentum. Try shorter, more frequent sessions.';
    } else if (score >= 20) {
      return '🌱 Starting strong! Set small, achievable daily goals.';
    } else {
      return '🚀 Every expert was once a beginner. Start with 15-minute focus sessions.';
    }
  }

  /// Calculate productivity insights (legacy method)
  Map<String, dynamic> _calculateProductivityInsights(
      List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) return {'insights': [], 'score': 0};

    final insights = <String>[];
    final completedSessions =
        sessions.where((s) => s['completed'] == true).toList();
    final completionRate = completedSessions.length / sessions.length;

    // Completion rate insights
    if (completionRate >= 0.8) {
      insights.add('Excellent focus! You complete most of your sessions.');
    } else if (completionRate >= 0.6) {
      insights.add('Good focus consistency. Try to complete more sessions.');
    } else {
      insights.add('Consider shorter sessions to improve completion rate.');
    }

    // Session timing insights
    final hourCounts = <int, int>{};
    for (final session in completedSessions) {
      final hour = DateTime.parse(session['startTime']).hour;
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    if (hourCounts.isNotEmpty) {
      final bestHour =
          hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      insights.add('Your most productive time is around $bestHour:00.');
    }

    // Weekly pattern insights
    final weekdayCounts = <int, int>{};
    for (final session in completedSessions) {
      final weekday = DateTime.parse(session['startTime']).weekday;
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    if (weekdayCounts.isNotEmpty) {
      final bestDay =
          weekdayCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      final dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      insights.add('You\'re most focused on ${dayNames[bestDay - 1]}s.');
    }

    // Calculate productivity score (0-100)
    final score = (completionRate * 100).round();

    return {
      'insights': insights,
      'score': score,
      'completionRate': completionRate,
      'bestHour': hourCounts.isNotEmpty
          ? hourCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : null,
    };
  }

  /// Calculate usage patterns
  Map<String, dynamic> _calculateUsagePatterns(
      List<Map<String, dynamic>> usage) {
    if (usage.isEmpty) return {'patterns': [], 'totalTime': 0};

    final screenTime = <String, int>{};
    var totalTime = 0;

    for (final entry in usage) {
      final screen = entry['screen'] as String;
      final time = entry['timeSpent'] as int;
      screenTime[screen] = (screenTime[screen] ?? 0) + time;
      totalTime += time;
    }

    final patterns = screenTime.entries
        .map((e) => {
              'screen': e.key,
              'timeSpent': e.value,
              'percentage':
                  totalTime > 0 ? (e.value / totalTime * 100).round() : 0,
            })
        .toList();

    patterns.sort(
        (a, b) => (b['timeSpent'] as int).compareTo(a['timeSpent'] as int));

    return {
      'patterns': patterns,
      'totalTime': totalTime,
      'mostUsedScreen': patterns.isNotEmpty ? patterns.first['screen'] : null,
    };
  }

  /// Calculate streak information
  Map<String, dynamic> _calculateStreakInfo(
      List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return {'currentStreak': 0, 'longestStreak': 0, 'streakDates': []};
    }

    final completedSessions =
        sessions.where((s) => s['completed'] == true).toList();
    final dates =
        completedSessions.map((s) => s['date'] as String).toSet().toList();
    dates.sort();

    var currentStreak = 0;
    var longestStreak = 0;
    var tempStreak = 0;

    final today = DateTime.now().toIso8601String().split('T')[0];
    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')[0];

    // Calculate current streak
    for (int i = dates.length - 1; i >= 0; i--) {
      final date = dates[i];
      if (i == dates.length - 1) {
        if (date == today || date == yesterday) {
          currentStreak = 1;
        }
      } else {
        final prevDate = DateTime.parse(dates[i + 1]);
        final currentDate = DateTime.parse(date);
        if (prevDate.difference(currentDate).inDays == 1) {
          currentStreak++;
        } else {
          break;
        }
      }
    }

    // Calculate longest streak
    for (int i = 0; i < dates.length; i++) {
      if (i == 0) {
        tempStreak = 1;
      } else {
        final prevDate = DateTime.parse(dates[i - 1]);
        final currentDate = DateTime.parse(dates[i]);
        if (currentDate.difference(prevDate).inDays == 1) {
          tempStreak++;
        } else {
          longestStreak = max(longestStreak, tempStreak);
          tempStreak = 1;
        }
      }
    }
    longestStreak = max(longestStreak, tempStreak);

    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'streakDates': dates,
      'activeDays': dates.length,
    };
  }

  /// Calculate weekly summary
  Map<String, dynamic> _calculateWeeklySummary(
      List<Map<String, dynamic>> sessions) {
    final completedSessions =
        sessions.where((s) => s['completed'] == true).toList();
    final totalFocusTime = completedSessions.fold<int>(
        0, (sum, s) => sum + (s['duration'] as int));

    final dailyStats = <String, Map<String, dynamic>>{};
    for (final session in completedSessions) {
      final date = session['date'] as String;
      if (!dailyStats.containsKey(date)) {
        dailyStats[date] = {'sessions': 0, 'focusTime': 0};
      }
      dailyStats[date]!['sessions'] =
          (dailyStats[date]!['sessions'] as int) + 1;
      dailyStats[date]!['focusTime'] = (dailyStats[date]!['focusTime'] as int) +
          (session['duration'] as int);
    }

    return {
      'totalSessions': completedSessions.length,
      'totalFocusTime': totalFocusTime,
      'averageDailyFocusTime': dailyStats.isNotEmpty ? totalFocusTime / 7 : 0,
      'activeDays': dailyStats.length,
      'dailyStats': dailyStats,
    };
  }

  /// Update daily statistics
  Future<void> _updateDailyStats(Map<String, dynamic> sessionData) async {
    // Implementation for daily stats aggregation
    // This could be used for quick daily summaries
  }

  /// Update weekly statistics
  Future<void> _updateWeeklyStats(Map<String, dynamic> sessionData) async {
    // Implementation for weekly stats aggregation
  }

  /// Update monthly statistics
  Future<void> _updateMonthlyStats(Map<String, dynamic> sessionData) async {
    // Implementation for monthly stats aggregation
  }

  /// Get comprehensive analytics including all screens and features
  Future<Map<String, dynamic>> getComprehensiveAnalytics() async {
    const cacheKey = 'comprehensive_analytics';
    final cached = _cache.getMemoryCache<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    try {
      // Get data from all integrated services
      final focusStats = await getFocusStatistics(days: 30);
      final taskStats = await _taskService.getTaskStatistics();
      final productivityInsights = await getProductivityInsights();

      // Get app usage data
      final appUsageEvents = await _getEvents('app_usage', days: 30);
      final featureUsageEvents = await _getEvents('feature_usage', days: 30);

      // Calculate cross-screen analytics
      final screenUsage = _calculateScreenUsage(appUsageEvents);
      final featurePopularity = _calculateFeaturePopularity(featureUsageEvents);
      final userJourney =
          _calculateUserJourney(appUsageEvents, featureUsageEvents);

      final comprehensiveData = {
        'focus': focusStats,
        'tasks': taskStats,
        'insights': productivityInsights,
        'screenUsage': screenUsage,
        'featurePopularity': featurePopularity,
        'userJourney': userJourney,
        'lastUpdated': DateTime.now().toIso8601String(),
      };

      _cache.setMemoryCache(cacheKey, comprehensiveData,
          ttl: const Duration(hours: 1));
      return comprehensiveData;
    } catch (e) {
      debugPrint('AnalyticsService: Error getting comprehensive analytics: $e');
      return {
        'focus': {},
        'tasks': {},
        'insights': {},
        'screenUsage': {},
        'featurePopularity': {},
        'userJourney': {},
        'lastUpdated': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Calculate screen usage patterns
  Map<String, dynamic> _calculateScreenUsage(
      List<Map<String, dynamic>> events) {
    final screenTime = <String, int>{};
    final screenVisits = <String, int>{};

    for (final event in events) {
      final screen = event['screen'] as String? ?? 'unknown';
      final timeSpent = event['timeSpent'] as int? ?? 0;

      screenTime[screen] = (screenTime[screen] ?? 0) + timeSpent;
      screenVisits[screen] = (screenVisits[screen] ?? 0) + 1;
    }

    final totalTime = screenTime.values.fold<int>(0, (sum, time) => sum + time);
    final screenPercentages = <String, double>{};

    for (final entry in screenTime.entries) {
      screenPercentages[entry.key] =
          totalTime > 0 ? (entry.value / totalTime) * 100 : 0.0;
    }

    return {
      'screenTime': screenTime,
      'screenVisits': screenVisits,
      'screenPercentages': screenPercentages,
      'totalTime': totalTime,
      'mostUsedScreen': screenTime.isNotEmpty
          ? screenTime.entries.reduce((a, b) => a.value > b.value ? a : b).key
          : 'none',
    };
  }

  /// Calculate feature popularity
  Map<String, dynamic> _calculateFeaturePopularity(
      List<Map<String, dynamic>> events) {
    final featureUsage = <String, int>{};
    final featureCategories = <String, Set<String>>{};

    for (final event in events) {
      final feature = event['feature'] as String? ?? 'unknown';
      featureUsage[feature] = (featureUsage[feature] ?? 0) + 1;

      // Categorize features
      final category = _categorizeFeature(feature);
      featureCategories[category] = (featureCategories[category] ?? <String>{})
        ..add(feature);
    }

    // Get top features
    final sortedFeatures = featureUsage.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return {
      'featureUsage': featureUsage,
      'topFeatures': sortedFeatures
          .take(10)
          .map((e) => {
                'feature': e.key,
                'usage': e.value,
              })
          .toList(),
      'featureCategories':
          featureCategories.map((k, v) => MapEntry(k, v.length)),
      'totalFeatureUsage':
          featureUsage.values.fold<int>(0, (sum, count) => sum + count),
    };
  }

  /// Categorize features for analytics
  String _categorizeFeature(String feature) {
    if (feature.startsWith('focus_') || feature.contains('session')) {
      return 'Focus';
    }
    if (feature.startsWith('task_') || feature.contains('task')) {
      return 'Tasks';
    }
    if (feature.startsWith('note_') || feature.contains('note')) {
      return 'Notes';
    }
    if (feature.startsWith('pdf_') || feature.contains('pdf')) {
      return 'PDF Reader';
    }
    if (feature.contains('search')) {
      return 'Search';
    }
    if (feature.contains('export') || feature.contains('import')) {
      return 'Data Management';
    }
    return 'Other';
  }

  /// Calculate user journey patterns
  Map<String, dynamic> _calculateUserJourney(
    List<Map<String, dynamic>> appUsageEvents,
    List<Map<String, dynamic>> featureUsageEvents,
  ) {
    // Combine and sort events by timestamp
    final allEvents = <Map<String, dynamic>>[];

    for (final event in appUsageEvents) {
      allEvents.add({
        ...event,
        'type': 'screen_visit',
        'timestamp': DateTime.parse(event['timestamp'] as String),
      });
    }

    for (final event in featureUsageEvents) {
      allEvents.add({
        ...event,
        'type': 'feature_usage',
        'timestamp': DateTime.parse(event['timestamp'] as String),
      });
    }

    allEvents.sort((a, b) =>
        (a['timestamp'] as DateTime).compareTo(b['timestamp'] as DateTime));

    // Analyze common patterns
    final sessionPatterns = <String>[];
    final featureSequences = <String>[];

    for (int i = 0; i < allEvents.length - 1; i++) {
      final current = allEvents[i];
      final next = allEvents[i + 1];

      if (current['type'] == 'screen_visit' &&
          next['type'] == 'feature_usage') {
        final pattern = '${current['screen']} → ${next['feature']}';
        sessionPatterns.add(pattern);
      }

      if (current['type'] == 'feature_usage' &&
          next['type'] == 'feature_usage') {
        final sequence = '${current['feature']} → ${next['feature']}';
        featureSequences.add(sequence);
      }
    }

    return {
      'totalEvents': allEvents.length,
      'sessionPatterns': _getTopPatterns(sessionPatterns, 5),
      'featureSequences': _getTopPatterns(featureSequences, 5),
      'averageSessionLength':
          allEvents.isNotEmpty ? allEvents.length / 10 : 0, // Rough estimate
    };
  }

  /// Get top patterns from a list
  List<Map<String, dynamic>> _getTopPatterns(List<String> patterns, int limit) {
    final patternCounts = <String, int>{};
    for (final pattern in patterns) {
      patternCounts[pattern] = (patternCounts[pattern] ?? 0) + 1;
    }

    final sortedPatterns = patternCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPatterns
        .take(limit)
        .map((e) => {
              'pattern': e.key,
              'count': e.value,
            })
        .toList();
  }

  /// Clear all analytics data
  Future<void> clearAllData() async {
    _prefs ??= await SharedPreferences.getInstance();
    final keys = _prefs!.getKeys().where((key) => key.startsWith('analytics_'));
    for (final key in keys) {
      await _prefs!.remove(key);
    }

    // Clear caches
    _cache.clearAllCache();
  }

  /// Export analytics data
  Future<Map<String, dynamic>> exportData() async {
    final focusSessions = await _getEvents('focus_session');
    final appUsage = await _getEvents('app_usage');
    final featureUsage = await _getEvents('feature_usage');

    return {
      'focusSessions': focusSessions,
      'appUsage': appUsage,
      'featureUsage': featureUsage,
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  /// Get focus sessions data
  Future<List<Map<String, dynamic>>> _getFocusSessions() async {
    try {
      final events = await _getEvents('focus_session');
      return events.map((event) {
        return {
          'startTime': DateTime.parse(event['timestamp']),
          'duration': event['data']['duration'] ?? 0,
          'completed': event['data']['completed'] ?? false,
          'sessionType': event['data']['sessionType'] ?? 'work',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get hourly productivity data
  Future<Map<String, dynamic>> getHourlyProductivity() async {
    try {
      final sessions = await _getFocusSessions();
      final hourlyData = <int, List<int>>{};

      // Group sessions by hour
      for (final session in sessions) {
        final hour = session['startTime'].hour;
        if (!hourlyData.containsKey(hour)) {
          hourlyData[hour] = [];
        }
        hourlyData[hour]!.add(session['duration']);
      }

      // Calculate average productivity per hour
      final hourlyProductivity = <String, dynamic>{};
      for (int hour = 0; hour < 24; hour++) {
        final sessions = hourlyData[hour] ?? [];
        final avgDuration = sessions.isNotEmpty
            ? sessions.reduce((a, b) => a + b) / sessions.length
            : 0.0;
        hourlyProductivity[hour.toString()] = {
          'sessionCount': sessions.length,
          'averageDuration': avgDuration,
          'totalTime':
              sessions.isNotEmpty ? sessions.reduce((a, b) => a + b) : 0,
        };
      }

      return hourlyProductivity;
    } catch (e) {
      return {};
    }
  }

  /// Get session trends over time
  Future<Map<String, dynamic>> getSessionTrends() async {
    try {
      final sessions = await _getFocusSessions();
      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));

      // Filter sessions from last 30 days
      final recentSessions = sessions.where((session) {
        return session['startTime'].isAfter(thirtyDaysAgo);
      }).toList();

      // Group by day
      final dailyData = <String, Map<String, dynamic>>{};
      for (final session in recentSessions) {
        final date = DateTime(
          session['startTime'].year,
          session['startTime'].month,
          session['startTime'].day,
        );
        final dateKey = date.toIso8601String().split('T')[0];

        if (!dailyData.containsKey(dateKey)) {
          dailyData[dateKey] = {
            'sessionCount': 0,
            'totalTime': 0,
            'completedSessions': 0,
          };
        }

        dailyData[dateKey]!['sessionCount'] =
            (dailyData[dateKey]!['sessionCount'] as int) + 1;
        dailyData[dateKey]!['totalTime'] =
            (dailyData[dateKey]!['totalTime'] as int) + session['duration'];
        if (session['completed'] == true) {
          dailyData[dateKey]!['completedSessions'] =
              (dailyData[dateKey]!['completedSessions'] as int) + 1;
        }
      }

      return {
        'dailyData': dailyData,
        'totalDays': dailyData.length,
        'averageSessionsPerDay': dailyData.isNotEmpty
            ? dailyData.values
                    .map((d) => d['sessionCount'] as int)
                    .reduce((a, b) => a + b) /
                dailyData.length
            : 0.0,
      };
    } catch (e) {
      return {};
    }
  }
}

/// Analytics summary data class
class AnalyticsSummary {
  final int totalEvents;
  final int eventsLast7Days;
  final int eventsLast30Days;
  final int sessionCount;
  final double averageSessionLength;
  final Map<String, int> topEvents;

  AnalyticsSummary({
    required this.totalEvents,
    required this.eventsLast7Days,
    required this.eventsLast30Days,
    required this.sessionCount,
    required this.averageSessionLength,
    required this.topEvents,
  });

  factory AnalyticsSummary.empty() {
    return AnalyticsSummary(
      totalEvents: 0,
      eventsLast7Days: 0,
      eventsLast30Days: 0,
      sessionCount: 0,
      averageSessionLength: 0.0,
      topEvents: {},
    );
  }
}
