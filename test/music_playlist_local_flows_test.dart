import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/music_track.dart';
import 'package:focusbro/services/music_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const globalAudioChannel = MethodChannel('xyz.luan/audioplayers.global');
  const audioChannel = MethodChannel('xyz.luan/audioplayers');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalAudioChannel, (_) async => null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(globalAudioChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
  });

  test('concurrent playlist creation always produces unique IDs', () async {
    final service = MusicService();
    final created = await Future.wait(
      List.generate(
        30,
        (index) => service.createPlaylist(
          name: 'Playlist $index',
          category: MusicCategory.custom,
        ),
      ),
    );
    addTearDown(() async {
      for (final playlist in created) {
        await service.deletePlaylist(playlist.id);
      }
    });

    expect(created.map((playlist) => playlist.id).toSet(), hasLength(30));
  });

  test('playlist nullable metadata can be cleared', () {
    final now = DateTime(2026, 6, 9);
    final playlist = MusicPlaylist(
      id: 'playlist',
      name: 'Local music',
      description: 'Description',
      trackIds: const [],
      category: MusicCategory.work,
      createdAt: now,
      updatedAt: now,
    );

    final cleared = playlist.copyWith(description: null, category: null);

    expect(cleared.description, isNull);
    expect(cleared.category, isNull);
  });

  test('playlist CRUD persists locally', () async {
    SharedPreferences.setMockInitialValues({});
    final service = MusicService();
    await service.initialize();

    final playlist = await service.createPlaylist(
      name: 'Android local playlist',
      description: 'Initial description',
      category: MusicCategory.work,
    );
    await service.updatePlaylist(
      playlist.copyWith(description: null, category: MusicCategory.custom),
    );
    expect(await service.bulkAddTracksToPlaylist(playlist.id, ['track-a']),
        isTrue);
    expect(
      await service.bulkAddTracksToPlaylist(playlist.id, ['track-a']),
      isFalse,
    );

    var prefs = await SharedPreferences.getInstance();
    var stored = jsonDecode(prefs.getString('user_playlists')!) as List;
    expect(stored, hasLength(1));
    expect(stored.single['description'], isNull);
    expect(stored.single['trackIds'], ['track-a']);

    expect(
      await service.bulkRemoveTracksFromPlaylist(playlist.id, ['track-a']),
      isTrue,
    );
    await service.deletePlaylist(playlist.id);

    prefs = await SharedPreferences.getInstance();
    stored = jsonDecode(prefs.getString('user_playlists')!) as List;
    expect(stored, isEmpty);
  });
}
