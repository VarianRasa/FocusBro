import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/goal.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/services/goal_service.dart';

void main() {
  test('GoalProvider exposes service snapshot immediately after initialize',
      () async {
    final goal = _goal();
    final service = _FakeGoalManager([goal]);
    final provider = GoalProvider(goalService: service);

    await provider.initialize();

    expect(provider.isInitialized, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.goals, [goal]);

    provider.dispose();
  });
}

Goal _goal() {
  final now = DateTime(2026, 6, 9);
  return Goal(
    id: 'goal-1',
    title: 'Finish Wave 1',
    type: GoalType.custom,
    targetValue: 1,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeGoalManager implements GoalManager {
  _FakeGoalManager(this._goals);

  final List<Goal> _goals;
  final StreamController<List<Goal>> _goalsController =
      StreamController<List<Goal>>.broadcast();
  final StreamController<Goal> _updatedController =
      StreamController<Goal>.broadcast();

  @override
  List<Goal> get goals => List.unmodifiable(_goals);

  @override
  Stream<List<Goal>> get goalsStream => _goalsController.stream;

  @override
  Stream<Goal> get goalUpdatedStream => _updatedController.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<Goal> createGoal({
    required String title,
    String description = '',
    required GoalType type,
    GoalFrequency frequency = GoalFrequency.daily,
    required double targetValue,
    String? customUnit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteGoal(String goalId) {
    throw UnimplementedError();
  }

  @override
  Goal? getGoalById(String goalId) {
    for (final goal in _goals) {
      if (goal.id == goalId) return goal;
    }
    return null;
  }

  @override
  Future<Goal> updateGoal(Goal updatedGoal) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateAllGoalProgress() async {}

  @override
  Future<Goal> updateGoalProgress(String goalId, double newValue) {
    throw UnimplementedError();
  }

  @override
  Future<Goal> updateGoalStatus(String goalId, GoalStatus status) {
    throw UnimplementedError();
  }

  @override
  void dispose() {
    _goalsController.close();
    _updatedController.close();
  }
}
