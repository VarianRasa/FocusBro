import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static const String _databaseName = 'focusbro.db';
  static const int _databaseVersion = 8;

  @visibleForTesting
  static Future<void> upgradeForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) {
    return DatabaseHelper()._onUpgrade(db, oldVersion, newVersion);
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);

      if (kDebugMode) {
        print('Database path: $path');
      }

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing database: $e');
      }
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
    if (kDebugMode) {
      print('Upgrading database from version $oldVersion to $newVersion');
    }

    // Handle specific version upgrades
    if (oldVersion < 3 && newVersion >= 3) {
      // Add sort_order column to tasks table
      try {
        await db.execute(
            'ALTER TABLE tasks ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0');
        await db
            .execute('CREATE INDEX idx_tasks_sort_order ON tasks(sort_order)');
        if (kDebugMode) {
          print(
              'DatabaseHelper: Successfully added sort_order column to tasks table');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DatabaseHelper: Error adding sort_order column: $e');
        }
        // If column already exists or other error, continue
      }
    }

    if (oldVersion < 4 && newVersion >= 4) {
      // Add is_pinned and tags columns to notes table
      try {
        await db.execute(
            'ALTER TABLE notes ADD COLUMN is_pinned BOOLEAN NOT NULL DEFAULT 0');
        await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
        if (kDebugMode) {
          print(
              'DatabaseHelper: Successfully added is_pinned column to notes table');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DatabaseHelper: Error adding is_pinned column: $e');
        }
      }

      try {
        await db.execute('ALTER TABLE notes ADD COLUMN tags TEXT DEFAULT \'\'');
        await db.execute('CREATE INDEX idx_notes_tags ON notes(tags)');
        if (kDebugMode) {
          print(
              'DatabaseHelper: Successfully added tags column to notes table');
        }
      } catch (e) {
        if (kDebugMode) {
          print('DatabaseHelper: Error adding tags column: $e');
        }
      }
    }

    if (oldVersion < 5 && newVersion >= 5) {
      // New migration for version 5
      await _createAppLockSettingsTable(db);
      if (kDebugMode) {
        print('DatabaseHelper: Successfully created app_lock_settings table');
      }
    }

    if (oldVersion < 6 && newVersion >= 6) {
      await _createSyncOutboxTable(db);
    }

    if (oldVersion < 7 && newVersion >= 7) {
      final taskColumns = await db.rawQuery('PRAGMA table_info(tasks)');
      if (taskColumns.isNotEmpty &&
          !taskColumns.any((column) => column['name'] == 'task_json')) {
        await db.execute('ALTER TABLE tasks ADD COLUMN task_json TEXT');
      }
    }

    if (oldVersion < 8 && newVersion >= 8) {
      await _createSyncCoordinatorTables(db);
    }

    // For other major changes, recreate tables (in production, use proper migrations)
    if (oldVersion < 2) {
      await _dropAllTables(db);
      await _createTables(db);
    }
  }

  Future<void> _onOpen(Database db) async {
    // Enable foreign key constraints
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTables(Database db) async {
    // Buat semua tabel terlebih dahulu
    await _createFocusSessionsTable(db);
    await _createTasksTable(db);
    await _createSubtasksTable(db);
    await _createNotesTable(db);
    await _createNoteAttachmentsTable(db);
    await _createAchievementsTable(db);
    await _createUserAchievementsTable(db);
    await _createRewardsTable(db);
    await _createSavedTimersTable(db);
    await _createUserSettingsTable(db);
    await _createFocusStatisticsTable(db);
    await _createTimerPresetsTable(db);
    await _createAppLockSettingsTable(db);
    await _createGoalsTable(db);
    await _createSyncOutboxTable(db);
    await _createSyncCoordinatorTables(db);
    // Setelah SEMUA tabel dibuat, baru insert default data
    await _insertDefaultData(db);
  }

  Future<void> _createFocusSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE focus_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_date TEXT NOT NULL,
        work_duration INTEGER NOT NULL,
        break_duration INTEGER NOT NULL,
        total_duration INTEGER NOT NULL,
        session_type TEXT NOT NULL DEFAULT 'work',
        completed BOOLEAN NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute(
        'CREATE INDEX idx_focus_sessions_date ON focus_sessions(session_date)');
    await db.execute(
        'CREATE INDEX idx_focus_sessions_completed ON focus_sessions(completed)');
  }

  Future<void> _createTasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        task_json TEXT,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        due_date TEXT,
        is_completed BOOLEAN NOT NULL DEFAULT 0,
        is_favorite BOOLEAN NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        notification_enabled BOOLEAN NOT NULL DEFAULT 1,
        notification_reminder_minutes INTEGER NOT NULL DEFAULT 60,
        notification_repeat BOOLEAN NOT NULL DEFAULT 0,
        notification_repeat_interval INTEGER NOT NULL DEFAULT 0,
        notification_sound BOOLEAN NOT NULL DEFAULT 1,
        notification_vibration BOOLEAN NOT NULL DEFAULT 1,
        notification_priority INTEGER NOT NULL DEFAULT 2,
        notification_custom_sound TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create indexes
    await db.execute('CREATE INDEX idx_tasks_category ON tasks(category)');
    await db.execute('CREATE INDEX idx_tasks_priority ON tasks(priority)');
    await db.execute('CREATE INDEX idx_tasks_due_date ON tasks(due_date)');
    await db.execute('CREATE INDEX idx_tasks_completed ON tasks(is_completed)');
    await db.execute('CREATE INDEX idx_tasks_favorite ON tasks(is_favorite)');
    await db.execute('CREATE INDEX idx_tasks_sort_order ON tasks(sort_order)');
  }

  Future<void> _createSubtasksTable(Database db) async {
    await db.execute('''
      CREATE TABLE subtasks (
        id TEXT PRIMARY KEY,
        task_id TEXT NOT NULL,
        title TEXT NOT NULL,
        is_completed BOOLEAN NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('CREATE INDEX idx_subtasks_task_id ON subtasks(task_id)');
    await db.execute(
        'CREATE INDEX idx_subtasks_completed ON subtasks(is_completed)');
  }

  Future<void> _createNotesTable(Database db) async {
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        is_favorite BOOLEAN NOT NULL DEFAULT 0,
        is_pinned BOOLEAN NOT NULL DEFAULT 0,
        tags TEXT DEFAULT '',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('CREATE INDEX idx_notes_category ON notes(category)');
    await db.execute('CREATE INDEX idx_notes_favorite ON notes(is_favorite)');
    await db.execute('CREATE INDEX idx_notes_pinned ON notes(is_pinned)');
    await db.execute('CREATE INDEX idx_notes_tags ON notes(tags)');
    await db.execute('CREATE INDEX idx_notes_created_at ON notes(created_at)');
  }

  Future<void> _createNoteAttachmentsTable(Database db) async {
    await db.execute('''
      CREATE TABLE note_attachments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        note_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_name TEXT NOT NULL,
        file_type TEXT,
        file_size INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
        'CREATE INDEX idx_note_attachments_note_id ON note_attachments(note_id)');
  }

  Future<void> _createAchievementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        icon TEXT NOT NULL,
        target_value INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createUserAchievementsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_achievements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        achievement_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        progress INTEGER NOT NULL DEFAULT 0,
        is_unlocked BOOLEAN NOT NULL DEFAULT 0,
        unlocked_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (achievement_id) REFERENCES achievements (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_user_achievements_achievement_id ON user_achievements(achievement_id)');
    await db.execute(
        'CREATE INDEX idx_user_achievements_user_id ON user_achievements(user_id)');
  }

  Future<void> _createRewardsTable(Database db) async {
    await db.execute('''
      CREATE TABLE rewards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        type TEXT NOT NULL,
        value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSavedTimersTable(Database db) async {
    await db.execute('''
      CREATE TABLE saved_timers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        duration_seconds INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createUserSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE user_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        setting_key TEXT NOT NULL UNIQUE,
        setting_value TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createFocusStatisticsTable(Database db) async {
    await db.execute('''
      CREATE TABLE focus_statistics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        current_streak INTEGER NOT NULL DEFAULT 0,
        longest_streak INTEGER NOT NULL DEFAULT 0,
        total_focus_time INTEGER NOT NULL DEFAULT 0,
        total_sessions INTEGER NOT NULL DEFAULT 0,
        last_focus_date TEXT,
        average_session_length INTEGER NOT NULL DEFAULT 0,
        best_day_date TEXT,
        best_day_duration INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createTimerPresetsTable(Database db) async {
    await db.execute('''
      CREATE TABLE timer_presets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        work_duration INTEGER NOT NULL,
        break_duration INTEGER NOT NULL,
        total_sessions INTEGER NOT NULL,
        is_built_in BOOLEAN NOT NULL DEFAULT 0,
        is_active BOOLEAN NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // New table for App Lock settings
  Future<void> _createAppLockSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE app_lock_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        is_app_lock_enabled BOOLEAN NOT NULL DEFAULT 0,
        lock_method TEXT NOT NULL DEFAULT 'pin',
        hashed_pin TEXT,
        pin_length INTEGER,
        lock_timeout_minutes INTEGER NOT NULL DEFAULT 5,
        last_unlock_time TEXT
      )
    ''');
    // Ensure there's always one row for settings
    await db.rawInsert(
        'INSERT INTO app_lock_settings (id, is_app_lock_enabled, lock_method, lock_timeout_minutes) VALUES (?, ?, ?, ?)',
        [1, 0, 'pin', 5]);
  }

  Future<void> _createGoalsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS goals (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        target_value REAL NOT NULL,
        current_value REAL NOT NULL DEFAULT 0,
        unit TEXT,
        deadline TEXT,
        is_completed BOOLEAN NOT NULL DEFAULT 0,
        category TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createSyncOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        operation_id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation_kind TEXT NOT NULL
          CHECK (operation_kind IN ('upsert', 'delete')),
        schema_version INTEGER NOT NULL CHECK (schema_version > 0),
        payload_json TEXT,
        status TEXT NOT NULL DEFAULT 'pending'
          CHECK (status IN ('pending', 'inProgress', 'failed', 'completed')),
        attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
        error_code TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        last_attempt_at TEXT,
        next_attempt_at TEXT,
        completed_at TEXT,
        deleted_at TEXT,
        account_uid TEXT
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_ready
      ON sync_outbox(status, next_attempt_at, created_at)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_entity
      ON sync_outbox(entity_type, entity_id, created_at)
    ''');
  }

  Future<void> _createSyncCoordinatorTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_state (
        singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
        account_uid TEXT,
        pending_account_uid TEXT,
        last_successful_sync TEXT
      )
    ''');
    await db.insert(
      'sync_state',
      {'singleton_id': 1},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_conflicts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        account_uid TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        local_version_json TEXT NOT NULL,
        remote_version_json TEXT NOT NULL,
        detected_at TEXT NOT NULL,
        UNIQUE(account_uid, entity_type, entity_id)
      )
    ''');
  }

  Future<void> _insertDefaultData(Database db) async {
    // Insert default timer presets if not exist
    final List<Map<String, dynamic>> existingPresets = await db.query(
      'timer_presets',
      limit: 1,
    );
    if (existingPresets.isEmpty) {
      final timestamp = DateTime.now().toIso8601String();
      await db.insert(
        'timer_presets',
        {
          'id': 'pomodoro_default',
          'name': 'Pomodoro',
          'work_duration': 25 * 60,
          'break_duration': 5 * 60,
          'total_sessions': 4,
          'is_built_in': 1,
          'is_active': 1,
          'created_at': timestamp,
          'updated_at': timestamp,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Default data for goals (if not already existing)
    final List<Map<String, dynamic>> existingGoals = await db.query(
      'goals',
      limit: 1,
    );
    if (existingGoals.isEmpty) {
      await db.insert(
        'goals',
        {
          'id': 'example_goal_1',
          'title': 'Complete Flutter Project',
          'description':
              'Finish the FocusBro application with all core features.',
          'target_value': 100,
          'current_value': 0,
          'unit': '%',
          'deadline':
              DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'is_completed': 0,
          'category': 'Development',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // Default data for user settings (if not already existing)
    final List<Map<String, dynamic>> existingSettings = await db.query(
      'user_settings',
      limit: 1,
    );
    if (existingSettings.isEmpty) {
      await db.insert(
        'user_settings',
        {
          'setting_key': 'default_app_theme',
          'setting_value': 'system',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _dropAllTables(Database db) async {
    // Drop all tables in reverse order of creation (if dependencies exist)
    await db.execute('DROP TABLE IF EXISTS app_lock_settings');
    await db.execute('DROP TABLE IF EXISTS timer_presets');
    await db.execute('DROP TABLE IF EXISTS focus_statistics');
    await db.execute('DROP TABLE IF EXISTS user_settings');
    await db.execute('DROP TABLE IF EXISTS saved_timers');
    await db.execute('DROP TABLE IF EXISTS rewards');
    await db.execute('DROP TABLE IF EXISTS user_achievements');
    await db.execute('DROP TABLE IF EXISTS achievements');
    await db.execute('DROP TABLE IF EXISTS note_attachments');
    await db.execute('DROP TABLE IF EXISTS notes');
    await db.execute('DROP TABLE IF EXISTS subtasks');
    await db.execute('DROP TABLE IF EXISTS tasks');
    await db.execute('DROP TABLE IF EXISTS focus_sessions');
    if (kDebugMode) {
      print('All tables dropped.');
    }
  }

  /// Close the database
  Future<void> close() async {
    final db = _database;
    if (db == null) return;
    await db.close();
    _database = null;
  }

  /// Delete the database file (for testing purposes)
  Future<void> deleteDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      if (kDebugMode) {
        print('Deleting database at: $path');
      }
      await databaseFactory.deleteDatabase(path);
      _database = null;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting database: $e');
      }
    }
  }

  // Backup & Restore operations

  /// Get all tasks for backup
  Future<List<Map<String, dynamic>>> getAllTasks() async {
    final db = await database;
    return await db.query('tasks');
  }

  /// Get all notes for backup
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    return await db.query('notes');
  }

  /// Get all focus sessions for backup
  Future<List<Map<String, dynamic>>> getAllFocusSessions() async {
    final db = await database;
    return await db.query('focus_sessions');
  }

  /// Get all timer presets for backup
  Future<List<Map<String, dynamic>>> getAllTimerPresets() async {
    final db = await database;
    return await db.query('timer_presets');
  }

  /// Get all subtasks for backup
  Future<List<Map<String, dynamic>>> getAllSubtasks() async {
    final db = await database;
    return await db.query('subtasks');
  }

  /// Get all achievements for backup
  Future<List<Map<String, dynamic>>> getAllAchievements() async {
    final db = await database;
    return await db.query('achievements');
  }

  /// Get all user achievements for backup
  Future<List<Map<String, dynamic>>> getAllUserAchievements() async {
    final db = await database;
    return await db.query('user_achievements');
  }

  /// Get all rewards for backup
  Future<List<Map<String, dynamic>>> getAllRewards() async {
    final db = await database;
    return await db.query('rewards');
  }

  /// Get all saved timers for backup
  Future<List<Map<String, dynamic>>> getAllSavedTimers() async {
    final db = await database;
    return await db.query('saved_timers');
  }

  /// Get all user settings for backup
  Future<List<Map<String, dynamic>>> getAllUserSettings() async {
    final db = await database;
    return await db.query('user_settings');
  }

  /// Get focus statistics for backup
  Future<List<Map<String, dynamic>>> getFocusStatistics() async {
    final db = await database;
    return await db.query('focus_statistics');
  }

  /// Clear all tasks
  Future<void> clearAllTasks() async {
    final db = await database;
    await db.delete('tasks');
  }

  /// Clear all notes
  Future<void> clearAllNotes() async {
    final db = await database;
    await db.delete('notes');
  }

  /// Clear all focus sessions
  Future<void> clearAllFocusSessions() async {
    final db = await database;
    await db.delete('focus_sessions');
  }

  /// Clear all timer presets (except built-in ones)
  Future<void> clearAllTimerPresets() async {
    final db = await database;
    await db.delete('timer_presets', where: 'is_built_in = ?', whereArgs: [0]);
  }

  /// Clear all subtasks
  Future<void> clearAllSubtasks() async {
    final db = await database;
    await db.delete('subtasks');
  }

  /// Clear all user achievements
  Future<void> clearAllUserAchievements() async {
    final db = await database;
    await db.delete('user_achievements');
  }

  /// Clear all rewards
  Future<void> clearAllRewards() async {
    final db = await database;
    await db.delete('rewards');
  }

  /// Clear all saved timers
  Future<void> clearAllSavedTimers() async {
    final db = await database;
    await db.delete('saved_timers');
  }

  /// Clear all user settings
  Future<void> clearAllUserSettings() async {
    final db = await database;
    await db.delete('user_settings');
  }

  /// Reset focus statistics
  Future<void> resetFocusStatistics() async {
    final db = await database;
    await db.delete('focus_statistics');
    // Insert default statistics
    await db.insert('focus_statistics', {
      'current_streak': 0,
      'longest_streak': 0,
      'total_focus_time': 0,
      'total_sessions': 0,
      'average_session_length': 0,
      'best_day_duration': 0,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Insert task for restore
  Future<int> insertTask(Map<String, dynamic> task) async {
    final db = await database;
    return await db.insert('tasks', task,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert note for restore
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert focus session for restore
  Future<int> insertFocusSession(Map<String, dynamic> session) async {
    final db = await database;
    return await db.insert('focus_sessions', session,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert timer preset for restore
  Future<int> insertTimerPreset(Map<String, dynamic> preset) async {
    final db = await database;
    return await db.insert('timer_presets', preset,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert subtask for restore
  Future<int> insertSubtask(Map<String, dynamic> subtask) async {
    final db = await database;
    return await db.insert('subtasks', subtask,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert user achievement for restore
  Future<int> insertUserAchievement(Map<String, dynamic> achievement) async {
    final db = await database;
    return await db.insert('user_achievements', achievement,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert reward for restore
  Future<int> insertReward(Map<String, dynamic> reward) async {
    final db = await database;
    return await db.insert('rewards', reward,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert saved timer for restore
  Future<int> insertSavedTimer(Map<String, dynamic> timer) async {
    final db = await database;
    return await db.insert('saved_timers', timer,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert user setting for restore
  Future<int> insertUserSetting(Map<String, dynamic> setting) async {
    final db = await database;
    return await db.insert('user_settings', setting,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Insert focus statistics for restore
  Future<int> insertFocusStatistics(Map<String, dynamic> stats) async {
    final db = await database;
    return await db.insert('focus_statistics', stats,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
