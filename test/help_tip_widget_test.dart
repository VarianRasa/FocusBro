import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/widgets/help_tip_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('only one first-visit help tip is visible at a time',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'show_onboarding': true,
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: const [
              HelpTipWidget(
                tipId: 'first_runtime_tip',
                title: 'First Tip',
                description: 'First tip description',
                child: Text('First child'),
              ),
              HelpTipWidget(
                tipId: 'second_runtime_tip',
                title: 'Second Tip',
                description: 'Second tip description',
                child: Text('Second child'),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    expect(find.textContaining('Tip:'), findsOneWidget);
  });
}
