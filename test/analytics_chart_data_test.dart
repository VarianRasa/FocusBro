import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/utils/analytics_chart_data.dart';

void main() {
  group('AnalyticsChartData', () {
    test('maps weekly focus seconds to weekday minute values', () {
      final monday = DateTime(2026, 6, 8);
      final data = {
        'weekly': {
          'dailyStats': {
            monday.toIso8601String().split('T').first: {
              'sessions': 2,
              'focusTime': 1500,
            },
            monday
                .add(const Duration(days: 2))
                .toIso8601String()
                .split('T')
                .first: {
              'sessions': 1,
              'focusTime': 600,
            },
          },
        },
      };

      expect(AnalyticsChartData.weeklyFocusMinutes(data), [
        25.0,
        0.0,
        10.0,
        0.0,
        0.0,
        0.0,
        0.0,
      ]);
    });

    test('calculates completion percentages from daily trend data', () {
      final data = {
        'trends': {
          'dailyData': {
            '2026-06-08': {'sessionCount': 4, 'completedSessions': 3},
            '2026-06-09': {'sessionCount': 2, 'completedSessions': 1},
          },
        },
      };

      expect(AnalyticsChartData.completionPercentages(data), [
        75.0,
        50.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
      ]);
    });

    test('scales hourly productivity scores from real hourly totals', () {
      final data = {
        'hourly': {
          '9': {'sessionCount': 2, 'totalTime': 3600},
          '10': {'sessionCount': 1, 'totalTime': 1800},
        },
      };

      final scores = AnalyticsChartData.hourlyProductivityScores(data);

      expect(scores[9], 10.0);
      expect(scores[10], 5.0);
      expect(scores[8], 0.0);
    });

    test('returns the most recent daily activities first', () {
      final data = {
        'trends': {
          'dailyData': {
            '2026-06-07': {
              'sessionCount': 2,
              'completedSessions': 1,
              'totalTime': 1800,
            },
            '2026-06-08': {
              'sessionCount': 3,
              'completedSessions': 3,
              'totalTime': 3600,
            },
          },
        },
      };

      final activities = AnalyticsChartData.recentActivities(data);

      expect(activities.first.date, DateTime(2026, 6, 8));
      expect(activities.first.sessionCount, 3);
      expect(activities.first.completedSessions, 3);
      expect(activities.first.totalMinutes, 60);
    });
  });
}
