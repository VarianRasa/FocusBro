import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/services/backup_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('rejects corrupted table payload before restore starts', () async {
    final file = File(
      '${Directory.systemTemp.path}/focusbro_corrupted_backup_test.json',
    );

    await file.writeAsString(
      jsonEncode({
        'version': 1,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'data': {
          'tasks': 'not-a-list',
        },
      }),
    );

    final result = await BackupService.instance.restoreFromBackup(
      filePath: file.path,
    );

    expect(result.success, isFalse);
    expect(result.error, contains('corrupted'));

    if (await file.exists()) {
      await file.delete();
    }
  });
}
