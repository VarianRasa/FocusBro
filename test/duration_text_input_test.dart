import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';

void main() {
  group('Duration Text Input Tests', () {
    late FocusProvider focusProvider;

    setUp(() {
      focusProvider = FocusProvider();
    });

    testWidgets('Text input allows direct duration entry',
        (WidgetTester tester) async {
      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find and tap on a text field (work duration)
      final textField = find.byType(TextFormField).first;
      expect(textField, findsOneWidget);

      // Test 1: Enter valid duration (30 minutes)
      await tester.enterText(textField, '30');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Verify the duration was set correctly
      expect(focusProvider.workDuration, equals(30 * 60));
    });

    testWidgets('Text input validates minimum duration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Enter below minimum (0 minutes)
      await tester.enterText(textField, '0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should be clamped to minimum (1 minute)
      expect(focusProvider.workDuration, equals(60));
    });

    testWidgets('Text input validates maximum duration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Enter above maximum (100 minutes)
      await tester.enterText(textField, '100');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should be clamped to maximum (60 minutes)
      expect(focusProvider.workDuration, equals(60 * 60));
    });

    testWidgets('Text input handles invalid input gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Set initial duration
      focusProvider.setWorkDuration(25 * 60);

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Enter invalid text
      await tester.enterText(textField, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should maintain previous valid value
      expect(focusProvider.workDuration, equals(25 * 60));
    });

    testWidgets('Text input handles empty input', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Clear field and submit
      await tester.enterText(textField, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should default to minimum (1 minute)
      expect(focusProvider.workDuration, equals(60));
    });

    testWidgets('Plus/minus buttons still work alongside text input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Set initial duration
      focusProvider.setWorkDuration(25 * 60);

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find plus button and tap it
      final plusButton = find.byIcon(Icons.add).first;
      await tester.tap(plusButton);
      await tester.pumpAndSettle();

      // Should increment by 1 minute
      expect(focusProvider.workDuration, equals(26 * 60));

      // Find minus button and tap it
      final minusButton = find.byIcon(Icons.remove).first;
      await tester.tap(minusButton);
      await tester.pumpAndSettle();

      // Should decrement by 1 minute
      expect(focusProvider.workDuration, equals(25 * 60));
    });

    testWidgets('Text input works for both work and break durations',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find all text fields (work and break duration)
      final textFields = find.byType(TextFormField);
      expect(textFields, findsAtLeastNWidgets(2));

      // Test work duration field (first field)
      await tester.enterText(textFields.first, '45');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(focusProvider.workDuration, equals(45 * 60));

      // Test break duration field (second field)
      await tester.enterText(textFields.at(1), '15');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(focusProvider.breakDuration, equals(15 * 60));
    });

    testWidgets('Text input shows validation feedback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Enter value above maximum
      await tester.enterText(textField, '100');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should show validation feedback (SnackBar)
      expect(find.text('Maximum duration is 60 minutes'), findsOneWidget);
    });

    testWidgets('Text input accepts only numeric input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const EnhancedFocusScreen(),
          ),
        ),
      );

      // Open Quick Settings modal
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      // Find text field
      final textField = find.byType(TextFormField).first;

      // Test: Try to enter non-numeric characters
      await tester.enterText(textField, 'abc123def');

      // The input formatters should filter out non-numeric characters
      // So entering 'abc123def' should result in '123' being entered
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should have parsed the numeric part (123 minutes)
      // But since 123 > 60, it should be clamped to 60
      expect(focusProvider.workDuration, equals(60 * 60));
    });
  });
}
