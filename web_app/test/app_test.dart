import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro_web/src/core/app.dart';

void main() {
  testWidgets('renders the FocusBro web home page', (tester) async {
    await tester.pumpWidget(const FocusBroWebApp());

    expect(find.text('FocusBro'), findsOneWidget);
    expect(find.text('Make room for focused work'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);

    await tester.tap(find.text('Start a focus session'));
    await tester.pump();
    expect(find.text('Pause session'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('24:59'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('Start a focus session'), findsOneWidget);
  });
}
