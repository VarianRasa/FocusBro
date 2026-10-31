import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_handler.dart';

/// Service for blocking social media apps and websites during focus sessions
class SocialMediaBlockingService extends ChangeNotifier {
  static final SocialMediaBlockingService _instance =
      SocialMediaBlockingService._internal();
  factory SocialMediaBlockingService() => _instance;
  SocialMediaBlockingService._internal();

  SharedPreferences? _prefs;
  bool _isInitialized = false;
  bool _isBlocking = false;
  bool _blockApps = true;
  bool _blockWebsites = true;
  bool _showBlockingOverlay = true;
  List<String> _blockedSocialApps = [];
  List<String> _blockedWebsites = [];
  Timer? _monitoringTimer;

  // Platform channel for native app monitoring
  static const MethodChannel _channel = MethodChannel('focusbro/app_blocking');

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isBlocking => _isBlocking;
  bool get blockApps => _blockApps;
  bool get blockWebsites => _blockWebsites;
  bool get showBlockingOverlay => _showBlockingOverlay;
  List<String> get blockedSocialApps => List.unmodifiable(_blockedSocialApps);
  List<String> get blockedWebsites => List.unmodifiable(_blockedWebsites);

  /// Initialize the social media blocking service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSettings();

      _isInitialized = true;
      debugPrint('SocialMediaBlockingService initialized successfully');
    } catch (e) {
      ErrorHandler.logError(
          'Failed to initialize SocialMediaBlockingService', e);
    }
  }

  /// Load social media blocking settings
  Future<void> _loadSettings() async {
    _blockApps = _prefs?.getBool('block_social_apps') ?? true;
    _blockWebsites = _prefs?.getBool('block_social_websites') ?? true;
    _showBlockingOverlay = _prefs?.getBool('show_blocking_overlay') ?? true;
    _blockedSocialApps =
        _prefs?.getStringList('blocked_social_apps') ?? _getDefaultSocialApps();
    _blockedWebsites = _prefs?.getStringList('blocked_websites') ??
        _getDefaultBlockedWebsites();
  }

  /// Save social media blocking settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('block_social_apps', _blockApps);
    await _prefs?.setBool('block_social_websites', _blockWebsites);
    await _prefs?.setBool('show_blocking_overlay', _showBlockingOverlay);
    await _prefs?.setStringList('blocked_social_apps', _blockedSocialApps);
    await _prefs?.setStringList('blocked_websites', _blockedWebsites);
  }

  /// Get default list of social media apps to block
  List<String> _getDefaultSocialApps() {
    return [
      'com.instagram.android',
      'com.facebook.katana',
      'com.twitter.android',
      'com.snapchat.android',
      'com.tiktok',
      'com.linkedin.android',
      'com.discord',
      'com.reddit.frontpage',
      'com.pinterest',
      'com.tumblr',
      'com.zhiliaoapp.musically', // TikTok alternative package
      'com.facebook.orca', // Facebook Messenger
      'com.whatsapp', // WhatsApp (social aspect)
      'com.telegram.messenger',
      'com.viber.voip',
    ];
  }

  /// Get default list of websites to block
  List<String> _getDefaultBlockedWebsites() {
    return [
      'facebook.com',
      'instagram.com',
      'twitter.com',
      'x.com',
      'snapchat.com',
      'tiktok.com',
      'linkedin.com',
      'discord.com',
      'reddit.com',
      'pinterest.com',
      'tumblr.com',
      'youtube.com',
      'twitch.tv',
      'netflix.com',
      'hulu.com',
      'disneyplus.com',
    ];
  }

  /// Enable social media blocking
  Future<bool> enableBlocking() async {
    if (!_isInitialized || _isBlocking) return false;

    try {
      bool success = true;

      if (_blockApps) {
        success &= await _enableAppBlocking();
      }

      if (_blockWebsites) {
        success &= await _enableWebsiteBlocking();
      }

      if (success) {
        _isBlocking = true;
        _startMonitoring();
        notifyListeners();
        debugPrint('Social media blocking enabled');
      }

      return success;
    } catch (e) {
      ErrorHandler.logError('Failed to enable social media blocking', e);
      return false;
    }
  }

  /// Disable social media blocking
  Future<bool> disableBlocking() async {
    if (!_isInitialized || !_isBlocking) return false;

    try {
      _stopMonitoring();

      bool success = true;

      if (_blockApps) {
        success &= await _disableAppBlocking();
      }

      if (_blockWebsites) {
        success &= await _disableWebsiteBlocking();
      }

      if (success) {
        _isBlocking = false;
        notifyListeners();
        debugPrint('Social media blocking disabled');
      }

      return success;
    } catch (e) {
      ErrorHandler.logError('Failed to disable social media blocking', e);
      return false;
    }
  }

  /// Enable app blocking (limited implementation due to Flutter constraints)
  Future<bool> _enableAppBlocking() async {
    try {
      if (Platform.isAndroid) {
        // Try to use native implementation for app monitoring
        final result = await _channel.invokeMethod('enableAppBlocking', {
          'packageNames': _blockedSocialApps,
          'showOverlay': _showBlockingOverlay,
        });

        if (result == true) {
          debugPrint('Native app blocking enabled');
          return true;
        }
      }

      // Fallback: Monitor app usage and show warnings
      debugPrint('Using fallback app monitoring mode');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to enable app blocking', e);
      return true; // Return true for fallback mode
    }
  }

  /// Disable app blocking
  Future<bool> _disableAppBlocking() async {
    try {
      if (Platform.isAndroid) {
        final result = await _channel.invokeMethod('disableAppBlocking');
        if (result == true) {
          debugPrint('Native app blocking disabled');
          return true;
        }
      }
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to disable app blocking', e);
      return true;
    }
  }

  /// Enable website blocking (guidance mode)
  Future<bool> _enableWebsiteBlocking() async {
    try {
      // Website blocking in Flutter is limited - we can provide guidance
      debugPrint('Website blocking guidance mode enabled');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to enable website blocking', e);
      return false;
    }
  }

  /// Disable website blocking
  Future<bool> _disableWebsiteBlocking() async {
    try {
      debugPrint('Website blocking guidance mode disabled');
      return true;
    } catch (e) {
      ErrorHandler.logError('Failed to disable website blocking', e);
      return false;
    }
  }

  /// Start monitoring for blocked apps
  void _startMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkRunningApps();
    });
  }

  /// Stop monitoring
  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  /// Check if any blocked apps are running
  Future<void> _checkRunningApps() async {
    if (!_isBlocking || !_blockApps) return;

    try {
      // Use platform channel to check running apps
      final result = await _channel.invokeMethod('getRunningApps');
      if (result is List) {
        final runningApps = result.cast<String>();

        // Check if any blocked apps are running
        for (final packageName in runningApps) {
          if (_blockedSocialApps.contains(packageName)) {
            debugPrint('Blocked app detected: $packageName');
          }
        }
      }
    } catch (e) {
      // Silently handle errors in monitoring
    }
  }

  /// Check if a URL should be blocked
  bool isWebsiteBlocked(String url) {
    if (!_isBlocking || !_blockWebsites) return false;

    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final domain = uri.host.toLowerCase();

    return _blockedWebsites.any((blockedSite) =>
        domain.contains(blockedSite.toLowerCase()) ||
        blockedSite.toLowerCase().contains(domain));
  }

  /// Get blocking message for a website
  String getWebsiteBlockingMessage(String url) {
    return 'This website is blocked during focus sessions.\n\n'
        'Focus on your current task and return to browsing after your session ends.\n\n'
        'Stay focused! 🎯';
  }

  /// Add social media app to blocked list
  Future<void> addBlockedApp(String packageName) async {
    if (!_blockedSocialApps.contains(packageName)) {
      _blockedSocialApps.add(packageName);
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Remove social media app from blocked list
  Future<void> removeBlockedApp(String packageName) async {
    if (_blockedSocialApps.remove(packageName)) {
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Add website to blocked list
  Future<void> addBlockedWebsite(String website) async {
    if (!_blockedWebsites.contains(website)) {
      _blockedWebsites.add(website);
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Remove website from blocked list
  Future<void> removeBlockedWebsite(String website) async {
    if (_blockedWebsites.remove(website)) {
      await _saveSettings();
      notifyListeners();
    }
  }

  /// Set app blocking enabled state
  Future<void> setAppBlockingEnabled(bool enabled) async {
    _blockApps = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set website blocking enabled state
  Future<void> setWebsiteBlockingEnabled(bool enabled) async {
    _blockWebsites = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Set overlay display enabled state
  Future<void> setOverlayEnabled(bool enabled) async {
    _showBlockingOverlay = enabled;
    await _saveSettings();
    notifyListeners();
  }

  /// Get installed social media apps
  Future<List<String>> getInstalledSocialApps() async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      if (result is List) {
        final installedApps = result.cast<String>();

        return installedApps
            .where((packageName) => _blockedSocialApps.contains(packageName))
            .toList();
      }
      return [];
    } catch (e) {
      ErrorHandler.logError('Failed to get installed social apps', e);
      return [];
    }
  }

  /// Get blocking status information
  Map<String, dynamic> getBlockingStatus() {
    return {
      'isBlocking': _isBlocking,
      'blockApps': _blockApps,
      'blockWebsites': _blockWebsites,
      'blockedAppsCount': _blockedSocialApps.length,
      'blockedWebsitesCount': _blockedWebsites.length,
      'showOverlay': _showBlockingOverlay,
    };
  }

  /// Get user-friendly app names for blocked social apps
  Map<String, String> getBlockedAppNames() {
    final appNames = <String, String>{};
    for (final packageName in _blockedSocialApps) {
      appNames[packageName] = _getFriendlyAppName(packageName);
    }
    return appNames;
  }

  /// Convert package name to user-friendly app name
  String _getFriendlyAppName(String packageName) {
    final nameMap = {
      'com.instagram.android': 'Instagram',
      'com.facebook.katana': 'Facebook',
      'com.twitter.android': 'Twitter',
      'com.snapchat.android': 'Snapchat',
      'com.tiktok': 'TikTok',
      'com.linkedin.android': 'LinkedIn',
      'com.discord': 'Discord',
      'com.reddit.frontpage': 'Reddit',
      'com.pinterest': 'Pinterest',
      'com.tumblr': 'Tumblr',
      'com.zhiliaoapp.musically': 'TikTok',
      'com.facebook.orca': 'Messenger',
      'com.whatsapp': 'WhatsApp',
      'com.telegram.messenger': 'Telegram',
      'com.viber.voip': 'Viber',
    };
    return nameMap[packageName] ?? packageName;
  }

  /// Dispose resources
  @override
  void dispose() {
    _stopMonitoring();
    super.dispose();
  }
}
