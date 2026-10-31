import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/notification_resources.dart';

void main() {
  test('Android notification services reference bundled drawable resources',
      () {
    final icon = File(
      'android/app/src/main/res/drawable/$androidNotificationIcon.xml',
    );
    expect(icon.existsSync(), isTrue);

    final keepRules =
        File('android/app/src/main/res/raw/keep.xml').readAsStringSync();
    expect(keepRules, contains('@drawable/$androidNotificationIcon'));

    for (final path in [
      'lib/services/advanced_notification_service.dart',
      'lib/services/session_notification_service.dart',
      'lib/services/smart_notification_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, isNot(contains('@mipmap/ic_launcher')));
      expect(
          source, isNot(contains("DrawableResourceAndroidBitmap('@drawable/")));
    }
  });
}
