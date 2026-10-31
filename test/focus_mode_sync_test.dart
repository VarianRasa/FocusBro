import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/providers/focus_provider.dart';

void main() {
  group('Focus Mode Synchronization Tests', () {
    testWidgets('Focus Mode toggle button should sync with settings dialog',
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

      // Initially, focus mode should be disabled
      expect(focusProvider.isFocusModeEnabled, false);

      // Find the focus mode toggle button
      final toggleButton = find.byTooltip('Toggle Focus Mode');
      expect(toggleButton, findsOneWidget);

      // Find the focus mode settings button
      final settingsButton = find.byTooltip('Focus Mode Settings');
      expect(settingsButton, findsOneWidget);

      // Open Focus Mode Settings dialog
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Should find the dialog
      expect(find.text('Focus Mode Settings'), findsOneWidget);

      // Initially should show "Enable Focus Mode" button
      expect(find.text('Enable Focus Mode'), findsOneWidget);
      expect(find.text('Disable Focus Mode'), findsNothing);

      // Tap Enable Focus Mode in dialog
      await tester.tap(find.text('Enable Focus Mode'));
      await tester.pumpAndSettle();

      // Dialog should close and focus mode should be enabled
      expect(find.text('Focus Mode Settings'), findsNothing);
      expect(focusProvider.isFocusModeEnabled, true);

      print('✅ Focus Mode enabled through dialog - Provider state updated');

      // Open settings dialog again
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Now should show "Disable Focus Mode" button
      expect(find.text('Disable Focus Mode'), findsOneWidget);
      expect(find.text('Enable Focus Mode'), findsNothing);

      // Tap Disable Focus Mode in dialog
      await tester.tap(find.text('Disable Focus Mode'));
      await tester.pumpAndSettle();

      // Dialog should close and focus mode should be disabled
      expect(find.text('Focus Mode Settings'), findsNothing);
      expect(focusProvider.isFocusModeEnabled, false);

      print('✅ Focus Mode disabled through dialog - Provider state updated');
    });

    testWidgets('Focus Mode toggle button icon should reflect current state',
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

      // Initially, focus mode should be disabled
      expect(focusProvider.isFocusModeEnabled, false);

      // Check that the toggle button shows disabled state
      final toggleButton = find.byTooltip('Toggle Focus Mode');
      expect(toggleButton, findsOneWidget);

      // Get the IconButton widget
      final IconButton iconButton = tester.widget(toggleButton);
      final Icon icon = iconButton.icon as Icon;

      // Should show do_not_disturb_off icon when disabled
      expect(icon.icon, Icons.do_not_disturb_off);

      // Toggle focus mode through the toggle button
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      // Focus mode should now be enabled
      expect(focusProvider.isFocusModeEnabled, true);

      // Check that the toggle button shows enabled state
      final IconButton enabledIconButton = tester.widget(toggleButton);
      final Icon enabledIcon = enabledIconButton.icon as Icon;

      // Should show do_not_disturb_on icon when enabled
      expect(enabledIcon.icon, Icons.do_not_disturb_on);

      print('✅ Toggle button icon correctly reflects focus mode state');
    });

    testWidgets(
        'Focus Mode state should remain consistent across dialog and toggle',
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

      // Test sequence: Toggle -> Dialog -> Toggle -> Dialog

      // 1. Enable through toggle button
      final toggleButton = find.byTooltip('Toggle Focus Mode');
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(focusProvider.isFocusModeEnabled, true);

      // 2. Check dialog shows correct state
      final settingsButton = find.byTooltip('Focus Mode Settings');
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(find.text('Disable Focus Mode'), findsOneWidget);
      expect(find.text('Enable Focus Mode'), findsNothing);

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // 3. Disable through toggle button
      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(focusProvider.isFocusModeEnabled, false);

      // 4. Check dialog shows correct state
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      expect(find.text('Enable Focus Mode'), findsOneWidget);
      expect(find.text('Disable Focus Mode'), findsNothing);

      print('✅ Focus Mode state remains consistent across dialog and toggle');
    });
  });
}
