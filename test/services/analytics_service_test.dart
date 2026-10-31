import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusbro/services/analytics_service.dart';

void main() {
  group('AnalyticsService Tests', () {
    late AnalyticsService analyticsService;

    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({});
      analyticsService = AnalyticsService();
      await analyticsService.initialize();
    });

    tearDown(() async {
      await analyticsService.clearAllData();
    });

    group('Focus Session Tracking', () {
      test('should track completed focus session', () async {
        // Arrange
        const duration = 1500; // 25 minutes
        const sessionType = 'work';
        final startTime =
            DateTime.now().subtract(const Duration(seconds: duration));
        final endTime = DateTime.now();

        // Act
        await analyticsService.trackFocusSession(
          duration: duration,
          completed: true,
          sessionType: sessionType,
          startTime: startTime,
          endTime: endTime,
        );

        // Assert
        final stats = await analyticsService.getFocusStatistics();
        expect(stats['totalSessions'], equals(1));
        expect(stats['completedSessions'], equals(1));
        expect(stats['totalFocusTime'], equals(duration));
        expect(stats['completionRate'], equals(1.0));
      });

      test('should track incomplete focus session', () async {
        // Arrange
        const duration = 1500;
        const sessionType = 'work';
        final startTime =
            DateTime.now().subtract(const Duration(seconds: duration));
        final endTime = DateTime.now();

        // Act
        await analyticsService.trackFocusSession(
          duration: duration,
          completed: false,
          sessionType: sessionType,
          startTime: startTime,
          endTime: endTime,
        );

        // Assert
        final stats = await analyticsService.getFocusStatistics();
        expect(stats['totalSessions'], equals(1));
        expect(stats['completedSessions'], equals(0));
        expect(stats['totalFocusTime'], equals(0));
        expect(stats['completionRate'], equals(0.0));
      });

      test('should calculate correct completion rate', () async {
        // Arrange & Act
        for (int i = 0; i < 10; i++) {
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: i < 7, // 7 out of 10 completed
            sessionType: 'work',
            startTime: DateTime.now().subtract(Duration(seconds: 1500 + i)),
            endTime: DateTime.now().subtract(Duration(seconds: i)),
          );
        }

        // Assert
        final stats = await analyticsService.getFocusStatistics();
        expect(stats['totalSessions'], equals(10));
        expect(stats['completedSessions'], equals(7));
        expect(stats['completionRate'], closeTo(0.7, 0.01));
      });
    });

    group('Productivity Insights', () {
      test('should generate insights for high completion rate', () async {
        // Arrange - Create sessions with high completion rate
        for (int i = 0; i < 10; i++) {
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: i < 9, // 90% completion rate
            sessionType: 'work',
            startTime: DateTime.now().subtract(Duration(hours: i)),
            endTime:
                DateTime.now().subtract(Duration(hours: i, seconds: -1500)),
          );
        }

        // Act
        final insights = await analyticsService.getProductivityInsights();

        // Assert
        expect(insights['score'], greaterThanOrEqualTo(80));
        expect(insights['completionRate'], closeTo(0.9, 0.01));
        final insightsList = insights['insights'] as List<String>;
        expect(
            insightsList.any((insight) => insight.contains('Excellent focus')),
            isTrue);
      });

      test('should generate insights for low completion rate', () async {
        // Arrange - Create sessions with low completion rate
        for (int i = 0; i < 10; i++) {
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: i < 4, // 40% completion rate
            sessionType: 'work',
            startTime: DateTime.now().subtract(Duration(hours: i)),
            endTime:
                DateTime.now().subtract(Duration(hours: i, seconds: -1500)),
          );
        }

        // Act
        final insights = await analyticsService.getProductivityInsights();

        // Assert
        expect(insights['score'], lessThan(60));
        expect(insights['completionRate'], closeTo(0.4, 0.01));
        final insightsList = insights['insights'] as List<String>;
        expect(
            insightsList.any((insight) => insight.contains('shorter sessions')),
            isTrue);
      });
    });

    group('Streak Calculation', () {
      test('should calculate current streak correctly', () async {
        // Arrange - Create sessions for consecutive days
        final today = DateTime.now();
        for (int i = 0; i < 5; i++) {
          final sessionDate = today.subtract(Duration(days: i));
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: true,
            sessionType: 'work',
            startTime: sessionDate,
            endTime: sessionDate.add(const Duration(seconds: 1500)),
          );
        }

        // Act
        final streakInfo = await analyticsService.getStreakInfo();

        // Assert
        expect(streakInfo['currentStreak'], equals(5));
        expect(streakInfo['longestStreak'], equals(5));
        expect(streakInfo['activeDays'], equals(5));
      });

      test('should handle broken streak correctly', () async {
        // Arrange - Create sessions with a gap
        final today = DateTime.now();

        // Sessions for days 0, 1, 2 (current streak)
        for (int i = 0; i < 3; i++) {
          final sessionDate = today.subtract(Duration(days: i));
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: true,
            sessionType: 'work',
            startTime: sessionDate,
            endTime: sessionDate.add(const Duration(seconds: 1500)),
          );
        }

        // Gap on day 3

        // Sessions for days 4, 5, 6, 7, 8 (previous streak)
        for (int i = 4; i < 9; i++) {
          final sessionDate = today.subtract(Duration(days: i));
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: true,
            sessionType: 'work',
            startTime: sessionDate,
            endTime: sessionDate.add(const Duration(seconds: 1500)),
          );
        }

        // Act
        final streakInfo = await analyticsService.getStreakInfo();

        // Assert
        expect(streakInfo['currentStreak'], equals(3));
        expect(streakInfo['longestStreak'], equals(5));
        expect(streakInfo['activeDays'], equals(8));
      });
    });

    group('Weekly Summary', () {
      test('should calculate weekly summary correctly', () async {
        // Arrange - Create sessions for the past week
        final today = DateTime.now();
        var totalFocusTime = 0;
        var totalSessions = 0;

        for (int i = 0; i < 7; i++) {
          final sessionDate = today.subtract(Duration(days: i));
          const sessionDuration = 1500;

          await analyticsService.trackFocusSession(
            duration: sessionDuration,
            completed: true,
            sessionType: 'work',
            startTime: sessionDate,
            endTime: sessionDate.add(const Duration(seconds: sessionDuration)),
          );

          totalFocusTime += sessionDuration;
          totalSessions++;
        }

        // Act
        final weeklySummary = await analyticsService.getWeeklySummary();

        // Assert
        expect(weeklySummary['totalSessions'], equals(totalSessions));
        expect(weeklySummary['totalFocusTime'], equals(totalFocusTime));
        expect(weeklySummary['activeDays'], equals(7));
        expect(weeklySummary['averageDailyFocusTime'],
            closeTo(totalFocusTime / 7, 1));
      });
    });

    group('Feature Usage Tracking', () {
      test('should track feature usage', () async {
        // Arrange
        const feature = 'timer_preset_save';
        final metadata = {'preset_name': 'Pomodoro', 'duration': 1500};

        // Act
        await analyticsService.trackFeatureUsage(feature, metadata: metadata);

        // Assert - This would require accessing internal data structure
        // In a real implementation, you might have a method to get feature usage stats
      });
    });

    group('Data Export', () {
      test('should export analytics data', () async {
        // Arrange - Create some test data
        await analyticsService.trackFocusSession(
          duration: 1500,
          completed: true,
          sessionType: 'work',
          startTime: DateTime.now().subtract(const Duration(seconds: 1500)),
          endTime: DateTime.now(),
        );

        await analyticsService.trackFeatureUsage('test_feature');

        // Act
        final exportedData = await analyticsService.exportData();

        // Assert
        expect(exportedData, isA<Map<String, dynamic>>());
        expect(exportedData.containsKey('focusSessions'), isTrue);
        expect(exportedData.containsKey('featureUsage'), isTrue);
        expect(exportedData.containsKey('exportDate'), isTrue);

        final focusSessions = exportedData['focusSessions'] as List;
        expect(focusSessions.length, equals(1));
      });
    });

    group('Data Validation', () {
      test('should handle invalid session data gracefully', () async {
        // This test would verify that the service handles edge cases
        // like negative durations, null values, etc.

        // Act & Assert - Should not throw
        expect(() async {
          await analyticsService.trackFocusSession(
            duration: -100, // Invalid duration
            completed: true,
            sessionType: 'work',
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          );
        }, returnsNormally);
      });
    });

    group('Performance Tests', () {
      test('should handle large amounts of data efficiently', () async {
        // Arrange & Act - Create a large number of sessions
        final stopwatch = Stopwatch()..start();

        for (int i = 0; i < 1000; i++) {
          await analyticsService.trackFocusSession(
            duration: 1500,
            completed: i % 2 == 0,
            sessionType: i % 3 == 0 ? 'work' : 'break',
            startTime: DateTime.now().subtract(Duration(seconds: i * 1500)),
            endTime:
                DateTime.now().subtract(Duration(seconds: i * 1500 - 1500)),
          );
        }

        final stats = await analyticsService.getFocusStatistics();
        stopwatch.stop();

        // Assert
        expect(stats['totalSessions'], equals(1000));
        expect(stopwatch.elapsedMilliseconds,
            lessThan(5000)); // Should complete in under 5 seconds
      });
    });
  });
}
