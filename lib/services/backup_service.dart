import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_helper.dart';

class BackupService {
  static const String _backupFileName = 'focusbro_backup.json';
  static const String _lastBackupKey = 'last_backup_date';
  static const int _backupVersion = 1;

  static BackupService? _instance;
  static BackupService get instance => _instance ??= BackupService._();

  BackupService._();

  /// Create a complete backup of all app data
  Future<BackupResult> createBackup() async {
    try {
      debugPrint('BackupService: Starting backup creation...');

      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/$_backupFileName');

      // Collect all data
      final backupData = await _collectAllData();

      // Create backup metadata
      final backup = {
        'version': _backupVersion,
        'created_at': DateTime.now().toIso8601String(),
        'app_version': '1.0.0', // You can get this from package_info
        'data': backupData,
      };

      // Write to file
      final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
      await backupFile.writeAsString(jsonString);

      // Update last backup date
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastBackupKey, DateTime.now().toIso8601String());

      final fileSize = await backupFile.length();
      debugPrint(
          'BackupService: Backup created successfully. Size: $fileSize bytes');

      return BackupResult.success(
        filePath: backupFile.path,
        fileSize: fileSize,
        itemCount: _calculateItemCount(backupData),
      );
    } catch (e) {
      debugPrint('BackupService: Error creating backup: $e');
      return BackupResult.error('Failed to create backup: $e');
    }
  }

  /// Restore data from backup file
  Future<RestoreResult> restoreFromBackup({String? filePath}) async {
    try {
      debugPrint('BackupService: Starting restore process...');

      File? backupFile;

      if (filePath != null) {
        backupFile = File(filePath);
      } else {
        // Let user pick backup file
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          dialogTitle: 'Select Backup File',
        );

        if (result == null || result.files.isEmpty) {
          return RestoreResult.error('No backup file selected');
        }

        backupFile = File(result.files.first.path!);
      }

      if (!await backupFile.exists()) {
        return RestoreResult.error('Backup file not found');
      }

      // Read and parse backup file
      final jsonString = await backupFile.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      // Validate backup format
      if (!_validateBackupFormat(backupData)) {
        return RestoreResult.error('Invalid backup file format');
      }

      // Extract data
      final data = backupData['data'] as Map<String, dynamic>;

      // Restore all data
      final restoreCount = await _restoreAllData(data);

      debugPrint(
          'BackupService: Restore completed successfully. Items restored: $restoreCount');

      return RestoreResult.success(
        itemCount: restoreCount,
        backupDate: DateTime.parse(backupData['created_at']),
      );
    } catch (e) {
      debugPrint('BackupService: Error restoring backup: $e');
      return RestoreResult.error('Failed to restore backup: $e');
    }
  }

  /// Get last backup information
  Future<BackupInfo?> getLastBackupInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastBackupDate = prefs.getString(_lastBackupKey);

      if (lastBackupDate == null) return null;

      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/$_backupFileName');

      if (!await backupFile.exists()) return null;

      final fileSize = await backupFile.length();

      return BackupInfo(
        date: DateTime.parse(lastBackupDate),
        filePath: backupFile.path,
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('BackupService: Error getting backup info: $e');
      return null;
    }
  }

  /// Export backup file to user-selected location
  Future<bool> exportBackup() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final backupFile = File('${directory.path}/$_backupFileName');

      if (!await backupFile.exists()) {
        return false;
      }

      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Backup',
        fileName:
            'focusbro_backup_${DateTime.now().millisecondsSinceEpoch}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null) return false;

      final exportFile = File(result);
      await backupFile.copy(exportFile.path);

      return true;
    } catch (e) {
      debugPrint('BackupService: Error exporting backup: $e');
      return false;
    }
  }

  /// Collect all app data for backup
  Future<Map<String, dynamic>> _collectAllData() async {
    final data = <String, dynamic>{};

    // Get database helper
    final dbHelper = DatabaseHelper();

    // Collect all database tables
    data['tasks'] = await dbHelper.getAllTasks();
    data['notes'] = await dbHelper.getAllNotes();
    data['focus_sessions'] = await dbHelper.getAllFocusSessions();
    data['timer_presets'] = await dbHelper.getAllTimerPresets();
    data['subtasks'] = await dbHelper.getAllSubtasks();
    data['achievements'] = await dbHelper.getAllAchievements();
    data['user_achievements'] = await dbHelper.getAllUserAchievements();
    data['rewards'] = await dbHelper.getAllRewards();
    data['saved_timers'] = await dbHelper.getAllSavedTimers();
    data['user_settings'] = await dbHelper.getAllUserSettings();
    data['focus_statistics'] = await dbHelper.getFocusStatistics();

    // Collect SharedPreferences settings
    final prefs = await SharedPreferences.getInstance();
    final settings = <String, dynamic>{};

    for (final key in prefs.getKeys()) {
      if (!key.startsWith('flutter.') && key != _lastBackupKey) {
        final value = prefs.get(key);
        if (value != null) {
          settings[key] = value;
        }
      }
    }
    data['shared_preferences'] = settings;

    return data;
  }

  /// Restore all data from backup
  Future<int> _restoreAllData(Map<String, dynamic> data) async {
    int restoredCount = 0;

    // Get database helper
    final dbHelper = DatabaseHelper();

    // Clear existing data first
    await _clearExistingData();

    // Restore all database tables
    final tableKeys = [
      'tasks',
      'notes',
      'focus_sessions',
      'timer_presets',
      'subtasks',
      'achievements',
      'user_achievements',
      'rewards',
      'saved_timers',
      'user_settings',
      'focus_statistics'
    ];

    for (final tableKey in tableKeys) {
      if (data.containsKey(tableKey)) {
        final tableData = data[tableKey] as List;
        for (final rowData in tableData) {
          try {
            switch (tableKey) {
              case 'tasks':
                await dbHelper.insertTask(rowData as Map<String, dynamic>);
                break;
              case 'notes':
                await dbHelper.insertNote(rowData as Map<String, dynamic>);
                break;
              case 'focus_sessions':
                await dbHelper
                    .insertFocusSession(rowData as Map<String, dynamic>);
                break;
              case 'timer_presets':
                await dbHelper
                    .insertTimerPreset(rowData as Map<String, dynamic>);
                break;
              case 'subtasks':
                await dbHelper.insertSubtask(rowData as Map<String, dynamic>);
                break;
              case 'user_achievements':
                await dbHelper
                    .insertUserAchievement(rowData as Map<String, dynamic>);
                break;
              case 'rewards':
                await dbHelper.insertReward(rowData as Map<String, dynamic>);
                break;
              case 'saved_timers':
                await dbHelper
                    .insertSavedTimer(rowData as Map<String, dynamic>);
                break;
              case 'user_settings':
                await dbHelper
                    .insertUserSetting(rowData as Map<String, dynamic>);
                break;
              case 'focus_statistics':
                await dbHelper
                    .insertFocusStatistics(rowData as Map<String, dynamic>);
                break;
            }
            restoredCount++;
          } catch (e) {
            debugPrint('Error restoring $tableKey: $e');
          }
        }
      }
    }

    // Restore SharedPreferences settings
    if (data.containsKey('shared_preferences')) {
      final settingsData = data['shared_preferences'] as Map<String, dynamic>;
      final prefs = await SharedPreferences.getInstance();

      for (final entry in settingsData.entries) {
        try {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is double) {
            await prefs.setDouble(entry.key, value);
          } else if (value is bool) {
            await prefs.setBool(entry.key, value);
          } else if (value is List<String>) {
            await prefs.setStringList(entry.key, value);
          }
          restoredCount++;
        } catch (e) {
          debugPrint('Error restoring setting ${entry.key}: $e');
        }
      }
    }

    return restoredCount;
  }

  /// Clear existing data before restore
  Future<void> _clearExistingData() async {
    final dbHelper = DatabaseHelper();

    // Clear database tables
    await dbHelper.clearAllTasks();
    await dbHelper.clearAllNotes();
    await dbHelper.clearAllFocusSessions();
    await dbHelper.clearAllTimerPresets();

    // Clear relevant SharedPreferences (keep system settings)
    final prefs = await SharedPreferences.getInstance();
    final keysToKeep = {
      'flutter.',
      _lastBackupKey,
      'has_seen_onboarding',
      'language_code',
    };

    final keysToRemove = prefs.getKeys().where((key) {
      return !keysToKeep.any((keepKey) => key.startsWith(keepKey));
    }).toList();

    for (final key in keysToRemove) {
      await prefs.remove(key);
    }
  }

  /// Validate backup file format
  bool _validateBackupFormat(Map<String, dynamic> backup) {
    return backup.containsKey('version') &&
        backup.containsKey('created_at') &&
        backup.containsKey('data') &&
        backup['version'] is int &&
        backup['data'] is Map<String, dynamic>;
  }

  /// Calculate total item count in backup data
  int _calculateItemCount(Map<String, dynamic> data) {
    int count = 0;

    if (data.containsKey('tasks')) {
      count += (data['tasks'] as List).length;
    }
    if (data.containsKey('notes')) {
      count += (data['notes'] as List).length;
    }
    if (data.containsKey('focus_sessions')) {
      count += (data['focus_sessions'] as List).length;
    }
    if (data.containsKey('timer_presets')) {
      count += (data['timer_presets'] as List).length;
    }
    if (data.containsKey('settings')) {
      count += (data['settings'] as Map<String, dynamic>).length;
    }

    return count;
  }
}

/// Result classes for backup operations
class BackupResult {
  final bool success;
  final String? error;
  final String? filePath;
  final int? fileSize;
  final int? itemCount;

  BackupResult._({
    required this.success,
    this.error,
    this.filePath,
    this.fileSize,
    this.itemCount,
  });

  factory BackupResult.success({
    required String filePath,
    required int fileSize,
    required int itemCount,
  }) {
    return BackupResult._(
      success: true,
      filePath: filePath,
      fileSize: fileSize,
      itemCount: itemCount,
    );
  }

  factory BackupResult.error(String error) {
    return BackupResult._(success: false, error: error);
  }
}

class RestoreResult {
  final bool success;
  final String? error;
  final int? itemCount;
  final DateTime? backupDate;

  RestoreResult._({
    required this.success,
    this.error,
    this.itemCount,
    this.backupDate,
  });

  factory RestoreResult.success({
    required int itemCount,
    required DateTime backupDate,
  }) {
    return RestoreResult._(
      success: true,
      itemCount: itemCount,
      backupDate: backupDate,
    );
  }

  factory RestoreResult.error(String error) {
    return RestoreResult._(success: false, error: error);
  }
}

class BackupInfo {
  final DateTime date;
  final String filePath;
  final int fileSize;

  BackupInfo({
    required this.date,
    required this.filePath,
    required this.fileSize,
  });

  String get formattedDate {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  String get formattedSize {
    if (fileSize < 1024) {
      return '${fileSize}B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
