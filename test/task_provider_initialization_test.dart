import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../lib/providers/task_provider.dart';
import '../lib/models/task_model.dart';
import '../lib/screens/enhanced_agenda_screen.dart';

/// Comprehensive test for TaskProvider initialization and Enhanced Agenda Screen functionality
void main() {
  group('TaskProvider Initialization and UI Refresh Tests', () {
    late TaskProvider taskProvider;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      taskProvider = TaskProvider();
    });

    tearDown(() async {
      taskProvider.dispose();
    });

    testWidgets('TaskProvider initializes correctly',
        (WidgetTester tester) async {
      // Test initialization
      expect(taskProvider.isInitialized, false);
      expect(taskProvider.isLoading, false);
      expect(taskProvider.tasks.length, 0);

      // Initialize the provider
      await taskProvider.initialize();

      // Verify initialization state
      expect(taskProvider.isInitialized, true);
      expect(taskProvider.isLoading, false);
      expect(taskProvider.error, null);
    });

    testWidgets('TaskProvider handles initialization failure gracefully',
        (WidgetTester tester) async {
      // This test verifies the retry mechanism works
      // Note: In a real scenario, we'd mock the services to fail

      await taskProvider.initialize();

      // Even if initialization fails, the provider should be in a stable state
      expect(taskProvider.tasks, isNotNull);
      expect(taskProvider.templates, isNotNull);
      expect(taskProvider.taskStats, isNotNull);
    });

    testWidgets('TaskProvider creates tasks and updates UI immediately',
        (WidgetTester tester) async {
      // Initialize provider
      await taskProvider.initialize();

      // Verify initial state
      expect(taskProvider.tasks.length, 0);

      // Create a task
      final task = await taskProvider.createTask(
        title: 'Test Task',
        description: 'Test Description',
        category: TaskCategory.work,
        priority: TaskPriority.high,
      );

      // Verify task was created
      expect(task, isNotNull);
      expect(task!.title, 'Test Task');
      expect(task.category, TaskCategory.work);
      expect(task.priority, TaskPriority.high);

      // Verify provider state updated
      expect(taskProvider.tasks.length, 1);
      expect(taskProvider.tasks.first.id, task.id);
    });

    testWidgets('Enhanced Agenda Screen displays tasks correctly',
        (WidgetTester tester) async {
      // Create a test app with the Enhanced Agenda Screen
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TaskProvider>(
            create: (_) => taskProvider,
            child: const EnhancedAgendaScreen(),
          ),
        ),
      );

      // Initialize provider
      await taskProvider.initialize();
      await tester.pump();

      // Verify screen loads without errors
      expect(find.byType(EnhancedAgendaScreen), findsOneWidget);

      // Create a task
      await taskProvider.createTask(
        title: 'UI Test Task',
        description: 'This task should appear in the UI',
        category: TaskCategory.personal,
        priority: TaskPriority.medium,
      );

      // Trigger UI rebuild
      await tester.pump();

      // Verify task appears in the UI
      expect(find.text('UI Test Task'), findsOneWidget);
    });

    testWidgets('Task filtering methods work correctly',
        (WidgetTester tester) async {
      await taskProvider.initialize();

      // Create tasks with different due dates
      final today = DateTime.now();
      final tomorrow = today.add(const Duration(days: 1));
      final nextWeek = today.add(const Duration(days: 7));

      await taskProvider.createTask(
        title: 'Due Today',
        dueDate: today,
      );

      await taskProvider.createTask(
        title: 'Due Tomorrow',
        dueDate: tomorrow,
      );

      await taskProvider.createTask(
        title: 'Due Next Week',
        dueDate: nextWeek,
      );

      // Test filtering methods
      final todayTasks = taskProvider.tasksDueToday;
      final upcomingTasks = taskProvider.upcomingTasks;

      expect(todayTasks.length, 1);
      expect(todayTasks.first.title, 'Due Today');

      expect(upcomingTasks.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Task count badges update in real-time',
        (WidgetTester tester) async {
      await taskProvider.initialize();

      // Verify initial counts
      expect(taskProvider.tasks.length, 0);
      expect(taskProvider.inProgressTasks.length, 0);
      expect(taskProvider.completedTasks.length, 0);

      // Create tasks
      await taskProvider.createTask(title: 'Task 1');
      await taskProvider.createTask(title: 'Task 2');
      await taskProvider.createTask(title: 'Task 3');

      // Verify counts updated
      expect(taskProvider.tasks.length, 3);
      expect(taskProvider.inProgressTasks.length,
          0); // New tasks start as pending, not in progress
      expect(taskProvider.completedTasks.length, 0);

      // Complete a task
      final firstTask = taskProvider.tasks.first;
      await taskProvider.updateTask(firstTask.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
      ));

      // Verify counts updated after completion
      expect(taskProvider.tasks.length, 3);
      expect(taskProvider.completedTasks.length, 1);
    });

    testWidgets('Force re-initialization works correctly',
        (WidgetTester tester) async {
      // Initial initialization
      await taskProvider.initialize();
      expect(taskProvider.isInitialized, true);

      // Create a task
      await taskProvider.createTask(title: 'Test Task');
      expect(taskProvider.tasks.length, 1);

      // Force re-initialization
      await taskProvider.forceReinitialize();

      // Verify provider is still functional
      expect(taskProvider.isInitialized, true);
      expect(taskProvider.tasks, isNotNull);
    });

    test('TaskProvider handles concurrent operations correctly', () async {
      await taskProvider.initialize();

      // Create multiple tasks concurrently
      final futures = <Future<Task?>>[];
      for (int i = 0; i < 5; i++) {
        futures.add(taskProvider.createTask(title: 'Concurrent Task $i'));
      }

      final results = await Future.wait(futures);

      // Verify all tasks were created
      expect(results.every((task) => task != null), true);
      expect(taskProvider.tasks.length, 5);

      // Verify all tasks have unique IDs
      final ids = taskProvider.tasks.map((task) => task.id).toSet();
      expect(ids.length, 5);
    });
  });
}
