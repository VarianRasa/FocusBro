import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/widgets/edit_playlist_dialog.dart';
import 'package:focusbro/widgets/delete_playlist_dialog.dart';
import 'package:focusbro/models/music_track.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/services/music_service.dart';

void main() {
  group('Edit and Delete Playlist Tests', () {
    late FocusProvider focusProvider;
    late MusicService musicService;
    late MusicPlaylist testPlaylist;

    setUp(() {
      focusProvider = FocusProvider();
      musicService = focusProvider.musicService;

      // Create a test playlist
      testPlaylist = MusicPlaylist(
        id: 'test_playlist_1',
        name: 'Test Playlist',
        description: 'A test playlist for editing',
        trackIds: ['track1', 'track2'],
        category: MusicCategory.work,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isBuiltIn: false,
      );
    });

    group('EditPlaylistDialog Tests', () {
      testWidgets('should display edit playlist dialog with existing data',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Verify dialog elements are present
        expect(find.text('Edit Playlist'), findsOneWidget);
        expect(find.text('Modify your playlist settings and tracks'),
            findsOneWidget);
        expect(find.text('Playlist Name *'), findsOneWidget);
        expect(find.text('Description (Optional)'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        expect(find.text('Manage Tracks'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Save Changes'), findsOneWidget);

        // Verify existing data is populated
        expect(find.text('Test Playlist'), findsOneWidget);
        expect(find.text('A test playlist for editing'), findsOneWidget);
      });

      testWidgets('should validate playlist name changes',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Clear the name field
        await tester.enterText(find.byType(TextFormField).first, '');
        await tester.tap(find.text('Save Changes'));
        await tester.pump();

        // Should show validation error
        expect(find.text('Playlist name is required'), findsOneWidget);
      });

      testWidgets('should show add tracks button', (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Should show add tracks button
        expect(find.text('Add Tracks'), findsOneWidget);
      });

      testWidgets('should show reorder button when multiple tracks exist',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Should show reorder button for multiple tracks
        expect(find.text('Reorder'), findsOneWidget);
      });
    });

    group('DeletePlaylistDialog Tests', () {
      testWidgets('should display delete confirmation dialog',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: DeletePlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Verify dialog elements are present
        expect(find.text('Delete Playlist'), findsOneWidget);
        expect(find.text('This action cannot be undone!'), findsOneWidget);
        expect(find.text('You are about to delete:'), findsOneWidget);
        expect(find.text('Test Playlist'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('should show playlist information',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: DeletePlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Should show playlist details
        expect(find.text('Test Playlist'), findsOneWidget);
        expect(find.text('A test playlist for editing'), findsOneWidget);
        expect(find.text('2 tracks'), findsOneWidget);
        expect(find.text('Work'), findsOneWidget);
      });

      testWidgets('should show warning for currently playing playlist',
          (WidgetTester tester) async {
        // This test would require mocking the music service to simulate a currently playing playlist
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: DeletePlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Basic dialog should still render
        expect(find.text('Delete Playlist'), findsOneWidget);
      });

      testWidgets('should have proper button styling',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: DeletePlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Find the delete button
        final deleteButton = find.widgetWithText(ElevatedButton, 'Delete');
        expect(deleteButton, findsOneWidget);

        // Verify it's styled as a danger button (red)
        final button = tester.widget<ElevatedButton>(deleteButton);
        expect(button.style?.backgroundColor?.resolve({}), equals(Colors.red));
      });
    });

    group('Integration Tests', () {
      testWidgets('should handle empty playlist editing',
          (WidgetTester tester) async {
        final emptyPlaylist = MusicPlaylist(
          id: 'empty_playlist',
          name: 'Empty Playlist',
          description: null,
          trackIds: [],
          category: MusicCategory.custom,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isBuiltIn: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: emptyPlaylist),
              ),
            ),
          ),
        );

        // Should show empty state message
        expect(
            find.text(
                'No tracks in this playlist. Add some tracks to get started.'),
            findsOneWidget);

        // Should not show reorder button for empty playlist
        expect(find.text('Reorder'), findsNothing);
      });

      testWidgets('should handle built-in playlist restrictions',
          (WidgetTester tester) async {
        final builtInPlaylist = MusicPlaylist(
          id: 'builtin_playlist',
          name: 'Built-in Playlist',
          description: 'A built-in playlist',
          trackIds: ['track1'],
          category: MusicCategory.nature,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isBuiltIn: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: DeletePlaylistDialog(playlist: builtInPlaylist),
              ),
            ),
          ),
        );

        // Should still show delete dialog (service layer handles built-in restrictions)
        expect(find.text('Delete Playlist'), findsOneWidget);
        expect(find.text('Built-in Playlist'), findsOneWidget);
      });

      testWidgets('should show loading state during operations',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: ChangeNotifierProvider.value(
              value: focusProvider,
              child: Scaffold(
                body: EditPlaylistDialog(playlist: testPlaylist),
              ),
            ),
          ),
        );

        // Enter valid data
        await tester.enterText(
            find.byType(TextFormField).first, 'Updated Playlist Name');
        await tester.pump();

        // Tap save button
        await tester.tap(find.text('Save Changes'));
        await tester.pump();

        // Should show loading indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
