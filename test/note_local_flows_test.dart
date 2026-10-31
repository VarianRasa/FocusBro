import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/database_helper.dart';
import 'package:focusbro/services/note_service.dart';
import 'package:focusbro/utils/cache_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  final databaseDirectory =
      Directory('${Directory.systemTemp.path}/focusbro_note_local_flows_test');
  final service = NoteService();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await databaseDirectory.create(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return databaseDirectory.path;
      }
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    CacheManager.disableExpirationTimers = true;
    await DatabaseHelper().deleteDatabase();
    await service.initialize();
  });

  setUp(() async {
    await service.clearAllNotes();
    await CacheManager().clearAllCache();
  });

  tearDownAll(() async {
    await service.clearAllNotes();
    await DatabaseHelper().close();
    final databaseFile = File('${databaseDirectory.path}/focusbro.db');
    if (await databaseFile.exists()) {
      await databaseFile.delete();
    }
    CacheManager().cancelAllExpirationTimers();
    CacheManager.disableExpirationTimers = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  test('concurrent note creation always produces unique IDs', () async {
    final created = await Future.wait(
      List.generate(
        30,
        (index) => service.createNote(
          title: 'Note $index',
          content: 'Content $index',
          category: 'Work',
        ),
      ),
    );

    expect(created.map((note) => note.id).toSet(), hasLength(30));
    expect(service.notes, hasLength(30));
  });

  test('note CRUD, tags, attachments, export, and import work locally',
      () async {
    final created = await service.createNote(
      title: 'Android Wave 2',
      content: 'Initial content',
      category: 'Work',
      tags: const ['android'],
    );

    final updated = await service.updateNote(
      created.copyWith(title: 'Android Wave 2 Notes'),
    );
    expect(updated.title, 'Android Wave 2 Notes');

    await service.addTagToNote(created.id, 'LOCAL');
    await service.toggleFavorite(created.id);
    await service.togglePinned(created.id);
    final current = service.notes.single;
    expect(current.tags, containsAll(['android', 'local']));
    expect(current.isFavorite, isTrue);
    expect(current.isPinned, isTrue);

    final sourceAttachment =
        File('${databaseDirectory.path}/reference-source.txt');
    await sourceAttachment.writeAsString('local attachment');
    final attachment = await service.addAttachment(
      noteId: created.id,
      filePath: sourceAttachment.path,
      fileName: 'reference.txt',
      fileType: 'text/plain',
      fileSize: 42,
    );
    expect(attachment.id, isNotNull);
    expect(attachment.filePath, isNot(sourceAttachment.path));
    expect(await File(attachment.filePath).exists(), isTrue);
    expect(await service.getAttachmentsForNote(created.id), hasLength(1));

    final exported = await service.exportNotes();
    await service.deleteNote(created.id);
    expect(service.notes, isEmpty);
    expect(await service.getAttachmentsForNote(created.id), isEmpty);
    expect(await File(attachment.filePath).exists(), isFalse);

    expect(await service.importNotes(exported), 1);
    expect(service.notes.single.title, 'Android Wave 2 Notes');
    expect(await service.searchNotesAdvanced('local'), hasLength(1));
  });
}
