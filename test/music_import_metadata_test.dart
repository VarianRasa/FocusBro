import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/services/music_import_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory appDirectory;

  setUp(() async {
    appDirectory =
        await Directory.systemTemp.createTemp('focusbro_music_import_app');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return appDirectory.path;
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await appDirectory.exists()) {
      await appDirectory.delete(recursive: true);
    }
  });

  test('extractMetadata reads ID3v1 tags before filename fallback', () async {
    final directory =
        await Directory.systemTemp.createTemp('focusbro_music_metadata_test');
    addTearDown(() => directory.delete(recursive: true));

    final file =
        File('${directory.path}${Platform.pathSeparator}wrong_name.mp3');
    await file.writeAsBytes([
      ...List<int>.filled(32, 0),
      ..._id3v1Tag(
        title: 'Deep Work',
        artist: 'Focus Artist',
        album: 'Flow Album',
        year: '2026',
      ),
    ]);

    final metadata = await MusicImportService().extractMetadata(file.path);

    expect(metadata['title'], 'Deep Work');
    expect(metadata['artist'], 'Focus Artist');
    expect(metadata['album'], 'Flow Album');
    expect(metadata['year'], '2026');
    expect(metadata['fileSize'], await file.length());
  });

  test('copying imported tracks with the same title never overwrites files',
      () async {
    final sourceDirectory =
        await Directory.systemTemp.createTemp('focusbro_music_import_sources');
    addTearDown(() => sourceDirectory.delete(recursive: true));
    final first = File('${sourceDirectory.path}/first.mp3')
      ..writeAsBytesSync([1, 2, 3]);
    final second = File('${sourceDirectory.path}/second.mp3')
      ..writeAsBytesSync([4, 5, 6]);

    final service = MusicImportService();
    final firstPath =
        await service.copyFileToAppDirectory(first.path, 'Focus Track');
    final secondPath =
        await service.copyFileToAppDirectory(second.path, 'Focus Track');

    expect(firstPath, isNot(secondPath));
    expect(await File(firstPath).readAsBytes(), [1, 2, 3]);
    expect(await File(secondPath).readAsBytes(), [4, 5, 6]);
  });

  test('audio validation safely rejects files without an extension', () {
    expect(MusicImportService().isValidAudioFile('recording'), isFalse);
  });
}

List<int> _id3v1Tag({
  required String title,
  required String artist,
  required String album,
  required String year,
}) {
  return [
    ...latin1.encode('TAG'),
    ..._fixedLatin1(title, 30),
    ..._fixedLatin1(artist, 30),
    ..._fixedLatin1(album, 30),
    ..._fixedLatin1(year, 4),
    ..._fixedLatin1('', 30),
    0,
  ];
}

List<int> _fixedLatin1(String value, int length) {
  final bytes = latin1.encode(value);
  final padding = (length - bytes.length).clamp(0, length).toInt();
  return [
    ...bytes.take(length),
    ...List<int>.filled(padding, 0x20),
  ];
}
