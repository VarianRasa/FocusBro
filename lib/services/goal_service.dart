import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/goal.dart';
import '../repositories/goal_repository.dart';
import '../services/analytics_service.dart';
import '../repositories/focus_repository.dart';

/// Service for managing goals and tracking progress
class GoalService {
  static final GoalService _instance = GoalService._internal();
  factory GoalService() => _instance;
  GoalService._internal();

  final GoalRepository _goalRepository = GoalRepository();
  final AnalyticsService _analyticsService = AnalyticsService();
  final FocusStatisticsRepository _focusStatsRepo = FocusStatisticsRepository();
  final FocusSessionRepository _focusSessionRepo = FocusSessionRepository();

  final StreamController<List<Goal>> _goalsController =
      StreamController<List<Goal>>.broadcast();
  final StreamController<Goal> _goalUpdatedController =
      StreamController<Goal>.broadcast();

  List<Goal> _goals = [];
  bool _isInitialized = false;

  /// Stream of all goals
  Stream<List<Goal>> get goalsStream => _goalsController.stream;

  /// Stream of goal updates
  Stream<Goal> get goalUpdatedStream => _goalUpdatedController.stream;

  /// Get all goals
  List<Goal> get goals => List.unmodifiable(_goals);

  /// Get active goals
  List<Goal> get activeGoals =>
      _goals.where((goal) => goal.status == GoalStatus.active).toList();

  /// Get completed goals
  List<Goal> get completedGoals =>
      _goals.where((goal) => goal.status == GoalStatus.completed).toList();

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _goalRepository.initialize();
      await _loadGoals();
      _isInitialized = true;
      debugPrint('GoalService initialized successfully');
    } catch (e) {
      debugPrint('Error initializing GoalService: $e');
      rethrow;
    }
  }

  /// Load all goals from database
  Future<void> _loadGoals() async {
    try {
      _goals = await _goalRepository.findAll(orderBy: 'createdAt DESC');
      _goalsController.add(_goals);
    } catch (e) {
      debugPrint('Error loading goals: $e');
      _goals = [];
      _goalsController.add(_goals);
    }
  }

  /// Create a new goal
  Future<Goal> createGoal({
    required String title,
    String description = '',
    required GoalType type,
    GoalFrequency frequency = GoalFrequency.daily,
    required double targetValue,
    String? customUnit,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!_isInitialized) {
      throw Exception('GoalService not initialized');
    }

    final now = DateTime.now();
    final goal = Goal(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      type: type,
      frequency: frequency,
      targetValue: targetValue,
      customUnit: customUnit,
      createdAt: now,
      updatedAt: now,
      startDate: startDate ?? now,
      endDate: endDate,
    );

    try {
      await _goalRepository.insert(goal);
      _goals.insert(0, goal); // Add to beginning for newest first
      _goalsController.add(_goals);

      debugPrint('Goal created: ${goal.title}');
      return goal;
    } catch (e) {
      debugPrint('Error creating goal: $e');
      rethrow;
    }
  }

  /// Update goal progress
  Future<Goal> updateGoalProgress(String goalId, double newValue) async {
    if (!_isInitialized) {
      throw Exception('GoalService not initialized');
    }

    final goalIndex = _goals.indexWhere((goal) => goal.id == goalId);
    if (goalIndex == -1) {
      throw Exception('Goal not found');
    }

    final goal = _goals[goalIndex];
    final now = DateTime.now();

    // Determine new status based on progress
    GoalStatus newStatus = goal.status;
    DateTime? completedAt = goal.completedAt;

    if (newValue >= goal.targetValue && goal.status == GoalStatus.active) {
      newStatus = GoalStatus.completed;
      completedAt = now;
    } else if (newValue < goal.targetValue &&
        goal.status == GoalStatus.completed) {
      newStatus = GoalStatus.active;
      completedAt = null;
    }

    final updatedGoal = goal.copyWith(
      currentValue: newValue,
      status: newStatus,
      completedAt: completedAt,
      updatedAt: now,
    );

    try {
      await _goalRepository.update(updatedGoal);
      _goals[goalIndex] = updatedGoal;
      _goalsController.add(_goals);
      _goalUpdatedController.add(updatedGoal);

      debugPrint(
          'Goal progress updated: ${updatedGoal.title} - ${updatedGoal.progressPercentage}%');
      return updatedGoal;
    } catch (e) {
      debugPrint('Error updating goal progress: $e');
      rethrow;
    }
  }

  /// Update an existing goal
  Future<Goal> updateGoal(Goal updatedGoal) async {
    if (!_isInitialized) {
      throw Exception('GoalService not initialized');
    }

    final goalIndex = _goals.indexWhere((goal) => goal.id == updatedGoal.id);
    if (goalIndex == -1) {
      throw Exception('Goal not found');
    }

    final now = DateTime.now();
    final goalToUpdate = updatedGoal.copyWith(updatedAt: now);

    try {
      await _goalRepository.update(goalToUpdate);
      _goals[goalIndex] = goalToUpdate;
      _goalsController.add(_goals);
      _goalUpdatedController.add(goalToUpdate);

      debugPrint('Goal updated: ${goalToUpdate.title}');
      return goalToUpdate;
    } catch (e) {
      debugPrint('Error updating goal: $e');
      rethrow;
    }
  }

  /// Update goal status
  Future<Goal> updateGoalStatus(String goalId, GoalStatus status) async {
    if (!_isInitialized) {
      throw Exception('GoalService not initialized');
    }

    final goalIndex = _goals.indexWhere((goal) => goal.id == goalId);
    if (goalIndex == -1) {
      throw Exception('Goal not found');
    }

    final goal = _goals[goalIndex];
    final now = DateTime.now();

    DateTime? completedAt = goal.completedAt;
    if (status == GoalStatus.completed && goal.status != GoalStatus.completed) {
      completedAt = now;
    } else if (status != GoalStatus.completed) {
      completedAt = null;
    }

    final updatedGoal = goal.copyWith(
      status: status,
      completedAt: completedAt,
      updatedAt: now,
    );

    try {
      await _goalRepository.update(updatedGoal);
      _goals[goalIndex] = updatedGoal;
      _goalsController.add(_goals);
      _goalUpdatedController.add(updatedGoal);

      debugPrint(
          'Goal status updated: ${updatedGoal.title} - ${status.displayName}');
      return updatedGoal;
    } catch (e) {
      debugPrint('Error updating goal status: $e');
      rethrow;
    }
  }

  /// Delete a goal
  Future<void> deleteGoal(String goalId) async {
    if (!_isInitialized) {
      throw Exception('GoalService not initialized');
    }

    try {
      await _goalRepository.delete(goalId);
      _goals.removeWhere((goal) => goal.id == goalId);
      _goalsController.add(_goals);

      debugPrint('Goal deleted: $goalId');
    } catch (e) {
      debugPrint('Error deleting goal: $e');
      rethrow;
    }
  }

  /// Get goal by ID
  Goal? getGoalById(String goalId) {
    return _goals.firstWhere(
      (goal) => goal.id == goalId,
      orElse: () => throw Exception('Goal not found'),
    );
  }

  /// Update all goal progress based on current analytics data
  Future<void> updateAllGoalProgress() async {
    if (!_isInitialized) return;

    try {
      // Get current analytics data
      final focusStats = await _analyticsService.getFocusStatistics();
      final streakInfo = await _analyticsService.getStreakInfo();

      // Get today's data
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySessions =
          await _focusSessionRepo.getSessionsInDateRange(startOfDay, endOfDay);
      final todayCompletedSessions =
          todaySessions.where((s) => s.completed).length;
      final todayFocusTime = todaySessions
              .where((s) => s.completed)
              .fold(0, (sum, session) => sum + session.workDuration) /
          3600.0; // Convert to hours

      // Get weekly data
      final startOfWeek =
          startOfDay.subtract(Duration(days: today.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));
      final weeklySessions = await _focusSessionRepo.getSessionsInDateRange(
          startOfWeek, endOfWeek);
      final weeklyCompletedSessions =
          weeklySessions.where((s) => s.completed).length;

      // Update goals based on their type
      for (final goal in activeGoals) {
        double newValue = goal.currentValue;

        switch (goal.type) {
          case GoalType.dailyFocusTime:
            if (goal.frequency == GoalFrequency.daily) {
              newValue = todayFocusTime;
            }
            break;
          case GoalType.weeklySessions:
            if (goal.frequency == GoalFrequency.weekly) {
              newValue = weeklyCompletedSessions.toDouble();
            } else if (goal.frequency == GoalFrequency.daily) {
              newValue = todayCompletedSessions.toDouble();
            }
            break;
          case GoalType.monthlyStreak:
            if (goal.frequency == GoalFrequency.monthly) {
              newValue = (streakInfo['currentStreak'] ?? 0).toDouble();
            }
            break;
          case GoalType.totalSessions:
            newValue = (focusStats['totalSessions'] ?? 0).toDouble();
            break;
          case GoalType.completionRate:
            final completionRate = focusStats['completionRate'] ?? 0.0;
            newValue = (completionRate * 100); // Convert to percentage
            break;
          case GoalType.custom:
            // Custom goals need manual updates
            continue;
        }

        if (newValue != goal.currentValue) {
          await updateGoalProgress(goal.id, newValue);
        }
      }
    } catch (e) {
      debugPrint('Error updating goal progress: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _goalsController.close();
    _goalUpdatedController.close();
  }
}
