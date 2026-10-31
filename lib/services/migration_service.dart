import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/focus_session.dart';
import '../models/note.dart';

import '../models/saved_timer.dart';
import '../repositories/focus_repository.dart';
import '../repositories/task_repository.dart';
import '../repositories/note_repository.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/settings_repository.dart';
import 'task_migration_contract.dart';

class MigrationService {
  static const String _migrationCompletedKey = 'database_migration_completed';
  static const String _migrationVersionKey = 'database_migration_version';
  static const int _currentMigrationVersion = 1;

  final FocusSessionRepository _focusSessionRepo = FocusSessionRepository();
  final FocusStatisticsRepository _focusStatsRepo = FocusStatisticsRepository();
  final CanonicalTaskRepository _canonicalTaskRepo = CanonicalTaskRepository();
  final NoteRepository _noteRepo = NoteRepository();
  final UserAchievementRepository _userAchievementRepo =
      UserAchievementRepository();

  final SavedTimerRepository _savedTimerRepo = SavedTimerRepository();
  final UserSettingRepository _settingsRepo = UserSettingRepository();

  TaskMigrationBatch? _lastTaskMigrationReport;
  bool _taskMigrationVerified = false;

  TaskMigrationBatch? get lastTaskMigrationReport => _lastTaskMigrationReport;

  /// Check if migration is needed and perform it
  Future<bool> performMigrationIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final migrationCompleted = prefs.getBool(_migrationCompletedKey) ?? false;
      final migrationVersion = prefs.getInt(_migrationVersionKey) ?? 0;

      if (!migrationCompleted || migrationVersion < _currentMigrationVersion) {
        if (kDebugMode) {
          print('Starting database migration...');
        }

        await _performMigration();

        // Mark migration as completed
        await prefs.setBool(_migrationCompletedKey, true);
        await prefs.setInt(_migrationVersionKey, _currentMigrationVersion);

        if (kDebugMode) {
          print('Database migration completed successfully');
        }

        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Migration failed: $e');
      }
      rethrow;
    }
  }

  /// Perform the actual migration
  Future<void> _performMigration() async {
    final prefs = await SharedPreferences.getInstance();

    // Migrate focus data
    await _migrateFocusData(prefs);

    // Migrate tasks
    await _migrateTasks(prefs);

    // Migrate notes
    await _migrateNotes(prefs);

    // Migrate achievements
    await _migrateAchievements(prefs);

    // Migrate saved timers
    await _migrateSavedTimers(prefs);

    // Migrate settings
    await _migrateSettings(prefs);
  }

  /// Migrate focus session data and statistics
  Future<void> _migrateFocusData(SharedPreferences prefs) async {
    try {
      // Migrate focus statistics
      final currentStreak = prefs.getInt('currentStreak') ?? 0;
      final longestStreak = prefs.getInt('longestStreak') ?? 0;
      final totalFocusTime = prefs.getInt('totalFocusTime') ?? 0;
      final lastFocusDateStr = prefs.getString('lastFocusDate');

      final focusStats = FocusStatistics(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        totalFocusTime: totalFocusTime,
        totalSessions: 0, // Will be calculated from sessions
        lastFocusDate:
            lastFocusDateStr != null ? DateTime.parse(lastFocusDateStr) : null,
        averageSessionLength: 0, // Will be calculated
        bestDayDuration: 0, // Will be calculated
        updatedAt: DateTime.now(),
      );

      await _focusStatsRepo.updateStatistics(focusStats);

      // Migrate session history
      final historyJson = prefs.getStringList('sessionHistory') ?? [];
      final sessions = <FocusSession>[];

      for (final json in historyJson) {
        try {
          final parts = json.split('|');
          if (parts.length >= 4) {
            final session = FocusSession(
              sessionDate: DateTime.parse(parts[0]),
              totalDuration: int.parse(parts[1]),
              workDuration: int.parse(parts[2]),
              breakDuration: int.parse(parts[3]),
              sessionType: 'work',
              completed: true,
              createdAt: DateTime.parse(parts[0]),
              updatedAt: DateTime.parse(parts[0]),
            );
            sessions.add(session);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error migrating session: $e');
          }
        }
      }

      if (sessions.isNotEmpty) {
        await _focusSessionRepo.insertBatch(sessions);
      }

      if (kDebugMode) {
        print('Migrated ${sessions.length} focus sessions');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating focus data: $e');
      }
    }
  }

  /// Migrate tasks and subtasks
  Future<void> _migrateTasks(SharedPreferences prefs) async {
    _lastTaskMigrationReport = null;
    _taskMigrationVerified = false;
    try {
      final sourceEntries = prefs.getStringList('tasks') ?? const <String>[];
      final sourceBatch =
          TaskMigrationContract.decodePreferenceEntries(sourceEntries);
      final existingTasks = await _canonicalTaskRepo.loadAllTaskPayloads();
      final mergedBatch = TaskMigrationContract.decodePreferenceEntries([
        ...existingTasks.map(jsonEncode),
        ...sourceEntries,
      ]);

      // Keep existing SQLite tasks in the desired set, and keep migration
      // writes out of the sync queue until the user chooses reconciliation.
      await _canonicalTaskRepo.replaceAllTaskPayloads(
        mergedBatch.tasks,
        enqueue: false,
      );
      _lastTaskMigrationReport = sourceBatch;
      _taskMigrationVerified = true;

      if (kDebugMode) {
        print(
          'Migrated ${sourceBatch.migratedCount} of '
          '${sourceBatch.scannedCount} task entries',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating tasks: $e');
      }
      rethrow;
    }
  }

  /// Migrate notes
  Future<void> _migrateNotes(SharedPreferences prefs) async {
    try {
      final notesJson = prefs.getStringList('notes') ?? [];
      final notes = <Note>[];

      for (final json in notesJson) {
        try {
          final data = jsonDecode(json);
          final note = Note(
            id: data['id'],
            title: data['title'],
            content: data['content'],
            category: data['category'],
            isFavorite: false, // Default value, can be enhanced later
            createdAt: DateTime.parse(data['date']),
            updatedAt: DateTime.parse(data['date']),
          );
          notes.add(note);
        } catch (e) {
          if (kDebugMode) {
            print('Error migrating note: $e');
          }
        }
      }

      if (notes.isNotEmpty) {
        await _noteRepo.insertBatch(notes);
      }

      if (kDebugMode) {
        print('Migrated ${notes.length} notes');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating notes: $e');
      }
    }
  }

  /// Migrate achievements
  Future<void> _migrateAchievements(SharedPreferences prefs) async {
    try {
      final unlockedAchievements =
          prefs.getStringList('unlockedAchievements') ?? [];

      // Unlock achievements that were previously unlocked
      for (final achievementId in unlockedAchievements) {
        await _userAchievementRepo.unlockAchievement(achievementId);
      }

      if (kDebugMode) {
        print('Migrated ${unlockedAchievements.length} unlocked achievements');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating achievements: $e');
      }
    }
  }

  /// Migrate saved timers
  Future<void> _migrateSavedTimers(SharedPreferences prefs) async {
    try {
      final savedTimersJson = prefs.getStringList('savedTimers') ?? [];
      final timers = <SavedTimer>[];

      for (final json in savedTimersJson) {
        try {
          final data = jsonDecode(json) as Map<String, dynamic>;
          final now = DateTime.now();

          final timer = SavedTimer(
            name: data['name'],
            workDuration: data['workDuration'],
            breakDuration: data['breakDuration'],
            sessionsUntilLongBreak: data['sessionsUntilLongBreak'] ?? 3,
            createdAt: now,
            updatedAt: now,
          );
          timers.add(timer);
        } catch (e) {
          if (kDebugMode) {
            print('Error migrating saved timer: $e');
          }
        }
      }

      if (timers.isNotEmpty) {
        await _savedTimerRepo.insertBatch(timers);
      }

      if (kDebugMode) {
        print('Migrated ${timers.length} saved timers');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating saved timers: $e');
      }
    }
  }

  /// Migrate app settings
  Future<void> _migrateSettings(SharedPreferences prefs) async {
    try {
      final settingsToMigrate = {
        'isDarkMode': prefs.getBool('isDarkMode'),
        'workDuration': prefs.getInt('workDuration'),
        'breakDuration': prefs.getInt('breakDuration'),
        'isMusicEnabled': prefs.getBool('isMusicEnabled'),
        'musicVolume': prefs.getDouble('musicVolume'),
        'selectedMusic': prefs.getString('selectedMusic'),
        'selectedNotificationSound':
            prefs.getString('selectedNotificationSound'),
        'isNotificationBlockingEnabled':
            prefs.getBool('isNotificationBlockingEnabled'),
        'showFocusNotification': prefs.getBool('showFocusNotification'),
        'isDNDEnabled': prefs.getBool('isDNDEnabled'),
        'isDNDScheduled': prefs.getBool('isDNDScheduled'),
        'dndStartHour': prefs.getInt('dndStartHour'),
        'dndStartMinute': prefs.getInt('dndStartMinute'),
        'dndEndHour': prefs.getInt('dndEndHour'),
        'dndEndMinute': prefs.getInt('dndEndMinute'),
        'isFocusModeEnabled': prefs.getBool('isFocusModeEnabled'),
      };

      final settingsMap = <String, dynamic>{};
      for (final entry in settingsToMigrate.entries) {
        if (entry.value != null) {
          settingsMap[entry.key] = entry.value;
        }
      }

      // Migrate string lists
      final stringListSettings = {
        'blockedApps': prefs.getStringList('blockedApps'),
        'allowedApps': prefs.getStringList('allowedApps'),
      };

      for (final entry in stringListSettings.entries) {
        if (entry.value != null) {
          settingsMap[entry.key] = jsonEncode(entry.value);
        }
      }

      if (settingsMap.isNotEmpty) {
        await _settingsRepo.bulkSetSettings(settingsMap);
      }

      if (kDebugMode) {
        print('Migrated ${settingsMap.length} settings');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error migrating settings: $e');
      }
    }
  }

  /// Clean up old SharedPreferences data after successful migration
  Future<void> cleanupOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // List of keys to remove after migration
      final keysToRemove = [
        'currentStreak',
        'longestStreak',
        'totalFocusTime',
        'lastFocusDate',
        'sessionHistory',
        'achievements',
        'unlockedAchievements',
        'notes',
        'savedTimers',
        'workDuration',
        'breakDuration',
        'completedSessions',
        'isMusicEnabled',
        'musicVolume',
        'selectedMusic',
        'selectedNotificationSound',
        'isNotificationBlockingEnabled',
        'blockedApps',
        'showFocusNotification',
        'isDNDEnabled',
        'isDNDScheduled',
        'dndStartHour',
        'dndStartMinute',
        'dndEndHour',
        'dndEndMinute',
        'isFocusModeEnabled',
        'allowedApps',
      ];

      final taskReport = _lastTaskMigrationReport;
      if (_taskMigrationVerified &&
          taskReport != null &&
          !taskReport.hasErrors) {
        keysToRemove.add('tasks');
      }

      for (final key in keysToRemove) {
        await prefs.remove(key);
      }

      if (kDebugMode) {
        print('Cleaned up ${keysToRemove.length} old SharedPreferences keys');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error cleaning up old data: $e');
      }
    }
  }
}
