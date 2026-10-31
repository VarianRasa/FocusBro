import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/achievement.dart';
import '../services/database_helper.dart';

class AchievementRepository extends BaseRepository<Achievement> {
  @override
  String get tableName => 'achievements';

  @override
  String get primaryKey => 'id';

  @override
  Achievement fromMap(Map<String, dynamic> map) {
    return Achievement.fromMap(map);
  }

  /// Get achievements with their unlock status
  Future<List<Achievement>> getAchievementsWithStatus() async {
    final result = await rawQuery('''
      SELECT 
        a.*,
        CASE WHEN ua.achievement_id IS NOT NULL THEN 1 ELSE 0 END as is_unlocked,
        ua.unlocked_at,
        ua.progress
      FROM $tableName a
      LEFT JOIN user_achievements ua ON a.id = ua.achievement_id
      ORDER BY a.created_at ASC
    ''');

    return result.map((map) {
      final achievement = fromMap(map);
      achievement.isUnlocked = map['is_unlocked'] == 1;
      return achievement;
    }).toList();
  }

  /// Get unlocked achievements
  Future<List<Achievement>> getUnlockedAchievements() async {
    final result = await rawQuery('''
      SELECT a.*
      FROM $tableName a
      INNER JOIN user_achievements ua ON a.id = ua.achievement_id
      ORDER BY ua.unlocked_at DESC
    ''');

    return result.map((map) {
      final achievement = fromMap(map);
      achievement.isUnlocked = true;
      return achievement;
    }).toList();
  }

  /// Get locked achievements
  Future<List<Achievement>> getLockedAchievements() async {
    final result = await rawQuery('''
      SELECT a.*
      FROM $tableName a
      LEFT JOIN user_achievements ua ON a.id = ua.achievement_id
      WHERE ua.achievement_id IS NULL
      ORDER BY a.created_at ASC
    ''');

    return result.map((map) => fromMap(map)).toList();
  }

  /// Get achievements by type
  Future<List<Achievement>> getAchievementsByType(
      String achievementType) async {
    return await findWhere(
      'achievement_type = ?',
      [achievementType],
      orderBy: 'target_value ASC',
    );
  }

  /// Check if achievement is unlocked
  Future<bool> isAchievementUnlocked(String achievementId) async {
    final userAchievementRepo = UserAchievementRepository();
    final count = await userAchievementRepo.countWhere(
      'achievement_id = ?',
      [achievementId],
    );
    return count > 0;
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

class UserAchievementRepository extends BaseRepository<UserAchievement> {
  @override
  String get tableName => 'user_achievements';

  @override
  UserAchievement fromMap(Map<String, dynamic> map) {
    return UserAchievement.fromMap(map);
  }

  /// Unlock an achievement
  Future<int> unlockAchievement(String achievementId,
      {int progress = 100}) async {
    // Check if already unlocked
    final existing = await findWhere('achievement_id = ?', [achievementId]);
    if (existing.isNotEmpty) {
      return 0; // Already unlocked
    }

    final userAchievement = UserAchievement(
      achievementId: achievementId,
      unlockedAt: DateTime.now(),
      progress: progress,
    );

    return await insert(userAchievement);
  }

  /// Update achievement progress
  Future<int> updateProgress(String achievementId, int progress) async {
    final db = await _database;
    return await db.update(
      tableName,
      {'progress': progress},
      where: 'achievement_id = ?',
      whereArgs: [achievementId],
    );
  }

  /// Get user achievements with achievement details
  Future<List<Map<String, dynamic>>> getUserAchievementsWithDetails() async {
    final result = await rawQuery('''
      SELECT 
        ua.*,
        a.title,
        a.description,
        a.icon_code_point,
        a.icon_font_family,
        a.achievement_type,
        a.target_value
      FROM $tableName ua
      INNER JOIN achievements a ON ua.achievement_id = a.id
      ORDER BY ua.unlocked_at DESC
    ''');

    return result;
  }

  /// Get recently unlocked achievements (last N days)
  Future<List<UserAchievement>> getRecentlyUnlocked(int days) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    return await findWhere(
      'unlocked_at >= ?',
      [cutoffDate.toIso8601String()],
      orderBy: 'unlocked_at DESC',
    );
  }

  /// Get achievement unlock count
  Future<int> getUnlockCount() async {
    return await count();
  }

  /// Get unlock rate (percentage of total achievements unlocked)
  Future<double> getUnlockRate() async {
    final achievementRepo = AchievementRepository();
    final totalAchievements = await achievementRepo.count();
    if (totalAchievements == 0) return 0.0;

    final unlockedCount = await count();
    return unlockedCount / totalAchievements;
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

class RewardRepository extends BaseRepository<Reward> {
  @override
  String get tableName => 'rewards';

  @override
  String get primaryKey => 'id';

  @override
  Reward fromMap(Map<String, dynamic> map) {
    return Reward.fromMap(map);
  }

  /// Get unlocked rewards
  Future<List<Reward>> getUnlockedRewards() async {
    return await findWhere(
      'is_unlocked = ?',
      [1],
      orderBy: 'unlocked_at DESC',
    );
  }

  /// Get locked rewards
  Future<List<Reward>> getLockedRewards() async {
    return await findWhere(
      'is_unlocked = ?',
      [0],
      orderBy: 'required_streak ASC',
    );
  }

  /// Get rewards sorted by required streak
  Future<List<Reward>> getRewardsByStreak() async {
    return await findAll(orderBy: 'required_streak ASC');
  }

  /// Unlock reward
  Future<int> unlockReward(String rewardId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [rewardId],
    );
  }

  /// Lock reward (for testing or reset purposes)
  Future<int> lockReward(String rewardId) async {
    final db = await _database;
    return await db.update(
      tableName,
      {
        'is_unlocked': 0,
        'unlocked_at': null,
      },
      where: 'id = ?',
      whereArgs: [rewardId],
    );
  }

  /// Update rewards based on current streak
  Future<void> updateRewardsForStreak(int currentStreak) async {
    final db = await _database;

    // Unlock rewards that meet the streak requirement
    await db.update(
      tableName,
      {
        'is_unlocked': 1,
        'unlocked_at': DateTime.now().toIso8601String(),
      },
      where: 'required_streak <= ? AND is_unlocked = 0',
      whereArgs: [currentStreak],
    );
  }

  /// Get next reward to unlock
  Future<Reward?> getNextReward(int currentStreak) async {
    final rewards = await findWhere(
      'required_streak > ? AND is_unlocked = 0',
      [currentStreak],
      orderBy: 'required_streak ASC',
      limit: 1,
    );

    return rewards.isNotEmpty ? rewards.first : null;
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}
