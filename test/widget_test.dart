import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart';
import 'package:focusbro/screens/language_selection_screen.dart';
import 'package:focusbro/theme/theme_provider.dart';

void main() {
  testWidgets('FocusBro app exposes the configured app title', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'FocusBro');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
