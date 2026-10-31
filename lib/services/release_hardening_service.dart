import 'package:shared_preferences/shared_preferences.dart';

import '../services/analytics_service.dart';
import '../services/backup_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/database_helper.dart';
import '../services/firebase_observability_service.dart';
import '../services/permissions_service.dart';
import '../services/reminder_reliability_service.dart';

enum ReleaseCheckSeverity {
  pass,
  warning,
  actionRequired,
}

class ReleaseCheck {
  final String id;
  final String title;
  final String message;
  final ReleaseCheckSeverity severity;
  final String action;

  const ReleaseCheck({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.action,
  });

  bool get passed => severity == ReleaseCheckSeverity.pass;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'severity': severity.name,
      'action': action,
    };
  }
}

class ReleaseHardeningReport {
  final DateTime generatedAt;
  final List<ReleaseCheck> checks;

  const ReleaseHardeningReport({
    required this.generatedAt,
    required this.checks,
  });

  int get score {
    if (checks.isEmpty) return 0;
    final total = checks.fold<int>(0, (sum, check) {
      switch (check.severity) {
        case ReleaseCheckSeverity.pass:
          return sum + 100;
        case ReleaseCheckSeverity.warning:
          return sum + 60;
        case ReleaseCheckSeverity.actionRequired:
          return sum;
      }
    });
    return (total / checks.length).round();
  }

  bool get readyForInternalQa {
    return checks.every(
        (check) => check.severity != ReleaseCheckSeverity.actionRequired);
  }

  int countBySeverity(ReleaseCheckSeverity severity) {
    return checks.where((check) => check.severity == severity).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'score': score,
      'readyForInternalQa': readyForInternalQa,
      'checks': checks.map((check) => check.toJson()).toList(),
    };
  }
}

class ReleaseHardeningService {
  static final ReleaseHardeningService _instance =
      ReleaseHardeningService._internal();
  factory ReleaseHardeningService() => _instance;
  static ReleaseHardeningService get instance => _instance;
  ReleaseHardeningService._internal();

  Future<ReleaseHardeningReport> runChecklist() async {
    final checks = <ReleaseCheck>[
      await _checkDatabaseMigrations(),
      await _checkBackupRestore(),
      await _checkPermissions(),
      await _checkNotificationReliability(),
      await _checkAnalyticsIntelligence(),
      await _checkCloudSync(),
      _checkFirebaseObservability(),
      await _checkStoreReadiness(),
    ];

    return ReleaseHardeningReport(
      generatedAt: DateTime.now(),
      checks: checks,
    );
  }

  Future<ReleaseCheck> _checkDatabaseMigrations() async {
    try {
      final db = await DatabaseHelper().database;
      final goalsInfo = await db.rawQuery('PRAGMA table_info(goals)');
      final goalColumns =
          goalsInfo.map((column) => column['name']).whereType<String>().toSet();
      const requiredGoalColumns = {
        'status',
        'type',
        'frequency',
        'targetValue',
        'currentValue',
        'createdAt',
        'updatedAt',
      };
      final missing = requiredGoalColumns.difference(goalColumns);

      if (missing.isNotEmpty) {
        return ReleaseCheck(
          id: 'database_migrations',
          title: 'Database migrations',
          message: 'Missing goals columns: ${missing.join(', ')}.',
          severity: ReleaseCheckSeverity.actionRequired,
          action: 'Open the app once after update so schema repair can run.',
        );
      }

      return const ReleaseCheck(
        id: 'database_migrations',
        title: 'Database migrations',
        message: 'Core schema checks passed.',
        severity: ReleaseCheckSeverity.pass,
        action: 'Run upgrade testing with an old app database before release.',
      );
    } catch (e) {
      return ReleaseCheck(
        id: 'database_migrations',
        title: 'Database migrations',
        message: 'Database check failed: $e',
        severity: ReleaseCheckSeverity.actionRequired,
        action: 'Fix database initialization before shipping.',
      );
    }
  }

  Future<ReleaseCheck> _checkBackupRestore() async {
    final info = await BackupService.instance.getLastBackupInfo();
    if (info == null) {
      return const ReleaseCheck(
        id: 'backup_restore',
        title: 'Backup and restore',
        message: 'No local backup has been created on this device.',
        severity: ReleaseCheckSeverity.warning,
        action:
            'Create and export a backup, then test restore on a clean install.',
      );
    }

    return ReleaseCheck(
      id: 'backup_restore',
      title: 'Backup and restore',
      message: 'Last backup: ${info.formattedDate}, ${info.formattedSize}.',
      severity: ReleaseCheckSeverity.pass,
      action: 'Test restore with a copied backup file before release.',
    );
  }

  Future<ReleaseCheck> _checkPermissions() async {
    final permissions = PermissionsService.instance;
    await permissions.initialize();
    await permissions.refreshPermissions();
    final summary = permissions.getPermissionsSummary();
    final deniedCritical = permissions.permissionStatuses.entries
        .where((entry) =>
            permissions.isPermissionCritical(entry.key) &&
            !permissions.isPermissionGranted(entry.key))
        .map((entry) => permissions.getPermissionDisplayName(entry.key))
        .toList();

    if (deniedCritical.isNotEmpty) {
      return ReleaseCheck(
        id: 'permissions',
        title: 'Permissions',
        message:
            'Critical permission(s) missing: ${deniedCritical.join(', ')}.',
        severity: ReleaseCheckSeverity.actionRequired,
        action: 'Show rationale and guide users to app settings.',
      );
    }

    if (!summary.allGranted) {
      return ReleaseCheck(
        id: 'permissions',
        title: 'Permissions',
        message:
            '${summary.granted}/${summary.total} permission(s) granted. Optional permissions may still be denied.',
        severity: ReleaseCheckSeverity.warning,
        action: 'Verify denied optional features degrade gracefully.',
      );
    }

    return ReleaseCheck(
      id: 'permissions',
      title: 'Permissions',
      message: '${summary.total} permission(s) checked and granted.',
      severity: ReleaseCheckSeverity.pass,
      action: 'Keep permission rationale text visible near each feature.',
    );
  }

  Future<ReleaseCheck> _checkNotificationReliability() async {
    final prefs = await SharedPreferences.getInstance();
    final smartEnabled = prefs.getBool('smart_reminders_enabled') ?? true;
    final taskAlertsEnabled = prefs.getBool('task_deadline_alerts') ?? true;
    final summary =
        await ReminderReliabilityService.instance.getSummary(days: 14);

    if (!smartEnabled || !taskAlertsEnabled) {
      return const ReleaseCheck(
        id: 'notification_reliability',
        title: 'Notification reliability',
        message: 'Task or smart reminders are disabled.',
        severity: ReleaseCheckSeverity.warning,
        action: 'Enable reminders and schedule a test task before release.',
      );
    }

    if (summary.needsAttention) {
      return ReleaseCheck(
        id: 'notification_reliability',
        title: 'Notification reliability',
        message:
            '${summary.actionableFailures} reminder issue(s) found in recent history.',
        severity: ReleaseCheckSeverity.warning,
        action: 'Open reminder history and retry failed schedules.',
      );
    }

    return ReleaseCheck(
      id: 'notification_reliability',
      title: 'Notification reliability',
      message:
          'Reminder reliability ${(summary.reliabilityRate * 100).round()}% across ${summary.total} recent log(s).',
      severity: ReleaseCheckSeverity.pass,
      action: 'Keep a test reminder in QA smoke testing.',
    );
  }

  Future<ReleaseCheck> _checkAnalyticsIntelligence() async {
    final analytics = AnalyticsService.instance;
    await analytics.initialize();
    final report = await analytics.getWeeklyIntelligenceReport();
    final focusMinutes = ((report['currentFocusMinutes'] as num?) ?? 0).round();
    final tasksCompleted = ((report['tasksCompleted'] as num?) ?? 0).round();

    if (focusMinutes == 0 && tasksCompleted == 0) {
      return const ReleaseCheck(
        id: 'analytics_intelligence',
        title: 'Analytics intelligence',
        message: 'No weekly task/focus activity detected yet.',
        severity: ReleaseCheckSeverity.warning,
        action: 'Verify empty-state analytics copy and charts.',
      );
    }

    return ReleaseCheck(
      id: 'analytics_intelligence',
      title: 'Analytics intelligence',
      message:
          'Weekly report generated with ${focusMinutes}m focus and $tasksCompleted completed task(s).',
      severity: ReleaseCheckSeverity.pass,
      action: 'Export analytics report during QA.',
    );
  }

  Future<ReleaseCheck> _checkCloudSync() async {
    final sync = CloudSyncService();
    await sync.initialize();
    final readiness = await sync.getBackendReadiness();

    if (!readiness.remoteBackendConfigured) {
      return ReleaseCheck(
        id: 'cloud_sync',
        title: 'Cloud sync',
        message: readiness.message,
        severity: ReleaseCheckSeverity.warning,
        action:
            'Configure Firebase/Supabase/custom backend for cross-device sync.',
      );
    }

    return ReleaseCheck(
      id: 'cloud_sync',
      title: 'Cloud sync',
      message: readiness.message,
      severity: ReleaseCheckSeverity.pass,
      action: 'Run cross-device conflict testing.',
    );
  }

  ReleaseCheck _checkFirebaseObservability() {
    return buildFirebaseObservabilityCheck(
      FirebaseObservabilityService.instance.getStatusSnapshot(),
    );
  }

  static ReleaseCheck buildFirebaseObservabilityCheck(
    Map<String, Object?> status,
  ) {
    final observabilityInitialized =
        status['observability_initialized'] == true;
    final firebaseInitialized = status['firebase_initialized'] == true;
    final analyticsEnabled = status['analytics_enabled'] == true;
    final crashReportingEnabled = status['crash_reporting_enabled'] == true;
    final projectId = (status['project_id'] ?? 'not_available').toString();

    if (!observabilityInitialized || !firebaseInitialized) {
      return const ReleaseCheck(
        id: 'firebase_observability',
        title: 'Firebase observability',
        message: 'Firebase observability is not initialized.',
        severity: ReleaseCheckSeverity.actionRequired,
        action:
            'Verify Firebase.initializeApp and observability initialization before app startup QA.',
      );
    }

    if (!analyticsEnabled && !crashReportingEnabled) {
      return ReleaseCheck(
        id: 'firebase_observability',
        title: 'Firebase observability',
        message:
            'Firebase is ready for $projectId, but Analytics and Crashlytics '
            'collection are disabled by privacy toggles.',
        severity: ReleaseCheckSeverity.warning,
        action:
            'Enable each toggle during QA, send test signals, then disable again if privacy review requires it.',
      );
    }

    if (!analyticsEnabled || !crashReportingEnabled) {
      final analyticsStatus = analyticsEnabled ? 'enabled' : 'disabled';
      final crashStatus = crashReportingEnabled ? 'enabled' : 'disabled';

      return ReleaseCheck(
        id: 'firebase_observability',
        title: 'Firebase observability',
        message:
            'Firebase is ready for $projectId. Analytics is $analyticsStatus and Crashlytics is $crashStatus.',
        severity: ReleaseCheckSeverity.warning,
        action:
            'Verify the disabled collection path and run the matching enabled test signal before release.',
      );
    }

    return ReleaseCheck(
      id: 'firebase_observability',
      title: 'Firebase observability',
      message:
          'Firebase observability is ready for $projectId with Analytics and Crashlytics enabled.',
      severity: ReleaseCheckSeverity.pass,
      action:
          'Send the Analytics test event and non-fatal test error from Settings > Advanced.',
    );
  }

  Future<ReleaseCheck> _checkStoreReadiness() async {
    final prefs = await SharedPreferences.getInstance();
    final privacyControlsConfigured = prefs.containsKey('analytics_enabled') ||
        prefs.containsKey('data_collection_enabled') ||
        prefs.containsKey('crash_reporting_enabled');

    if (!privacyControlsConfigured) {
      return const ReleaseCheck(
        id: 'store_readiness',
        title: 'Store readiness',
        message: 'Privacy controls have not been reviewed on this device.',
        severity: ReleaseCheckSeverity.warning,
        action:
            'Review privacy toggles, permission rationale, icon, splash, and release build.',
      );
    }

    return const ReleaseCheck(
      id: 'store_readiness',
      title: 'Store readiness',
      message: 'Privacy controls are available and ready for release review.',
      severity: ReleaseCheckSeverity.pass,
      action: 'Generate final Android release build and verify store metadata.',
    );
  }
}
