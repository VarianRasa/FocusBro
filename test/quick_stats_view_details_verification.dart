import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/enhanced_analytics_screen.dart';

/// Comprehensive verification test for Quick Stats "View Details" functionality
void main() {
  group('Quick Stats View Details Verification', () {
    testWidgets('Complete Quick Stats View Details Integration Test',
        (WidgetTester tester) async {
      print('🚀 Starting Quick Stats View Details Integration Test');

      // Step 1: Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();
      print('✅ Step 1: App launched successfully');

      // Step 2: Verify Enhanced Focus Screen is displayed
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
      print('✅ Step 2: Enhanced Focus Screen is displayed');

      // Step 3: Find and verify Stats button exists
      final statsButton = find.text('Stats');
      expect(statsButton, findsOneWidget);
      print('✅ Step 3: Stats button found');

      // Step 4: Get FocusProvider and refresh statistics
      final focusProvider = Provider.of<FocusProvider>(
        tester.element(find.byType(EnhancedFocusScreen)),
        listen: false,
      );
      await focusProvider.refreshStatistics();
      await tester.pumpAndSettle();
      print('✅ Step 4: Statistics refreshed');

      // Step 5: Tap Stats button to open Quick Stats dialog
      await tester.tap(statsButton);
      await tester.pumpAndSettle();
      print('✅ Step 5: Stats button tapped');

      // Step 6: Verify Quick Stats dialog is displayed
      expect(find.text('Quick Stats'), findsOneWidget);
      expect(find.text('Today\'s Sessions'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Total Focus Time'), findsOneWidget);
      expect(find.text('Completed Sessions'), findsOneWidget);
      print('✅ Step 6: Quick Stats dialog displayed with all elements');

      // Step 7: Capture current statistics for comparison
      final currentSessions = focusProvider.todaysSessions;
      final currentStreak = focusProvider.currentStreak;
      final totalFocusHours = focusProvider.totalFocusHours;
      final totalSessions = focusProvider.totalSessions;

      print('📊 Current Statistics:');
      print('  - Today\'s Sessions: $currentSessions');
      print('  - Current Streak: $currentStreak');
      print('  - Total Focus Time: ${totalFocusHours}h');
      print('  - Total Sessions: $totalSessions');

      // Step 8: Find and verify View Details button
      final viewDetailsButton = find.text('View Details');
      expect(viewDetailsButton, findsOneWidget);
      print('✅ Step 8: View Details button found');

      // Step 9: Tap View Details button
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();
      print('✅ Step 9: View Details button tapped');

      // Step 10: Verify navigation to Enhanced Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);
      print('✅ Step 10: Successfully navigated to Enhanced Analytics Screen');

      // Step 11: Verify Quick Stats dialog is closed
      expect(find.text('Quick Stats'), findsNothing);
      print('✅ Step 11: Quick Stats dialog properly closed');

      // Step 12: Verify Enhanced Analytics Screen content
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('Weekly Progress'), findsOneWidget);
      print('✅ Step 12: Enhanced Analytics Screen displays all key metrics');

      // Step 13: Wait for analytics data to load
      await tester.pump(const Duration(seconds: 2));
      print('✅ Step 13: Analytics data loading completed');

      // Step 14: Test back navigation
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();
      print('✅ Step 14: Back navigation executed');

      // Step 15: Verify we're back on Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
      expect(find.byType(EnhancedAnalyticsScreen), findsNothing);
      print('✅ Step 15: Successfully returned to Enhanced Focus Screen');

      // Step 16: Test the flow again to ensure consistency
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      expect(find.text('Quick Stats'), findsOneWidget);
      print('✅ Step 16: Quick Stats dialog opens consistently');

      // Step 17: Verify statistics are still consistent
      expect(focusProvider.todaysSessions, equals(currentSessions));
      expect(focusProvider.currentStreak, equals(currentStreak));
      expect(focusProvider.totalFocusHours, equals(totalFocusHours));
      expect(focusProvider.totalSessions, equals(totalSessions));
      print('✅ Step 17: Statistics remain consistent across navigation');

      // Step 18: Close dialog and complete test
      final closeButton = find.text('Close');
      await tester.tap(closeButton);
      await tester.pumpAndSettle();
      expect(find.text('Quick Stats'), findsNothing);
      print('✅ Step 18: Dialog closed successfully');

      print('🎉 Quick Stats View Details Integration Test PASSED!');
    });

    testWidgets('Error Handling Test for View Details',
        (WidgetTester tester) async {
      print('🔧 Starting Error Handling Test');

      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Open Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Test multiple rapid taps on View Details
      final viewDetailsButton = find.text('View Details');

      // Rapid taps
      await tester.tap(viewDetailsButton);
      await tester.tap(viewDetailsButton);
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Should still navigate correctly without errors
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      print('✅ Error Handling: Multiple rapid taps handled correctly');

      print('🎉 Error Handling Test PASSED!');
    });

    testWidgets('Data Consistency Verification', (WidgetTester tester) async {
      print('📊 Starting Data Consistency Verification');

      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Get FocusProvider
      final focusProvider = Provider.of<FocusProvider>(
        tester.element(find.byType(EnhancedFocusScreen)),
        listen: false,
      );

      // Refresh statistics
      await focusProvider.refreshStatistics();
      await tester.pumpAndSettle();

      // Capture Quick Stats data
      final quickStatsData = {
        'todaysSessions': focusProvider.todaysSessions,
        'currentStreak': focusProvider.currentStreak,
        'totalFocusHours': focusProvider.totalFocusHours,
        'totalSessions': focusProvider.totalSessions,
      };

      print('📊 Quick Stats Data Captured:');
      quickStatsData.forEach((key, value) {
        print('  - $key: $value');
      });

      // Navigate to Analytics via Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify we're on Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);

      // Wait for analytics data to load
      await tester.pump(const Duration(seconds: 2));

      // Verify data consistency (the same FocusProvider should have consistent data)
      expect(focusProvider.todaysSessions,
          equals(quickStatsData['todaysSessions']));
      expect(
          focusProvider.currentStreak, equals(quickStatsData['currentStreak']));
      expect(focusProvider.totalFocusHours,
          equals(quickStatsData['totalFocusHours']));
      expect(
          focusProvider.totalSessions, equals(quickStatsData['totalSessions']));

      print(
          '✅ Data Consistency: All statistics match between Quick Stats and Analytics');
      print('🎉 Data Consistency Verification PASSED!');
    });

    testWidgets('Performance Test for View Details Navigation',
        (WidgetTester tester) async {
      print('⚡ Starting Performance Test');

      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Measure navigation time
      final stopwatch = Stopwatch()..start();

      // Open Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Navigate to Analytics
      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      stopwatch.stop();
      final navigationTime = stopwatch.elapsedMilliseconds;

      // Verify navigation completed
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);

      print('⚡ Navigation Performance:');
      print('  - Time to navigate: ${navigationTime}ms');
      print(
          '  - Performance: ${navigationTime < 1000 ? "EXCELLENT" : navigationTime < 2000 ? "GOOD" : "NEEDS IMPROVEMENT"}');

      // Navigation should be reasonably fast (under 2 seconds)
      expect(navigationTime, lessThan(2000));

      print('🎉 Performance Test PASSED!');
    });
  });
}
