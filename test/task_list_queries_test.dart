import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/services/task_service.dart';
import 'package:focusbro/utils/task_list_queries.dart';

void main() {
  final taskService = TaskService();

  test('tasksDueToday includes open tasks due today and undated todo tasks',
      () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = [
      _task(
        id: 'today',
        title: 'Today',
        dueDate: today.add(const Duration(hours: 9)),
      ),
      _task(
        id: 'undated',
        title: 'Undated',
        status: TaskStatus.todo,
      ),
      _task(
        id: 'future',
        title: 'Future',
        dueDate: today.add(const Duration(days: 3)),
      ),
    ];

    final dueToday = TaskListQueries.tasksDueToday(tasks);

    expect(dueToday.map((task) => task.id), ['today', 'undated']);
  });

  test('filterAndSort applies search and priority filters', () {
    final tasks = [
      _task(id: 'a', title: 'Write report', priority: TaskPriority.high),
      _task(id: 'b', title: 'Buy milk', priority: TaskPriority.low),
      _task(id: 'c', title: 'Write code', priority: TaskPriority.high),
    ];

    final filtered = TaskListQueries.filterAndSort(
      tasks: tasks,
      sortBy: 'title',
      filterBy: 'all',
      searchQuery: 'write',
      priorityFilter: TaskPriority.high,
      categoryFilter: null,
      taskService: taskService,
    );

    expect(filtered.map((task) => task.id), ['a', 'c']);
  });
}

Task _task({
  required String id,
  required String title,
  TaskPriority priority = TaskPriority.medium,
  TaskStatus status = TaskStatus.todo,
  DateTime? dueDate,
}) {
  final createdAt = DateTime(2026, 5, 1);
  return Task(
    id: id,
    title: title,
    priority: priority,
    status: status,
    createdAt: createdAt,
    updatedAt: createdAt,
    dueDate: dueDate,
  );
}
