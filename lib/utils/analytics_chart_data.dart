class AnalyticsChartData {
  static const int daysPerWeek = 7;
  static const int hoursPerDay = 24;

  static List<double> weeklyFocusMinutes(Map<String, dynamic> analyticsData) {
    final values = List<double>.filled(daysPerWeek, 0);
    final dailyStats =
        _readMap(_readMap(analyticsData['weekly'])['dailyStats']);

    for (final entry in dailyStats.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;

      final stats = _readMap(entry.value);
      final focusSeconds = _readDouble(stats['focusTime']);
      values[date.weekday - 1] += focusSeconds / 60;
    }

    return values;
  }

  static List<double> completionPercentages(
      Map<String, dynamic> analyticsData) {
    final values = List<double>.filled(daysPerWeek, 0);
    final dailyData = _readMap(_readMap(analyticsData['trends'])['dailyData']);

    for (final entry in dailyData.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;

      final stats = _readMap(entry.value);
      final sessionCount = _readDouble(stats['sessionCount']);
      if (sessionCount <= 0) continue;

      final completedSessions = _readDouble(stats['completedSessions']);
      values[date.weekday - 1] =
          (completedSessions / sessionCount * 100).clamp(0, 100).toDouble();
    }

    return values;
  }

  static List<double> hourlyProductivityScores(
      Map<String, dynamic> analyticsData) {
    final totals = List<double>.filled(hoursPerDay, 0);
    final hourly = _readMap(analyticsData['hourly']);

    for (var hour = 0; hour < hoursPerDay; hour++) {
      final stats = _readMap(hourly[hour.toString()]);
      totals[hour] = _readDouble(stats['totalTime']);
    }

    final maxTotal = totals.fold<double>(
      0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );
    if (maxTotal <= 0) return totals;

    return totals.map((value) => value / maxTotal * 10).toList();
  }

  static List<AnalyticsDailyActivity> recentActivities(
    Map<String, dynamic> analyticsData, {
    int limit = 5,
  }) {
    final dailyData = _readMap(_readMap(analyticsData['trends'])['dailyData']);
    final activities = <AnalyticsDailyActivity>[];

    for (final entry in dailyData.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;

      final stats = _readMap(entry.value);
      activities.add(
        AnalyticsDailyActivity(
          date: date,
          sessionCount: _readDouble(stats['sessionCount']).round(),
          completedSessions: _readDouble(stats['completedSessions']).round(),
          totalSeconds: _readDouble(stats['totalTime']).round(),
        ),
      );
    }

    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities.take(limit).toList();
  }

  static List<double> weeklyActivityIntensity(
      Map<String, dynamic> analyticsData) {
    final minutes = weeklyFocusMinutes(analyticsData);
    final maxMinutes = minutes.fold<double>(
      0,
      (maxValue, value) => value > maxValue ? value : maxValue,
    );
    if (maxMinutes <= 0) return List<double>.filled(daysPerWeek, 0);

    return minutes
        .map((value) => (value / maxMinutes).clamp(0.15, 1.0))
        .toList();
  }

  static double maxOrDefault(List<double> values, double fallback) {
    final maxValue = values.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    return maxValue > 0 ? maxValue : fallback;
  }

  static Map<String, dynamic> _readMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    return const {};
  }

  static double _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class AnalyticsDailyActivity {
  const AnalyticsDailyActivity({
    required this.date,
    required this.sessionCount,
    required this.completedSessions,
    required this.totalSeconds,
  });

  final DateTime date;
  final int sessionCount;
  final int completedSessions;
  final int totalSeconds;

  int get totalMinutes => (totalSeconds / 60).round();
}
