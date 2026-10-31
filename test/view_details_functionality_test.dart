import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/enhanced_analytics_screen.dart';
import 'package:focusbro/providers/focus_provider.dart';

void main() {
  group('View Details Functionality Tests', () {
    testWidgets(
        'Enhanced Focus Screen - View Details button should navigate to Analytics',
        (WidgetTester tester) async {
      final focusProvider = FocusProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pump();

      // Find the Quick Stats button (stats icon)
      final statsButton = find.byIcon(Icons.analytics);
      expect(statsButton, findsOneWidget);

      // Tap the stats button to open Quick Stats dialog
      await tester.tap(statsButton);
      await tester.pumpAndSettle();

      // Should find the Quick Stats dialog
      expect(find.text('Quick Stats'), findsOneWidget);

      // Should find the View Details button
      expect(find.text('View Details'), findsOneWidget);

      // Tap View Details button
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Should navigate to Enhanced Analytics Screen
      expect(find.byType(EnhancedAnalyticsScreen), findsOneWidget);

      print(
          '✅ Enhanced Focus Screen - View Details navigation works correctly');
    });

    testWidgets(
        'Enhanced Analytics Screen - View Details button should open detailed chart modal',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EnhancedAnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Find the View Details button in the Weekly Progress Chart
      final viewDetailsButtons = find.text('View Details');
      expect(viewDetailsButtons, findsAtLeastNWidgets(1));

      // Tap the first View Details button (should be in Weekly Progress Chart)
      await tester.tap(viewDetailsButtons.first);
      await tester.pumpAndSettle();

      // Should open the detailed chart modal
      expect(find.text('Detailed Weekly Progress'), findsOneWidget);
      expect(find.text('Focus Sessions This Week'), findsOneWidget);
      expect(find.text('Weekly Summary'), findsOneWidget);

      // Should find export button
      expect(find.text('Export Data'), findsOneWidget);

      // Should find close button
      expect(find.text('Close'), findsOneWidget);

      print('✅ Enhanced Analytics Screen - View Details modal opens correctly');

      // Test Export Data functionality
      await tester.tap(find.text('Export Data'));
      await tester.pumpAndSettle();

      // Should open export options bottom sheet
      expect(find.text('Export Analytics Data'), findsOneWidget);
      expect(find.text('Export as CSV'), findsOneWidget);
      expect(find.text('Export as PDF'), findsOneWidget);
      expect(find.text('Share Summary'), findsOneWidget);

      print('✅ Export Data functionality works correctly');

      // Test CSV export
      await tester.tap(find.text('Export as CSV'));
      await tester.pumpAndSettle();

      // Should show coming soon message
      expect(find.text('📊 CSV export feature coming soon!'), findsOneWidget);

      print('✅ CSV export shows coming soon message');
    });

    testWidgets('Enhanced Analytics Screen - Export functionality should work',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EnhancedAnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Open detailed chart modal first
      final viewDetailsButtons = find.text('View Details');
      await tester.tap(viewDetailsButtons.first);
      await tester.pumpAndSettle();

      // Test Export Data functionality
      await tester.tap(find.text('Export Data'));
      await tester.pumpAndSettle();

      // Test PDF export
      await tester.tap(find.text('Export as PDF'));
      await tester.pumpAndSettle();

      // Should show coming soon message
      expect(find.text('📄 PDF export feature coming soon!'), findsOneWidget);

      print('✅ PDF export shows coming soon message');

      // Reopen export dialog
      await tester.tap(find.text('Export Data'));
      await tester.pumpAndSettle();

      // Test Share Summary
      await tester.tap(find.text('Share Summary'));
      await tester.pumpAndSettle();

      // Should show coming soon message
      expect(find.text('📤 Share feature coming soon!'), findsOneWidget);

      print('✅ Share Summary shows coming soon message');
    });

    testWidgets('Detailed chart modal should display summary statistics',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EnhancedAnalyticsScreen(),
        ),
      );

      await tester.pump();

      // Open detailed chart modal
      final viewDetailsButtons = find.text('View Details');
      await tester.tap(viewDetailsButtons.first);
      await tester.pumpAndSettle();

      // Should display summary statistics
      expect(find.text('Total Sessions'), findsOneWidget);
      expect(find.text('38'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
      expect(find.text('12.5h'), findsOneWidget);
      expect(find.text('Completion Rate'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.text('Best Day'), findsOneWidget);
      expect(find.text('Saturday'), findsOneWidget);

      print('✅ Detailed chart modal displays summary statistics correctly');

      // Test close functionality
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Modal should be closed
      expect(find.text('Detailed Weekly Progress'), findsNothing);

      print('✅ Close button works correctly');
    });
  });
}
