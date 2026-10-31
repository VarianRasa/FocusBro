import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/theme/theme_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';

void main() {
  group('Simple Routing Tests', () {
    testWidgets('App should start with Enhanced Focus Screen visible',
        (WidgetTester tester) async {
      // Initialize providers
      final themeProvider = ThemeProvider();
      final focusProvider = FocusProvider();

      // Build the app
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: focusProvider),
          ],
          child: const MyApp(),
        ),
      );

      // Wait for splash screen to complete
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      // Wait for MainScreen initialization
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Check if Enhanced Focus Screen is present
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Check for key Enhanced Focus Screen elements
      expect(find.byIcon(Icons.play_arrow), findsOneWidget); // Main play button
      expect(find.byIcon(Icons.psychology_alt),
          findsOneWidget); // Focus Mode Settings button

      // Check for bottom navigation
      expect(find.byType(NavigationBar), findsOneWidget);

      // Check that we're on the Focus tab (first tab)
      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(0));

      print(
          '✅ Enhanced Focus Screen is correctly displayed as the default screen');
    });

    testWidgets('Enhanced Focus Screen should be accessible directly',
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

      // Should find Enhanced Focus Screen elements
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.psychology_alt), findsOneWidget);
      expect(find.byIcon(Icons.tune),
          findsAtLeastNWidgets(1)); // May have multiple settings icons

      print('✅ Enhanced Focus Screen works correctly when accessed directly');
    });

    testWidgets('MainScreen should default to Enhanced Focus Screen',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      final focusProvider = FocusProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: focusProvider),
          ],
          child: MaterialApp(
            home: const MainScreen(),
          ),
        ),
      );

      await tester.pump();

      // Wait for MainScreen initialization
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      // Should display Enhanced Focus Screen by default
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Should have bottom navigation
      expect(find.byType(NavigationBar), findsOneWidget);

      // Should be on Focus tab (index 0)
      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(0));

      print('✅ MainScreen correctly defaults to Enhanced Focus Screen');
    });
  });
}
