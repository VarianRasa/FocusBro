import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_helper.dart'; // Import DatabaseHelper

class AppLockService extends ChangeNotifier {
  static AppLockService? _instance;
  static AppLockService get instance => _instance ??= AppLockService._();

  AppLockService._();

  // Private variables
  DatabaseHelper _dbHelper = DatabaseHelper(); // Use DatabaseHelper
  // SharedPreferences? _prefs; // Remove SharedPreferences
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isInitialized = false;
  bool _isAppLockEnabled = false;
  String _lockMethod = 'pin'; // 'pin' or 'biometric'
  String? _hashedPin;
  int? _pinLength; // New variable to store PIN length
  bool _biometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _isLocked = false;
  DateTime? _lastUnlockTime;
  int _lockTimeoutMinutes = 5; // Auto-lock after 5 minutes

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isAppLockEnabled => _isAppLockEnabled;
  String get lockMethod => _lockMethod;
  bool get biometricAvailable => _biometricAvailable;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  bool get isLocked => _isLocked;
  int get lockTimeoutMinutes => _lockTimeoutMinutes;
  bool get hasPinSet => _hashedPin != null;
  int get pinLength =>
      _pinLength ?? 6; // Default to 6 if not set, or max allowed

  /// Initialize the app lock service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('AppLockService: Starting initialization...');

      await _dbHelper.database;
      await _migrateFromSharedPreferences();
      await _loadSettings();
      await _checkBiometricAvailability();

      // Temporarily force disable app lock
      _isAppLockEnabled = false;
      _isLocked = false;
      await _saveSettings();

      _isInitialized = true;
      debugPrint('AppLockService: Initialization completed successfully');
      debugPrint('AppLockService: App lock temporarily disabled');

      // Check if app should be locked on startup
      if (_isAppLockEnabled) {
        _checkAutoLock();
      }
    } catch (e) {
      debugPrint('AppLockService: Initialization failed: $e');
    }
  }

  /// Migration from SharedPreferences to SQFlite (one-time)
  Future<void> _migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final bool? legacyAppLockEnabled = prefs.getBool('app_lock_enabled');

    if (legacyAppLockEnabled != null) {
      debugPrint(
          'AppLockService: Migrating legacy SharedPreferences app lock settings...');

      // Check if data already exists in sqflite
      final List<Map<String, dynamic>> existingSettings =
          await _dbHelper.database.then((db) => db.query(
                'app_lock_settings',
                where: 'id = ?',
                whereArgs: [1],
              ));

      if (existingSettings.isEmpty) {
        // Only migrate if no settings exist in sqflite
        _isAppLockEnabled = legacyAppLockEnabled;
        _lockMethod = prefs.getString('lock_method') ?? 'pin';
        _hashedPin = prefs.getString('hashed_pin');
        _pinLength = prefs.getInt('pin_length');
        _lockTimeoutMinutes = prefs.getInt('lock_timeout_minutes') ?? 5;
        final lastUnlockString = prefs.getString('last_unlock_time');
        _lastUnlockTime = lastUnlockString != null
            ? DateTime.tryParse(lastUnlockString)
            : null;

        // Save to sqflite
        await _saveSettings();

        // Clear from SharedPreferences to prevent re-migration
        await prefs.remove('app_lock_enabled');
        await prefs.remove('lock_method');
        await prefs.remove('hashed_pin');
        await prefs.remove('pin_length');
        await prefs.remove('lock_timeout_minutes');
        await prefs.remove('last_unlock_time');

        debugPrint(
            'AppLockService: Legacy settings migrated and cleared from SharedPreferences.');
      } else {
        debugPrint(
            'AppLockService: App lock settings already exist in SQFlite, skipping migration.');
      }
    }
  }

  /// Load settings from SQFlite
  Future<void> _loadSettings() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps =
        await db.query('app_lock_settings', where: 'id = ?', whereArgs: [1]);

    if (maps.isNotEmpty) {
      final settings = maps.first;
      _isAppLockEnabled = settings['is_app_lock_enabled'] == 1;
      _lockMethod = settings['lock_method'];
      _hashedPin = settings['hashed_pin'];
      _pinLength = settings['pin_length'];
      _lockTimeoutMinutes = settings['lock_timeout_minutes'];
      final lastUnlockString = settings['last_unlock_time'];
      _lastUnlockTime =
          lastUnlockString != null ? DateTime.tryParse(lastUnlockString) : null;
    } else {
      // Default values if no settings found (should not happen if default insert works)
      _isAppLockEnabled = false;
      _lockMethod = 'pin';
      _hashedPin = null;
      _pinLength = null;
      _lockTimeoutMinutes = 5;
      _lastUnlockTime = null;
    }
    debugPrint(
        'AppLockService: _loadSettings - loaded _hashedPin: $_hashedPin, _pinLength: $_pinLength, isAppLockEnabled: $_isAppLockEnabled');
  }

  /// Save settings to SQFlite
  Future<void> _saveSettings() async {
    final db = await _dbHelper.database;
    final Map<String, dynamic> settingsMap = {
      'id': 1, // Always update the single settings row
      'is_app_lock_enabled': _isAppLockEnabled ? 1 : 0,
      'lock_method': _lockMethod,
      'hashed_pin': _hashedPin,
      'pin_length': _pinLength,
      'lock_timeout_minutes': _lockTimeoutMinutes,
      'last_unlock_time': _lastUnlockTime?.toIso8601String(),
    };

    await db.update(
      'app_lock_settings',
      settingsMap,
      where: 'id = ?',
      whereArgs: [1],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    debugPrint(
        'AppLockService: _saveSettings - saved _hashedPin: $_hashedPin, _pinLength: $_pinLength, isAppLockEnabled: $_isAppLockEnabled');
  }

  /// Check biometric availability
  Future<void> _checkBiometricAvailability() async {
    try {
      _biometricAvailable = await _localAuth.canCheckBiometrics;
      if (_biometricAvailable) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        debugPrint('AppLockService: Biometric available: $_biometricAvailable');
        debugPrint(
            'AppLockService: Available biometrics: $_availableBiometrics');
      } else {
        debugPrint('AppLockService: No biometrics available on this device');
      }
    } catch (e) {
      debugPrint('AppLockService: Error checking biometric availability: $e');
      _biometricAvailable = false;
      _availableBiometrics = [];
    }
  }

  /// Enable app lock
  Future<bool> enableAppLock(String method) async {
    try {
      if (method == 'biometric' && !_biometricAvailable) {
        return false;
      }

      _isAppLockEnabled = true;
      _lockMethod = method;
      await _saveSettings();

      notifyListeners();
      debugPrint('AppLockService: App lock enabled with method: $method');
      return true;
    } catch (e) {
      debugPrint('AppLockService: Error enabling app lock: $e');
      return false;
    }
  }

  /// Disable app lock
  Future<bool> disableAppLock() async {
    try {
      _isAppLockEnabled = false;
      _isLocked = false;
      _hashedPin = null;
      _pinLength = null; // Clear PIN length
      _lastUnlockTime = null;

      // Update the database to reflect disabled state and clear sensitive data
      final db = await _dbHelper.database;
      await db.update(
        'app_lock_settings',
        {
          'is_app_lock_enabled': 0,
          'hashed_pin': null,
          'pin_length': null,
          'last_unlock_time': null,
        },
        where: 'id = ?',
        whereArgs: [1],
      );

      // Removed SharedPreferences removal calls as settings are now in SQFlite

      notifyListeners();
      debugPrint('AppLockService: App lock disabled');
      return true;
    } catch (e) {
      debugPrint('AppLockService: Error disabling app lock: $e');
      return false;
    }
  }

  /// Set PIN for app lock
  Future<bool> setPIN(String pin) async {
    try {
      if (pin.length < 4 || pin.length > 6) {
        debugPrint(
            'AppLockService: setPIN - PIN length invalid: ${pin.length}');
        return false;
      }

      // Hash the PIN for security
      final bytes = utf8.encode(pin);
      final digest = sha256.convert(bytes);
      _hashedPin = digest.toString();
      _pinLength = pin.length; // Store PIN length
      debugPrint(
          'AppLockService: setPIN - Hashed PIN: $_hashedPin, PIN Length: $_pinLength');

      // Save to database
      await _saveSettings();

      notifyListeners();

      debugPrint('AppLockService: PIN set successfully');
      return true;
    } catch (e) {
      debugPrint('AppLockService: Error setting PIN: $e');
      return false;
    }
  }

  /// Verify PIN
  bool verifyPIN(String pin) {
    debugPrint('AppLockService: verifyPIN - Input PIN: $pin');
    debugPrint('AppLockService: verifyPIN - Stored Hashed PIN: $_hashedPin');
    if (_hashedPin == null) {
      debugPrint('AppLockService: verifyPIN - _hashedPin is null');
      return false;
    }

    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    debugPrint(
        'AppLockService: verifyPIN - Input Hashed PIN: ${digest.toString()}');
    return digest.toString() == _hashedPin;
  }

  /// Authenticate with biometric
  Future<bool> authenticateWithBiometric() async {
    try {
      if (!_biometricAvailable) {
        debugPrint('AppLockService: Biometric authentication not available');
        return false;
      }

      // Check if device has biometrics enrolled
      final canAuthenticate = await _localAuth.canCheckBiometrics;
      if (!canAuthenticate) {
        debugPrint('AppLockService: No biometrics enrolled on this device');
        return false;
      }

      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to unlock FocusBro',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (isAuthenticated) {
        debugPrint('AppLockService: Biometric authentication successful');
        await _onSuccessfulUnlock();
      } else {
        debugPrint('AppLockService: Biometric authentication failed');
      }

      return isAuthenticated;
    } catch (e) {
      debugPrint('AppLockService: Biometric authentication error: $e');
      return false;
    }
  }

  /// Unlock app with PIN
  Future<bool> unlockWithPIN(String pin) async {
    if (verifyPIN(pin)) {
      await _onSuccessfulUnlock();
      return true;
    }
    return false;
  }

  /// Handle successful unlock
  Future<void> _onSuccessfulUnlock() async {
    _isLocked = false;
    _lastUnlockTime = DateTime.now();
    await _saveSettings();
    notifyListeners();
    debugPrint('AppLockService: App unlocked successfully');
  }

  /// Lock the app
  void lockApp() {
    if (_isAppLockEnabled) {
      _isLocked = true;
      notifyListeners();
      debugPrint('AppLockService: App locked');
    }
  }

  /// Check if app should be auto-locked
  void _checkAutoLock() {
    if (!_isAppLockEnabled) return;

    if (_lastUnlockTime == null) {
      _isLocked = true;
      return;
    }

    final timeSinceUnlock = DateTime.now().difference(_lastUnlockTime!);
    if (timeSinceUnlock.inMinutes >= _lockTimeoutMinutes) {
      _isLocked = true;
    }
  }

  /// Set lock timeout
  Future<void> setLockTimeout(int minutes) async {
    _lockTimeoutMinutes = minutes;
    await _saveSettings();
    notifyListeners();
  }

  /// Check if app should be locked (call this on app resume)
  void checkLockStatus() {
    if (_isAppLockEnabled) {
      _checkAutoLock();
      notifyListeners();
    }
  }

  /// Get biometric type string
  String getBiometricTypeString() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (_availableBiometrics.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (_availableBiometrics.contains(BiometricType.strong)) {
      return 'Strong Biometric';
    } else if (_availableBiometrics.contains(BiometricType.weak)) {
      return 'Weak Biometric';
    } else {
      return 'Biometric';
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('AppLockService: Disposing...');
    super.dispose();
  }
}

/// App lock authentication result
class AppLockResult {
  final bool success;
  final String? error;
  final String? method;

  AppLockResult._({
    required this.success,
    this.error,
    this.method,
  });

  factory AppLockResult.success(String method) {
    return AppLockResult._(success: true, method: method);
  }

  factory AppLockResult.failure(String error) {
    return AppLockResult._(success: false, error: error);
  }
}
