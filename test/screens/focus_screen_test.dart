import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/theme/theme_provider.dart';

void main() {
  group('FocusScreen Widget Tests', () {
    late FocusProvider focusProvider;
    late ThemeProvider themeProvider;

    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({
        'workDuration': 1500,
        'breakDuration': 300,
        'sessionsUntilLongBreak': 4,
        'currentStreak': 0,
        'longestStreak': 0,
        'totalFocusTime': 0,
        'completedSessions': 0,
        'savedTimers': <String>[],
      });

      focusProvider = FocusProvider();
      themeProvider = ThemeProvider();
      await focusProvider.initialize();
    });

    Widget createTestWidget() {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<FocusProvider>.value(value: focusProvider),
          ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
        ],
        child: MaterialApp(
          home: const EnhancedFocusScreen(),
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
        ),
      );
    }

    group('Timer Display', () {
      testWidgets('should display initial timer value',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('25:00'), findsOneWidget);
      });

      testWidgets('should display session progress',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('Session 1/4'), findsOneWidget);
      });

      testWidgets('should display streak information',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.textContaining('Day Streak'), findsOneWidget);
        expect(find.textContaining('Longest:'), findsOneWidget);
      });
    });

    group('Timer Controls', () {
      testWidgets('should have start and reset buttons',
          (WidgetTester tester) async {
        // Arrange & Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Start'), findsOneWidget);
        expect(find.text('Reset'), findsOneWidget);
      });

      testWidgets('should change start button to pause when timer is running',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.text('Start'));
        await tester.pump();

        // Assert
        expect(find.text('Pause'), findsOneWidget);
        expect(find.text('Start'), findsNothing);
      });

      testWidgets('should reset timer when reset button is tapped',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Start timer first
        await tester.tap(find.text('Start'));
        await tester.pump();

        // Act
        await tester.tap(find.text('Reset'));
        await tester.pump();

        // Assert
        expect(find.text('25:00'), findsOneWidget);
        expect(find.text('Start'), findsOneWidget);
      });
    });

    group('Settings Menu', () {
      testWidgets('should open settings menu when settings button is tapped',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Timer Settings'), findsOneWidget);
      });

      testWidgets('should display work duration setting',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Work Duration'), findsOneWidget);
        expect(find.text('25 minutes'), findsOneWidget);
      });

      testWidgets('should display break duration setting',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Break Duration'), findsOneWidget);
        expect(find.text('5 minutes'), findsOneWidget);
      });

      testWidgets('should display sessions until long break setting',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.settings));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Sessions Until Long Break'), findsOneWidget);
        expect(find.text('4 sessions'), findsOneWidget);
      });
    });

    group('Timer Presets', () {
      testWidgets('should show save timer preset option',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Save Timer Preset'), findsOneWidget);
      });

      testWidgets('should show manage timer presets option',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Manage Timer Presets'), findsOneWidget);
      });

      testWidgets('should open save preset dialog',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Timer Preset'));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Save Timer Preset'), findsWidgets);
        expect(find.text('Preset Name'), findsOneWidget);
        expect(find.text('Save'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
      });
    });

    group('Music Controls', () {
      testWidgets('should show music toggle button',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.byIcon(Icons.music_note), findsOneWidget);
      });

      testWidgets('should show music selection when music button is tapped',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act
        await tester.tap(find.byIcon(Icons.music_note));
        await tester.pumpAndSettle();

        // Assert
        expect(find.text('Background Music'), findsOneWidget);
      });
    });

    group('Accessibility', () {
      testWidgets('should have semantic labels for timer controls',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel('Start timer'), findsOneWidget);
        expect(find.bySemanticsLabel('Reset timer'), findsOneWidget);
      });

      testWidgets('should have semantic labels for timer display',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(
            find.bySemanticsLabel(
                RegExp(r'.*minutes.*seconds.*remaining.*work session')),
            findsOneWidget);
      });

      testWidgets('should have semantic labels for session progress',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        expect(find.bySemanticsLabel(RegExp(r'Session \d+ of \d+')),
            findsOneWidget);
      });
    });

    group('Theme Support', () {
      testWidgets('should adapt to light theme', (WidgetTester tester) async {
        // Arrange
        themeProvider.setThemeMode(ThemeMode.light);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.theme?.brightness, equals(Brightness.light));
      });

      testWidgets('should adapt to dark theme', (WidgetTester tester) async {
        // Arrange
        themeProvider.setThemeMode(ThemeMode.dark);
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Assert
        final materialApp =
            tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(materialApp.darkTheme?.brightness, equals(Brightness.dark));
      });
    });

    group('Error Handling', () {
      testWidgets('should handle invalid timer preset gracefully',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - Try to save preset with empty name
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Timer Preset'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        // Assert - Should show warning message
        expect(
            find.textContaining('Please enter a preset name'), findsOneWidget);
      });
    });

    group('State Persistence', () {
      testWidgets('should maintain timer state during widget rebuilds',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - Start timer
        await tester.tap(find.text('Start'));
        await tester.pump();

        // Trigger rebuild
        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        // Assert - Timer should still be running
        expect(find.text('Pause'), findsOneWidget);
      });
    });

    group('Performance', () {
      testWidgets('should render within reasonable time',
          (WidgetTester tester) async {
        // Arrange
        final stopwatch = Stopwatch()..start();

        // Act
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        stopwatch.stop();

        // Assert - Should render in under 1 second
        expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      });

      testWidgets('should handle rapid button taps without errors',
          (WidgetTester tester) async {
        // Arrange
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Act - Rapidly tap start/pause button
        for (int i = 0; i < 10; i++) {
          await tester.tap(find.text(i % 2 == 0 ? 'Start' : 'Pause'));
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Assert - Should not throw any errors
        expect(tester.takeException(), isNull);
      });
    });
  });
}
