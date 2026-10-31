import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';

void main() {
  final createdAt = DateTime(2026, 6, 9, 9);
  final completedAt = DateTime(2026, 6, 9, 10);
  final dueDate = DateTime(2026, 6, 10, 10);

  test('Task.copyWith can clear nullable lifecycle fields', () {
    final task = Task(
      id: 'task-1',
      title: 'Prepare report',
      status: TaskStatus.completed,
      createdAt: createdAt,
      updatedAt: completedAt,
      dueDate: dueDate,
      completedAt: completedAt,
      recurringPattern: 'daily',
      lastFocusSession: completedAt,
    );

    final reopened = task.copyWith(
      status: TaskStatus.todo,
      dueDate: null,
      completedAt: null,
      recurringPattern: null,
      lastFocusSession: null,
    );

    expect(reopened.dueDate, isNull);
    expect(reopened.completedAt, isNull);
    expect(reopened.recurringPattern, isNull);
    expect(reopened.lastFocusSession, isNull);
  });

  test('SubTask.copyWith can clear completion timestamp', () {
    final subTask = SubTask(
      id: 'subtask-1',
      title: 'Draft',
      isCompleted: true,
      createdAt: createdAt,
      completedAt: completedAt,
    );

    final reopened = subTask.copyWith(
      isCompleted: false,
      completedAt: null,
    );

    expect(reopened.isCompleted, isFalse);
    expect(reopened.completedAt, isNull);
  });
}
