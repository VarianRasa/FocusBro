import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:focusbro/widgets/create_playlist_dialog.dart';
import 'package:focusbro/models/music_track.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/services/music_service.dart';

void main() {
  group('CreatePlaylistDialog Tests', () {
    late FocusProvider focusProvider;
    late MusicService musicService;

    setUp(() {
      focusProvider = FocusProvider();
      musicService = focusProvider.musicService;
    });

    testWidgets('should display create playlist dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Verify dialog elements are present
      expect(find.text('Create Playlist'), findsOneWidget);
      expect(find.text('Playlist Name *'), findsOneWidget);
      expect(find.text('Description (Optional)'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Add Tracks'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Create Playlist'), findsAtLeastNWidgets(1));
    });

    testWidgets('should validate required playlist name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Try to create playlist without name
      await tester.tap(find.text('Create Playlist').last);
      await tester.pump();

      // Should show validation error
      expect(find.text('Playlist name is required'), findsOneWidget);
    });

    testWidgets('should validate playlist name length',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Enter too short name
      await tester.enterText(find.byType(TextFormField).first, 'A');
      await tester.tap(find.text('Create Playlist').last);
      await tester.pump();

      // Should show validation error
      expect(find.text('Playlist name must be at least 2 characters'),
          findsOneWidget);
    });

    testWidgets('should accept valid playlist name',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Enter valid name
      await tester.enterText(
          find.byType(TextFormField).first, 'My Test Playlist');
      await tester.pump();

      // Should not show validation error
      expect(find.text('Playlist name is required'), findsNothing);
      expect(find.text('Playlist name must be at least 2 characters'),
          findsNothing);
    });

    testWidgets('should display category dropdown',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Find and tap category dropdown
      final dropdown = find.byType(DropdownButtonFormField<MusicCategory>);
      expect(dropdown, findsOneWidget);

      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Should show category options
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Study'), findsOneWidget);
      expect(find.text('Break'), findsOneWidget);
      expect(find.text('Meditation'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
    });

    testWidgets('should show track selection dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Tap browse button
      await tester.tap(find.text('Browse'));
      await tester.pumpAndSettle();

      // Should show track selection dialog
      expect(find.text('Select Tracks'), findsOneWidget);
      expect(find.text('Search tracks...'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Clear All'), findsOneWidget);
      expect(find.text('Cancel'), findsAtLeastNWidgets(1));
    });

    testWidgets('should display initial tracks when provided',
        (WidgetTester tester) async {
      final testTrack = MusicTrack(
        id: 'test1',
        title: 'Test Track',
        artist: 'Test Artist',
        filePath: '/test/path',
        category: MusicCategory.work,
        source: MusicSource.file,
        duration: const Duration(minutes: 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: Scaffold(
              body: CreatePlaylistDialog(
                initialTracks: [testTrack],
                suggestedCategory: MusicCategory.work,
              ),
            ),
          ),
        ),
      );

      // Should show initial track
      expect(find.text('Selected Tracks (1)'), findsOneWidget);
      expect(find.text('Test Track'), findsOneWidget);
      expect(find.text('Test Artist'), findsOneWidget);
    });

    testWidgets('should allow removing selected tracks',
        (WidgetTester tester) async {
      final testTrack = MusicTrack(
        id: 'test1',
        title: 'Test Track',
        artist: 'Test Artist',
        filePath: '/test/path',
        category: MusicCategory.work,
        source: MusicSource.file,
        duration: const Duration(minutes: 3),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: Scaffold(
              body: CreatePlaylistDialog(
                initialTracks: [testTrack],
              ),
            ),
          ),
        ),
      );

      // Should show remove button
      expect(find.byIcon(Icons.remove_circle_outline), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byIcon(Icons.remove_circle_outline));
      await tester.pump();

      // Track should be removed
      expect(find.text('Selected Tracks (1)'), findsNothing);
      expect(find.text('No tracks selected. You can add tracks now or later.'),
          findsOneWidget);
    });

    testWidgets('should show loading state during creation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: focusProvider,
            child: const Scaffold(
              body: CreatePlaylistDialog(),
            ),
          ),
        ),
      );

      // Enter valid playlist name
      await tester.enterText(find.byType(TextFormField).first, 'Test Playlist');
      await tester.pump();

      // Tap create button
      await tester.tap(find.text('Create Playlist').last);
      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
