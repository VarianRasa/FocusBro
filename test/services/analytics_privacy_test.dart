import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('analytics opt-out prevents local usage event collection', () async {
    SharedPreferences.setMockInitialValues({});
    final analytics = AnalyticsService();
    await analytics.initialize();
    await analytics.disableAnalytics();
    await analytics.clearAllData();

    await analytics.trackAppUsage(
      screen: 'focus',
      timeSpent: const Duration(seconds: 30),
    );
    await analytics.trackFeatureUsage('timer_started');
    await analytics.trackPreferenceChange('theme', 'dark');

    final export = await analytics.exportData();
    expect(export['appUsage'], isEmpty);
    expect(export['featureUsage'], isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('analytics_preference_change'), isNull);
  });
}
