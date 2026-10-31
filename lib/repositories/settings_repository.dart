import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/saved_timer.dart';
import '../services/database_helper.dart';

class SavedTimerRepository extends BaseRepository<SavedTimer> {
  @override
  String get tableName => 'saved_timers';

  @override
  SavedTimer fromMap(Map<String, dynamic> map) {
    return SavedTimer.fromMap(map);
  }

  /// Get all saved timers ordered by creation date
  Future<List<SavedTimer>> getAllTimers() async {
    return await findAll(orderBy: 'created_at DESC');
  }

  /// Get default timer
  Future<SavedTimer?> getDefaultTimer() async {
    final timers = await findWhere(
      'is_default = ?',
      [1],
      limit: 1,
    );
    return timers.isNotEmpty ? timers.first : null;
  }

  /// Set timer as default
  Future<void> setAsDefault(int timerId) async {
    final db = await _database;

    // First, remove default status from all timers
    await db.update(
      tableName,
      {'is_default': 0},
      where: 'is_default = 1',
    );

    // Then set the specified timer as default
    await db.update(
      tableName,
      {
        'is_default': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [timerId],
    );
  }

  /// Get timers by name (search)
  Future<List<SavedTimer>> searchTimers(String query) async {
    return await findWhere(
      'name LIKE ?',
      ['%$query%'],
      orderBy: 'name ASC',
    );
  }

  /// Check if timer name exists
  Future<bool> timerNameExists(String name, {int? excludeId}) async {
    String where = 'name = ?';
    List<dynamic> whereArgs = [name];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final count = await countWhere(where, whereArgs);
    return count > 0;
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}

class UserSettingRepository extends BaseRepository<UserSetting> {
  @override
  String get tableName => 'user_settings';

  @override
  String get primaryKey => 'key';

  @override
  UserSetting fromMap(Map<String, dynamic> map) {
    return UserSetting.fromMap(map);
  }

  /// Get setting value by key
  Future<String?> getValue(String key) async {
    final setting = await findById(key);
    return setting?.value;
  }

  /// Get boolean setting
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await getValue(key);
    if (value == null) return defaultValue;
    return value.toLowerCase() == 'true';
  }

  /// Get integer setting
  Future<int> getInt(String key, {int defaultValue = 0}) async {
    final value = await getValue(key);
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }

  /// Get double setting
  Future<double> getDouble(String key, {double defaultValue = 0.0}) async {
    final value = await getValue(key);
    if (value == null) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }

  /// Get string setting
  Future<String> getString(String key, {String defaultValue = ''}) async {
    final value = await getValue(key);
    return value ?? defaultValue;
  }

  /// Set boolean setting
  Future<void> setBool(String key, bool value) async {
    await _setSetting(UserSetting.fromBool(key, value));
  }

  /// Set integer setting
  Future<void> setInt(String key, int value) async {
    await _setSetting(UserSetting.fromInt(key, value));
  }

  /// Set double setting
  Future<void> setDouble(String key, double value) async {
    await _setSetting(UserSetting.fromDouble(key, value));
  }

  /// Set string setting
  Future<void> setString(String key, String value) async {
    await _setSetting(UserSetting.fromString(key, value));
  }

  /// Internal method to set setting (insert or update)
  Future<void> _setSetting(UserSetting setting) async {
    final existing = await findById(setting.key);

    if (existing != null) {
      await update(setting);
    } else {
      await insert(setting);
    }
  }

  /// Get all settings as a map
  Future<Map<String, String>> getAllSettings() async {
    final settings = await findAll();
    final map = <String, String>{};

    for (final setting in settings) {
      map[setting.key] = setting.value;
    }

    return map;
  }

  /// Get settings by prefix
  Future<Map<String, String>> getSettingsByPrefix(String prefix) async {
    final settings = await findWhere(
      'key LIKE ?',
      ['$prefix%'],
      orderBy: 'key ASC',
    );

    final map = <String, String>{};
    for (final setting in settings) {
      map[setting.key] = setting.value;
    }

    return map;
  }

  /// Delete setting by key
  Future<int> deleteSetting(String key) async {
    return await delete(key);
  }

  /// Delete settings by prefix
  Future<int> deleteSettingsByPrefix(String prefix) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: 'key LIKE ?',
      whereArgs: ['$prefix%'],
    );
  }

  /// Check if setting exists
  Future<bool> settingExists(String key) async {
    return await exists(key);
  }

  /// Get setting with metadata
  Future<UserSetting?> getSettingWithMetadata(String key) async {
    return await findById(key);
  }

  /// Bulk set settings
  Future<void> bulkSetSettings(Map<String, dynamic> settings) async {
    final db = await _database;
    final batch = db.batch();

    for (final entry in settings.entries) {
      final setting = _createSettingFromValue(entry.key, entry.value);

      // Check if exists to decide insert or update
      final existing = await findById(entry.key);
      if (existing != null) {
        batch.update(
          tableName,
          setting.toMap(),
          where: 'key = ?',
          whereArgs: [entry.key],
        );
      } else {
        batch.insert(tableName, setting.toMap());
      }
    }

    await batch.commit();
  }

  /// Create UserSetting from dynamic value
  UserSetting _createSettingFromValue(String key, dynamic value) {
    if (value is bool) {
      return UserSetting.fromBool(key, value);
    } else if (value is int) {
      return UserSetting.fromInt(key, value);
    } else if (value is double) {
      return UserSetting.fromDouble(key, value);
    } else {
      return UserSetting.fromString(key, value.toString());
    }
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}
