import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/app_diagnostics_service.dart';
import 'package:focusbro/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('collect returns observability and cloud sync diagnostics', () async {
    final snapshot = await AppDiagnosticsService.instance.collect();

    expect(snapshot.observability.containsKey('firebase_initialized'), isTrue);
    expect(snapshot.cloudSync['provider'], isA<String>());
    expect(snapshot.cloudSync['missing_items_count'], isA<int>());
    expect(snapshot.cache.containsKey('memoryEntries'), isTrue);
    expect(snapshot.toJson()['cloudSyncReady'], isA<bool>());
  });

  test('cloudSyncReady is false when firebase backend is not configured',
      () async {
    final cloudSync = CloudSyncService();
    await cloudSync.configureBackend(
      provider: CloudSyncBackendProvider.firebase,
      projectId: 'focusbro-test',
    );

    final snapshot = await AppDiagnosticsService.instance.collect();

    expect(
        snapshot.cloudSync['provider'], CloudSyncBackendProvider.firebase.name);
    expect(snapshot.cloudSyncReady, isFalse);
    expect(snapshot.cloudSync['missing_items'], isNotEmpty);
  });
}
