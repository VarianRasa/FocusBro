import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/goal.dart';
import '../services/goal_service.dart';

/// Provider for managing goal state and UI updates
class GoalProvider extends ChangeNotifier {
  final GoalService _goalService = GoalService();

  List<Goal> _goals = [];
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  StreamSubscription<List<Goal>>? _goalsSubscription;
  StreamSubscription<Goal>? _goalUpdatedSubscription;

  /// Get all goals
  List<Goal> get goals => List.unmodifiable(_goals);

  /// Get active goals
  List<Goal> get activeGoals =>
      _goals.where((goal) => goal.status == GoalStatus.active).toList();

  /// Get completed goals
  List<Goal> get completedGoals =>
      _goals.where((goal) => goal.status == GoalStatus.completed).toList();

  /// Get goals by type
  List<Goal> getGoalsByType(GoalType type) =>
      _goals.where((goal) => goal.type == type).toList();

  /// Get goals by frequency
  List<Goal> getGoalsByFrequency(GoalFrequency frequency) =>
      _goals.where((goal) => goal.frequency == frequency).toList();

  /// Loading state
  bool get isLoading => _isLoading;

  /// Error state
  String? get error => _error;

  /// Initialization state
  bool get isInitialized => _isInitialized;

  /// Goal statistics
  Map<String, dynamic> get statistics {
    final total = _goals.length;
    final active = activeGoals.length;
    final completed = completedGoals.length;
    final paused =
        _goals.where((goal) => goal.status == GoalStatus.paused).length;
    final cancelled =
        _goals.where((goal) => goal.status == GoalStatus.cancelled).length;

    double averageProgress = 0.0;
    if (active > 0) {
      averageProgress =
          activeGoals.map((goal) => goal.progress).reduce((a, b) => a + b) /
              active;
    }

    return {
      'totalGoals': total,
      'activeGoals': active,
      'completedGoals': completed,
      'pausedGoals': paused,
      'cancelledGoals': cancelled,
      'averageProgress': averageProgress * 100, // Convert to percentage
    };
  }

  /// Initialize the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      await _goalService.initialize();

      // Subscribe to goal updates
      _goalsSubscription = _goalService.goalsStream.listen(
        (goals) {
          _goals = goals;
          _setLoading(false);
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load goals: $error');
          _setLoading(false);
        },
      );

      _goalUpdatedSubscription = _goalService.goalUpdatedStream.listen(
        (updatedGoal) {
          final index = _goals.indexWhere((goal) => goal.id == updatedGoal.id);
          if (index != -1) {
            _goals[index] = updatedGoal;
            notifyListeners();
          }
        },
      );

      _isInitialized = true;
      debugPrint('GoalProvider initialized successfully');
    } catch (e) {
      _setError('Failed to initialize goals: $e');
      _setLoading(false);
      debugPrint('Error initializing GoalProvider: $e');
    }
  }

  /// Create a new goal
  Future<Goal?> createGoal({
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
      _setError('Goal provider not initialized');
      return null;
    }

    try {
      _clearError();

      final goal = await _goalService.createGoal(
        title: title,
        description: description,
        type: type,
        frequency: frequency,
        targetValue: targetValue,
        customUnit: customUnit,
        startDate: startDate,
        endDate: endDate,
      );

      debugPrint('Goal created successfully: ${goal.title}');
      return goal;
    } catch (e) {
      _setError('Failed to create goal: $e');
      debugPrint('Error creating goal: $e');
      return null;
    }
  }

  /// Update an existing goal
  Future<Goal?> updateGoal(Goal updatedGoal) async {
    if (!_isInitialized) {
      _setError('Goal provider not initialized');
      return null;
    }

    try {
      _clearError();

      final goal = await _goalService.updateGoal(updatedGoal);
      debugPrint('Goal updated successfully: ${goal.title}');
      return goal;
    } catch (e) {
      _setError('Failed to update goal: $e');
      debugPrint('Error updating goal: $e');
      return null;
    }
  }

  /// Update goal progress
  Future<bool> updateGoalProgress(String goalId, double newValue) async {
    if (!_isInitialized) {
      _setError('Goal provider not initialized');
      return false;
    }

    try {
      _clearError();

      await _goalService.updateGoalProgress(goalId, newValue);
      debugPrint('Goal progress updated successfully');
      return true;
    } catch (e) {
      _setError('Failed to update goal progress: $e');
      debugPrint('Error updating goal progress: $e');
      return false;
    }
  }

  /// Update goal status
  Future<bool> updateGoalStatus(String goalId, GoalStatus status) async {
    if (!_isInitialized) {
      _setError('Goal provider not initialized');
      return false;
    }

    try {
      _clearError();

      await _goalService.updateGoalStatus(goalId, status);
      debugPrint('Goal status updated successfully');
      return true;
    } catch (e) {
      _setError('Failed to update goal status: $e');
      debugPrint('Error updating goal status: $e');
      return false;
    }
  }

  /// Delete a goal
  Future<bool> deleteGoal(String goalId) async {
    if (!_isInitialized) {
      _setError('Goal provider not initialized');
      return false;
    }

    try {
      _clearError();

      await _goalService.deleteGoal(goalId);
      debugPrint('Goal deleted successfully');
      return true;
    } catch (e) {
      _setError('Failed to delete goal: $e');
      debugPrint('Error deleting goal: $e');
      return false;
    }
  }

  /// Get goal by ID
  Goal? getGoalById(String goalId) {
    try {
      return _goalService.getGoalById(goalId);
    } catch (e) {
      return null;
    }
  }

  /// Update all goal progress based on current analytics
  Future<void> updateAllGoalProgress() async {
    if (!_isInitialized) return;

    try {
      _clearError();
      await _goalService.updateAllGoalProgress();
      debugPrint('All goal progress updated successfully');
    } catch (e) {
      _setError('Failed to update goal progress: $e');
      debugPrint('Error updating all goal progress: $e');
    }
  }

  /// Refresh goals from database
  Future<void> refreshGoals() async {
    if (!_isInitialized) return;

    try {
      _setLoading(true);
      _clearError();

      // The service will automatically emit updated goals through the stream
      await _goalService.updateAllGoalProgress();
    } catch (e) {
      _setError('Failed to refresh goals: $e');
      _setLoading(false);
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _goalsSubscription?.cancel();
    _goalUpdatedSubscription?.cancel();
    _goalService.dispose();
    super.dispose();
  }
}
