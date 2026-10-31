import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('cold start reaches and visits every primary destination',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('has_seen_onboarding', true);
    await preferences.setBool('show_onboarding', false);
    await preferences.setString('default_view', 'focus');

    app.main();
    await waitFor(tester, find.byKey(const ValueKey('main_navigation')));

    const destinations = ['focus', 'agenda', 'notes', 'pdf', 'settings'];
    for (final destination in destinations) {
      await tester.tap(find.byKey(ValueKey('nav_$destination')));
      await tester.pump(const Duration(milliseconds: 750));

      final navigation = tester.widget<NavigationBar>(
        find.byKey(const ValueKey('main_navigation')),
      );
      expect(navigation.selectedIndex, destinations.indexOf(destination));
    }
  });
}
