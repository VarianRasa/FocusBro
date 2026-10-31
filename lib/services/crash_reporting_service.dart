import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CrashReportingService extends ChangeNotifier {
  static CrashReportingService? _instance;
  static CrashReportingService get instance =>
      _instance ??= CrashReportingService._();

  CrashReportingService._();

  // Private variables
  SharedPreferences? _prefs;
  DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _packageInfo;

  bool _isInitialized = false;
  bool _crashReportingEnabled = false;
  bool _automaticReportingEnabled = false;
  bool _includeDeviceInfoEnabled = true;
  bool _includeAppStateEnabled = true;

  List<Map<String, dynamic>> _crashReports = [];
  List<Map<String, dynamic>> _errorLogs = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get crashReportingEnabled => _crashReportingEnabled;
  bool get automaticReportingEnabled => _automaticReportingEnabled;
  bool get includeDeviceInfoEnabled => _includeDeviceInfoEnabled;
  bool get includeAppStateEnabled => _includeAppStateEnabled;
  int get crashReportsCount => _crashReports.length;
  int get errorLogsCount => _errorLogs.length;
  List<Map<String, dynamic>> get crashReports => List.from(_crashReports);
  List<Map<String, dynamic>> get errorLogs => List.from(_errorLogs);

  /// Initialize the crash reporting service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('CrashReportingService: Starting initialization...');

      _prefs = await SharedPreferences.getInstance();
      _packageInfo = await PackageInfo.fromPlatform();
      await _loadSettings();
      await _loadStoredReports();
      _setupErrorHandling();

      _isInitialized = true;
      debugPrint(
          'CrashReportingService: Initialization completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('CrashReportingService: Initialization failed: $e');
    }
  }

  /// Load crash reporting settings
  Future<void> _loadSettings() async {
    _crashReportingEnabled =
        _prefs?.getBool('crash_reporting_enabled') ?? false;
    _automaticReportingEnabled =
        _prefs?.getBool('automatic_reporting_enabled') ?? false;
    _includeDeviceInfoEnabled =
        _prefs?.getBool('include_device_info_enabled') ?? true;
    _includeAppStateEnabled =
        _prefs?.getBool('include_app_state_enabled') ?? true;
  }

  /// Save crash reporting settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('crash_reporting_enabled', _crashReportingEnabled);
    await _prefs?.setBool(
        'automatic_reporting_enabled', _automaticReportingEnabled);
    await _prefs?.setBool(
        'include_device_info_enabled', _includeDeviceInfoEnabled);
    await _prefs?.setBool('include_app_state_enabled', _includeAppStateEnabled);
  }

  /// Load stored crash reports and error logs
  Future<void> _loadStoredReports() async {
    try {
      final crashReportsJson = _prefs?.getString('crash_reports') ?? '[]';
      _crashReports =
          List<Map<String, dynamic>>.from(jsonDecode(crashReportsJson));

      final errorLogsJson = _prefs?.getString('error_logs') ?? '[]';
      _errorLogs = List<Map<String, dynamic>>.from(jsonDecode(errorLogsJson));

      debugPrint(
          'CrashReportingService: Loaded ${_crashReports.length} crash reports and ${_errorLogs.length} error logs');
    } catch (e) {
      debugPrint('CrashReportingService: Error loading stored reports: $e');
      _crashReports = [];
      _errorLogs = [];
    }
  }

  /// Setup error handling
  void _setupErrorHandling() {
    if (!_crashReportingEnabled) return;

    // Setup Flutter error handling
    FlutterError.onError = (FlutterErrorDetails details) {
      _handleFlutterError(details);
    };

    // Setup platform error handling
    PlatformDispatcher.instance.onError = (error, stack) {
      _handlePlatformError(error, stack);
      return true;
    };

    debugPrint('CrashReportingService: Error handling setup completed');
  }

  /// Handle Flutter errors
  void _handleFlutterError(FlutterErrorDetails details) async {
    if (!_crashReportingEnabled) return;

    try {
      final crashReport = await _createCrashReport(
        error: details.exception,
        stackTrace: details.stack,
        errorType: 'Flutter Error',
        context: details.context?.toString(),
        library: details.library,
      );

      await _storeCrashReport(crashReport);

      if (_automaticReportingEnabled) {
        await _sendCrashReport(crashReport);
      }

      debugPrint('CrashReportingService: Flutter error captured and stored');
    } catch (e) {
      debugPrint('CrashReportingService: Error handling Flutter error: $e');
    }
  }

  /// Handle platform errors
  void _handlePlatformError(Object error, StackTrace stackTrace) async {
    if (!_crashReportingEnabled) return;

    try {
      final crashReport = await _createCrashReport(
        error: error,
        stackTrace: stackTrace,
        errorType: 'Platform Error',
      );

      await _storeCrashReport(crashReport);

      if (_automaticReportingEnabled) {
        await _sendCrashReport(crashReport);
      }

      debugPrint('CrashReportingService: Platform error captured and stored');
    } catch (e) {
      debugPrint('CrashReportingService: Error handling platform error: $e');
    }
  }

  /// Create crash report
  Future<Map<String, dynamic>> _createCrashReport({
    required Object error,
    StackTrace? stackTrace,
    required String errorType,
    String? context,
    String? library,
  }) async {
    final report = <String, dynamic>{
      'id': _generateReportId(),
      'timestamp': DateTime.now().toIso8601String(),
      'error_type': errorType,
      'error_message': error.toString(),
      'stack_trace': stackTrace?.toString(),
      'context': context,
      'library': library,
    };

    if (_includeDeviceInfoEnabled) {
      report['device_info'] = await _getDeviceInfo();
    }

    if (_includeAppStateEnabled) {
      report['app_info'] = await _getAppInfo();
    }

    return report;
  }

  /// Generate unique report ID
  String _generateReportId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Get device information
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final info = <String, dynamic>{};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'platform': 'Android',
          'version': androidInfo.version.release,
          'sdk_int': androidInfo.version.sdkInt,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
          'device': androidInfo.device,
          'hardware': androidInfo.hardware,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'platform': 'iOS',
          'version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'name': iosInfo.name,
          'system_name': iosInfo.systemName,
          'machine': iosInfo.utsname.machine,
        });
      }

      return info;
    } catch (e) {
      debugPrint('CrashReportingService: Error getting device info: $e');
      return {'error': 'Unable to get device info'};
    }
  }

  /// Get app information
  Future<Map<String, dynamic>> _getAppInfo() async {
    try {
      return {
        'app_name': _packageInfo?.appName ?? 'Unknown',
        'package_name': _packageInfo?.packageName ?? 'Unknown',
        'version': _packageInfo?.version ?? 'Unknown',
        'build_number': _packageInfo?.buildNumber ?? 'Unknown',
        'build_signature': _packageInfo?.buildSignature ?? 'Unknown',
        'installer_store': _packageInfo?.installerStore ?? 'Unknown',
        'debug_mode': kDebugMode,
        'profile_mode': kProfileMode,
        'release_mode': kReleaseMode,
      };
    } catch (e) {
      debugPrint('CrashReportingService: Error getting app info: $e');
      return {'error': 'Unable to get app info'};
    }
  }

  /// Store crash report locally
  Future<void> _storeCrashReport(Map<String, dynamic> report) async {
    try {
      _crashReports.add(report);

      // Keep only last 100 crash reports
      if (_crashReports.length > 100) {
        _crashReports.removeRange(0, _crashReports.length - 100);
      }

      await _prefs?.setString('crash_reports', jsonEncode(_crashReports));
      notifyListeners();
    } catch (e) {
      debugPrint('CrashReportingService: Error storing crash report: $e');
    }
  }

  /// Send crash report (placeholder for actual implementation)
  Future<void> _sendCrashReport(Map<String, dynamic> report) async {
    try {
      // In a real implementation, you would send this to your crash reporting backend
      debugPrint(
          'CrashReportingService: Sending crash report: ${report['id']}');

      // Simulate network request
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('CrashReportingService: Crash report sent successfully');
    } catch (e) {
      debugPrint('CrashReportingService: Error sending crash report: $e');
    }
  }

  /// Log custom error
  Future<void> logError({
    required String message,
    Object? error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalData,
  }) async {
    if (!_crashReportingEnabled) return;

    try {
      final errorLog = {
        'id': _generateReportId(),
        'timestamp': DateTime.now().toIso8601String(),
        'message': message,
        'error': error?.toString(),
        'stack_trace': stackTrace?.toString(),
        'additional_data': additionalData ?? {},
      };

      _errorLogs.add(errorLog);

      // Keep only last 500 error logs
      if (_errorLogs.length > 500) {
        _errorLogs.removeRange(0, _errorLogs.length - 500);
      }

      await _prefs?.setString('error_logs', jsonEncode(_errorLogs));
      notifyListeners();

      debugPrint('CrashReportingService: Error logged: $message');
    } catch (e) {
      debugPrint('CrashReportingService: Error logging custom error: $e');
    }
  }

  /// Enable crash reporting
  Future<void> enableCrashReporting() async {
    _crashReportingEnabled = true;
    await _saveSettings();
    _setupErrorHandling();
    notifyListeners();
    debugPrint('CrashReportingService: Crash reporting enabled');
  }

  /// Disable crash reporting
  Future<void> disableCrashReporting() async {
    _crashReportingEnabled = false;
    await _saveSettings();
    _teardownErrorHandling();
    notifyListeners();
    debugPrint('CrashReportingService: Crash reporting disabled');
  }

  /// Enable automatic reporting
  Future<void> enableAutomaticReporting() async {
    _automaticReportingEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable automatic reporting
  Future<void> disableAutomaticReporting() async {
    _automaticReportingEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable device info inclusion
  Future<void> enableDeviceInfoInclusion() async {
    _includeDeviceInfoEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable device info inclusion
  Future<void> disableDeviceInfoInclusion() async {
    _includeDeviceInfoEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable app state inclusion
  Future<void> enableAppStateInclusion() async {
    _includeAppStateEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable app state inclusion
  Future<void> disableAppStateInclusion() async {
    _includeAppStateEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Teardown error handling
  void _teardownErrorHandling() {
    FlutterError.onError = null;
    // Note: PlatformDispatcher.instance.onError cannot be set to null
    debugPrint('CrashReportingService: Error handling teardown completed');
  }

  /// Clear all crash reports
  Future<void> clearCrashReports() async {
    _crashReports.clear();
    await _prefs?.remove('crash_reports');
    notifyListeners();
    debugPrint('CrashReportingService: All crash reports cleared');
  }

  /// Clear all error logs
  Future<void> clearErrorLogs() async {
    _errorLogs.clear();
    await _prefs?.remove('error_logs');
    notifyListeners();
    debugPrint('CrashReportingService: All error logs cleared');
  }

  /// Get crash reporting summary
  CrashReportingSummary getCrashReportingSummary() {
    final now = DateTime.now();
    final last7Days = now.subtract(const Duration(days: 7));
    final last30Days = now.subtract(const Duration(days: 30));

    final recentCrashes = _crashReports.where((report) {
      final reportTime = DateTime.parse(report['timestamp']);
      return reportTime.isAfter(last7Days);
    }).length;

    final monthlyCrashes = _crashReports.where((report) {
      final reportTime = DateTime.parse(report['timestamp']);
      return reportTime.isAfter(last30Days);
    }).length;

    final recentErrors = _errorLogs.where((log) {
      final logTime = DateTime.parse(log['timestamp']);
      return logTime.isAfter(last7Days);
    }).length;

    return CrashReportingSummary(
      totalCrashReports: _crashReports.length,
      totalErrorLogs: _errorLogs.length,
      crashesLast7Days: recentCrashes,
      crashesLast30Days: monthlyCrashes,
      errorsLast7Days: recentErrors,
      lastCrashTime: _crashReports.isNotEmpty
          ? DateTime.parse(_crashReports.last['timestamp'])
          : null,
    );
  }

  /// Export crash data
  Future<String> exportCrashData() async {
    try {
      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'crash_reports': _crashReports,
        'error_logs': _errorLogs,
        'settings': {
          'crash_reporting_enabled': _crashReportingEnabled,
          'automatic_reporting_enabled': _automaticReportingEnabled,
          'include_device_info_enabled': _includeDeviceInfoEnabled,
          'include_app_state_enabled': _includeAppStateEnabled,
        },
      };

      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('CrashReportingService: Error exporting crash data: $e');
      return '{"error": "Failed to export crash data"}';
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('CrashReportingService: Disposing...');
    super.dispose();
  }
}

/// Crash reporting summary data class
class CrashReportingSummary {
  final int totalCrashReports;
  final int totalErrorLogs;
  final int crashesLast7Days;
  final int crashesLast30Days;
  final int errorsLast7Days;
  final DateTime? lastCrashTime;

  CrashReportingSummary({
    required this.totalCrashReports,
    required this.totalErrorLogs,
    required this.crashesLast7Days,
    required this.crashesLast30Days,
    required this.errorsLast7Days,
    this.lastCrashTime,
  });

  bool get hasRecentCrashes => crashesLast7Days > 0;
  bool get hasRecentErrors => errorsLast7Days > 0;
  bool get isStable => crashesLast7Days == 0 && errorsLast7Days == 0;
}
