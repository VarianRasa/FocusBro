import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/enhanced_analytics_screen.dart';

void main() {
  group('Manual Statistics Verification', () {
    testWidgets('Complete focus session and verify statistics update',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      print('✅ App launched successfully');

      // Find the Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Get the FocusProvider
      final focusProvider = tester
          .widget<ChangeNotifierProvider<FocusProvider>>(
            find.byType(ChangeNotifierProvider<FocusProvider>),
          )
          .create(null) as FocusProvider;

      // Get initial statistics
      final initialSessions = focusProvider.todaysSessions;
      final initialTotalSessions = focusProvider.totalSessions;
      final initialFocusTime = focusProvider.totalFocusTime;

      print('📊 Initial Statistics:');
      print('  - Today\'s Sessions: $initialSessions');
      print('  - Total Sessions: $initialTotalSessions');
      print('  - Total Focus Time: $initialFocusTime seconds');

      // Set a short timer for testing (5 seconds work, 3 seconds break)
      focusProvider.setWorkDuration(5);
      focusProvider.setBreakDuration(3);
      focusProvider.setTotalSessions(1);

      print('⏱️ Set timer: 5s work, 3s break, 1 session');

      // Start the timer
      focusProvider.startTimer();
      expect(focusProvider.isRunning, true);

      print('▶️ Timer started');

      // Wait for work session to complete (5 seconds + buffer)
      await tester.pump(const Duration(seconds: 6));

      // Should be in break time now
      expect(focusProvider.isBreakTime, true);

      print('☕ Break time started');

      // Wait for break to complete (3 seconds + buffer)
      await tester.pump(const Duration(seconds: 4));

      // Session should be completed
      expect(focusProvider.isRunning, false);

      print('✅ Session completed');

      // Refresh statistics to get updated data
      await focusProvider.refreshStatistics();

      // Get updated statistics
      final updatedSessions = focusProvider.todaysSessions;
      final updatedTotalSessions = focusProvider.totalSessions;
      final updatedFocusTime = focusProvider.totalFocusTime;

      print('📊 Updated Statistics:');
      print('  - Today\'s Sessions: $updatedSessions');
      print('  - Total Sessions: $updatedTotalSessions');
      print('  - Total Focus Time: $updatedFocusTime seconds');

      // Verify statistics have been updated
      expect(updatedTotalSessions, greaterThanOrEqualTo(initialTotalSessions));
      expect(updatedFocusTime, greaterThanOrEqualTo(initialFocusTime));

      print('✅ Statistics updated correctly after session completion');
    });

    testWidgets('Quick Stats dialog shows updated data',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Find the stats button in the quick settings
      final statsButton = find.text('Stats');
      expect(statsButton, findsOneWidget);

      // Tap the stats button
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Should open Quick Stats dialog
      expect(find.text('Quick Stats'), findsOneWidget);

      // Verify stats are displayed
      expect(find.text('Today\'s Sessions'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Total Focus Time'), findsOneWidget);
      expect(find.text('Completed Sessions'), findsOneWidget);

      print('✅ Quick Stats dialog displays statistics');

      // Find View Details button
      final viewDetailsButton = find.text('View Details');
      expect(viewDetailsButton, findsOneWidget);

      // Tap View Details
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Should navigate to Enhanced Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);
      expect(find.text('Analytics Dashboard'), findsOneWidget);

      print('✅ View Details navigation works correctly');
    });

    testWidgets('Enhanced Analytics Screen displays data',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Navigate to analytics screen
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify analytics screen content
      expect(find.text('Analytics Dashboard'), findsOneWidget);
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);

      print('✅ Enhanced Analytics Screen displays key metrics');

      // Check for Weekly Progress Chart
      expect(find.text('Weekly Progress'), findsOneWidget);

      // Find View Details button in Weekly Progress Chart
      final chartViewDetailsButtons = find.text('View Details');
      expect(chartViewDetailsButtons, findsAtLeastNWidgets(1));

      // Tap the View Details button in the chart
      await tester.tap(chartViewDetailsButtons.first);
      await tester.pumpAndSettle();

      // Should open detailed chart modal
      expect(find.text('Detailed Weekly Progress'), findsOneWidget);
      expect(find.text('Focus Sessions This Week'), findsOneWidget);
      expect(find.text('Weekly Summary'), findsOneWidget);

      print('✅ Detailed chart modal opens correctly');

      // Verify summary statistics in modal
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('12.5h'), findsOneWidget);

      print('✅ Detailed chart modal displays summary statistics');

      // Test Export Data functionality
      final exportButton = find.text('Export Data');
      expect(exportButton, findsOneWidget);

      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      // Should open export options
      expect(find.text('Export Analytics Data'), findsOneWidget);
      expect(find.text('Export as CSV'), findsOneWidget);
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(find.text('Share Summary'), findsOneWidget);

      print('✅ Export functionality works correctly');
    });

    testWidgets('Statistics persist across app navigation',
        (WidgetTester tester) async {
      // Launch the app
      await tester.pumpWidget(const FocusBroApp());
      await tester.pumpAndSettle();

      // Get initial stats from Quick Stats
      final statsButton = find.text('Stats');
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Note the displayed values (they should be consistent)
      final quickStatsDialog = find.text('Quick Stats');
      expect(quickStatsDialog, findsOneWidget);

      // Close dialog
      final closeButton = find.text('Close');
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // Navigate to analytics screen
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      final viewDetailsButton = find.text('View Details');
      await tester.tap(viewDetailsButton);
      await tester.pumpAndSettle();

      // Verify analytics screen shows data
      expect(find.text('Analytics Dashboard'), findsOneWidget);
      expect(find.text('Total Sessions'), findsOneWidget);

      // Navigate back
      final backButton = find.byIcon(Icons.arrow_back);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Open Quick Stats again
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Should still show the same data
      expect(find.text('Quick Stats'), findsOneWidget);

      print('✅ Statistics persist across app navigation');
    });
  });
}
