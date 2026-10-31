import 'dart:async';
import 'package:flutter/material.dart';

import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/error_handler.dart';

/// Service for managing screen brightness during focus sessions
class ScreenBrightnessService extends ChangeNotifier {
  static final ScreenBrightnessService _instance =
      ScreenBrightnessService._internal();
  factory ScreenBrightnessService() => _instance;
  ScreenBrightnessService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isDimmed = false;
  double _originalBrightness = 0.5;
  double _dimmedBrightness = 0.2;
  bool _autoDimEnabled = true;
  Timer? _dimTimer;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isDimmed => _isDimmed;
  bool get autoDimEnabled => _autoDimEnabled;
  double get originalBrightness => _originalBrightness;
  double get dimmedBrightness => _dimmedBrightness;

  /// Initialize the screen brightness service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      await _getCurrentBrightness();

      _isInitialized = true;
      debugPrint('ScreenBrightnessService initialized successfully');
    } catch (e) {
      ErrorHandler.logError('Failed to initialize ScreenBrightnessService', e);
    }
  }

  /// Load brightness settings from preferences
  Future<void> _loadSettings() async {
    _autoDimEnabled = _prefs?.getBool('auto_dim_enabled') ?? true;
    _dimmedBrightness = _prefs?.getDouble('dimmed_brightness') ?? 0.2;
    _originalBrightness = _prefs?.getDouble('original_brightness') ?? 0.5;
  }

  /// Save brightness settings to preferences
  Future<void> _saveSettings() async {
    await _prefs?.setBool('auto_dim_enabled', _autoDimEnabled);
    await _prefs?.setDouble('dimmed_brightness', _dimmedBrightness);
    await _prefs?.setDouble('original_brightness', _originalBrightness);
  }

  /// Get current system brightness
  Future<void> _getCurrentBrightness() async {
    try {
      final currentBrightness = await ScreenBrightness().current;
      if (!_isDimmed) {
        _originalBrightness = currentBrightness;
        await _saveSettings();
      }
    } catch (e) {
      ErrorHandler.logError('Failed to get current brightness', e);
      // Use default value if unable to get current brightness
      _originalBrightness = 0.5;
    }
  }

  /// Enable screen dimming for focus mode
  Future<bool> enableDimming() async {
    if (!_isInitialized || _isDimmed) return false;

    try {
      // Store current brightness before dimming
      await _getCurrentBrightness();

      // Apply dimmed brightness
      await ScreenBrightness().setScreenBrightness(_dimmedBrightness);

      _isDimmed = true;
      notifyListeners();

      debugPrint(
          'Screen dimming enabled: ${(_dimmedBrightness * 100).round()}%');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to enable screen dimming', e);
      return false;
    }
  }

  /// Disable screen dimming and restore original brightness
  Future<bool> disableDimming() async {
    if (!_isInitialized || !_isDimmed) return false;

    try {
      // Restore original brightness
      await ScreenBrightness().setScreenBrightness(_originalBrightness);

      _isDimmed = false;
      notifyListeners();

      debugPrint(
          'Screen dimming disabled: ${(_originalBrightness * 100).round()}%');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to disable screen dimming', e);
      return false;
    }
  }

  /// Set custom dimmed brightness level (0.0 to 1.0)
  Future<void> setDimmedBrightness(double brightness) async {
    if (brightness < 0.0 || brightness > 1.0) return;

    _dimmedBrightness = brightness;
    await _saveSettings();

    // Apply immediately if currently dimmed
    if (_isDimmed) {
      try {
        await ScreenBrightness().setScreenBrightness(_dimmedBrightness);
      } catch (e) {
        ErrorHandler.logError('Failed to apply new dimmed brightness', e);
      }
    }

    notifyListeners();
  }

  /// Toggle auto-dim feature
  Future<void> setAutoDimEnabled(bool enabled) async {
    _autoDimEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Start auto-dimming with delay (for focus sessions)
  void startAutoDim({Duration delay = const Duration(seconds: 30)}) {
    if (!_autoDimEnabled || _isDimmed) return;

    _dimTimer?.cancel();
    _dimTimer = Timer(delay, () {
      enableDimming();
    });

    debugPrint('Auto-dim scheduled in ${delay.inSeconds} seconds');
  }

  /// Cancel auto-dimming timer
  void cancelAutoDim() {
    _dimTimer?.cancel();
    _dimTimer = null;
  }

  /// Temporarily brighten screen (for user interaction)
  Future<void> temporaryBrighten(
      {Duration duration = const Duration(seconds: 10)}) async {
    if (!_isDimmed) return;

    try {
      // Temporarily restore brightness
      await ScreenBrightness().setScreenBrightness(_originalBrightness);

      // Schedule return to dimmed state
      Timer(duration, () {
        if (_isDimmed) {
          ScreenBrightness().setScreenBrightness(_dimmedBrightness);
        }
      });

      debugPrint(
          'Temporary brightness boost for ${duration.inSeconds} seconds');
    } catch (e) {
      ErrorHandler.logError('Failed to temporarily brighten screen', e);
    }
  }

  /// Reset brightness to system default
  Future<void> resetToSystemBrightness() async {
    try {
      await ScreenBrightness().resetScreenBrightness();
      _isDimmed = false;
      notifyListeners();
      debugPrint('Screen brightness reset to system default');
    } catch (e) {
      ErrorHandler.logError('Failed to reset screen brightness', e);
    }
  }

  /// Check if brightness control is available
  Future<bool> isBrightnessControlAvailable() async {
    try {
      await ScreenBrightness().current;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get brightness level as percentage string
  String getBrightnessPercentage(double brightness) {
    return '${(brightness * 100).round()}%';
  }

  /// Get current brightness status
  Map<String, dynamic> getBrightnessStatus() {
    return {
      'isDimmed': _isDimmed,
      'autoDimEnabled': _autoDimEnabled,
      'originalBrightness': _originalBrightness,
      'dimmedBrightness': _dimmedBrightness,
      'originalPercentage': getBrightnessPercentage(_originalBrightness),
      'dimmedPercentage': getBrightnessPercentage(_dimmedBrightness),
    };
  }

  /// Dispose resources
  @override
  void dispose() {
    _dimTimer?.cancel();
    super.dispose();
  }
}
