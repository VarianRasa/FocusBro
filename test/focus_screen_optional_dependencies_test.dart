import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/screens/enhanced_focus_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('focus screen renders without optional task and note providers',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FocusProvider(),
          child: const EnhancedFocusScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('focus_start_pause')), findsOneWidget);
  });
}
