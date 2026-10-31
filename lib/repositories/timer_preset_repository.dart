import 'package:sqflite/sqflite.dart';
import 'base_repository.dart';
import '../models/timer_preset.dart';
import '../services/database_helper.dart';

class TimerPresetRepository extends BaseRepository<TimerPreset> {
  @override
  String get tableName => 'timer_presets';

  @override
  TimerPreset fromMap(Map<String, dynamic> map) {
    return TimerPreset.fromMap(map);
  }

  /// Initialize built-in presets if they don't exist
  Future<void> initializeBuiltInPresets() async {
    final db = await _database;

    // Check if built-in presets already exist
    final existingBuiltIns = await findWhere('is_built_in = ?', [1]);

    if (existingBuiltIns.isEmpty) {
      // Insert built-in presets
      final builtInPresets = TimerPreset.builtInPresets;
      for (final preset in builtInPresets) {
        await insert(preset);
      }
    }
  }

  /// Get all presets ordered by built-in first, then by creation date
  Future<List<TimerPreset>> getAllPresets() async {
    return await findAll(orderBy: 'is_built_in DESC, created_at ASC');
  }

  /// Get only built-in presets
  Future<List<TimerPreset>> getBuiltInPresets() async {
    return await findWhere('is_built_in = ?', [1], orderBy: 'created_at ASC');
  }

  /// Get only custom (user-created) presets
  Future<List<TimerPreset>> getCustomPresets() async {
    return await findWhere('is_built_in = ?', [0], orderBy: 'created_at DESC');
  }

  /// Get currently active preset
  Future<TimerPreset?> getActivePreset() async {
    final presets = await findWhere('is_active = ?', [1], limit: 1);
    return presets.isNotEmpty ? presets.first : null;
  }

  /// Set a preset as active (only one can be active at a time)
  Future<void> setActivePreset(int presetId) async {
    final db = await _database;

    // First, deactivate all presets
    await db.update(
      tableName,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'is_active = 1',
    );

    // Then activate the specified preset
    await db.update(
      tableName,
      {'is_active': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [presetId],
    );
  }

  /// Clear active preset
  Future<void> clearActivePreset() async {
    final db = await _database;
    await db.update(
      tableName,
      {'is_active': 0, 'updated_at': DateTime.now().toIso8601String()},
      where: 'is_active = 1',
    );
  }

  /// Check if preset name exists (excluding specified ID for updates)
  Future<bool> presetNameExists(String name, {int? excludeId}) async {
    String where = 'LOWER(name) = LOWER(?)';
    List<dynamic> whereArgs = [name.trim()];

    if (excludeId != null) {
      where += ' AND id != ?';
      whereArgs.add(excludeId);
    }

    final count = await countWhere(where, whereArgs);
    return count > 0;
  }

  /// Search presets by name
  Future<List<TimerPreset>> searchPresets(String query) async {
    return await findWhere(
      'name LIKE ?',
      ['%$query%'],
      orderBy: 'is_built_in DESC, name ASC',
    );
  }

  /// Delete preset (only custom presets can be deleted)
  Future<bool> deleteCustomPreset(int presetId) async {
    // First check if it's a custom preset
    final preset = await findById(presetId);
    if (preset == null || preset.isBuiltIn) {
      return false; // Cannot delete built-in presets
    }

    final result = await delete(presetId);
    return result > 0;
  }

  /// Update preset (only custom presets can be updated)
  Future<bool> updateCustomPreset(TimerPreset preset) async {
    if (preset.id == null || preset.isBuiltIn) {
      return false; // Cannot update built-in presets
    }

    final result = await update(preset);
    return result > 0;
  }

  /// Create a new custom preset
  Future<TimerPreset?> createCustomPreset({
    required String name,
    required int workDuration,
    required int breakDuration,
    required int totalSessions,
  }) async {
    // Check if name already exists
    if (await presetNameExists(name)) {
      return null;
    }

    final now = DateTime.now();
    final preset = TimerPreset(
      name: name.trim(),
      workDuration: workDuration,
      breakDuration: breakDuration,
      totalSessions: totalSessions,
      isBuiltIn: false,
      createdAt: now,
      updatedAt: now,
    );

    // Validate preset
    if (!preset.isValid) {
      return null;
    }

    final id = await insert(preset);
    return preset.copyWith(id: id);
  }

  /// Duplicate a preset (create a copy with a new name)
  Future<TimerPreset?> duplicatePreset(int presetId, String newName) async {
    final originalPreset = await findById(presetId);
    if (originalPreset == null) {
      return null;
    }

    return await createCustomPreset(
      name: newName,
      workDuration: originalPreset.workDuration,
      breakDuration: originalPreset.breakDuration,
      totalSessions: originalPreset.totalSessions,
    );
  }

  /// Get preset statistics
  Future<Map<String, int>> getPresetStats() async {
    final allPresets = await getAllPresets();
    final customPresets = allPresets.where((p) => !p.isBuiltIn).toList();
    final builtInPresets = allPresets.where((p) => p.isBuiltIn).toList();

    return {
      'total': allPresets.length,
      'custom': customPresets.length,
      'builtIn': builtInPresets.length,
    };
  }

  Future<Database> get _database async => await DatabaseHelper().database;
}
