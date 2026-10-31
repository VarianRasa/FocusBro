import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/cache_manager.dart';
import '../utils/error_handler.dart';
import '../services/task_service.dart';
import '../repositories/focus_repository.dart';
import '../models/focus_session.dart';
import '../models/task_model.dart';

/// Enhanced cloud sync service with real-time synchronization
class EnhancedCloudSyncService {
  static final EnhancedCloudSyncService _instance =
      EnhancedCloudSyncService._internal();
  factory EnhancedCloudSyncService() => _instance;
  EnhancedCloudSyncService._internal();

  SharedPreferences? _prefs;
  final CacheManager _cache = CacheManager();
  final TaskService _taskService = TaskService();
  final FocusSessionRepository _focusRepo = FocusSessionRepository();

  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  // Sync status callbacks
  Function(String)? _onSyncStatusChanged;
  Function(String)? _onSyncError;
  Function()? _onSyncCompleted;

  /// Initialize the enhanced cloud sync service
  Future<void> initialize({
    Function(String)? onSyncStatusChanged,
    Function(String)? onSyncError,
    Function()? onSyncCompleted,
  }) async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _onSyncStatusChanged = onSyncStatusChanged;
    _onSyncError = onSyncError;
    _onSyncCompleted = onSyncCompleted;

    // Load last sync time
    final lastSyncString = _prefs?.getString('last_sync_time');
    if (lastSyncString != null) {
      _lastSyncTime = DateTime.parse(lastSyncString);
    }

    _isInitialized = true;
  }

  /// Perform full synchronization
  Future<bool> performFullSync() async {
    if (_isSyncing) {
      _onSyncError?.call('Sync already in progress');
      return false;
    }

    _isSyncing = true;
    _onSyncStatusChanged?.call('Starting synchronization...');

    try {
      // Sync tasks
      _onSyncStatusChanged?.call('Syncing tasks...');
      await _syncTasks();

      // Sync focus sessions
      _onSyncStatusChanged?.call('Syncing focus sessions...');
      await _syncFocusSessions();

      // Sync user preferences
      _onSyncStatusChanged?.call('Syncing preferences...');
      await _syncUserPreferences();

      // Update last sync time
      _lastSyncTime = DateTime.now();
      await _prefs?.setString(
          'last_sync_time', _lastSyncTime!.toIso8601String());

      _onSyncStatusChanged?.call('Sync completed successfully');
      _onSyncCompleted?.call();

      return true;
    } catch (e) {
      ErrorHandler.logError('Full sync failed', e);
      _onSyncError?.call('Sync failed: ${e.toString()}');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync tasks with cloud storage
  Future<void> _syncTasks() async {
    try {
      // Get local tasks
      final localTasks = _taskService.tasks;

      // Get cloud tasks (mock implementation - replace with actual cloud service)
      final cloudTasks = await _getCloudTasks();

      // Merge tasks based on timestamps
      final mergedTasks = _mergeTasks(localTasks, cloudTasks);

      // Update local storage
      await _updateLocalTasks(mergedTasks);

      // Update cloud storage
      await _updateCloudTasks(mergedTasks);
    } catch (e) {
      ErrorHandler.logError('Task sync failed', e);
      throw Exception('Failed to sync tasks: ${e.toString()}');
    }
  }

  /// Sync focus sessions with cloud storage
  Future<void> _syncFocusSessions() async {
    try {
      // Get local focus sessions from last 30 days
      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));
      final localSessions =
          await _focusRepo.getSessionsInDateRange(startDate, endDate);

      // Get cloud sessions (mock implementation)
      final cloudSessions = await _getCloudFocusSessions();

      // Merge sessions
      final mergedSessions = _mergeFocusSessions(localSessions, cloudSessions);

      // Update local storage
      await _updateLocalFocusSessions(mergedSessions);

      // Update cloud storage
      await _updateCloudFocusSessions(mergedSessions);
    } catch (e) {
      ErrorHandler.logError('Focus session sync failed', e);
      throw Exception('Failed to sync focus sessions: ${e.toString()}');
    }
  }

  /// Sync user preferences
  Future<void> _syncUserPreferences() async {
    try {
      // Get local preferences
      final localPrefs = await _getLocalPreferences();

      // Get cloud preferences (mock implementation)
      final cloudPrefs = await _getCloudPreferences();

      // Merge preferences (cloud takes precedence for newer timestamps)
      final mergedPrefs = _mergePreferences(localPrefs, cloudPrefs);

      // Update local preferences
      await _updateLocalPreferences(mergedPrefs);

      // Update cloud preferences
      await _updateCloudPreferences(mergedPrefs);
    } catch (e) {
      ErrorHandler.logError('Preferences sync failed', e);
      throw Exception('Failed to sync preferences: ${e.toString()}');
    }
  }

  /// Get cloud tasks (mock implementation - replace with actual cloud service)
  Future<List<Task>> _getCloudTasks() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Mock implementation - return empty list
    // In real implementation, this would call your cloud service API
    return [];
  }

  /// Get cloud focus sessions (mock implementation)
  Future<List<FocusSession>> _getCloudFocusSessions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  /// Get cloud preferences (mock implementation)
  Future<Map<String, dynamic>> _getCloudPreferences() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {};
  }

  /// Merge tasks based on timestamps
  List<Task> _mergeTasks(List<Task> localTasks, List<Task> cloudTasks) {
    final Map<String, Task> taskMap = {};

    // Add local tasks
    for (final task in localTasks) {
      taskMap[task.id] = task;
    }

    // Merge cloud tasks (newer timestamps win)
    for (final cloudTask in cloudTasks) {
      final localTask = taskMap[cloudTask.id];
      if (localTask == null ||
          cloudTask.createdAt.isAfter(localTask.createdAt)) {
        taskMap[cloudTask.id] = cloudTask;
      }
    }

    return taskMap.values.toList();
  }

  /// Merge focus sessions based on timestamps
  List<FocusSession> _mergeFocusSessions(
      List<FocusSession> localSessions, List<FocusSession> cloudSessions) {
    final Map<String, FocusSession> sessionMap = {};

    // Add local sessions
    for (final session in localSessions) {
      final key =
          '${session.sessionDate.millisecondsSinceEpoch}_${session.workDuration}';
      sessionMap[key] = session;
    }

    // Merge cloud sessions
    for (final cloudSession in cloudSessions) {
      final key =
          '${cloudSession.sessionDate.millisecondsSinceEpoch}_${cloudSession.workDuration}';
      final localSession = sessionMap[key];
      if (localSession == null ||
          cloudSession.updatedAt.isAfter(localSession.updatedAt)) {
        sessionMap[key] = cloudSession;
      }
    }

    return sessionMap.values.toList();
  }

  /// Merge preferences based on timestamps
  Map<String, dynamic> _mergePreferences(
      Map<String, dynamic> localPrefs, Map<String, dynamic> cloudPrefs) {
    final merged = Map<String, dynamic>.from(localPrefs);

    // Cloud preferences take precedence if they have newer timestamps
    cloudPrefs.forEach((key, value) {
      if (value is Map && value.containsKey('timestamp')) {
        final cloudTimestamp = DateTime.parse(value['timestamp']);
        final localValue = merged[key];

        if (localValue == null ||
            (localValue is Map &&
                localValue.containsKey('timestamp') &&
                cloudTimestamp
                    .isAfter(DateTime.parse(localValue['timestamp'])))) {
          merged[key] = value;
        }
      } else {
        merged[key] = value;
      }
    });

    return merged;
  }

  /// Update local tasks
  Future<void> _updateLocalTasks(List<Task> tasks) async {
    // Clear existing tasks and add merged tasks
    await _taskService.clearAllTasks();
    for (final task in tasks) {
      await _taskService.createTask(
        title: task.title,
        description: task.description,
        priority: task.priority,
        category: task.category,
        dueDate: task.dueDate,
        tags: task.tags,
        estimatedFocusSessions: task.estimatedFocusSessions,
        isRecurring: task.isRecurring,
        recurringPattern: task.recurringPattern,
      );
    }
  }

  /// Update cloud tasks (mock implementation)
  Future<void> _updateCloudTasks(List<Task> tasks) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Mock implementation - in real app, this would upload to cloud service
  }

  /// Update local focus sessions
  Future<void> _updateLocalFocusSessions(List<FocusSession> sessions) async {
    // In a real implementation, you would update the database
    // For now, we'll just cache the data
    final sessionsJson = sessions.map((s) => s.toMap()).toList();
    _cache.setMemoryCache('synced_focus_sessions', sessionsJson,
        ttl: const Duration(hours: 1));
  }

  /// Update cloud focus sessions (mock implementation)
  Future<void> _updateCloudFocusSessions(List<FocusSession> sessions) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Mock implementation
  }

  /// Get local preferences
  Future<Map<String, dynamic>> _getLocalPreferences() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefsJson = _prefs?.getString('user_preferences') ?? '{}';
    return jsonDecode(prefsJson);
  }

  /// Update local preferences
  Future<void> _updateLocalPreferences(Map<String, dynamic> preferences) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString('user_preferences', jsonEncode(preferences));
  }

  /// Update cloud preferences (mock implementation)
  Future<void> _updateCloudPreferences(Map<String, dynamic> preferences) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Mock implementation
  }

  /// Check if sync is needed
  bool get needsSync {
    if (_lastSyncTime == null) return true;
    final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
    return timeSinceLastSync.inHours >= 1; // Sync every hour
  }

  /// Get sync status
  Map<String, dynamic> get syncStatus => {
        'isInitialized': _isInitialized,
        'isSyncing': _isSyncing,
        'lastSyncTime': _lastSyncTime?.toIso8601String(),
        'needsSync': needsSync,
      };

  /// Force sync
  Future<bool> forceSync() async {
    _lastSyncTime = null; // Reset last sync time to force sync
    return await performFullSync();
  }
}
