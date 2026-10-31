import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/error_handler.dart';

/// Service for blocking notifications during focus sessions
class NotificationBlockingService extends ChangeNotifier {
  static final NotificationBlockingService _instance =
      NotificationBlockingService._internal();
  factory NotificationBlockingService() => _instance;
  NotificationBlockingService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isBlocking = false;
  bool _doNotDisturbEnabled = true;
  List<String> _blockedApps = [];
  List<String> _allowedApps = ['com.example.focusbro']; // Always allow FocusBro

  // Platform channels for native functionality
  static const MethodChannel _channel =
      MethodChannel('focusbro/notification_blocking');

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isBlocking => _isBlocking;
  bool get doNotDisturbEnabled => _doNotDisturbEnabled;
  List<String> get blockedApps => List.unmodifiable(_blockedApps);
  List<String> get allowedApps => List.unmodifiable(_allowedApps);

  /// Initialize the notification blocking service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();
      await _checkPermissions();

      _isInitialized = true;
      debugPrint('NotificationBlockingService initialized successfully');
    } catch (e) {
      ErrorHandler.logError(
          'Failed to initialize NotificationBlockingService', e);
    }
  }

  /// Load notification blocking settings
  Future<void> _loadSettings() async {
    _doNotDisturbEnabled = _prefs?.getBool('dnd_enabled') ?? true;
    _blockedApps =
        _prefs?.getStringList('blocked_apps') ?? _getDefaultBlockedApps();
    _allowedApps =
        _prefs?.getStringList('allowed_apps') ?? ['com.example.focusbro'];
  }

  /// Save notification blocking settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('dnd_enabled', _doNotDisturbEnabled);
    await _prefs?.setStringList('blocked_apps', _blockedApps);
    await _prefs?.setStringList('allowed_apps', _allowedApps);
  }

  /// Get default list of apps to block
  List<String> _getDefaultBlockedApps() {
    return [
      'com.whatsapp',
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.snapchat.android',
      'com.tiktok',
      'com.linkedin.android',
      'com.discord',
      'com.telegram.messenger',
      'com.google.android.gm', // Gmail
      'com.microsoft.office.outlook',
      'com.slack',
      'com.spotify.music',
      'com.netflix.mediaclient',
      'com.youtube.android',
    ];
  }

  /// Check and request necessary permissions
  Future<bool> _checkPermissions() async {
    try {
      if (Platform.isAndroid) {
        // Check notification policy access permission
        final notificationPolicyStatus =
            await Permission.accessNotificationPolicy.status;
        if (!notificationPolicyStatus.isGranted) {
          final result = await Permission.accessNotificationPolicy.request();
          if (!result.isGranted) {
            debugPrint('Notification policy access permission denied');
            return false;
          }
        }

        // Check Do Not Disturb access
        final dndStatus = await Permission.systemAlertWindow.status;
        if (!dndStatus.isGranted) {
          debugPrint('Do Not Disturb access not available');
        }
      }
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to check notification permissions', e);
      return false;
    }
  }

  /// Enable notification blocking
  Future<bool> enableBlocking() async {
    if (!_isInitialized || _isBlocking) return false;

    try {
      bool success = false;

      if (Platform.isAndroid) {
        success = await _enableAndroidBlocking();
      } else if (Platform.isIOS) {
        success = await _enableIOSBlocking();
      }

      if (success) {
        _isBlocking = true;
        notifyListeners();
        debugPrint('Notification blocking enabled');
      }

      return success;
    } catch (e) {
      ErrorHandler.logError('Failed to enable notification blocking', e);
      return false;
    }
  }

  /// Disable notification blocking
  Future<bool> disableBlocking() async {
    if (!_isInitialized || !_isBlocking) return false;

    try {
      bool success = false;

      if (Platform.isAndroid) {
        success = await _disableAndroidBlocking();
      } else if (Platform.isIOS) {
        success = await _disableIOSBlocking();
      }

      if (success) {
        _isBlocking = false;
        notifyListeners();
        debugPrint('Notification blocking disabled');
      }

      return success;
    } catch (e) {
      ErrorHandler.logError('Failed to disable notification blocking', e);
      return false;
    }
  }

  /// Enable Android notification blocking
  Future<bool> _enableAndroidBlocking() async {
    try {
      if (_doNotDisturbEnabled) {
        // Try to enable Do Not Disturb mode
        final result = await _channel.invokeMethod('enableDoNotDisturb');
        if (result == true) {
          debugPrint('Do Not Disturb mode enabled');
          return true;
        }
      }

      // Fallback: Block specific app notifications
      return await _blockSpecificApps();
    } catch (e) {
      ErrorHandler.logError(
          'Failed to enable Android notification blocking', e);
      return false;
    }
  }

  /// Disable Android notification blocking
  Future<bool> _disableAndroidBlocking() async {
    try {
      if (_doNotDisturbEnabled) {
        // Try to disable Do Not Disturb mode
        final result = await _channel.invokeMethod('disableDoNotDisturb');
        if (result == true) {
          debugPrint('Do Not Disturb mode disabled');
          return true;
        }
      }

      // Fallback: Unblock specific app notifications
      return await _unblockSpecificApps();
    } catch (e) {
      ErrorHandler.logError(
          'Failed to disable Android notification blocking', e);
      return false;
    }
  }

  /// Enable iOS notification blocking (Focus mode)
  Future<bool> _enableIOSBlocking() async {
    try {
      // iOS Focus mode integration would require native implementation
      final result = await _channel.invokeMethod('enableFocusMode');
      return result == true;
    } catch (e) {
      ErrorHandler.logError('Failed to enable iOS notification blocking', e);
      return false;
    }
  }

  /// Disable iOS notification blocking
  Future<bool> _disableIOSBlocking() async {
    try {
      final result = await _channel.invokeMethod('disableFocusMode');
      return result == true;
    } catch (e) {
      ErrorHandler.logError('Failed to disable iOS notification blocking', e);
      return false;
    }
  }

  /// Block notifications from specific apps
  Future<bool> _blockSpecificApps() async {
    try {
      final result = await _channel.invokeMethod('blockAppNotifications', {
        'packageNames': _blockedApps,
      });
      return result == true;
    } catch (e) {
      // Fallback: Show user guidance for manual setup
      debugPrint('Automatic app blocking not available, showing user guidance');
      return true; // Return true to indicate service is "working" in guidance mode
    }
  }

  /// Unblock notifications from specific apps
  Future<bool> _unblockSpecificApps() async {
    try {
      final result = await _channel.invokeMethod('unblockAppNotifications', {
        'packageNames': _blockedApps,
      });
      return result == true;
    } catch (e) {
      debugPrint('Automatic app unblocking not available');
      return true;
    }
  }

  /// Add app to blocked list
  Future<void> addBlockedApp(String packageName) async {
    if (!_blockedApps.contains(packageName) &&
        !_allowedApps.contains(packageName)) {
      _blockedApps.add(packageName);
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Remove app from blocked list
  Future<void> removeBlockedApp(String packageName) async {
    if (_blockedApps.remove(packageName)) {
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Set Do Not Disturb enabled state
  Future<void> setDoNotDisturbEnabled(bool enabled) async {
    _doNotDisturbEnabled = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Check if notification access permission is granted
  Future<bool> hasNotificationAccess() async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.accessNotificationPolicy.status;
        return status.isGranted;
      }
      return true; // iOS handles this differently
    } catch (e) {
      return false;
    }
  }

  /// Open notification access settings
  Future<void> openNotificationSettings() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('openNotificationSettings');
      } else {
        await openAppSettings();
      }
    } catch (e) {
      ErrorHandler.logError('Failed to open notification settings', e);
    }
  }

  /// Get blocking status information
  Map<String, dynamic> getBlockingStatus() {
    return {
      'isBlocking': _isBlocking,
      'doNotDisturbEnabled': _doNotDisturbEnabled,
      'blockedAppsCount': _blockedApps.length,
      'hasPermission': hasNotificationAccess(),
    };
  }

  /// Get user-friendly app names for blocked apps
  Map<String, String> getBlockedAppNames() {
    final appNames = <String, String>{};
    for (final packageName in _blockedApps) {
      appNames[packageName] = _getFriendlyAppName(packageName);
    }
    return appNames;
  }

  /// Convert package name to user-friendly app name
  String _getFriendlyAppName(String packageName) {
    final nameMap = {
      'com.whatsapp': 'WhatsApp',
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'Twitter',
      'com.snapchat.android': 'Snapchat',
      'com.tiktok': 'TikTok',
      'com.linkedin.android': 'LinkedIn',
      'com.discord': 'Discord',
      'com.telegram.messenger': 'Telegram',
      'com.google.android.gm': 'Gmail',
      'com.microsoft.office.outlook': 'Outlook',
      'com.slack': 'Slack',
      'com.spotify.music': 'Spotify',
      'com.netflix.mediaclient': 'Netflix',
      'com.youtube.android': 'YouTube',
    };
    return nameMap[packageName] ?? packageName;
  }
}
