import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../services/music_service.dart';
import '../providers/focus_provider.dart';
import 'music_import_dialog.dart';
import 'create_playlist_dialog.dart';
import 'edit_playlist_dialog.dart';
import 'delete_playlist_dialog.dart';

/// Comprehensive music library dialog for browsing and managing music
class MusicLibraryDialog extends StatefulWidget {
  const MusicLibraryDialog({super.key});

  @override
  State<MusicLibraryDialog> createState() => _MusicLibraryDialogState();
}

class _MusicLibraryDialogState extends State<MusicLibraryDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MusicCategory _selectedCategory = MusicCategory.nature;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.library_music,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Music Library',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search music and playlists...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  icon: Icon(Icons.music_note),
                  text: 'Tracks',
                ),
                Tab(
                  icon: Icon(Icons.playlist_play),
                  text: 'Playlists',
                ),
                Tab(
                  icon: Icon(Icons.category),
                  text: 'Categories',
                ),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTracksTab(),
                  _buildPlaylistsTab(),
                  _buildCategoriesTab(),
                ],
              ),
            ),

            // Bottom actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showCreatePlaylistDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Create Playlist'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showAddMusicDialog,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Add Music'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracksTab() {
    return Consumer<MusicService>(
      builder: (context, musicService, child) {
        final tracks = musicService.allTracks.where((track) {
          final matchesSearch = _searchQuery.isEmpty ||
              track.title.toLowerCase().contains(_searchQuery) ||
              track.artist.toLowerCase().contains(_searchQuery);
          return matchesSearch;
        }).toList();

        if (tracks.isEmpty) {
          return const Center(
            child: Text('No tracks found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tracks.length,
          itemBuilder: (context, index) {
            final track = tracks[index];
            return _buildTrackTile(track, musicService);
          },
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return Consumer<MusicService>(
      builder: (context, musicService, child) {
        final playlists = musicService.allPlaylists.where((playlist) {
          final matchesSearch = _searchQuery.isEmpty ||
              playlist.name.toLowerCase().contains(_searchQuery);
          return matchesSearch;
        }).toList();

        if (playlists.isEmpty) {
          return const Center(
            child: Text('No playlists found'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return _buildPlaylistTile(playlist, musicService);
          },
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    return Consumer<MusicService>(
      builder: (context, musicService, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: MusicCategory.values.length,
          itemBuilder: (context, index) {
            final category = MusicCategory.values[index];
            final tracks = musicService.getTracksByCategory(category);

            if (tracks.isEmpty) return const SizedBox.shrink();

            return _buildCategoryTile(category, tracks, musicService);
          },
        );
      },
    );
  }

  Widget _buildTrackTile(MusicTrack track, MusicService musicService) {
    final theme = Theme.of(context);
    final isCurrentTrack = musicService.currentTrack?.id == track.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.primary.withOpacity(0.1),
          ),
          child: Icon(
            _getCategoryIcon(track.category),
            color: theme.colorScheme.primary,
          ),
        ),
        title: Text(
          track.title,
          style: TextStyle(
            fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
            color: isCurrentTrack ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.artist),
            const SizedBox(height: 2),
            Text(
              track.category.displayName,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentTrack && musicService.isPlaying)
              Icon(
                Icons.equalizer,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            IconButton(
              onPressed: () => musicService.playTrack(track),
              icon: Icon(
                isCurrentTrack && musicService.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleTrackAction(value, track, musicService),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'add_to_playlist',
                  child: ListTile(
                    leading: Icon(Icons.playlist_add),
                    title: Text('Add to Playlist'),
                  ),
                ),
                if (!track.isBuiltIn)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(MusicPlaylist playlist, MusicService musicService) {
    final theme = Theme.of(context);
    final tracks = musicService.getTracksFromPlaylist(playlist);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: theme.colorScheme.secondary.withOpacity(0.1),
          ),
          child: Icon(
            Icons.playlist_play,
            color: theme.colorScheme.secondary,
          ),
        ),
        title: Text(
          playlist.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${tracks.length} tracks'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => musicService.playPlaylist(playlist),
              icon: const Icon(Icons.play_arrow),
            ),
            if (!playlist.isBuiltIn)
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _handlePlaylistAction(value, playlist, musicService),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile(MusicCategory category, List<MusicTrack> tracks,
      MusicService musicService) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(
          _getCategoryIcon(category),
          color: theme.colorScheme.primary,
        ),
        title: Text(
          category.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text('${tracks.length} tracks'),
        children: tracks
            .map((track) => _buildTrackTile(track, musicService))
            .toList(),
      ),
    );
  }

  void _handleTrackAction(
      String action, MusicTrack track, MusicService musicService) {
    switch (action) {
      case 'add_to_playlist':
        _showAddToPlaylistDialog(track, musicService);
        break;
      case 'delete':
        _showDeleteTrackDialog(track, musicService);
        break;
    }
  }

  void _handlePlaylistAction(
      String action, MusicPlaylist playlist, MusicService musicService) {
    switch (action) {
      case 'edit':
        _showEditPlaylistDialog(playlist, musicService);
        break;
      case 'delete':
        _showDeletePlaylistDialog(playlist, musicService);
        break;
    }
  }

  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const CreatePlaylistDialog(),
      ),
    );
  }

  void _showAddMusicDialog() {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: const MusicImportDialog(),
      ),
    );
  }

  void _showAddToPlaylistDialog(MusicTrack track, MusicService musicService) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: musicService,
        child: _buildAddToPlaylistDialog(track, musicService),
      ),
    );
  }

  void _showDeleteTrackDialog(MusicTrack track, MusicService musicService) {
    showDialog(
      context: context,
      builder: (context) => _buildDeleteTrackDialog(track, musicService),
    );
  }

  void _showEditPlaylistDialog(
      MusicPlaylist playlist, MusicService musicService) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: EditPlaylistDialog(playlist: playlist),
      ),
    );
  }

  void _showDeletePlaylistDialog(
      MusicPlaylist playlist, MusicService musicService) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: DeletePlaylistDialog(playlist: playlist),
      ),
    );
  }

  Widget _buildAddToPlaylistDialog(
      MusicTrack track, MusicService musicService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.playlist_add, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Add to Playlist',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Track info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getCategoryIcon(track.category),
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artist,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Playlist:',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Playlist list
            SizedBox(
              height: 200,
              child: Builder(
                builder: (context) {
                  final userPlaylists = musicService.allPlaylists
                      .where((p) => !p.isBuiltIn)
                      .toList();

                  if (userPlaylists.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.playlist_remove,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No custom playlists found',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a playlist first to add tracks',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: userPlaylists.length,
                    itemBuilder: (context, index) {
                      final playlist = userPlaylists[index];
                      final isTrackInPlaylist =
                          playlist.trackIds.contains(track.id);

                      return ListTile(
                        leading: Icon(
                          playlist.category != null
                              ? _getCategoryIcon(playlist.category!)
                              : Icons.queue_music,
                          color: isTrackInPlaylist
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          playlist.name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isTrackInPlaylist
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color:
                                isTrackInPlaylist ? colorScheme.primary : null,
                          ),
                        ),
                        subtitle: Text(
                          '${playlist.trackIds.length} tracks',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: isTrackInPlaylist
                            ? Icon(
                                Icons.check_circle,
                                color: colorScheme.primary,
                              )
                            : Icon(
                                Icons.add_circle_outline,
                                color: colorScheme.onSurfaceVariant,
                              ),
                        onTap: isTrackInPlaylist
                            ? null
                            : () async {
                                try {
                                  await musicService.addTrackToPlaylist(
                                    playlist.id,
                                    track.id,
                                  );

                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '✅ Added "${track.title}" to "${playlist.name}"',
                                        ),
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('❌ Failed to add track: $e'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                }
                              },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildDeleteTrackDialog(MusicTrack track, MusicService musicService) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_forever, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Delete Track',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warning message
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This action cannot be undone!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Track info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(track.category),
                  color: colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artist,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (track.description != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          track.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Are you sure you want to delete this track?',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The track will be removed from your library and all playlists.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: track.isBuiltIn
              ? null
              : () async {
                  try {
                    // Use the new public method to remove track
                    final success =
                        await musicService.removeUserTrack(track.id);

                    if (mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '✅ Deleted "${track.title}" from library',
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '❌ Failed to delete "${track.title}"',
                            ),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Failed to delete track: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(track.isBuiltIn ? 'Cannot Delete Built-in' : 'Delete'),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(MusicCategory category) {
    switch (category) {
      case MusicCategory.nature:
        return Icons.nature;
      case MusicCategory.whiteNoise:
        return Icons.graphic_eq;
      case MusicCategory.instrumental:
        return Icons.piano;
      case MusicCategory.binaural:
        return Icons.waves;
      case MusicCategory.ambient:
        return Icons.cloud;
      case MusicCategory.lofi:
        return Icons.headphones;
      case MusicCategory.classical:
        return Icons.library_music;
      case MusicCategory.meditation:
        return Icons.self_improvement;
      case MusicCategory.work:
        return Icons.work;
      case MusicCategory.study:
        return Icons.school;
      case MusicCategory.break_:
        return Icons.coffee;
      case MusicCategory.custom:
        return Icons.music_note;
    }
  }
}
