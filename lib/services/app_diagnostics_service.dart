import '../utils/cache_manager.dart';
import 'app_initialization_service.dart';
import 'cloud_sync_service.dart';
import 'firebase_observability_service.dart';

class AppDiagnosticsSnapshot {
  final DateTime generatedAt;
  final Map<String, Object?> observability;
  final Map<String, Object?> cloudSync;
  final Map<String, int> cache;
  final bool appDatabaseInitialized;

  const AppDiagnosticsSnapshot({
    required this.generatedAt,
    required this.observability,
    required this.cloudSync,
    required this.cache,
    required this.appDatabaseInitialized,
  });

  bool get cloudSyncReady =>
      cloudSync['remote_backend_configured'] == true &&
      cloudSync['missing_items_count'] == 0;

  Map<String, Object?> toJson() {
    return {
      'generatedAt': generatedAt.toIso8601String(),
      'observability': observability,
      'cloudSync': cloudSync,
      'cache': cache,
      'appDatabaseInitialized': appDatabaseInitialized,
      'cloudSyncReady': cloudSyncReady,
    };
  }
}

/// Aggregates lightweight runtime diagnostics for Settings and QA tooling.
class AppDiagnosticsService {
  static final AppDiagnosticsService _instance = AppDiagnosticsService._();
  factory AppDiagnosticsService() => _instance;
  static AppDiagnosticsService get instance => _instance;
  AppDiagnosticsService._();

  final FirebaseObservabilityService _observability =
      FirebaseObservabilityService.instance;
  final CloudSyncService _cloudSync = CloudSyncService();
  final CacheManager _cache = CacheManager();

  Future<AppDiagnosticsSnapshot> collect() async {
    await _cloudSync.initialize();
    final readiness = await _cloudSync.getBackendReadiness();

    return AppDiagnosticsSnapshot(
      generatedAt: DateTime.now(),
      observability: _observability.getStatusSnapshot(),
      cloudSync: {
        'provider': readiness.provider.name,
        'provider_label': readiness.provider.displayName,
        'remote_backend_configured': readiness.remoteBackendConfigured,
        'missing_items': readiness.missingItems,
        'missing_items_count': readiness.missingItems.length,
        'project_id': readiness.projectId ?? 'not_available',
        'endpoint': readiness.endpoint ?? 'not_available',
        'is_authenticated': _cloudSync.isAuthenticated,
        'is_syncing': _cloudSync.isSyncing,
        'auto_sync_enabled': _cloudSync.isAutoSyncEnabled,
        'last_sync_time': _cloudSync.lastSyncTime?.toIso8601String(),
        'last_status_message': _cloudSync.lastStatusMessage,
      },
      cache: _cache.getCacheInfo(),
      appDatabaseInitialized: AppInitializationService().isInitialized,
    );
  }
}
