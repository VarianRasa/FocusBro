import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen_brightness_service.dart';
import 'notification_blocking_service.dart';
import 'social_media_blocking_service.dart';
import '../utils/error_handler.dart';

/// Coordinator service for all focus mode features
class FocusModeService extends ChangeNotifier {
  static final FocusModeService _instance = FocusModeService._internal();
  factory FocusModeService() => _instance;
  FocusModeService._internal();

  // Individual services
  final ScreenBrightnessService _brightnessService = ScreenBrightnessService();
  final NotificationBlockingService _notificationService =
      NotificationBlockingService();
  final SocialMediaBlockingService _socialMediaService =
      SocialMediaBlockingService();

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isFocusModeActive = false;

  // Focus mode settings
  bool _enableScreenDimming = true;
  bool _enableNotificationBlocking = true;
  bool _enableSocialMediaBlocking = false;
  bool _autoEnableOnFocusStart = true;
  bool _showFocusModeIndicator = true;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isFocusModeActive => _isFocusModeActive;
  bool get enableScreenDimming => _enableScreenDimming;
  bool get enableNotificationBlocking => _enableNotificationBlocking;
  bool get enableSocialMediaBlocking => _enableSocialMediaBlocking;
  bool get autoEnableOnFocusStart => _autoEnableOnFocusStart;
  bool get showFocusModeIndicator => _showFocusModeIndicator;

  // Service getters
  ScreenBrightnessService get brightnessService => _brightnessService;
  NotificationBlockingService get notificationService => _notificationService;
  SocialMediaBlockingService get socialMediaService => _socialMediaService;

  /// Initialize the focus mode service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();

      // Initialize individual services
      await _brightnessService.initialize();
      await _notificationService.initialize();
      await _socialMediaService.initialize();

      // Listen to service changes
      _brightnessService.addListener(_onServiceChanged);
      _notificationService.addListener(_onServiceChanged);
      _socialMediaService.addListener(_onServiceChanged);

      _isInitialized = true;
      debugPrint('FocusModeService initialized successfully');
    } catch (e) {
      ErrorHandler.logError('Failed to initialize FocusModeService', e);
    }
  }

  /// Load focus mode settings
  Future<void> _loadSettings() async {
    _enableScreenDimming = _prefs?.getBool('focus_screen_dimming') ?? true;
    _enableNotificationBlocking =
        _prefs?.getBool('focus_notification_blocking') ?? true;
    _enableSocialMediaBlocking =
        _prefs?.getBool('focus_social_media_blocking') ?? false;
    _autoEnableOnFocusStart = _prefs?.getBool('focus_auto_enable') ?? true;
    _showFocusModeIndicator = _prefs?.getBool('focus_show_indicator') ?? true;
  }

  /// Save focus mode settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('focus_screen_dimming', _enableScreenDimming);
    await _prefs?.setBool(
        'focus_notification_blocking', _enableNotificationBlocking);
    await _prefs?.setBool(
        'focus_social_media_blocking', _enableSocialMediaBlocking);
    await _prefs?.setBool('focus_auto_enable', _autoEnableOnFocusStart);
    await _prefs?.setBool('focus_show_indicator', _showFocusModeIndicator);
  }

  /// Handle service state changes
  void _onServiceChanged() {
    notifyListeners();
  }

  /// Enable focus mode with all configured features
  Future<bool> enableFocusMode() async {
    if (!_isInitialized || _isFocusModeActive) return false;

    try {
      final results = <String, bool>{};

      // Enable screen dimming if configured
      if (_enableScreenDimming) {
        results['brightness'] = await _brightnessService.enableDimming();
      }

      // Enable notification blocking if configured
      if (_enableNotificationBlocking) {
        results['notifications'] = await _notificationService.enableBlocking();
      }

      // Enable social media blocking if configured
      if (_enableSocialMediaBlocking) {
        results['socialMedia'] = await _socialMediaService.enableBlocking();
      }

      // Check if at least one feature was successfully enabled
      final anySuccess = results.values.any((success) => success);

      if (anySuccess) {
        _isFocusModeActive = true;
        notifyListeners();

        debugPrint('Focus mode enabled with features: ${results.toString()}');
        return true;
      }

      return false;
    } catch (e) {
      ErrorHandler.logError('Failed to enable focus mode', e);
      return false;
    }
  }

  /// Disable focus mode and restore normal settings
  Future<bool> disableFocusMode() async {
    if (!_isInitialized || !_isFocusModeActive) return false;

    try {
      final results = <String, bool>{};

      // Disable screen dimming
      if (_enableScreenDimming && _brightnessService.isDimmed) {
        results['brightness'] = await _brightnessService.disableDimming();
      }

      // Disable notification blocking
      if (_enableNotificationBlocking && _notificationService.isBlocking) {
        results['notifications'] = await _notificationService.disableBlocking();
      }

      // Disable social media blocking
      if (_enableSocialMediaBlocking && _socialMediaService.isBlocking) {
        results['socialMedia'] = await _socialMediaService.disableBlocking();
      }

      _isFocusModeActive = false;
      notifyListeners();

      debugPrint('Focus mode disabled with results: ${results.toString()}');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to disable focus mode', e);
      return false;
    }
  }

  /// Toggle focus mode on/off
  Future<bool> toggleFocusMode() async {
    if (_isFocusModeActive) {
      return await disableFocusMode();
    } else {
      return await enableFocusMode();
    }
  }

  /// Set screen dimming enabled state
  Future<void> setScreenDimmingEnabled(bool enabled) async {
    _enableScreenDimming = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set notification blocking enabled state
  Future<void> setNotificationBlockingEnabled(bool enabled) async {
    _enableNotificationBlocking = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set social media blocking enabled state
  Future<void> setSocialMediaBlockingEnabled(bool enabled) async {
    _enableSocialMediaBlocking = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set auto-enable on focus start
  Future<void> setAutoEnableOnFocusStart(bool enabled) async {
    _autoEnableOnFocusStart = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set focus mode indicator visibility
  Future<void> setShowFocusModeIndicator(bool enabled) async {
    _showFocusModeIndicator = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Get comprehensive focus mode status
  Map<String, dynamic> getFocusModeStatus() {
    return {
      'isActive': _isFocusModeActive,
      'enableScreenDimming': _enableScreenDimming,
      'enableNotificationBlocking': _enableNotificationBlocking,
      'enableSocialMediaBlocking': _enableSocialMediaBlocking,
      'autoEnableOnFocusStart': _autoEnableOnFocusStart,
      'showFocusModeIndicator': _showFocusModeIndicator,
      'brightness': _brightnessService.getBrightnessStatus(),
      'notifications': _notificationService.getBlockingStatus(),
      'socialMedia': _socialMediaService.getBlockingStatus(),
    };
  }

  /// Get active features list
  List<String> getActiveFeatures() {
    final activeFeatures = <String>[];

    if (_isFocusModeActive) {
      if (_enableScreenDimming && _brightnessService.isDimmed) {
        activeFeatures.add('Screen Dimming');
      }
      if (_enableNotificationBlocking && _notificationService.isBlocking) {
        activeFeatures.add('Notification Blocking');
      }
      if (_enableSocialMediaBlocking && _socialMediaService.isBlocking) {
        activeFeatures.add('Social Media Blocking');
      }
    }

    return activeFeatures;
  }

  /// Get focus mode summary for UI display
  String getFocusModeSummary() {
    if (!_isFocusModeActive) {
      return 'Focus mode is disabled';
    }

    final activeFeatures = getActiveFeatures();
    if (activeFeatures.isEmpty) {
      return 'Focus mode is active (no features enabled)';
    }

    return 'Focus mode is active: ${activeFeatures.join(', ')}';
  }

  /// Check if any focus mode features are available
  Future<bool> areFocusFeaturesAvailable() async {
    final brightnessAvailable =
        await _brightnessService.isBrightnessControlAvailable();
    final notificationAvailable =
        await _notificationService.hasNotificationAccess();

    return brightnessAvailable || notificationAvailable;
  }

  /// Get setup requirements for focus mode features
  Future<Map<String, bool>> getSetupRequirements() async {
    return {
      'brightnessControl':
          await _brightnessService.isBrightnessControlAvailable(),
      'notificationAccess': await _notificationService.hasNotificationAccess(),
      'deviceAppsAccess':
          true, // Device apps package doesn't require special permissions
    };
  }

  /// Open relevant settings for focus mode setup
  Future<void> openFocusModeSettings() async {
    try {
      await _notificationService.openNotificationSettings();
    } catch (e) {
      ErrorHandler.logError('Failed to open focus mode settings', e);
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _brightnessService.removeListener(_onServiceChanged);
    _notificationService.removeListener(_onServiceChanged);
    _socialMediaService.removeListener(_onServiceChanged);
    super.dispose();
  }
}
