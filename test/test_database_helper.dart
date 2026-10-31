import 'dart:async';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestDatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    // Use in-memory database for testing
    return await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Create focus_sessions table
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

    // Create tasks table
    await db.execute('''
      CREATE TABLE tasks (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        category TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        due_date TEXT,
        is_completed BOOLEAN NOT NULL DEFAULT 0,
        is_favorite BOOLEAN NOT NULL DEFAULT 0,
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

    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        is_favorite BOOLEAN NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Create focus_statistics table
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

  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  static Future<void> reset() async {
    await close();
    _database = null;
  }
}
