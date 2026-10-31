import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android local media uses valid modern permissions', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final pdfReader =
        File('lib/screens/enhanced_pdf_reader_screen.dart').readAsStringSync();

    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, isNot(contains('android.permission.MICROPHONE')));
    expect(pdfReader, isNot(contains('Permission.storage.request()')));
    expect(pdfReader, isNot(contains('/storage/emulated/0/Download')));
  });
}
