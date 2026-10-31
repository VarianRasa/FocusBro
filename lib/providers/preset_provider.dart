import 'package:flutter/foundation.dart';
import '../models/timer_preset.dart';
import '../repositories/timer_preset_repository.dart';

class PresetProvider extends ChangeNotifier {
  final TimerPresetRepository _repository = TimerPresetRepository();

  List<TimerPreset> _presets = [];
  TimerPreset? _activePreset;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<TimerPreset> get presets => _presets;
  List<TimerPreset> get builtInPresets =>
      _presets.where((p) => p.isBuiltIn).toList();
  List<TimerPreset> get customPresets =>
      _presets.where((p) => !p.isBuiltIn).toList();
  TimerPreset? get activePreset => _activePreset;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCustomPresets => customPresets.isNotEmpty;

  /// Initialize the provider and load presets
  Future<void> initialize() async {
    await _setLoading(true);
    try {
      // Initialize built-in presets if they don't exist
      await _repository.initializeBuiltInPresets();

      // Load all presets
      await loadPresets();

      _clearError();
    } catch (e) {
      _setError('Failed to initialize presets: $e');
    } finally {
      await _setLoading(false);
    }
  }

  /// Load all presets from database
  Future<void> loadPresets() async {
    try {
      _presets = await _repository.getAllPresets();
      _activePreset = await _repository.getActivePreset();
      notifyListeners();
    } catch (e) {
      _setError('Failed to load presets: $e');
    }
  }

  /// Create a new custom preset
  Future<bool> createPreset({
    required String name,
    required int workDuration,
    required int breakDuration,
    required int totalSessions,
  }) async {
    await _setLoading(true);
    try {
      // Validate input
      final preset = TimerPreset(
        name: name.trim(),
        workDuration: workDuration,
        breakDuration: breakDuration,
        totalSessions: totalSessions,
        isBuiltIn: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final validationError = preset.validationError;
      if (validationError != null) {
        _setError(validationError);
        return false;
      }

      // Check if name already exists
      if (await _repository.presetNameExists(name.trim())) {
        _setError('A preset with this name already exists');
        return false;
      }

      // Create the preset
      final createdPreset = await _repository.createCustomPreset(
        name: name.trim(),
        workDuration: workDuration,
        breakDuration: breakDuration,
        totalSessions: totalSessions,
      );

      if (createdPreset != null) {
        await loadPresets();
        _clearError();
        return true;
      } else {
        _setError('Failed to create preset');
        return false;
      }
    } catch (e) {
      _setError('Failed to create preset: $e');
      return false;
    } finally {
      await _setLoading(false);
    }
  }

  /// Update an existing custom preset
  Future<bool> updatePreset({
    required int presetId,
    required String name,
    required int workDuration,
    required int breakDuration,
    required int totalSessions,
  }) async {
    await _setLoading(true);
    try {
      // Find the existing preset
      final existingPreset = _presets.firstWhere(
        (p) => p.id == presetId,
        orElse: () => throw Exception('Preset not found'),
      );

      // Check if it's a built-in preset
      if (existingPreset.isBuiltIn) {
        _setError('Cannot edit built-in presets');
        return false;
      }

      // Create updated preset
      final updatedPreset = existingPreset.copyWith(
        name: name.trim(),
        workDuration: workDuration,
        breakDuration: breakDuration,
        totalSessions: totalSessions,
        updatedAt: DateTime.now(),
      );

      final validationError = updatedPreset.validationError;
      if (validationError != null) {
        _setError(validationError);
        return false;
      }

      // Check if name already exists (excluding current preset)
      if (await _repository.presetNameExists(name.trim(),
          excludeId: presetId)) {
        _setError('A preset with this name already exists');
        return false;
      }

      // Update the preset
      final success = await _repository.updateCustomPreset(updatedPreset);
      if (success) {
        await loadPresets();
        _clearError();
        return true;
      } else {
        _setError('Failed to update preset');
        return false;
      }
    } catch (e) {
      _setError('Failed to update preset: $e');
      return false;
    } finally {
      await _setLoading(false);
    }
  }

  /// Delete a custom preset
  Future<bool> deletePreset(int presetId) async {
    await _setLoading(true);
    try {
      // Find the preset
      final preset = _presets.firstWhere(
        (p) => p.id == presetId,
        orElse: () => throw Exception('Preset not found'),
      );

      // Check if it's a built-in preset
      if (preset.isBuiltIn) {
        _setError('Cannot delete built-in presets');
        return false;
      }

      // If this is the active preset, clear it
      if (_activePreset?.id == presetId) {
        await _repository.clearActivePreset();
        _activePreset = null;
      }

      // Delete the preset
      final success = await _repository.deleteCustomPreset(presetId);
      if (success) {
        await loadPresets();
        _clearError();
        return true;
      } else {
        _setError('Failed to delete preset');
        return false;
      }
    } catch (e) {
      _setError('Failed to delete preset: $e');
      return false;
    } finally {
      await _setLoading(false);
    }
  }

  /// Apply a preset (set as active and return its values)
  Future<Map<String, int>?> applyPreset(int presetId) async {
    try {
      // Find the preset
      final preset = _presets.firstWhere(
        (p) => p.id == presetId,
        orElse: () => throw Exception('Preset not found'),
      );

      // Set as active
      await _repository.setActivePreset(presetId);
      _activePreset = preset;
      notifyListeners();

      // Return the preset values
      return {
        'workDuration': preset.workDuration,
        'breakDuration': preset.breakDuration,
        'totalSessions': preset.totalSessions,
      };
    } catch (e) {
      _setError('Failed to apply preset: $e');
      return null;
    }
  }

  /// Clear the active preset
  Future<void> clearActivePreset() async {
    try {
      await _repository.clearActivePreset();
      _activePreset = null;
      notifyListeners();
    } catch (e) {
      _setError('Failed to clear active preset: $e');
    }
  }

  /// Duplicate a preset
  Future<bool> duplicatePreset(int presetId, String newName) async {
    await _setLoading(true);
    try {
      // Check if name already exists
      if (await _repository.presetNameExists(newName.trim())) {
        _setError('A preset with this name already exists');
        return false;
      }

      // Duplicate the preset
      final duplicatedPreset =
          await _repository.duplicatePreset(presetId, newName.trim());
      if (duplicatedPreset != null) {
        await loadPresets();
        _clearError();
        return true;
      } else {
        _setError('Failed to duplicate preset');
        return false;
      }
    } catch (e) {
      _setError('Failed to duplicate preset: $e');
      return false;
    } finally {
      await _setLoading(false);
    }
  }

  /// Search presets by name
  Future<List<TimerPreset>> searchPresets(String query) async {
    try {
      if (query.trim().isEmpty) {
        return _presets;
      }
      return await _repository.searchPresets(query.trim());
    } catch (e) {
      _setError('Failed to search presets: $e');
      return [];
    }
  }

  /// Get preset statistics
  Future<Map<String, int>> getPresetStats() async {
    try {
      return await _repository.getPresetStats();
    } catch (e) {
      _setError('Failed to get preset statistics: $e');
      return {'total': 0, 'custom': 0, 'builtIn': 0};
    }
  }

  // Private helper methods
  Future<void> _setLoading(bool loading) async {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Check if a preset name is valid and available
  Future<String?> validatePresetName(String name, {int? excludeId}) async {
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return 'Preset name cannot be empty';
    }

    if (trimmedName.length > 50) {
      return 'Preset name must be 50 characters or less';
    }

    if (await _repository.presetNameExists(trimmedName, excludeId: excludeId)) {
      return 'A preset with this name already exists';
    }

    return null;
  }
}
