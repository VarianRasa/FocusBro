import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';

void main() {
  group('Enhanced Focus Screen Fixes Tests', () {
    late FocusProvider focusProvider;

    setUp(() {
      focusProvider = FocusProvider();
    });

    testWidgets('Timer Presets Issue - Short break times work correctly',
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

      // Test 1: Apply "Short Focus" preset (15min work, 3min break)
      focusProvider.setWorkDuration(15 * 60); // 15 minutes
      focusProvider.setBreakDuration(3 * 60); // 3 minutes

      // Verify work duration is set correctly
      expect(focusProvider.workDuration, equals(15 * 60));
      expect(focusProvider.breakDuration, equals(3 * 60));

      // Test 2: Apply "Quick Break" preset (10min work, 2min break)
      focusProvider.setWorkDuration(10 * 60); // 10 minutes
      focusProvider.setBreakDuration(2 * 60); // 2 minutes

      // Verify break duration is set correctly (should be 2 minutes, not default 5)
      expect(focusProvider.workDuration, equals(10 * 60));
      expect(focusProvider.breakDuration, equals(2 * 60));

      // Test 3: Test skip session uses correct durations
      focusProvider.skipSession();

      // After skipping work session, should be in break time with correct duration
      expect(focusProvider.isWorkTime, isFalse);
      expect(
          focusProvider.timeLeft, equals(2 * 60)); // Should be 2 minutes, not 5
    });

    testWidgets('Session Editing Functionality - Can modify total sessions',
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

      // Test 1: Default total sessions
      expect(focusProvider.totalSessions, equals(4));

      // Test 2: Increase total sessions
      focusProvider.setTotalSessions(6);
      expect(focusProvider.totalSessions, equals(6));

      // Test 3: Decrease total sessions
      focusProvider.setTotalSessions(2);
      expect(focusProvider.totalSessions, equals(2));

      // Test 4: Test boundary conditions
      focusProvider.setTotalSessions(0); // Should clamp to 1
      expect(focusProvider.totalSessions, equals(1));

      focusProvider.setTotalSessions(25); // Should clamp to 20
      expect(focusProvider.totalSessions, equals(20));

      // Test 5: Test completed sessions reset when exceeding new total
      focusProvider.setTotalSessions(4);
      // Simulate completing 3 sessions
      for (int i = 0; i < 3; i++) {
        focusProvider.skipSession(); // Skip work session
        focusProvider.skipSession(); // Skip break session
      }
      expect(focusProvider.completedSessions, equals(3));

      // Set total sessions to 2 (less than completed)
      focusProvider.setTotalSessions(2);
      expect(focusProvider.completedSessions, equals(0)); // Should reset
    });

    testWidgets('Reset Button Functionality - Properly resets all state',
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

      // Test 1: Set up some state to reset
      focusProvider.setWorkDuration(30 * 60); // 30 minutes
      focusProvider.setBreakDuration(10 * 60); // 10 minutes
      focusProvider.setTotalSessions(6);

      // Start timer and complete some sessions
      focusProvider.toggleTimer();
      expect(focusProvider.isRunning, isTrue);

      // Skip a few sessions to change state
      focusProvider.skipSession(); // Complete work session 1
      focusProvider.skipSession(); // Complete break session 1
      focusProvider.skipSession(); // Complete work session 2

      expect(focusProvider.completedSessions, equals(2));
      expect(focusProvider.isWorkTime, isFalse); // Should be in break time

      // Test 2: Reset timer
      focusProvider.resetTimer();

      // Verify all state is reset correctly
      expect(focusProvider.isRunning, isFalse);
      expect(focusProvider.isWorkTime, isTrue);
      expect(
          focusProvider.timeLeft, equals(30 * 60)); // Should be work duration
      expect(focusProvider.progress, equals(0.0));
      expect(focusProvider.completedSessions, equals(0)); // Should reset to 0

      // Test 3: Verify timer durations are preserved
      expect(focusProvider.workDuration, equals(30 * 60));
      expect(focusProvider.breakDuration, equals(10 * 60));
      expect(focusProvider.totalSessions, equals(6));
    });

    test('Timer Presets Configuration - All presets have correct values', () {
      // Test preset configurations
      final presets = [
        {'name': 'Pomodoro', 'work': 25, 'break': 5, 'sessions': 4},
        {'name': 'Short Focus', 'work': 15, 'break': 3, 'sessions': 6},
        {'name': 'Deep Work', 'work': 45, 'break': 10, 'sessions': 3},
        {'name': 'Study Session', 'work': 30, 'break': 5, 'sessions': 4},
        {'name': 'Quick Break', 'work': 10, 'break': 2, 'sessions': 8},
      ];

      for (final preset in presets) {
        // Apply preset
        focusProvider.setWorkDuration((preset['work'] as int) * 60);
        focusProvider.setBreakDuration((preset['break'] as int) * 60);
        focusProvider.setTotalSessions(preset['sessions'] as int);

        // Verify preset is applied correctly
        expect(
            focusProvider.workDuration, equals((preset['work'] as int) * 60));
        expect(
            focusProvider.breakDuration, equals((preset['break'] as int) * 60));
        expect(focusProvider.totalSessions, equals(preset['sessions'] as int));

        // Test that short break times work (especially 2 and 3 minute breaks)
        if ((preset['break'] as int) < 5) {
          focusProvider.skipSession(); // Go to break time
          expect(focusProvider.timeLeft, equals((preset['break'] as int) * 60));
          focusProvider.resetTimer(); // Reset for next test
        }
      }
    });

    test('Edge Cases - Timer handles minimum durations correctly', () {
      // Test 1: Set minimum work duration (1 minute)
      focusProvider.setWorkDuration(60); // 1 minute
      expect(focusProvider.workDuration, equals(60));

      // Test 2: Set minimum break duration (1 minute)
      focusProvider.setBreakDuration(60); // 1 minute
      expect(focusProvider.breakDuration, equals(60));

      // Test 3: Test skip session with minimum durations
      focusProvider.skipSession();
      expect(focusProvider.timeLeft, equals(60)); // Should be 1 minute break

      // Test 4: Test reset with minimum durations
      focusProvider.resetTimer();
      expect(focusProvider.timeLeft, equals(60)); // Should be 1 minute work
      expect(focusProvider.isWorkTime, isTrue);
    });
  });
}
