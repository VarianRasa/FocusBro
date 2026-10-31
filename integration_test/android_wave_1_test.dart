import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart' as app;
import 'package:focusbro/models/goal.dart';
import 'package:focusbro/models/session_notification_data.dart';
import 'package:focusbro/models/task_model.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/providers/task_provider.dart';
import 'package:focusbro/services/session_notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  Future<void> waitUntil(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!condition() && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(condition(), isTrue);
  }

  testWidgets('Android Wave 1 local productivity flows work', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('has_seen_onboarding', true);
    await preferences.setBool('show_onboarding', false);
    await preferences.setString('default_view', 'focus');

    app.main();
    await waitFor(tester, find.byKey(const ValueKey('main_navigation')));

    final providerContext =
        tester.element(find.byKey(const ValueKey('main_navigation')));
    final taskProvider =
        Provider.of<TaskProvider>(providerContext, listen: false);
    final focusProvider =
        Provider.of<FocusProvider>(providerContext, listen: false);
    final goalProvider =
        Provider.of<GoalProvider>(providerContext, listen: false);

    await tester.tap(find.byKey(const ValueKey('nav_agenda')));
    await waitFor(tester, find.byKey(const ValueKey('agenda_new_task')));

    await tester.tap(find.byKey(const ValueKey('agenda_new_task')));
    await waitFor(tester, find.byKey(const ValueKey('task_title_field')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('task_title_field')),
        matching: find.byType(TextFormField),
      ),
      'Android Wave 1 task',
    );
    await tester.tap(find.byKey(const ValueKey('task_save')));
    await waitUntil(
      tester,
      () =>
          taskProvider.tasks.any((task) => task.title == 'Android Wave 1 task'),
    );

    const viewLabels = {
      'calendar': 'Calendar View',
      'matrix': 'Priority Matrix',
      'kanban': 'Kanban Board',
      'list': 'List View',
    };
    for (final view in viewLabels.keys) {
      await tester.tap(find.byKey(const ValueKey('agenda_view_selector')));
      await tester.pumpAndSettle();
      final option = find.byKey(ValueKey('agenda_view_option_$view'));
      await waitFor(tester, option);
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      await waitFor(tester, find.byKey(ValueKey('agenda_view_$view')));
    }

    var task = taskProvider.tasks
        .firstWhere((item) => item.title == 'Android Wave 1 task');
    final taskId = task.id;
    task = (await taskProvider.updateTask(
      task.copyWith(title: 'Android Wave 1 task edited'),
    ))!;
    expect(task.title, 'Android Wave 1 task edited');
    expect(await taskProvider.completeTask(taskId), isTrue);
    expect(
      taskProvider.tasks.firstWhere((item) => item.id == taskId).status,
      TaskStatus.completed,
    );
    expect(await taskProvider.toggleTaskCompletion(taskId), isTrue);
    expect(
      taskProvider.tasks.firstWhere((item) => item.id == taskId).status,
      TaskStatus.todo,
    );

    await tester.tap(find.byKey(const ValueKey('nav_focus')));
    final focusControl = find.byKey(const ValueKey('focus_start_pause'));
    await waitFor(tester, focusControl);
    await tester.ensureVisible(focusControl);
    await tester.pump(const Duration(milliseconds: 500));
    focusProvider.setWorkDuration(60);
    focusProvider.setBreakDuration(30);
    focusProvider.setTotalSessions(4);
    focusProvider.resetTimer();

    await tester.tap(focusControl);
    await tester.pump(const Duration(seconds: 1));
    expect(focusProvider.isRunning, isTrue);
    expect(focusProvider.timeLeft, 59);

    await tester.tap(focusControl);
    expect(focusProvider.isRunning, isFalse);
    await tester.tap(focusControl);
    await tester.tap(find.byKey(const ValueKey('focus_skip')));
    expect(focusProvider.completedSessions, 1);
    expect(focusProvider.isWorkTime, isFalse);
    await tester.tap(find.byKey(const ValueKey('focus_reset')));
    expect(focusProvider.completedSessions, 0);
    expect(focusProvider.isWorkTime, isTrue);

    final goal = await goalProvider.createGoal(
      title: 'Android Wave 1 goal',
      type: GoalType.custom,
      targetValue: 3,
      customUnit: 'flows',
    );
    expect(goal, isNotNull);
    expect(await goalProvider.updateGoalProgress(goal!.id, 3), isTrue);
    expect(goalProvider.getGoalById(goal.id)?.status, GoalStatus.completed);
    expect(await goalProvider.updateGoalProgress(goal.id, 1), isTrue);
    expect(goalProvider.getGoalById(goal.id)?.status, GoalStatus.active);
    expect(await goalProvider.deleteGoal(goal.id), isTrue);

    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.cancelAll();
    await SessionNotificationService().initialize();
    await SessionNotificationService().showSessionCompleteNotification(
      const SessionNotificationData(
        sessionType: 'work',
        sessionNumber: 1,
        totalSessions: 4,
        duration: 60,
        isAllSessionsComplete: false,
        totalFocusTime: 60,
        currentStreak: 1,
      ),
    );
    final pending = await notifications.pendingNotificationRequests();
    expect(pending.any((notification) => notification.id == 1004), isTrue);
    await notifications.cancelAll();

    expect(await taskProvider.deleteTask(taskId), isTrue);
  });
}
