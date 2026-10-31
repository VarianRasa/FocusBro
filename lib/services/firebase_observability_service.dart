import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseObservabilityService {
  static final FirebaseObservabilityService _instance =
      FirebaseObservabilityService._internal();
  factory FirebaseObservabilityService() => _instance;
  static FirebaseObservabilityService get instance => _instance;
  FirebaseObservabilityService._internal();

  static const String _analyticsEnabledKey = 'analytics_enabled';
  static const String _crashReportingEnabledKey = 'crash_reporting_enabled';
  static const Set<String> _sensitiveKeyFragments = {
    'email',
    'password',
    'passcode',
    'pin',
    'token',
    'secret',
    'content',
    'body',
    'title',
    'description',
    'file_path',
    'filepath',
    'path',
    'stack',
    'payload',
  };

  bool _isInitialized = false;
  bool _analyticsEnabled = false;
  bool _crashReportingEnabled = false;

  bool get isInitialized => _isInitialized;
  bool get analyticsEnabled => _analyticsEnabled;
  bool get crashReportingEnabled => _crashReportingEnabled;

  Map<String, Object?> getStatusSnapshot() {
    String? projectId;
    String? appId;
    String? appName;

    try {
      if (_isFirebaseInitialized) {
        final app = Firebase.app();
        projectId = app.options.projectId;
        appId = app.options.appId;
        appName = app.name;
      }
    } catch (_) {
      // Keep diagnostics resilient if Firebase is not ready.
    }

    return {
      'observability_initialized': _isInitialized,
      'firebase_initialized': _isFirebaseInitialized,
      'analytics_enabled': _analyticsEnabled,
      'crash_reporting_enabled': _crashReportingEnabled,
      'project_id': projectId ?? 'not_available',
      'app_id': appId ?? 'not_available',
      'app_name': appName ?? 'not_available',
    };
  }

  Future<void> logDiagnosticsEvent() async {
    await logEvent('observability_test_event', {
      'feature': 'observability',
      'screen': 'settings',
      'status': 'manual_test',
    });
  }

  Future<void> recordDiagnosticsNonFatal() async {
    await recordNonFatal(
      'observability_test_nonfatal',
      StateError('FocusBro observability non-fatal test'),
      StackTrace.current,
      const {
        'feature': 'observability',
        'screen': 'settings',
        'status': 'manual_test',
      },
    );
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _analyticsEnabled = prefs.getBool(_analyticsEnabledKey) ?? false;
    _crashReportingEnabled = prefs.getBool(_crashReportingEnabledKey) ?? false;

    await _applyCollectionSettings();
    _isInitialized = true;
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    _analyticsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_analyticsEnabledKey, enabled);
    await _applyAnalyticsCollection();
  }

  Future<void> setCrashReportingEnabled(bool enabled) async {
    _crashReportingEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_crashReportingEnabledKey, enabled);
    await _applyCrashlyticsCollection();
  }

  Future<void> logEvent(
    String name, [
    Map<String, Object?> parameters = const {},
  ]) async {
    if (!_analyticsEnabled || !_isFirebaseInitialized) return;

    try {
      await FirebaseAnalytics.instance.logEvent(
        name: _normalizeEventName(name),
        parameters: _sanitizeParameters(parameters),
      );
    } catch (error) {
      debugPrint('FirebaseObservabilityService: logEvent failed: $error');
    }
  }

  Future<void> recordNonFatal(
    String context,
    Object error, [
    StackTrace? stackTrace,
    Map<String, Object?> metadata = const {},
  ]) async {
    if (!_crashReportingEnabled || !_isFirebaseInitialized) return;

    try {
      final sanitized = _sanitizeParameters(metadata);
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: _normalizeCrashContext(context),
        information: sanitized.entries
            .map((entry) => '${entry.key}=${entry.value}')
            .toList(),
        fatal: false,
      );
    } catch (recordError) {
      debugPrint(
        'FirebaseObservabilityService: recordNonFatal failed: $recordError',
      );
    }
  }

  static String normalizeEventNameForTesting(String name) {
    return _normalizeEventName(name);
  }

  static Map<String, Object> sanitizeParametersForTesting(
    Map<String, Object?> parameters,
  ) {
    return _sanitizeParameters(parameters);
  }

  Future<void> _applyCollectionSettings() async {
    if (!_isFirebaseInitialized) return;
    await _applyAnalyticsCollection();
    await _applyCrashlyticsCollection();
  }

  Future<void> _applyAnalyticsCollection() async {
    if (!_isFirebaseInitialized) return;
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(_analyticsEnabled);
    } catch (error) {
      debugPrint(
        'FirebaseObservabilityService: analytics toggle failed: $error',
      );
    }
  }

  Future<void> _applyCrashlyticsCollection() async {
    if (!_isFirebaseInitialized) return;
    try {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(_crashReportingEnabled);
    } catch (error) {
      debugPrint(
        'FirebaseObservabilityService: crashlytics toggle failed: $error',
      );
    }
  }

  bool get _isFirebaseInitialized {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _normalizeEventName(String name) {
    var normalized = name
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();

    if (normalized.isEmpty) {
      normalized = 'app_event';
    }

    if (!RegExp(r'^[a-z]').hasMatch(normalized)) {
      normalized = 'event_$normalized';
    }

    if (normalized.length > 40) {
      normalized = normalized.substring(0, 40).replaceAll(RegExp(r'_+$'), '');
    }

    return normalized.isEmpty ? 'app_event' : normalized;
  }

  static Map<String, Object> _sanitizeParameters(
    Map<String, Object?> parameters,
  ) {
    final sanitized = <String, Object>{};

    for (final entry in parameters.entries) {
      final key = _normalizeParameterKey(entry.key);
      final value = entry.value;

      if (key.isEmpty || value == null || _isSensitiveKey(key)) {
        continue;
      }

      if (value is String) {
        sanitized[key] = value.length > 100 ? value.substring(0, 100) : value;
      } else if (value is num) {
        sanitized[key] = value;
      } else if (value is bool) {
        sanitized[key] = value ? 1 : 0;
      }
    }

    return sanitized;
  }

  static String _normalizeParameterKey(String key) {
    final normalized = key
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '')
        .toLowerCase();

    var firebaseSafe = normalized;
    if (firebaseSafe.isNotEmpty && !RegExp(r'^[a-z]').hasMatch(firebaseSafe)) {
      firebaseSafe = 'param_$firebaseSafe';
    }

    if (firebaseSafe.length <= 40) return firebaseSafe;
    return firebaseSafe.substring(0, 40).replaceAll(RegExp(r'_+$'), '');
  }

  static bool _isSensitiveKey(String key) {
    return _sensitiveKeyFragments.any((fragment) => key.contains(fragment));
  }

  static String _normalizeCrashContext(String context) {
    final normalized = _normalizeEventName(context);
    return normalized.length <= 80 ? normalized : normalized.substring(0, 80);
  }
}
