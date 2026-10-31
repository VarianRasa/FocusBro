import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Audio equalizer service for customizing sound
class AudioEqualizerService extends ChangeNotifier {
  static final AudioEqualizerService _instance =
      AudioEqualizerService._internal();
  factory AudioEqualizerService() => _instance;
  AudioEqualizerService._internal();

  SharedPreferences? _prefs;

  // Equalizer bands (Hz frequencies)
  static const List<int> frequencies = [
    60,
    170,
    310,
    600,
    1000,
    3000,
    6000,
    12000,
    14000,
    16000
  ];

  // Current equalizer settings (-12 to +12 dB)
  List<double> _bandLevels = List.filled(frequencies.length, 0.0);

  // Preset equalizer settings
  final Map<String, List<double>> _presets = {
    'Flat': List.filled(frequencies.length, 0.0),
    'Rock': [-1.0, 2.0, 4.0, 2.0, -1.0, 1.0, 3.0, 4.0, 3.0, 2.0],
    'Pop': [1.0, 3.0, 4.0, 3.0, 0.0, -1.0, 1.0, 2.0, 3.0, 3.0],
    'Jazz': [2.0, 1.0, 0.0, 1.0, 2.0, 2.0, 1.0, 0.0, 1.0, 2.0],
    'Classical': [2.0, 1.0, -1.0, -1.0, 0.0, 1.0, 2.0, 3.0, 3.0, 2.0],
    'Electronic': [3.0, 2.0, 0.0, -1.0, 1.0, 2.0, 1.0, 2.0, 3.0, 4.0],
    'Hip Hop': [4.0, 3.0, 1.0, 2.0, -1.0, -1.0, 1.0, 2.0, 3.0, 3.0],
    'Vocal': [0.0, -1.0, -2.0, -1.0, 1.0, 3.0, 4.0, 3.0, 2.0, 1.0],
    'Bass Boost': [6.0, 4.0, 2.0, 1.0, 0.0, -1.0, 0.0, 1.0, 2.0, 2.0],
    'Treble Boost': [0.0, 0.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 4.0, 3.0],
  };

  String _currentPreset = 'Flat';
  bool _isEnabled = false;

  // Getters
  List<double> get bandLevels => List.from(_bandLevels);
  Map<String, List<double>> get presets => Map.from(_presets);
  String get currentPreset => _currentPreset;
  bool get isEnabled => _isEnabled;

  /// Initialize the equalizer service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();

      if (kDebugMode) {
        print('AudioEqualizerService initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing AudioEqualizerService: $e');
      }
    }
  }

  /// Load equalizer settings from storage
  Future<void> _loadSettings() async {
    try {
      // Load band levels
      final bandLevelsJson = _prefs?.getString('equalizer_band_levels');
      if (bandLevelsJson != null) {
        final List<dynamic> levels = jsonDecode(bandLevelsJson);
        _bandLevels = levels.cast<double>();
      }

      // Load current preset
      _currentPreset = _prefs?.getString('equalizer_current_preset') ?? 'Flat';

      // Load enabled state
      _isEnabled = _prefs?.getBool('equalizer_enabled') ?? false;

      // Load custom presets
      final customPresetsJson = _prefs?.getString('equalizer_custom_presets');
      if (customPresetsJson != null) {
        final Map<String, dynamic> customPresets =
            jsonDecode(customPresetsJson);
        customPresets.forEach((key, value) {
          _presets[key] = (value as List).cast<double>();
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading equalizer settings: $e');
      }
    }
  }

  /// Save equalizer settings to storage
  Future<void> _saveSettings() async {
    try {
      // Save band levels
      await _prefs?.setString('equalizer_band_levels', jsonEncode(_bandLevels));

      // Save current preset
      await _prefs?.setString('equalizer_current_preset', _currentPreset);

      // Save enabled state
      await _prefs?.setBool('equalizer_enabled', _isEnabled);

      // Save custom presets (exclude built-in presets)
      final customPresets = <String, List<double>>{};
      _presets.forEach((key, value) {
        if (!_isBuiltInPreset(key)) {
          customPresets[key] = value;
        }
      });
      await _prefs?.setString(
          'equalizer_custom_presets', jsonEncode(customPresets));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving equalizer settings: $e');
      }
    }
  }

  /// Check if a preset is built-in
  bool _isBuiltInPreset(String presetName) {
    const builtInPresets = [
      'Flat',
      'Rock',
      'Pop',
      'Jazz',
      'Classical',
      'Electronic',
      'Hip Hop',
      'Vocal',
      'Bass Boost',
      'Treble Boost'
    ];
    return builtInPresets.contains(presetName);
  }

  /// Set equalizer band level
  Future<void> setBandLevel(int bandIndex, double level) async {
    if (bandIndex >= 0 && bandIndex < _bandLevels.length) {
      // Clamp level between -12 and +12 dB
      _bandLevels[bandIndex] = level.clamp(-12.0, 12.0);
      _currentPreset = 'Custom';
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Apply equalizer preset
  Future<void> applyPreset(String presetName) async {
    if (_presets.containsKey(presetName)) {
      _bandLevels = List.from(_presets[presetName]!);
      _currentPreset = presetName;
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Create custom preset
  Future<bool> createCustomPreset(String name, List<double>? levels) async {
    try {
      if (name.trim().isEmpty) return false;

      // Use current levels if none provided
      final presetLevels = levels ?? List.from(_bandLevels);

      // Validate levels
      if (presetLevels.length != frequencies.length) return false;

      // Clamp all levels
      final clampedLevels =
          presetLevels.map((level) => level.clamp(-12.0, 12.0)).toList();

      _presets[name] = clampedLevels;
      await _saveSettings();
      notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating custom preset: $e');
      }
      return false;
    }
  }

  /// Delete custom preset
  Future<bool> deleteCustomPreset(String name) async {
    try {
      if (_isBuiltInPreset(name)) return false;

      _presets.remove(name);

      // If current preset was deleted, switch to Flat
      if (_currentPreset == name) {
        await applyPreset('Flat');
      } else {
        await _saveSettings();
        notifyListeners();
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting custom preset: $e');
      }
      return false;
    }
  }

  /// Toggle equalizer enabled state
  Future<void> toggleEnabled() async {
    _isEnabled = !_isEnabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set equalizer enabled state
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Reset equalizer to flat
  Future<void> reset() async {
    await applyPreset('Flat');
  }

  /// Get frequency label for display
  String getFrequencyLabel(int index) {
    if (index < 0 || index >= frequencies.length) return '';

    final freq = frequencies[index];
    if (freq < 1000) {
      return '${freq}Hz';
    } else {
      return '${(freq / 1000).toStringAsFixed(freq % 1000 == 0 ? 0 : 1)}kHz';
    }
  }

  /// Get band level in dB string format
  String getBandLevelString(int index) {
    if (index < 0 || index >= _bandLevels.length) return '0dB';

    final level = _bandLevels[index];
    final sign = level >= 0 ? '+' : '';
    return '$sign${level.toStringAsFixed(1)}dB';
  }

  /// Get equalizer curve data for visualization
  List<double> getEqualizerCurve() {
    // Return normalized values for visualization (0.0 to 1.0)
    return _bandLevels.map((level) => (level + 12.0) / 24.0).toList();
  }

  /// Apply equalizer settings to audio player
  /// Note: This would integrate with the actual audio player implementation
  void applyToAudioPlayer() {
    if (!_isEnabled) return;

    // In a real implementation, this would apply the equalizer settings
    // to the audio player using platform-specific audio processing
    if (kDebugMode) {
      print('Applying equalizer settings: $_bandLevels');
    }
  }
}
