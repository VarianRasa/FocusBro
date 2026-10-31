import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DataCollectionService extends ChangeNotifier {
  static DataCollectionService? _instance;
  static DataCollectionService get instance =>
      _instance ??= DataCollectionService._();

  DataCollectionService._();

  // Private variables
  SharedPreferences? _prefs;
  DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  PackageInfo? _packageInfo;

  bool _isInitialized = false;
  bool _dataCollectionEnabled = false;
  bool _personalDataCollectionEnabled = false;
  bool _usagePatternsCollectionEnabled = false;
  bool _performanceDataCollectionEnabled = false;
  bool _diagnosticDataCollectionEnabled = false;
  bool _locationDataCollectionEnabled = false;
  bool _contactsDataCollectionEnabled = false;

  Map<String, dynamic> _collectedData = {};
  List<String> _dataCategories = [];

  // Getters
  bool get isInitialized => _isInitialized;
  bool get dataCollectionEnabled => _dataCollectionEnabled;
  bool get personalDataCollectionEnabled => _personalDataCollectionEnabled;
  bool get usagePatternsCollectionEnabled => _usagePatternsCollectionEnabled;
  bool get performanceDataCollectionEnabled =>
      _performanceDataCollectionEnabled;
  bool get diagnosticDataCollectionEnabled => _diagnosticDataCollectionEnabled;
  bool get locationDataCollectionEnabled => _locationDataCollectionEnabled;
  bool get contactsDataCollectionEnabled => _contactsDataCollectionEnabled;
  Map<String, dynamic> get collectedData => Map.from(_collectedData);
  List<String> get dataCategories => List.from(_dataCategories);

  /// Initialize the data collection service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('DataCollectionService: Starting initialization...');

      _prefs = await SharedPreferences.getInstance();
      _packageInfo = await PackageInfo.fromPlatform();
      await _loadSettings();
      await _initializeDataCategories();

      _isInitialized = true;
      debugPrint(
          'DataCollectionService: Initialization completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('DataCollectionService: Initialization failed: $e');
    }
  }

  /// Load data collection settings
  Future<void> _loadSettings() async {
    _dataCollectionEnabled =
        _prefs?.getBool('data_collection_enabled') ?? false;
    _personalDataCollectionEnabled =
        _prefs?.getBool('personal_data_collection_enabled') ?? false;
    _usagePatternsCollectionEnabled =
        _prefs?.getBool('usage_patterns_collection_enabled') ?? false;
    _performanceDataCollectionEnabled =
        _prefs?.getBool('performance_data_collection_enabled') ?? false;
    _diagnosticDataCollectionEnabled =
        _prefs?.getBool('diagnostic_data_collection_enabled') ?? false;
    _locationDataCollectionEnabled =
        _prefs?.getBool('location_data_collection_enabled') ?? false;
    _contactsDataCollectionEnabled =
        _prefs?.getBool('contacts_data_collection_enabled') ?? false;
  }

  /// Save data collection settings
  Future<void> _saveSettings() async {
    await _prefs?.setBool('data_collection_enabled', _dataCollectionEnabled);
    await _prefs?.setBool(
        'personal_data_collection_enabled', _personalDataCollectionEnabled);
    await _prefs?.setBool(
        'usage_patterns_collection_enabled', _usagePatternsCollectionEnabled);
    await _prefs?.setBool('performance_data_collection_enabled',
        _performanceDataCollectionEnabled);
    await _prefs?.setBool(
        'diagnostic_data_collection_enabled', _diagnosticDataCollectionEnabled);
    await _prefs?.setBool(
        'location_data_collection_enabled', _locationDataCollectionEnabled);
    await _prefs?.setBool(
        'contacts_data_collection_enabled', _contactsDataCollectionEnabled);
  }

  /// Initialize data categories
  Future<void> _initializeDataCategories() async {
    _dataCategories = [
      'App Usage Statistics',
      'Focus Session Data',
      'Task Management Data',
      'Note Content (Encrypted)',
      'User Preferences',
      'Device Information',
      'Performance Metrics',
      'Error Logs',
      'Feature Usage',
      'Settings Configuration',
    ];
  }

  /// Enable data collection
  Future<void> enableDataCollection() async {
    _dataCollectionEnabled = true;
    await _saveSettings();
    await _startDataCollection();
    notifyListeners();
    debugPrint('DataCollectionService: Data collection enabled');
  }

  /// Disable data collection
  Future<void> disableDataCollection() async {
    _dataCollectionEnabled = false;
    await _saveSettings();
    await _stopDataCollection();
    notifyListeners();
    debugPrint('DataCollectionService: Data collection disabled');
  }

  /// Enable personal data collection
  Future<void> enablePersonalDataCollection() async {
    _personalDataCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable personal data collection
  Future<void> disablePersonalDataCollection() async {
    _personalDataCollectionEnabled = false;
    await _saveSettings();
    await _removePersonalData();
    notifyListeners();
  }

  /// Enable usage patterns collection
  Future<void> enableUsagePatternsCollection() async {
    _usagePatternsCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable usage patterns collection
  Future<void> disableUsagePatternsCollection() async {
    _usagePatternsCollectionEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable performance data collection
  Future<void> enablePerformanceDataCollection() async {
    _performanceDataCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable performance data collection
  Future<void> disablePerformanceDataCollection() async {
    _performanceDataCollectionEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable diagnostic data collection
  Future<void> enableDiagnosticDataCollection() async {
    _diagnosticDataCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable diagnostic data collection
  Future<void> disableDiagnosticDataCollection() async {
    _diagnosticDataCollectionEnabled = false;
    await _saveSettings();
    notifyListeners();
  }

  /// Enable location data collection
  Future<void> enableLocationDataCollection() async {
    _locationDataCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable location data collection
  Future<void> disableLocationDataCollection() async {
    _locationDataCollectionEnabled = false;
    await _saveSettings();
    await _removeLocationData();
    notifyListeners();
  }

  /// Enable contacts data collection
  Future<void> enableContactsDataCollection() async {
    _contactsDataCollectionEnabled = true;
    await _saveSettings();
    notifyListeners();
  }

  /// Disable contacts data collection
  Future<void> disableContactsDataCollection() async {
    _contactsDataCollectionEnabled = false;
    await _saveSettings();
    await _removeContactsData();
    notifyListeners();
  }

  /// Start data collection
  Future<void> _startDataCollection() async {
    if (!_dataCollectionEnabled) return;

    try {
      await _collectBasicAppData();
      await _collectDeviceInfo();

      debugPrint('DataCollectionService: Data collection started');
    } catch (e) {
      debugPrint('DataCollectionService: Error starting data collection: $e');
    }
  }

  /// Stop data collection
  Future<void> _stopDataCollection() async {
    try {
      await _clearCollectedData();
      debugPrint('DataCollectionService: Data collection stopped');
    } catch (e) {
      debugPrint('DataCollectionService: Error stopping data collection: $e');
    }
  }

  /// Collect basic app data
  Future<void> _collectBasicAppData() async {
    try {
      _collectedData['app_info'] = {
        'app_name': _packageInfo?.appName ?? 'Unknown',
        'version': _packageInfo?.version ?? 'Unknown',
        'build_number': _packageInfo?.buildNumber ?? 'Unknown',
        'collection_timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('DataCollectionService: Error collecting basic app data: $e');
    }
  }

  /// Collect device information
  Future<void> _collectDeviceInfo() async {
    try {
      final info = <String, dynamic>{};

      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        info.addAll({
          'platform': 'Android',
          'version': androidInfo.version.release,
          'model': androidInfo.model,
          'manufacturer': androidInfo.manufacturer,
          'brand': androidInfo.brand,
        });
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        info.addAll({
          'platform': 'iOS',
          'version': iosInfo.systemVersion,
          'model': iosInfo.model,
          'name': iosInfo.name,
        });
      }

      _collectedData['device_info'] = info;
    } catch (e) {
      debugPrint('DataCollectionService: Error collecting device info: $e');
    }
  }

  /// Collect usage data
  Future<void> collectUsageData({
    required String feature,
    required Map<String, dynamic> data,
  }) async {
    if (!_dataCollectionEnabled || !_usagePatternsCollectionEnabled) return;

    try {
      if (!_collectedData.containsKey('usage_data')) {
        _collectedData['usage_data'] = <String, List<Map<String, dynamic>>>{};
      }

      if (!_collectedData['usage_data'].containsKey(feature)) {
        _collectedData['usage_data'][feature] = <Map<String, dynamic>>[];
      }

      _collectedData['usage_data'][feature].add({
        'timestamp': DateTime.now().toIso8601String(),
        'data': data,
      });

      await _storeCollectedData();
    } catch (e) {
      debugPrint('DataCollectionService: Error collecting usage data: $e');
    }
  }

  /// Collect performance data
  Future<void> collectPerformanceData({
    required String metric,
    required double value,
    String? unit,
  }) async {
    if (!_dataCollectionEnabled || !_performanceDataCollectionEnabled) return;

    try {
      if (!_collectedData.containsKey('performance_data')) {
        _collectedData['performance_data'] = <Map<String, dynamic>>[];
      }

      _collectedData['performance_data'].add({
        'timestamp': DateTime.now().toIso8601String(),
        'metric': metric,
        'value': value,
        'unit': unit ?? 'ms',
      });

      await _storeCollectedData();
    } catch (e) {
      debugPrint(
          'DataCollectionService: Error collecting performance data: $e');
    }
  }

  /// Store collected data
  Future<void> _storeCollectedData() async {
    try {
      await _prefs?.setString('collected_data', jsonEncode(_collectedData));
    } catch (e) {
      debugPrint('DataCollectionService: Error storing collected data: $e');
    }
  }

  /// Remove personal data
  Future<void> _removePersonalData() async {
    try {
      _collectedData.remove('personal_data');
      await _storeCollectedData();
      debugPrint('DataCollectionService: Personal data removed');
    } catch (e) {
      debugPrint('DataCollectionService: Error removing personal data: $e');
    }
  }

  /// Remove location data
  Future<void> _removeLocationData() async {
    try {
      _collectedData.remove('location_data');
      await _storeCollectedData();
      debugPrint('DataCollectionService: Location data removed');
    } catch (e) {
      debugPrint('DataCollectionService: Error removing location data: $e');
    }
  }

  /// Remove contacts data
  Future<void> _removeContactsData() async {
    try {
      _collectedData.remove('contacts_data');
      await _storeCollectedData();
      debugPrint('DataCollectionService: Contacts data removed');
    } catch (e) {
      debugPrint('DataCollectionService: Error removing contacts data: $e');
    }
  }

  /// Clear all collected data
  Future<void> _clearCollectedData() async {
    try {
      _collectedData.clear();
      await _prefs?.remove('collected_data');
      debugPrint('DataCollectionService: All collected data cleared');
    } catch (e) {
      debugPrint('DataCollectionService: Error clearing collected data: $e');
    }
  }

  /// Get data collection summary
  DataCollectionSummary getDataCollectionSummary() {
    final categories = <String>[];
    int totalDataPoints = 0;

    if (_personalDataCollectionEnabled) categories.add('Personal Data');
    if (_usagePatternsCollectionEnabled) categories.add('Usage Patterns');
    if (_performanceDataCollectionEnabled) categories.add('Performance Data');
    if (_diagnosticDataCollectionEnabled) categories.add('Diagnostic Data');
    if (_locationDataCollectionEnabled) categories.add('Location Data');
    if (_contactsDataCollectionEnabled) categories.add('Contacts Data');

    // Count data points
    for (final value in _collectedData.values) {
      if (value is List) {
        totalDataPoints += value.length;
      } else if (value is Map) {
        totalDataPoints += value.length;
      } else {
        totalDataPoints += 1;
      }
    }

    return DataCollectionSummary(
      isEnabled: _dataCollectionEnabled,
      activeCategories: categories,
      totalDataPoints: totalDataPoints,
      dataSize: _calculateDataSize(),
      lastCollectionTime: _getLastCollectionTime(),
    );
  }

  /// Calculate data size
  double _calculateDataSize() {
    try {
      final jsonString = jsonEncode(_collectedData);
      return jsonString.length / 1024.0; // Size in KB
    } catch (e) {
      return 0.0;
    }
  }

  /// Get last collection time
  DateTime? _getLastCollectionTime() {
    try {
      if (_collectedData.containsKey('app_info')) {
        final timestamp = _collectedData['app_info']['collection_timestamp'];
        return DateTime.parse(timestamp);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Export collected data
  Future<String> exportCollectedData() async {
    try {
      final exportData = {
        'export_timestamp': DateTime.now().toIso8601String(),
        'data_collection_settings': {
          'data_collection_enabled': _dataCollectionEnabled,
          'personal_data_collection_enabled': _personalDataCollectionEnabled,
          'usage_patterns_collection_enabled': _usagePatternsCollectionEnabled,
          'performance_data_collection_enabled':
              _performanceDataCollectionEnabled,
          'diagnostic_data_collection_enabled':
              _diagnosticDataCollectionEnabled,
          'location_data_collection_enabled': _locationDataCollectionEnabled,
          'contacts_data_collection_enabled': _contactsDataCollectionEnabled,
        },
        'collected_data': _collectedData,
        'data_categories': _dataCategories,
      };

      return jsonEncode(exportData);
    } catch (e) {
      debugPrint('DataCollectionService: Error exporting collected data: $e');
      return '{"error": "Failed to export collected data"}';
    }
  }

  /// Get data transparency report
  Map<String, dynamic> getDataTransparencyReport() {
    return {
      'data_collection_enabled': _dataCollectionEnabled,
      'collection_categories': {
        'personal_data': _personalDataCollectionEnabled,
        'usage_patterns': _usagePatternsCollectionEnabled,
        'performance_data': _performanceDataCollectionEnabled,
        'diagnostic_data': _diagnosticDataCollectionEnabled,
        'location_data': _locationDataCollectionEnabled,
        'contacts_data': _contactsDataCollectionEnabled,
      },
      'data_usage_purposes': [
        'Improve app performance and stability',
        'Enhance user experience',
        'Provide personalized recommendations',
        'Debug and fix issues',
        'Analyze usage patterns',
        'Optimize features',
      ],
      'data_retention_period': '12 months',
      'data_sharing': 'Data is not shared with third parties',
      'user_rights': [
        'Right to access collected data',
        'Right to delete collected data',
        'Right to opt-out of data collection',
        'Right to data portability',
      ],
    };
  }

  /// Dispose resources
  @override
  void dispose() {
    debugPrint('DataCollectionService: Disposing...');
    super.dispose();
  }
}

/// Data collection summary data class
class DataCollectionSummary {
  final bool isEnabled;
  final List<String> activeCategories;
  final int totalDataPoints;
  final double dataSize;
  final DateTime? lastCollectionTime;

  DataCollectionSummary({
    required this.isEnabled,
    required this.activeCategories,
    required this.totalDataPoints,
    required this.dataSize,
    this.lastCollectionTime,
  });

  String get dataSizeFormatted => '${dataSize.toStringAsFixed(2)} KB';
  bool get hasData => totalDataPoints > 0;
}
