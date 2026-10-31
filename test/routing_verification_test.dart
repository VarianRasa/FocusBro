import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/theme/theme_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:focusbro/screens/SplashScreen.dart';

void main() {
  group('Routing Verification Tests', () {
    testWidgets('App should display Enhanced Focus Screen as default',
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

      // Wait for splash screen
      await tester.pumpAndSettle();

      // Should find the Enhanced Focus Screen elements
      expect(find.text('Focus'), findsOneWidget); // Bottom nav label
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Should find Enhanced Focus Screen specific elements
      expect(
          find.byIcon(Icons.timer_outlined), findsWidgets); // Timer icon in nav
      expect(find.byIcon(Icons.play_arrow), findsOneWidget); // Play button

      // Should be on the Focus tab (index 0)
      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(0));
    });

    testWidgets(
        'Enhanced Focus Screen should be the first screen in MainScreen',
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

      await tester.pumpAndSettle();

      // Should display Enhanced Focus Screen by default
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Should have bottom navigation
      expect(find.byType(NavigationBar), findsOneWidget);

      // Should be on Focus tab
      final NavigationBar navBar = tester.widget(find.byType(NavigationBar));
      expect(navBar.selectedIndex, equals(0));
    });

    testWidgets('Enhanced Focus Screen should have all expected elements',
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

      await tester.pumpAndSettle();

      // Should find Enhanced Focus Screen specific elements
      expect(find.byIcon(Icons.play_arrow), findsOneWidget); // Main play button
      expect(find.byIcon(Icons.psychology_alt),
          findsOneWidget); // Focus Mode Settings button
      expect(find.byIcon(Icons.tune), findsOneWidget); // Settings button
      expect(find.byIcon(Icons.mic), findsOneWidget); // Voice commands button

      // Should find timer display
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Should find session info
      expect(find.text('Session'), findsOneWidget);
    });

    testWidgets('Navigation should work correctly between screens',
        (WidgetTester tester) async {
      final themeProvider = ThemeProvider();
      final focusProvider = FocusProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: themeProvider),
            ChangeNotifierProvider.value(value: focusProvider),
          ],
          child: const MyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Should start on Focus screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);

      // Tap on Agenda tab
      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();

      // Should navigate to Agenda screen
      expect(find.byType(EnhancedFocusScreen), findsNothing);

      // Tap back on Focus tab
      await tester.tap(find.text('Focus'));
      await tester.pumpAndSettle();

      // Should be back on Enhanced Focus Screen
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
    });

    testWidgets(
        'Splash screen should navigate to MainScreen with Enhanced Focus Screen',
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
            initialRoute: '/',
            routes: {
              '/': (context) => const SplashScreen(),
              '/main': (context) => const MainScreen(),
            },
          ),
        ),
      );

      // Should start with splash screen
      expect(find.byType(SplashScreen), findsOneWidget);

      // Wait for navigation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Should navigate to MainScreen with Enhanced Focus Screen
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(MainScreen), findsOneWidget);
      expect(find.byType(EnhancedFocusScreen), findsOneWidget);
    });
  });
}
