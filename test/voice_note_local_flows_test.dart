import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/models/voice_note.dart';
import 'package:focusbro/services/voice_notes_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('voice note nullable metadata can be cleared', () {
    final now = DateTime(2026, 6, 9);
    final note = VoiceNote(
      id: 'voice-note',
      title: 'Voice note',
      transcription: 'Draft text',
      transcriptionConfidence: 0.8,
      audioFormat: 'aac',
      sampleRate: 44100,
      bitRate: 128000,
      audioFilePath: '/tmp/voice-note.aac',
      duration: const Duration(seconds: 2),
      createdAt: now,
      updatedAt: now,
    );

    final cleared = note.copyWith(
      transcription: null,
      transcriptionConfidence: null,
      audioFormat: null,
      sampleRate: null,
      bitRate: null,
    );

    expect(cleared.transcription, isNull);
    expect(cleared.transcriptionConfidence, isNull);
    expect(cleared.audioFormat, isNull);
    expect(cleared.sampleRate, isNull);
    expect(cleared.bitRate, isNull);
  });

  test('voice note save, update, and delete persist locally', () async {
    SharedPreferences.setMockInitialValues({});
    final service = VoiceNotesService();

    final directory =
        await Directory.systemTemp.createTemp('focusbro_voice_note_test');
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final audio = File('${directory.path}${Platform.pathSeparator}note.aac');
    await audio.writeAsBytes(List<int>.filled(32, 1));
    final now = DateTime.now();
    final note = VoiceNote(
      id: 'voice-note-local-flow',
      title: 'Initial title',
      audioFilePath: audio.path,
      duration: const Duration(seconds: 2),
      createdAt: now,
      updatedAt: now,
    );

    expect(await service.saveVoiceNote(note), isTrue);
    expect(await service.saveVoiceNote(note), isTrue);
    var prefs = await SharedPreferences.getInstance();
    var stored = prefs.getStringList('voice_notes')!;
    expect(stored, hasLength(1));
    expect(jsonDecode(stored.single)['title'], 'Initial title');

    expect(
      await service.updateVoiceNote(note.copyWith(title: 'Updated title')),
      isTrue,
    );
    prefs = await SharedPreferences.getInstance();
    stored = prefs.getStringList('voice_notes')!;
    expect(jsonDecode(stored.single)['title'], 'Updated title');

    expect(await service.deleteVoiceNote(note.id), isTrue);
    expect(await audio.exists(), isFalse);
    expect(
      (await SharedPreferences.getInstance()).getStringList('voice_notes'),
      isEmpty,
    );
  });
}
