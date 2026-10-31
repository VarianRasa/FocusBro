import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/providers/note_provider.dart';
import 'package:focusbro/providers/task_provider.dart';
import 'package:focusbro/screens/language_selection_screen.dart';
import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'default_view': 'focus',
    });
  });

  testWidgets('primary destinations expose stable Android QA keys',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => FocusProvider()),
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => NoteProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
          ChangeNotifierProvider.value(value: AppLockService.instance),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const ValueKey('main_navigation')), findsOneWidget);
    for (final destination in ['focus', 'agenda', 'notes', 'pdf', 'settings']) {
      expect(find.byKey(ValueKey('nav_$destination')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(
      find.byKey(const ValueKey('main_navigation')),
    );
    expect(navigation.selectedIndex, 4);
  });
}
