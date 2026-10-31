import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/goal.dart';

void main() {
  test('Goal.copyWith can clear nullable lifecycle fields', () {
    final now = DateTime(2026, 6, 9, 10);
    final goal = Goal(
      id: 'goal-1',
      title: 'Read books',
      type: GoalType.custom,
      targetValue: 10,
      currentValue: 10,
      status: GoalStatus.completed,
      customUnit: 'books',
      createdAt: now,
      updatedAt: now,
      endDate: now.add(const Duration(days: 30)),
      completedAt: now,
      metadata: const {'source': 'manual'},
    );

    final reopened = goal.copyWith(
      status: GoalStatus.active,
      customUnit: null,
      endDate: null,
      completedAt: null,
      metadata: null,
    );

    expect(reopened.customUnit, isNull);
    expect(reopened.endDate, isNull);
    expect(reopened.completedAt, isNull);
    expect(reopened.metadata, isNull);
  });
}
