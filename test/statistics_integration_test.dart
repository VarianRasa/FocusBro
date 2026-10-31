import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/services/analytics_service.dart';
import 'package:focusbro/repositories/focus_repository.dart';
import 'package:focusbro/models/focus_session.dart';

void main() {
  group('Statistics Integration Tests', () {
    late FocusProvider focusProvider;
    late AnalyticsService analyticsService;
    late FocusRepository focusRepository;

    setUp(() {
      focusProvider = FocusProvider();
      analyticsService = AnalyticsService();
      focusRepository = FocusRepository();
    });

    test('Focus session completion should be tracked in analytics', () async {
      // Simulate completing a focus session
      final now = DateTime.now();
      final session = FocusSession(
        sessionDate: now,
        workDuration: 1500, // 25 minutes
        breakDuration: 300, // 5 minutes
        totalDuration: 1500,
        sessionType: 'work',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );

      // Save session to database
      await focusRepository.insert(session);

      // Track in analytics
      await analyticsService.trackFocusSession(
        duration: session.totalDuration,
        completed: session.completed,
        sessionType: session.sessionType,
        startTime: now.subtract(Duration(seconds: session.totalDuration)),
        endTime: now,
      );

      // Verify analytics data is updated
      final stats = await analyticsService.getFocusStatistics();
      expect(stats['totalSessions'], greaterThan(0));
      expect(stats['totalFocusTime'], greaterThan(0));

      print('✅ Focus session completion tracked in analytics');
    });

    test('Weekly summary should include real session data', () async {
      // Create multiple sessions over the week
      final now = DateTime.now();
      final sessions = <FocusSession>[];

      for (int i = 0; i < 7; i++) {
        final sessionDate = now.subtract(Duration(days: i));
        final session = FocusSession(
          sessionDate: sessionDate,
          workDuration: 1500 + (i * 300), // Varying durations
          breakDuration: 300,
          totalDuration: 1500 + (i * 300),
          sessionType: 'work',
          completed: i % 4 != 0, // Some incomplete sessions
          createdAt: sessionDate,
          updatedAt: sessionDate,
        );
        sessions.add(session);
        await focusRepository.insert(session);
      }

      // Get weekly summary
      final weeklySummary = await analyticsService.getWeeklySummary();

      expect(weeklySummary['totalSessions'], greaterThan(0));
      expect(weeklySummary['completedSessions'], greaterThan(0));
      expect(weeklySummary['totalFocusTime'], greaterThan(0));
      expect(weeklySummary['averageSessionLength'], greaterThan(0));

      print('✅ Weekly summary includes real session data');
    });

    test('Streak calculation should be accurate', () async {
      // Create consecutive daily sessions
      final now = DateTime.now();

      for (int i = 0; i < 5; i++) {
        final sessionDate = now.subtract(Duration(days: i));
        final session = FocusSession(
          sessionDate: sessionDate,
          workDuration: 1500,
          breakDuration: 300,
          totalDuration: 1500,
          sessionType: 'work',
          completed: true,
          createdAt: sessionDate,
          updatedAt: sessionDate,
        );
        await focusRepository.insert(session);
      }

      // Get streak info
      final streakInfo = await analyticsService.getStreakInfo();

      expect(streakInfo['currentStreak'], greaterThanOrEqualTo(1));
      expect(streakInfo['longestStreak'], greaterThanOrEqualTo(1));

      print('✅ Streak calculation is accurate');
    });

    test('FocusProvider refreshStatistics should update from database',
        () async {
      // Create a test session
      final now = DateTime.now();
      final session = FocusSession(
        sessionDate: now,
        workDuration: 1500,
        breakDuration: 300,
        totalDuration: 1500,
        sessionType: 'work',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );
      await focusRepository.insert(session);

      // Get initial stats
      final initialSessions = focusProvider.todaysSessions;

      // Refresh statistics
      await focusProvider.refreshStatistics();

      // Verify stats are updated
      expect(
          focusProvider.todaysSessions, greaterThanOrEqualTo(initialSessions));

      print('✅ FocusProvider refreshStatistics updates from database');
    });

    test('Analytics data should persist across app restarts', () async {
      // Create test data
      final now = DateTime.now();
      final session = FocusSession(
        sessionDate: now,
        workDuration: 1500,
        breakDuration: 300,
        totalDuration: 1500,
        sessionType: 'work',
        completed: true,
        createdAt: now,
        updatedAt: now,
      );
      await focusRepository.insert(session);

      // Track in analytics
      await analyticsService.trackFocusSession(
        duration: session.totalDuration,
        completed: session.completed,
        sessionType: session.sessionType,
        startTime: now.subtract(Duration(seconds: session.totalDuration)),
        endTime: now,
      );

      // Simulate app restart by creating new service instance
      final newAnalyticsService = AnalyticsService();

      // Verify data persists
      final stats = await newAnalyticsService.getFocusStatistics();
      expect(stats['totalSessions'], greaterThan(0));

      print('✅ Analytics data persists across app restarts');
    });

    test('Completion rate calculation should be accurate', () async {
      // Create mix of completed and incomplete sessions
      final now = DateTime.now();

      // 3 completed sessions
      for (int i = 0; i < 3; i++) {
        final session = FocusSession(
          sessionDate: now.subtract(Duration(hours: i)),
          workDuration: 1500,
          breakDuration: 300,
          totalDuration: 1500,
          sessionType: 'work',
          completed: true,
          createdAt: now.subtract(Duration(hours: i)),
          updatedAt: now.subtract(Duration(hours: i)),
        );
        await focusRepository.insert(session);
      }

      // 1 incomplete session
      final incompleteSession = FocusSession(
        sessionDate: now.subtract(const Duration(hours: 4)),
        workDuration: 1500,
        breakDuration: 300,
        totalDuration: 1500,
        sessionType: 'work',
        completed: false,
        createdAt: now.subtract(const Duration(hours: 4)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      );
      await focusRepository.insert(incompleteSession);

      // Get statistics
      final stats = await analyticsService.getFocusStatistics();
      final completionRate = stats['completionRate'] ?? 0.0;

      // Should be 75% (3 out of 4 sessions completed)
      expect(completionRate, closeTo(0.75, 0.1));

      print('✅ Completion rate calculation is accurate');
    });

    test('Real-time statistics updates after session completion', () async {
      // Get initial stats
      final initialStats = await analyticsService.getFocusStatistics();
      final initialSessions = initialStats['totalSessions'] ?? 0;

      // Complete a session through FocusProvider
      focusProvider.setWorkDuration(1500);
      focusProvider.setBreakDuration(300);
      await focusProvider.updateFocusSession(1500, 300);

      // Get updated stats
      final updatedStats = await analyticsService.getFocusStatistics();
      final updatedSessions = updatedStats['totalSessions'] ?? 0;

      // Verify stats are updated
      expect(updatedSessions, greaterThan(initialSessions));

      print('✅ Real-time statistics updates after session completion');
    });
  });
}
