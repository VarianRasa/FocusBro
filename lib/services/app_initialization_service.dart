import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'migration_service.dart';
import '../repositories/focus_repository.dart';

class AppInitializationService {
  static final AppInitializationService _instance =
      AppInitializationService._internal();
  factory AppInitializationService() => _instance;
  AppInitializationService._internal();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  /// Initialize the app's database and perform migrations
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (kDebugMode) {
        print('Initializing FocusBro app...');
      }

      // Initialize database
      final databaseHelper = DatabaseHelper();
      await databaseHelper.database; // This will create tables if needed

      // Perform migration from SharedPreferences if needed
      final migrationService = MigrationService();
      final migrationPerformed =
          await migrationService.performMigrationIfNeeded();

      if (migrationPerformed) {
        if (kDebugMode) {
          print('Migration completed successfully');
        }

        // Optionally clean up old SharedPreferences data
        // await migrationService.cleanupOldData();
      }

      // Initialize focus statistics if empty
      final focusStatsRepo = FocusStatisticsRepository();
      await focusStatsRepo.initializeIfEmpty();

      _isInitialized = true;

      if (kDebugMode) {
        print('App initialization completed');
      }
    } catch (e) {
      if (kDebugMode) {
        print('App initialization failed: $e');
      }
      rethrow;
    }
  }

  /// Reset the initialization state (for testing purposes)
  void reset() {
    _isInitialized = false;
  }
}
