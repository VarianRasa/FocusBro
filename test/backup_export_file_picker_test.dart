import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focusbro/services/backup_service.dart';

class CapturingFilePicker extends FilePicker {
  Uint8List? savedBytes;
  final String destinationPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}focusbro_export_test.json';

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    savedBytes = bytes;
    return destinationPath;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('backup export sends backup bytes to the mobile file picker', () async {
    await Directory('.dart_tool/test_storage').create(recursive: true);
    final filePicker = CapturingFilePicker();
    FilePicker.platform = filePicker;

    final created = await BackupService.instance.createBackup();
    expect(created.success, isTrue);

    expect(await BackupService.instance.exportBackup(), isTrue);
    expect(filePicker.savedBytes, isNotNull);
    expect(
      jsonDecode(utf8.decode(filePicker.savedBytes!)),
      isA<Map<String, dynamic>>(),
    );

    final exportedFile = File(filePicker.destinationPath);
    if (await exportedFile.exists()) {
      await exportedFile.delete();
    }
  });
}
