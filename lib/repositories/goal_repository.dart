import 'package:sqflite/sqflite.dart';
import '../models/goal.dart';
import '../services/database_helper.dart';
import 'base_repository.dart';

/// Repository for managing goals in the database
class GoalRepository extends BaseRepository<Goal> {
  @override
  String get tableName => 'goals';

  @override
  String get primaryKey => 'id';

  @override
  Goal fromMap(Map<String, dynamic> map) {
    return Goal.fromJson(map);
  }

  /// Initialize the repository and create table if needed
  Future<void> initialize() async {
    final db = await DatabaseHelper().database;
    await _createTable(db);
  }

  /// Create the goals table
  Future<void> _createTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        type TEXT NOT NULL,
        frequency TEXT NOT NULL,
        status TEXT NOT NULL,
        targetValue REAL NOT NULL,
        currentValue REAL DEFAULT 0.0,
        customUnit TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        startDate TEXT,
        endDate TEXT,
        completedAt TEXT,
        isArchived INTEGER DEFAULT 0,
        metadata TEXT
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goals_status ON $tableName(status)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goals_type ON $tableName(type)
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_goals_created_at ON $tableName(createdAt)
    ''');
  }

  /// Get active goals
  Future<List<Goal>> getActiveGoals() async {
    return await findWhere(
      'status = ? AND isArchived = ?',
      [GoalStatus.active.name, 0],
      orderBy: 'createdAt DESC',
    );
  }

  /// Get completed goals
  Future<List<Goal>> getCompletedGoals() async {
    return await findWhere(
      'status = ? AND isArchived = ?',
      [GoalStatus.completed.name, 0],
      orderBy: 'completedAt DESC',
    );
  }

  /// Get goals by type
  Future<List<Goal>> getGoalsByType(GoalType type) async {
    return await findWhere(
      'type = ? AND isArchived = ?',
      [type.name, 0],
      orderBy: 'createdAt DESC',
    );
  }

  /// Get goals by frequency
  Future<List<Goal>> getGoalsByFrequency(GoalFrequency frequency) async {
    return await findWhere(
      'frequency = ? AND isArchived = ?',
      [frequency.name, 0],
      orderBy: 'createdAt DESC',
    );
  }

  /// Get goals created in date range
  Future<List<Goal>> getGoalsInDateRange(
      DateTime startDate, DateTime endDate) async {
    return await findWhere(
      'createdAt >= ? AND createdAt <= ? AND isArchived = ?',
      [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        0,
      ],
      orderBy: 'createdAt DESC',
    );
  }

  /// Get goals due in date range
  Future<List<Goal>> getGoalsDueInRange(
      DateTime startDate, DateTime endDate) async {
    return await findWhere(
      'endDate >= ? AND endDate <= ? AND status = ? AND isArchived = ?',
      [
        startDate.toIso8601String(),
        endDate.toIso8601String(),
        GoalStatus.active.name,
        0,
      ],
      orderBy: 'endDate ASC',
    );
  }

  /// Archive a goal
  Future<void> archiveGoal(String goalId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      tableName,
      {
        'isArchived': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  /// Unarchive a goal
  Future<void> unarchiveGoal(String goalId) async {
    final db = await DatabaseHelper().database;
    await db.update(
      tableName,
      {
        'isArchived': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  /// Get archived goals
  Future<List<Goal>> getArchivedGoals() async {
    return await findWhere(
      'isArchived = ?',
      [1],
      orderBy: 'updatedAt DESC',
    );
  }

  /// Get goal statistics
  Future<Map<String, dynamic>> getGoalStatistics() async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalGoals,
        COUNT(CASE WHEN status = ? THEN 1 END) as activeGoals,
        COUNT(CASE WHEN status = ? THEN 1 END) as completedGoals,
        COUNT(CASE WHEN status = ? THEN 1 END) as pausedGoals,
        COUNT(CASE WHEN status = ? THEN 1 END) as cancelledGoals,
        AVG(CASE WHEN status = ? THEN (currentValue / targetValue) * 100 END) as avgProgress
      FROM $tableName 
      WHERE isArchived = 0
    ''', [
      GoalStatus.active.name,
      GoalStatus.completed.name,
      GoalStatus.paused.name,
      GoalStatus.cancelled.name,
      GoalStatus.active.name,
    ]);

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalGoals': row['totalGoals'] ?? 0,
        'activeGoals': row['activeGoals'] ?? 0,
        'completedGoals': row['completedGoals'] ?? 0,
        'pausedGoals': row['pausedGoals'] ?? 0,
        'cancelledGoals': row['cancelledGoals'] ?? 0,
        'averageProgress': row['avgProgress'] ?? 0.0,
      };
    }

    return {
      'totalGoals': 0,
      'activeGoals': 0,
      'completedGoals': 0,
      'pausedGoals': 0,
      'cancelledGoals': 0,
      'averageProgress': 0.0,
    };
  }

  /// Get goals completion rate by type
  Future<Map<String, double>> getCompletionRateByType() async {
    final db = await DatabaseHelper().database;

    final result = await db.rawQuery('''
      SELECT 
        type,
        COUNT(*) as total,
        COUNT(CASE WHEN status = ? THEN 1 END) as completed
      FROM $tableName 
      WHERE isArchived = 0
      GROUP BY type
    ''', [GoalStatus.completed.name]);

    final Map<String, double> completionRates = {};

    for (final row in result) {
      final type = row['type'] as String;
      final total = row['total'] as int;
      final completed = row['completed'] as int;

      if (total > 0) {
        completionRates[type] = (completed / total) * 100;
      }
    }

    return completionRates;
  }

  /// Clean up old archived goals
  Future<void> cleanupOldArchivedGoals({int daysOld = 90}) async {
    final db = await DatabaseHelper().database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));

    await db.delete(
      tableName,
      where: 'isArchived = 1 AND updatedAt < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Map<String, dynamic> toMap(Goal item) {
    final map = item.toJson();
    // Convert metadata to JSON string if it exists
    if (map['metadata'] != null) {
      map['metadata'] = map['metadata'].toString();
    }
    // Convert boolean to integer for SQLite
    map['isArchived'] = (map['isArchived'] as bool) ? 1 : 0;
    return map;
  }
}
