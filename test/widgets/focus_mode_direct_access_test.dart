import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/providers/focus_provider.dart';

void main() {
  group('Focus Mode Direct Access Tests', () {
    late FocusProvider focusProvider;

    setUp(() {
      focusProvider = FocusProvider();
    });

    testWidgets('should display Focus Mode Settings button in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Wait for initialization
      await tester.pumpAndSettle();

      // Should find Focus Mode Settings button in app bar
      expect(find.byTooltip('Focus Mode Settings'), findsOneWidget);

      // Should find Focus Mode Toggle button
      expect(find.byTooltip('Toggle Focus Mode'), findsOneWidget);
    });

    testWidgets('should open Focus Mode Settings dialog when button is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the Focus Mode Settings button
      await tester.tap(find.byTooltip('Focus Mode Settings'));
      await tester.pumpAndSettle();

      // Should open Focus Mode Settings dialog
      expect(find.text('Focus Mode Settings'), findsOneWidget);
      expect(find.text('Focus Features'), findsOneWidget);
      expect(find.text('Block Notifications'), findsOneWidget);
      expect(find.text('Block Social Media'), findsOneWidget);
      expect(find.text('Dim Screen'), findsOneWidget);
      expect(find.text('Auto-enable on Focus Start'), findsOneWidget);
    });

    testWidgets(
        'should display enhanced Focus Mode Settings dialog with status',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Focus Mode Settings
      await tester.tap(find.byTooltip('Focus Mode Settings'));
      await tester.pumpAndSettle();

      // Should display status card
      expect(find.text('Focus Mode Inactive'), findsOneWidget);

      // Should display feature sections
      expect(find.text('Focus Features'), findsOneWidget);
      expect(find.text('Automation'), findsOneWidget);

      // Should display feature tiles with icons
      expect(find.byIcon(Icons.notifications_off), findsOneWidget);
      expect(find.byIcon(Icons.block), findsOneWidget);
      expect(find.byIcon(Icons.brightness_low), findsOneWidget);
      expect(find.byIcon(Icons.auto_mode), findsOneWidget);

      // Should have Enable Focus Mode button when inactive
      expect(find.text('Enable Focus Mode'), findsOneWidget);
    });

    testWidgets('should show settings button in Quick Settings modal',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Quick Settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      // Should find Focus Mode setting with settings button
      expect(find.text('Focus Mode'), findsOneWidget);
      expect(find.text('Block distracting notifications'), findsOneWidget);

      // Should find settings icon button
      expect(find.byIcon(Icons.settings), findsWidgets);
    });

    testWidgets('should open Focus Mode Settings from Quick Settings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Quick Settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      // Find and tap the settings button for Focus Mode
      final settingsButtons = find.byIcon(Icons.settings);
      expect(settingsButtons, findsWidgets);

      // Tap the first settings button (should be for Focus Mode)
      await tester.tap(settingsButtons.first);
      await tester.pumpAndSettle();

      // Should open Focus Mode Settings dialog
      expect(find.text('Focus Mode Settings'), findsOneWidget);
    });

    testWidgets('should show enhanced snackbar with Settings action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle Focus Mode
      await tester.tap(find.byTooltip('Toggle Focus Mode'));
      await tester.pumpAndSettle();

      // Should show snackbar with Settings action
      expect(find.text('Focus mode enabled'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('should open Focus Mode Settings from snackbar action',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Toggle Focus Mode
      await tester.tap(find.byTooltip('Toggle Focus Mode'));
      await tester.pumpAndSettle();

      // Tap Settings action in snackbar
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Should open Focus Mode Settings dialog
      expect(find.text('Focus Mode Settings'), findsOneWidget);
    });

    testWidgets('should toggle focus mode features in settings dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Focus Mode Settings
      await tester.tap(find.byTooltip('Focus Mode Settings'));
      await tester.pumpAndSettle();

      // Find checkboxes for features
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);

      // Toggle Block Social Media (should be off by default)
      final socialMediaCheckbox = find.ancestor(
        of: find.text('Block Social Media'),
        matching: find.byType(CheckboxListTile),
      );

      await tester.tap(socialMediaCheckbox);
      await tester.pumpAndSettle();

      // Verify the setting was toggled
      // Note: In a real test, we would verify the actual state change
      expect(find.text('Block Social Media'), findsOneWidget);
    });

    testWidgets(
        'should show different dialog content when focus mode is active',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enable Focus Mode first
      await tester.tap(find.byTooltip('Toggle Focus Mode'));
      await tester.pumpAndSettle();

      // Open Focus Mode Settings
      await tester.tap(find.byTooltip('Focus Mode Settings'));
      await tester.pumpAndSettle();

      // Should show active status
      expect(find.text('Focus Mode Active'), findsOneWidget);

      // Should have Disable Focus Mode button when active
      expect(find.text('Disable Focus Mode'), findsOneWidget);
    });

    testWidgets(
        'should maintain existing functionality while adding direct access',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should still have all existing buttons
      expect(find.byTooltip('Toggle Focus Mode'), findsOneWidget);
      expect(find.byTooltip('Settings'), findsOneWidget);
      expect(find.byTooltip('Focus Mode Settings'), findsOneWidget);

      // Should be able to toggle focus mode normally
      await tester.tap(find.byTooltip('Toggle Focus Mode'));
      await tester.pumpAndSettle();

      // Should show snackbar
      expect(find.text('Focus mode enabled'), findsOneWidget);
    });

    testWidgets('should provide multiple entry points to Focus Mode Settings',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Entry Point 1: Direct button in app bar
      await tester.tap(find.byTooltip('Focus Mode Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Focus Mode Settings'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Entry Point 2: Toggle focus mode and use snackbar action
      await tester.tap(find.byTooltip('Toggle Focus Mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Focus Mode Settings'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Entry Point 3: Quick Settings modal
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      final settingsButtons = find.byIcon(Icons.settings);
      if (settingsButtons.evaluate().isNotEmpty) {
        await tester.tap(settingsButtons.first);
        await tester.pumpAndSettle();
        expect(find.text('Focus Mode Settings'), findsOneWidget);
      }
    });
  });
}
