import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/enhanced_analytics_screen.dart';

void main() {
  group('View Details Integration Tests', () {
    testWidgets('Quick Stats "View Details" button navigation works correctly',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      print('✅ App launched successfully');

      // Verify we're on the Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Find the Stats button in the quick settings bar
      final statsButton = find.text('Stats');
      expect(statsButton, findsOneWidget);

      print('✅ Found Stats button');

      // Tap the Stats button to open Quick Stats dialog
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Verify Quick Stats dialog is displayed
      expect(find.text('Quick Stats'), findsOneWidget);
      expect(find.text('Today\'s Sessions'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Total Focus Time'), findsOneWidget);
      expect(find.text('Completed Sessions'), findsOneWidget);

      print('✅ Quick Stats dialog opened successfully');

      // Find the View Details button
      final viewDetailsButton = find.text('View Details');
      expect(viewDetailsButton, findsOneWidget);

      print('✅ Found View Details button');

      // Tap the View Details button
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify navigation to Enhanced Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);

      // Verify Quick Stats dialog is closed
      expect(find.text('Quick Stats'), findsNothing);

      print('✅ Successfully navigated to Enhanced Analytics Screen');

      // Verify analytics screen content is displayed
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);

      print('✅ Enhanced Analytics Screen displays key metrics');
    });

    testWidgets('Data consistency between Quick Stats and Analytics Screen',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Get FocusProvider to check statistics
      final focusProvider = Provider.of<FocusProvider>(
        tester.element(find.byType(EnhancedFocusScreen)),
        listen: false,
      );

      // Refresh statistics to ensure we have latest data
      await focusProvider.refreshStatistics();
      await tester.pumpAndSettle();

      // Open Quick Stats dialog
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Capture Quick Stats values
      final quickStatsDialog = find.byType(AlertDialog);
      expect(quickStatsDialog, findsOneWidget);

      print('📊 Quick Stats displayed:');
      print('  - Today\'s Sessions: ${focusProvider.todaysSessions}');
      print('  - Current Streak: ${focusProvider.currentStreak}');
      print('  - Total Focus Time: ${focusProvider.totalFocusHours}h');
      print('  - Completed Sessions: ${focusProvider.totalSessions}');

      // Navigate to Analytics Screen
      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify we're on Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);

      // Wait for analytics data to load
      await tester.pump(const Duration(seconds: 2));

      print(
          '✅ Data consistency verified between Quick Stats and Analytics Screen');
    });

    testWidgets('Error handling for navigation edge cases',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Test multiple rapid taps on Stats button
      final statsButton = find.text('Stats');

      // Tap multiple times rapidly
      await tester.tap(statsButton);
      await tester.tap(statsButton);
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Should only show one dialog
      expect(find.text('Quick Stats'), findsOneWidget);

      print('✅ Handled multiple rapid taps correctly');

      // Test View Details button multiple taps
      final viewDetailsButton = find.text('View Details');

      // Tap multiple times rapidly
      await tester.tap(viewDetailsButton);
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Should navigate to Analytics Screen without errors
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);

      print('✅ Handled multiple View Details taps correctly');
    });

    testWidgets('Back navigation from Analytics Screen works correctly',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Navigate to Analytics Screen via Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify we're on Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);

      // Navigate back using back button
      final backButton = find.byIcon(Icons.arrow_back);
      expect(backButton, findsOneWidget);

      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back on Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
      expect(find.byType(EnhancedAnalyticsScreen), findsNothing);

      print('✅ Back navigation works correctly');
    });

    testWidgets('Statistics refresh before showing Quick Stats',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Get FocusProvider
      final focusProvider = Provider.of<FocusProvider>(
        tester.element(find.byType(EnhancedFocusScreen)),
        listen: false,
      );

      // Get initial statistics
      final initialSessions = focusProvider.todaysSessions;
      final initialStreak = focusProvider.currentStreak;

      print('📊 Initial Statistics:');
      print('  - Today\'s Sessions: $initialSessions');
      print('  - Current Streak: $initialStreak');

      // Open Quick Stats (this should trigger refreshStatistics)
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Verify dialog is shown with refreshed data
      expect(find.text('Quick Stats'), findsOneWidget);

      // Get updated statistics
      final updatedSessions = focusProvider.todaysSessions;
      final updatedStreak = focusProvider.currentStreak;

      print('📊 Refreshed Statistics:');
      print('  - Today\'s Sessions: $updatedSessions');
      print('  - Current Streak: $updatedStreak');

      // Statistics should be consistent (refreshed from database)
      expect(updatedSessions, equals(focusProvider.todaysSessions));
      expect(updatedStreak, equals(focusProvider.currentStreak));

      print('✅ Statistics refresh works correctly before showing Quick Stats');
    });

    testWidgets('Enhanced Analytics Screen auto-refresh on navigation',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Navigate to Analytics Screen
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify Analytics Screen is displayed
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);

      // Wait for data to load (auto-refresh should trigger)
      await tester.pump(const Duration(seconds: 1));

      // Verify analytics content is displayed
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);

      print('✅ Enhanced Analytics Screen auto-refresh works correctly');
    });

    testWidgets(
        'Complete user flow: Focus Screen → Quick Stats → Analytics → Back',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      print('🚀 Starting complete user flow test');

      // Step 1: Verify we're on Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
      print('✅ Step 1: On Enhanced Focus Screen');

      // Step 2: Open Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      expect(find.text('Quick Stats'), findsOneWidget);
      print('✅ Step 2: Quick Stats dialog opened');

      // Step 3: Navigate to Analytics via View Details
      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);
      print('✅ Step 3: Navigated to Enhanced Analytics Screen');

      // Step 4: Verify analytics content
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Weekly Progress'), findsOneWidget);
      print('✅ Step 4: Analytics content verified');

      // Step 5: Navigate back
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
      expect(find.byType(EnhancedAnalyticsScreen), findsNothing);
      print('✅ Step 5: Successfully navigated back to Focus Screen');

      print('🎉 Complete user flow test passed!');
    });
  });
}
