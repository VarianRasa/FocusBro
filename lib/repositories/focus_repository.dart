import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/focus_session.dart';

class FocusSessionRepository extends BaseRepository<FocusSession> {
  @override
  String get tableName => 'focus_sessions';

  @override
  FocusSession fromMap(Map<String, dynamic> map) {
    return FocusSession.fromMap(map);
  }

  /// Get sessions for a specific date range
  Future<List<FocusSession>> getSessionsInDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await findWhere(
      'session_date >= ? AND session_date <= ?',
      [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'session_date DESC',
    );
  }

  /// Get sessions for today
  Future<List<FocusSession>> getTodaySessions() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getSessionsInDateRange(startOfDay, endOfDay);
  }

  /// Get sessions for this week
  Future<List<FocusSession>> getThisWeekSessions() async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfWeekDay =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final endOfWeek = startOfWeekDay.add(const Duration(days: 7));

    return await getSessionsInDateRange(startOfWeekDay, endOfWeek);
  }

  /// Get sessions for this month
  Future<List<FocusSession>> getThisMonthSessions() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 1);

    return await getSessionsInDateRange(startOfMonth, endOfMonth);
  }

  /// Get completed sessions count
  Future<int> getCompletedSessionsCount() async {
    return await countWhere('completed = ?', [1]);
  }

  /// Get total focus time in seconds
  Future<int> getTotalFocusTime() async {
    final result = await rawQuery(
      'SELECT SUM(work_duration) as total FROM $tableName WHERE completed = 1',
    );
    return result.isNotEmpty ? (result.first['total'] as int? ?? 0) : 0;
  }

  /// Get average session length
  Future<double> getAverageSessionLength() async {
    final result = await rawQuery(
      'SELECT AVG(work_duration) as average FROM $tableName WHERE completed = 1',
    );
    return result.isNotEmpty
        ? (result.first['average'] as double? ?? 0.0)
        : 0.0;
  }

  /// Get longest session duration
  Future<int> getLongestSessionDuration() async {
    final result = await rawQuery(
      'SELECT MAX(work_duration) as longest FROM $tableName WHERE completed = 1',
    );
    return result.isNotEmpty ? (result.first['longest'] as int? ?? 0) : 0;
  }

  /// Get daily statistics for a date range
  Future<Map<String, int>> getDailyStats(
      DateTime startDate, DateTime endDate) async {
    final result = await rawQuery('''
      SELECT 
        DATE(session_date) as date,
        SUM(work_duration) as total_time
      FROM $tableName 
      WHERE session_date >= ? AND session_date <= ? AND completed = 1
      GROUP BY DATE(session_date)
      ORDER BY date
    ''', [startDate.toIso8601String(), endDate.toIso8601String()]);

    final stats = <String, int>{};
    for (final row in result) {
      stats[row['date'] as String] = row['total_time'] as int;
    }
    return stats;
  }

  /// Get best day (highest focus time)
  Future<Map<String, dynamic>?> getBestDay() async {
    final result = await rawQuery('''
      SELECT 
        DATE(session_date) as date,
        SUM(work_duration) as total_time
      FROM $tableName 
      WHERE completed = 1
      GROUP BY DATE(session_date)
      ORDER BY total_time DESC
      LIMIT 1
    ''');

    if (result.isNotEmpty) {
      return {
        'date': DateTime.parse(result.first['date'] as String),
        'duration': result.first['total_time'] as int,
      };
    }
    return null;
  }

  /// Delete old sessions (keep only last N sessions)
  Future<int> deleteOldSessions(int keepCount) async {
    final result = await rawQuery('''
      SELECT id FROM $tableName 
      ORDER BY session_date DESC 
      LIMIT -1 OFFSET ?
    ''', [keepCount]);

    if (result.isNotEmpty) {
      final idsToDelete = result.map((row) => row['id']).toList();
      return await deleteBatch(idsToDelete);
    }
    return 0;
  }
}

class FocusStatisticsRepository extends BaseRepository<FocusStatistics> {
  @override
  String get tableName => 'focus_statistics';

  @override
  FocusStatistics fromMap(Map<String, dynamic> map) {
    return FocusStatistics.fromMap(map);
  }

  /// Get the current statistics (there should only be one record)
  Future<FocusStatistics?> getCurrentStatistics() async {
    final stats = await findAll(limit: 1);
    return stats.isNotEmpty ? stats.first : null;
  }

  /// Update or create statistics
  Future<void> updateStatistics(FocusStatistics statistics) async {
    final existing = await getCurrentStatistics();

    if (existing != null) {
      await update(statistics.copyWith(id: existing.id));
    } else {
      await insert(statistics);
    }
  }

  /// Initialize default statistics if none exist
  Future<void> initializeIfEmpty() async {
    final count = await this.count();
    if (count == 0) {
      await insert(FocusStatistics(
        currentStreak: 0,
        longestStreak: 0,
        totalFocusTime: 0,
        totalSessions: 0,
        averageSessionLength: 0,
        bestDayDuration: 0,
        updatedAt: DateTime.now(),
      ));
    }
  }
}
