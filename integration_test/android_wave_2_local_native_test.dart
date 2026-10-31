import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'package:focusbro/models/music_track.dart';
import 'package:focusbro/models/voice_note.dart';
import 'package:focusbro/services/music_service.dart';
import 'package:focusbro/services/note_service.dart';
import 'package:focusbro/services/pdf_edit_service.dart';
import 'package:focusbro/services/pdf_outline_service.dart';
import 'package:focusbro/services/voice_notes_service.dart';
import 'package:focusbro/services/voice_recording_service.dart';
import 'package:focusbro/utils/local_id_generator.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android Wave 2 local native flows work', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();

    final noteService = NoteService();
    await noteService.initialize();
    final note = await noteService.createNote(
      title: 'Android Wave 2 note',
      content: 'Stored in the native Android database',
      category: 'Work',
      tags: const ['android', 'local'],
    );
    expect(noteService.notes.any((item) => item.id == note.id), isTrue);
    await noteService.deleteNote(note.id);
    expect(noteService.notes.any((item) => item.id == note.id), isFalse);

    final recordingService = VoiceRecordingService();
    expect(await recordingService.initialize(), isTrue);
    expect(await recordingService.startRecording(), isTrue);
    await tester.pump(const Duration(seconds: 2));
    final recordingPath = await recordingService.stopRecording();
    expect(recordingPath, isNotNull);
    final recordingFile = File(recordingPath!);
    expect(await recordingFile.exists(), isTrue);
    expect(await recordingFile.length(), greaterThan(0));

    final playbackStartedAt = DateTime.now();
    expect(await recordingService.playAudio(recordingPath), isTrue);
    expect(
      DateTime.now().difference(playbackStartedAt),
      lessThan(const Duration(seconds: 1)),
    );
    expect(recordingService.isPlaying, isTrue);
    await recordingService.pausePlayback();
    expect(recordingService.isPaused, isTrue);
    await recordingService.resumePlayback();
    expect(recordingService.isPaused, isFalse);
    await recordingService.stopPlayback();
    expect(recordingService.isPlaying, isFalse);

    final now = DateTime.now();
    final voiceNote = VoiceNote(
      id: LocalIdGenerator.next(),
      title: 'Android native recording',
      audioFilePath: recordingPath,
      duration: recordingService.recordingDuration,
      createdAt: now,
      updatedAt: now,
      audioFormat: recordingService.audioFormat,
      sampleRate: recordingService.sampleRate,
      bitRate: recordingService.bitRate,
    );
    final voiceNotesService = VoiceNotesService();
    expect(await voiceNotesService.saveVoiceNote(voiceNote), isTrue);
    expect(voiceNotesService.getVoiceNote(voiceNote.id), isNotNull);

    final musicService = MusicService();
    await musicService.initialize();
    if (!musicService.isMusicEnabled) {
      await musicService.toggleMusic();
    }
    final localTrack = MusicTrack(
      id: LocalIdGenerator.next(),
      title: 'Android local playback',
      artist: 'FocusBro',
      filePath: recordingPath,
      category: MusicCategory.custom,
      source: MusicSource.file,
    );
    expect(await musicService.addUserTrack(localTrack), isTrue);
    await musicService.playTrack(localTrack);
    await tester.pump(const Duration(milliseconds: 500));
    expect(musicService.currentTrack, localTrack);
    expect(musicService.isPlaying, isTrue);
    await musicService.pause();
    expect(musicService.isPaused, isTrue);
    await musicService.resume();
    await tester.pump(const Duration(milliseconds: 500));
    expect(musicService.isPlaying, isTrue);
    await musicService.stop();
    expect(musicService.currentTrack, isNull);
    expect(await musicService.removeUserTrack(localTrack.id), isTrue);
    if (musicService.isMusicEnabled) {
      await musicService.toggleMusic();
    }

    final playlist = await musicService.createPlaylist(
      name: 'Android local playlist',
      category: MusicCategory.custom,
    );
    expect(
      musicService.allPlaylists.any((item) => item.id == playlist.id),
      isTrue,
    );
    await musicService.deletePlaylist(playlist.id);
    expect(
      musicService.allPlaylists.any((item) => item.id == playlist.id),
      isFalse,
    );
    expect(await voiceNotesService.deleteVoiceNote(voiceNote.id), isTrue);
    expect(await recordingFile.exists(), isFalse);

    final source = PdfDocument();
    final firstPage = source.pages.add();
    source.pages.add();
    source.bookmarks.add('Android PDF outline').destination =
        PdfDestination(firstPage);
    final sourceBytes = await source.save();
    source.dispose();

    final outline = PdfOutlineService.extract(sourceBytes);
    expect(outline.single.title, 'Android PDF outline');
    expect(outline.single.pageNumber, 1);

    final editedBytes = await PdfEditService.applyEdits(
      sourceBytes,
      [
        {
          'action': 'delete_pages',
          'data': {
            'pageNumbers': [2],
          },
        },
        {
          'action': 'add_blank_page',
          'data': {'pageNumber': 2},
        },
      ],
    );
    final edited = PdfDocument(inputBytes: editedBytes);
    expect(edited.pages.count, 2);
    edited.dispose();
  });
}
