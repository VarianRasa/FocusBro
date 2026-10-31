import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/focus_session.dart';
import '../models/achievement.dart';
import '../repositories/focus_repository.dart';
import '../repositories/achievement_repository.dart';
import '../services/voice_command_service.dart';
import '../services/smart_notification_service.dart';
import '../services/audio_feedback_service.dart';
import '../services/music_service.dart';
import '../services/focus_mode_service.dart';
import '../services/analytics_service.dart';
import '../services/session_notification_service.dart';
import '../models/session_notification_data.dart';
// import 'package:intl/intl.dart';

class FocusProvider extends ChangeNotifier {
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalFocusTime = 0;
  DateTime? _lastFocusDate;
  List<Achievement> _achievements = [];
  List<Reward> _rewards = [];

  // Timer state
  bool _isRunning = false;
  bool _isWorkTime = true;
  int _timeLeft = 1500; // 25 minutes default
  int _workDuration = 1500; // 25 minutes
  int _breakDuration = 300; // 5 minutes
  int _completedSessions = 0;
  int _totalSessions = 4;
  double _progress = 0.0;
  Timer? _timer;
  bool _hasTriggeredCompletion =
      false; // Flag to track if completion has been triggered

  // Settings
  bool _isVoiceEnabled = false;
  bool _isFocusModeEnabled = false;
  bool _isMusicEnabled = false;
  int _todaysSessions = 0;
  int _totalFocusHours = 0;

  // Services
  final VoiceCommandService _voiceService = VoiceCommandService();
  final SmartNotificationService _notificationService =
      SmartNotificationService();
  final AudioFeedbackService _audioService = AudioFeedbackService();
  final MusicService _musicService = MusicService();
  final FocusModeService _focusModeService = FocusModeService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final SessionNotificationService _sessionNotificationService =
      SessionNotificationService();

  // Database repositories
  final FocusStatisticsRepository _focusStatsRepo = FocusStatisticsRepository();
  final FocusSessionRepository _focusSessionRepo = FocusSessionRepository();
  final AchievementRepository _achievementRepo = AchievementRepository();
  final UserAchievementRepository _userAchievementRepo =
      UserAchievementRepository();
  final RewardRepository _rewardRepo = RewardRepository();

  // Getters
  int get currentStreak => _currentStreak;
  int get longestStreak => _longestStreak;
  int get totalFocusTime => _totalFocusTime;
  List<Achievement> get achievements => _achievements;
  List<Reward> get rewards => _rewards;

  // Timer getters
  bool get isRunning => _isRunning;
  bool get isWorkTime => _isWorkTime;
  int get timeLeft => _timeLeft;
  int get completedSessions => _completedSessions;
  int get totalSessions => _totalSessions;
  double get progress => _progress;

  // Settings getters
  bool get isVoiceEnabled => _isVoiceEnabled;
  bool get isFocusModeEnabled => _isFocusModeEnabled;
  bool get isMusicEnabled => _isMusicEnabled;
  int get todaysSessions => _todaysSessions;
  int get totalFocusHours => _totalFocusHours;

  // Service getters
  MusicService get musicService => _musicService;
  FocusModeService get focusModeService => _focusModeService;

  // Computed getters
  String get formattedTime {
    final minutes = _timeLeft ~/ 60;
    final seconds = _timeLeft % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get canSkip => _isRunning && !isAllSessionsComplete;

  bool get isAllSessionsComplete => _completedSessions >= _totalSessions;

  FocusProvider() {
    // Constructor should not call async methods directly
    // Use initialize() method instead
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize voice commands
      await _voiceService.initialize();
      _setupVoiceCommands();

      // Initialize notifications
      await _notificationService.initialize();

      // Initialize audio feedback
      await _audioService.initialize();

      // Initialize music service
      await _musicService.initialize();

      // Initialize focus mode service
      await _focusModeService.initialize();

      // Initialize session notification service
      await _sessionNotificationService.initialize();

      // Listen to focus mode service changes for real-time UI updates
      _focusModeService.addListener(_onFocusModeServiceChanged);
    } catch (e) {
      // Handle initialization errors gracefully
      debugPrint('FocusBro: Service initialization error: $e');
    }
  }

  void _setupVoiceCommands() {
    _voiceService.setCallbacks(
      onStartTimer: () => toggleTimer(),
      onPauseTimer: () => toggleTimer(),
      onResetTimer: () => resetTimer(),
      onSkipSession: () => skipSession(),
      onSetWorkDuration: (duration) => setWorkDuration(duration),
      onSetBreakDuration: (duration) => setBreakDuration(duration),
      onShowStats: () {
        // This will be handled by the UI
      },
      onShowSettings: () {
        // This will be handled by the UI
      },
    );
  }

  /// Handle focus mode service changes for real-time UI updates
  void _onFocusModeServiceChanged() {
    // Notify listeners when focus mode service state changes
    // This ensures that UI components using Consumer<FocusProvider>
    // will update when focus mode settings are changed
    debugPrint(
        'FocusProvider: Focus mode service state changed, notifying listeners');
    notifyListeners();
  }

  Future<void> _loadData() async {
    try {
      // Load focus statistics from database
      final stats = await _focusStatsRepo.getCurrentStatistics();
      if (stats != null) {
        _currentStreak = stats.currentStreak;
        _longestStreak = stats.longestStreak;
        _totalFocusTime = stats.totalFocusTime;
        _lastFocusDate = stats.lastFocusDate;
      } else {
        // Initialize with default values if no stats exist
        _currentStreak = 0;
        _longestStreak = 0;
        _totalFocusTime = 0;
        _lastFocusDate = null;
      }

      // Load user preferences
      await _loadUserPreferences();

      _loadAchievements();
      _loadRewards();
      notifyListeners();
    } catch (e) {
      // Fallback to SharedPreferences if database fails
      final prefs = await SharedPreferences.getInstance();
      _currentStreak = prefs.getInt('currentStreak') ?? 0;
      _longestStreak = prefs.getInt('longestStreak') ?? 0;
      _totalFocusTime = prefs.getInt('totalFocusTime') ?? 0;

      final lastFocusDateStr = prefs.getString('lastFocusDate');
      if (lastFocusDateStr != null) {
        _lastFocusDate = DateTime.parse(lastFocusDateStr);
      }

      // Load user preferences even in fallback mode
      await _loadUserPreferences();

      _loadAchievements();
      _loadRewards();
      notifyListeners();
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _totalSessions = prefs.getInt('totalSessions') ?? 4; // Default 4 sessions
      _workDuration =
          prefs.getInt('workDuration') ?? 1500; // Default 25 minutes
      _breakDuration =
          prefs.getInt('breakDuration') ?? 300; // Default 5 minutes
      _isMusicEnabled = prefs.getBool('isMusicEnabled') ?? false;
      _isVoiceEnabled = prefs.getBool('isVoiceEnabled') ?? false;
      _isFocusModeEnabled = prefs.getBool('isFocusModeEnabled') ?? false;

      // Set initial timer values
      _timeLeft = _workDuration;
    } catch (e) {
      debugPrint('Error loading user preferences: $e');
    }
  }

  Future<void> _saveData() async {
    try {
      // Save to database
      final stats = FocusStatistics(
        currentStreak: _currentStreak,
        longestStreak: _longestStreak,
        totalFocusTime: _totalFocusTime,
        totalSessions: await _focusSessionRepo.getCompletedSessionsCount(),
        lastFocusDate: _lastFocusDate,
        averageSessionLength:
            (await _focusSessionRepo.getAverageSessionLength()).round(),
        bestDayDuration: 0, // Will be calculated separately
        updatedAt: DateTime.now(),
      );

      await _focusStatsRepo.updateStatistics(stats);
    } catch (e) {
      // Fallback to SharedPreferences if database fails
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('currentStreak', _currentStreak);
      await prefs.setInt('longestStreak', _longestStreak);
      await prefs.setInt('totalFocusTime', _totalFocusTime);
      if (_lastFocusDate != null) {
        await prefs.setString(
            'lastFocusDate', _lastFocusDate!.toIso8601String());
      }
    }

    // Always save user preferences to SharedPreferences
    await _saveUserPreferences();
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('totalSessions', _totalSessions);
      await prefs.setInt('workDuration', _workDuration);
      await prefs.setInt('breakDuration', _breakDuration);
      await prefs.setBool('isMusicEnabled', _isMusicEnabled);
      await prefs.setBool('isVoiceEnabled', _isVoiceEnabled);
      await prefs.setBool('isFocusModeEnabled', _isFocusModeEnabled);
    } catch (e) {
      debugPrint('Error saving user preferences: $e');
    }
  }

  void _initializeAchievements() {
    // Achievements are now loaded from database in _loadAchievements()
    // This method is kept for backward compatibility but does nothing
  }

  void _loadAchievements() async {
    try {
      // Load achievements from database
      _achievements = await _achievementRepo.getAchievementsWithStatus();
      notifyListeners();
    } catch (e) {
      // Fallback to SharedPreferences if database fails
      final prefs = await SharedPreferences.getInstance();
      final unlockedAchievements =
          prefs.getStringList('unlockedAchievements') ?? [];

      for (var achievement in _achievements) {
        achievement.isUnlocked = unlockedAchievements.contains(achievement.id);
      }
      notifyListeners();
    }
  }

  void _loadRewards() async {
    try {
      // Load rewards from database
      _rewards = await _rewardRepo.getRewardsByStreak();
      notifyListeners();
    } catch (e) {
      // Fallback to hardcoded rewards if database fails
      _rewards = [
        Reward(
          id: 'streak_3',
          title: '3-Day Streak',
          description: 'Unlock custom timer presets',
          requiredStreak: 3,
          isUnlocked: _currentStreak >= 3,
          createdAt: DateTime.now(),
        ),
        Reward(
          id: 'streak_7',
          title: '7-Day Streak',
          description: 'Unlock premium focus sounds',
          requiredStreak: 7,
          isUnlocked: _currentStreak >= 7,
          createdAt: DateTime.now(),
        ),
        Reward(
          id: 'streak_30',
          title: '30-Day Streak',
          description: 'Unlock all premium features',
          requiredStreak: 30,
          isUnlocked: _currentStreak >= 30,
          createdAt: DateTime.now(),
        ),
      ];
      notifyListeners();
    }
  }

  void updateFocusSession(int workDuration, int breakDuration) async {
    final now = DateTime.now();
    _totalFocusTime += workDuration;

    // Create focus session record
    final session = FocusSession(
      sessionDate: now,
      workDuration: workDuration,
      breakDuration: breakDuration,
      totalDuration: workDuration + breakDuration,
      sessionType: 'work',
      completed: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      // Save session to database
      await _focusSessionRepo.insert(session);

      // Track session in analytics
      final sessionStartTime = now.subtract(Duration(seconds: workDuration));
      await _trackSessionInAnalytics(session, sessionStartTime, now);
    } catch (e) {
      // Handle database error
      debugPrint('Error saving focus session: $e');
    }

    // Update streak
    if (_lastFocusDate != null) {
      final difference = now.difference(_lastFocusDate!).inDays;
      if (difference == 1) {
        _currentStreak++;
        if (_currentStreak > _longestStreak) {
          _longestStreak = _currentStreak;
        }
      } else if (difference > 1) {
        _currentStreak = 1;
      }
    } else {
      _currentStreak = 1;
    }

    _lastFocusDate = now;
    _checkAchievements();
    _updateRewards();
    await _saveData();
    notifyListeners();
  }

  void _checkAchievements() async {
    try {
      for (var achievement in _achievements) {
        if (!achievement.isUnlocked) {
          bool shouldUnlock = false;

          switch (achievement.achievementType) {
            case 'session_count':
              final sessionCount =
                  await _focusSessionRepo.getCompletedSessionsCount();
              shouldUnlock = sessionCount >= (achievement.targetValue ?? 1);
              break;
            case 'streak':
              shouldUnlock = _currentStreak >= (achievement.targetValue ?? 1);
              break;
            case 'total_time':
              shouldUnlock =
                  _totalFocusTime >= (achievement.targetValue ?? 3600);
              break;
          }

          if (shouldUnlock) {
            achievement.isUnlocked = true;
            await _userAchievementRepo.unlockAchievement(achievement.id);
          }
        }
      }
    } catch (e) {
      // Handle database error
      debugPrint('Error checking achievements: $e');
    }
  }

  void _updateRewards() async {
    try {
      // Update rewards in database based on current streak
      await _rewardRepo.updateRewardsForStreak(_currentStreak);

      // Reload rewards to get updated status
      _rewards = await _rewardRepo.getRewardsByStreak();
      notifyListeners();
    } catch (e) {
      // Fallback to local update if database fails
      for (var reward in _rewards) {
        if (_currentStreak >= reward.requiredStreak && !reward.isUnlocked) {
          reward = reward.copyWith(
            isUnlocked: true,
            unlockedAt: DateTime.now(),
          );
        }
      }
    }
  }

  // Timer control methods
  void toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _isRunning = true;

    // Auto-enable focus mode if configured and this is a work session
    if (_isWorkTime &&
        _focusModeService.autoEnableOnFocusStart &&
        !_focusModeService.isFocusModeActive) {
      _focusModeService.enableFocusMode().then((success) {
        if (success) {
          debugPrint('Focus mode auto-enabled for work session');
        }
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        _timeLeft--;
        _updateProgress();
        notifyListeners();

        // Voice feedback for timer status
        if (_isVoiceEnabled && _timeLeft % 300 == 0) {
          // Every 5 minutes
          _voiceService.speakTimerStatus(
            timeLeft: _timeLeft,
            isWorkTime: _isWorkTime,
            isRunning: _isRunning,
          );
        }
      } else {
        _onSessionComplete();
      }
    });
    notifyListeners();
  }

  void _pauseTimer() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  void _updateProgress() {
    final totalDuration = _isWorkTime ? _workDuration : _breakDuration;
    _progress = 1.0 - (_timeLeft / totalDuration);
  }

  void _onSessionComplete() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;

    // Save completed session
    _saveCompletedSession();

    // Update session count
    if (_isWorkTime) {
      _completedSessions++;
      _todaysSessions++;
    }

    // Play audio feedback for session completion
    try {
      if (_isWorkTime) {
        _audioService.playWorkSessionComplete();
      } else {
        _audioService.playBreakSessionComplete();
      }
    } catch (e) {
      debugPrint('Error playing session completion audio: $e');
    }

    // Voice feedback for session completion
    if (_isVoiceEnabled) {
      final nextDuration = _isWorkTime ? _breakDuration : _workDuration;
      _voiceService.speakSessionComplete(
        isWorkTime: _isWorkTime,
        nextDuration: nextDuration,
      );
    }

    // Send notification
    _sendSessionCompleteNotification();

    // Check if all sessions are complete
    if (isAllSessionsComplete && !_hasTriggeredCompletion) {
      // Play completion sound and trigger completion dialog
      try {
        _audioService.playSessionCompletion();
      } catch (e) {
        debugPrint('Error playing session completion sound: $e');
      }
      _hasTriggeredCompletion = true;
      // The UI will handle showing the completion dialog
      notifyListeners();
      return;
    }

    // Switch to next session type
    _isWorkTime = !_isWorkTime;
    _timeLeft = _isWorkTime ? _workDuration : _breakDuration;
    _progress = 0.0;

    // Play audio for next session start
    try {
      if (_isWorkTime) {
        _audioService.playWorkSessionStart();
      } else {
        _audioService.playBreakSessionStart();
      }
    } catch (e) {
      debugPrint('Error playing session start audio: $e');
    }

    // Auto-play appropriate music for session type
    try {
      _musicService.autoPlayForSession(isWorkTime: _isWorkTime);
    } catch (e) {
      debugPrint('Error auto-playing music: $e');
    }

    notifyListeners();
  }

  void resetTimer() {
    _timer?.cancel();
    _timer = null;
    _isRunning = false;
    _isWorkTime = true;
    _timeLeft = _workDuration;
    _progress = 0.0;
    _completedSessions = 0; // Reset session progress
    _hasTriggeredCompletion = false; // Reset completion flag
    notifyListeners();
  }

  void _saveCompletedSession() {
    final now = DateTime.now();
    final sessionStartTime = now.subtract(
        Duration(seconds: _isWorkTime ? _workDuration : _breakDuration));
    final session = FocusSession(
      sessionDate: now,
      workDuration: _workDuration,
      breakDuration: _breakDuration,
      totalDuration: _isWorkTime ? _workDuration : _breakDuration,
      sessionType: _isWorkTime ? 'work' : 'break',
      completed: true,
      createdAt: now,
      updatedAt: now,
    );

    // Save to database
    _saveFocusSessionToDb(session);

    // Track session in analytics
    _trackSessionInAnalytics(session, sessionStartTime, now);
  }

  Future<void> _saveFocusSessionToDb(FocusSession session) async {
    try {
      await _focusSessionRepo.insert(session);
    } catch (e) {
      // Handle database error silently
    }
  }

  Future<void> _trackSessionInAnalytics(
      FocusSession session, DateTime startTime, DateTime endTime) async {
    try {
      await _analyticsService.trackFocusSession(
        duration: session.totalDuration,
        completed: session.completed,
        sessionType: session.sessionType,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (e) {
      // Handle analytics error silently
      debugPrint('Error tracking session in analytics: $e');
    }
  }

  void _sendSessionCompleteNotification() async {
    try {
      // Check for newly unlocked achievements
      final newAchievements = <String>[];
      for (var achievement in _achievements) {
        if (achievement.isUnlocked) {
          // For simplicity, consider all unlocked achievements as "new"
          // In a real implementation, you'd track unlock timestamps
          newAchievements.add(achievement.title);
        }
      }

      // Create session notification data
      final notificationData = SessionNotificationData(
        sessionType: _isWorkTime ? 'work' : 'break',
        sessionNumber: _completedSessions,
        totalSessions: _totalSessions,
        duration: _isWorkTime ? _workDuration : _breakDuration,
        isAllSessionsComplete: isAllSessionsComplete,
        totalFocusTime: _totalFocusTime,
        currentStreak: _currentStreak,
        hasAchievements: newAchievements.isNotEmpty,
        achievements: newAchievements,
      );

      // Send enhanced session completion notification
      await _sessionNotificationService
          .showSessionCompleteNotification(notificationData);
    } catch (e) {
      debugPrint('Error sending session complete notification: $e');
      // Fallback to basic notification if enhanced service fails
      _sendBasicNotification();
    }
  }

  /// Fallback basic notification method
  void _sendBasicNotification() {
    try {
      final sessionType = _isWorkTime ? 'Work' : 'Break';
      final title = '$sessionType Session Complete!';
      final body = isAllSessionsComplete
          ? 'All $_totalSessions sessions completed! Great work! 🎉'
          : 'Session $_completedSessions/$_totalSessions done. Keep it up! 💪';

      // Use existing smart notification service as fallback
      // This is a simplified notification without actions
      debugPrint('Fallback notification: $title - $body');
    } catch (e) {
      debugPrint('Error sending basic notification: $e');
    }
  }

  void skipSession() {
    if (!canSkip) return;

    // Update session count
    if (_isWorkTime) {
      _completedSessions++;
    }

    // Play audio feedback for skipped session
    try {
      if (_isWorkTime) {
        _audioService.playWorkSessionComplete();
      } else {
        _audioService.playBreakSessionComplete();
      }
    } catch (e) {
      debugPrint('Error playing skipped session audio: $e');
    }

    // Check if all sessions are complete after skipping
    if (isAllSessionsComplete && !_hasTriggeredCompletion) {
      // Play completion sound and trigger completion dialog
      try {
        _audioService.playSessionCompletion();
      } catch (e) {
        debugPrint('Error playing completion sound: $e');
      }
      _hasTriggeredCompletion = true;
      _isRunning = false;
      notifyListeners();
      return;
    }

    // Switch to next session type
    _isWorkTime = !_isWorkTime;
    _timeLeft = _isWorkTime ? _workDuration : _breakDuration;
    _progress = 0.0;

    // Play audio for next session start
    try {
      if (_isWorkTime) {
        _audioService.playWorkSessionStart();
      } else {
        _audioService.playBreakSessionStart();
      }
    } catch (e) {
      debugPrint('Error playing session start audio: $e');
    }

    notifyListeners();
  }

  void toggleVoiceCommands() async {
    _isVoiceEnabled = !_isVoiceEnabled;

    // Save the changes immediately for persistence
    await _saveUserPreferences();
    notifyListeners();
  }

  void toggleFocusMode() async {
    _isFocusModeEnabled = !_isFocusModeEnabled;

    // Apply focus mode settings using the focus mode service
    if (_isFocusModeEnabled) {
      await _focusModeService.enableFocusMode();
    } else {
      await _focusModeService.disableFocusMode();
    }

    // Save the changes immediately for persistence
    await _saveUserPreferences();
    notifyListeners();
  }

  /// Set focus mode state without triggering service calls
  /// This is used for synchronization when the service state changes externally
  void setFocusModeState(bool enabled) {
    if (_isFocusModeEnabled != enabled) {
      _isFocusModeEnabled = enabled;
      notifyListeners();
    }
  }

  /// Refresh statistics from database
  Future<void> refreshStatistics() async {
    try {
      // Get updated statistics from database
      final stats = await _focusStatsRepo.getCurrentStatistics();
      if (stats != null) {
        _currentStreak = stats.currentStreak;
        _longestStreak = stats.longestStreak;
        _totalFocusTime = stats.totalFocusTime;
        _lastFocusDate = stats.lastFocusDate;
        _totalFocusHours = (_totalFocusTime / 3600).round();
      }

      // Get today's sessions count
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final todaySessions =
          await _focusSessionRepo.getSessionsInDateRange(startOfDay, endOfDay);
      _todaysSessions = todaySessions.where((s) => s.completed).length;

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing statistics: $e');
    }
  }

  void toggleMusic() async {
    _isMusicEnabled = !_isMusicEnabled;

    // Save the changes immediately for persistence
    await _saveUserPreferences();
    notifyListeners();
  }

  // Audio feedback methods
  bool get soundEffectsEnabled => _audioService.soundEffectsEnabled;
  bool get notificationSoundsEnabled => _audioService.notificationSoundsEnabled;
  double get audioVolume => _audioService.volume;

  Future<void> setSoundEffectsEnabled(bool enabled) async {
    await _audioService.setSoundEffectsEnabled(enabled);
    notifyListeners();
  }

  Future<void> setNotificationSoundsEnabled(bool enabled) async {
    await _audioService.setNotificationSoundsEnabled(enabled);
    notifyListeners();
  }

  Future<void> setAudioVolume(double volume) async {
    await _audioService.setVolume(volume);
    notifyListeners();
  }

  // Audio service getter for testing
  AudioFeedbackService get audioService => _audioService;

  int get workDuration => _workDuration;
  int get breakDuration => _breakDuration;

  void setWorkDuration(int duration) async {
    _workDuration = duration;
    if (_isWorkTime) {
      _timeLeft = duration;
      _updateProgress();
    }

    // Save the changes immediately for persistence
    await _saveUserPreferences();
    notifyListeners();
  }

  void setBreakDuration(int duration) async {
    _breakDuration = duration;
    if (!_isWorkTime) {
      _timeLeft = duration;
      _updateProgress();
    }

    // Save the changes immediately for persistence
    await _saveUserPreferences();
    notifyListeners();
  }

  void setTotalSessions(int sessions) async {
    _totalSessions = sessions.clamp(1, 20); // Limit between 1 and 20 sessions
    // Reset completed sessions if it exceeds new total
    if (_completedSessions >= _totalSessions) {
      _completedSessions = 0;
    }

    // Save the changes immediately for persistence
    await _saveData();
    notifyListeners();
  }

  // Initialize method for compatibility
  Future<void> initialize() async {
    await _loadData();
    _initializeAchievements();
    await _initializeServices();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _voiceService.dispose();

    // Remove focus mode service listener to prevent memory leaks
    try {
      _focusModeService.removeListener(_onFocusModeServiceChanged);
    } catch (e) {
      debugPrint(
          'Warning: Could not remove FocusProvider listener during disposal: $e');
    }

    super.dispose();
  }
}
