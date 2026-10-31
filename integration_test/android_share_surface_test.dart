import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android native share sheet accepts local FocusBro content',
      (tester) async {
    await Share.share(
      'FocusBro Android local share verification',
      subject: 'FocusBro',
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
