import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/cloud_sync_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reports local snapshot mode until a remote backend is configured',
      () async {
    final service = CloudSyncService();
    await service.initialize();

    final initialReadiness = await service.getBackendReadiness();
    expect(initialReadiness.provider, CloudSyncBackendProvider.localSnapshot);
    expect(initialReadiness.remoteBackendConfigured, isFalse);
    expect(initialReadiness.missingItems, isNotEmpty);

    await service.configureBackend(
      provider: CloudSyncBackendProvider.firebase,
      projectId: 'focusbro-prod',
      apiKey: 'test-api-key',
    );

    final firebaseReadiness = await service.getBackendReadiness();
    expect(firebaseReadiness.provider, CloudSyncBackendProvider.firebase);
    expect(firebaseReadiness.remoteBackendConfigured, isFalse);
    expect(firebaseReadiness.missingItems, contains('Firebase initialization'));

    await service.configureBackend(
      provider: CloudSyncBackendProvider.firebase,
      projectId: 'focusbro-prod-renamed',
      apiKey: null,
    );

    final updatedReadiness = await service.getBackendReadiness();
    expect(updatedReadiness.remoteBackendConfigured, isFalse);
    expect(updatedReadiness.projectId, 'focusbro-prod-renamed');
    expect(updatedReadiness.missingItems, contains('Firebase initialization'));
  });
}
