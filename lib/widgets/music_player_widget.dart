import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../services/music_service.dart';
import '../providers/focus_provider.dart';
import 'create_playlist_dialog.dart';

/// Compact music player widget for the focus screen
class MusicPlayerWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback? onToggleExpanded;

  const MusicPlayerWidget({
    super.key,
    this.isExpanded = false,
    this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicService>(
      builder: (context, musicService, child) {
        if (!musicService.isMusicEnabled || musicService.currentTrack == null) {
          return const SizedBox.shrink();
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: isExpanded ? 200 : 80,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: isExpanded
                ? _buildExpandedPlayer(context, musicService)
                : _buildCompactPlayer(context, musicService),
          ),
        );
      },
    );
  }

  Widget _buildCompactPlayer(BuildContext context, MusicService musicService) {
    final theme = Theme.of(context);
    final track = musicService.currentTrack!;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Album art placeholder
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.primary.withOpacity(0.1),
            ),
            child: Icon(
              _getCategoryIcon(track.category),
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  track.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Play/pause button
          IconButton(
            onPressed: () {
              if (musicService.isPlaying) {
                musicService.pause();
              } else {
                musicService.resume();
              }
            },
            icon: Icon(
              musicService.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 28,
            ),
          ),

          // Expand button
          if (onToggleExpanded != null)
            IconButton(
              onPressed: onToggleExpanded,
              icon: const Icon(Icons.expand_less),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedPlayer(BuildContext context, MusicService musicService) {
    final theme = Theme.of(context);
    final track = musicService.currentTrack!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with collapse button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Now Playing',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _handleMenuAction(context, value, musicService),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'create_playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add),
                        SizedBox(width: 8),
                        Text('Create Playlist'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_to_playlist',
                    child: Row(
                      children: [
                        Icon(Icons.playlist_add_check),
                        SizedBox(width: 8),
                        Text('Add to Playlist'),
                      ],
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: onToggleExpanded,
                icon: const Icon(Icons.expand_more),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Track info and controls
          Row(
            children: [
              // Album art
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
                child: Icon(
                  _getCategoryIcon(track.category),
                  color: theme.colorScheme.primary,
                  size: 32,
                ),
              ),

              const SizedBox(width: 16),

              // Track details and controls
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      track.artist,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.category.displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress bar
          _buildProgressBar(context, musicService),

          const SizedBox(height: 12),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: musicService.playPrevious,
                icon: const Icon(Icons.skip_previous),
                iconSize: 32,
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
                child: IconButton(
                  onPressed: () {
                    if (musicService.isPlaying) {
                      musicService.pause();
                    } else {
                      musicService.resume();
                    }
                  },
                  icon: Icon(
                    musicService.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: theme.colorScheme.onPrimary,
                  ),
                  iconSize: 32,
                ),
              ),
              IconButton(
                onPressed: musicService.playNext,
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context, MusicService musicService) {
    final theme = Theme.of(context);

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.colorScheme.primary,
            inactiveTrackColor: theme.colorScheme.primary.withOpacity(0.3),
            thumbColor: theme.colorScheme.primary,
            overlayColor: theme.colorScheme.primary.withOpacity(0.2),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            value: musicService.progress.clamp(0.0, 1.0),
            onChanged: (value) {
              final position = Duration(
                milliseconds:
                    (value * musicService.totalDuration.inMilliseconds).round(),
              );
              musicService.seekTo(position);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                musicService.formatDuration(musicService.currentPosition),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              Text(
                musicService.formatDuration(musicService.totalDuration),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(
      BuildContext context, String action, MusicService musicService) {
    switch (action) {
      case 'create_playlist':
        _showCreatePlaylistDialog(context, musicService.currentTrack);
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context, musicService.currentTrack);
        break;
    }
  }

  void _showCreatePlaylistDialog(
      BuildContext context, MusicTrack? currentTrack) {
    showDialog(
      context: context,
      builder: (context) => ChangeNotifierProvider.value(
        value: Provider.of<FocusProvider>(context, listen: false).musicService,
        child: CreatePlaylistDialog(
          initialTracks: currentTrack != null ? [currentTrack] : null,
          suggestedCategory: currentTrack?.category,
        ),
      ),
    );
  }

  Future<void> _showAddToPlaylistDialog(
      BuildContext context, MusicTrack? currentTrack) async {
    if (currentTrack == null) return;

    final musicService = context.read<FocusProvider>().musicService;
    final playlists = musicService.allPlaylists
        .where((playlist) => !playlist.isBuiltIn)
        .toList();
    if (playlists.isEmpty) {
      _showCreatePlaylistDialog(context, currentTrack);
      return;
    }

    final selected = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add to playlist'),
          content: SizedBox(
            width: 360,
            child: ListView(
              shrinkWrap: true,
              children: playlists.map((playlist) {
                final containsTrack =
                    playlist.trackIds.contains(currentTrack.id);
                return CheckboxListTile(
                  value: containsTrack || selected.contains(playlist.id),
                  title: Text(playlist.name),
                  subtitle: Text(containsTrack
                      ? 'Already contains this track'
                      : '${playlist.trackIds.length} tracks'),
                  enabled: !containsTrack,
                  onChanged: containsTrack
                      ? null
                      : (checked) => setDialogState(() {
                            if (checked == true) {
                              selected.add(playlist.id);
                            } else {
                              selected.remove(playlist.id);
                            }
                          }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(true),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    for (final playlist in playlists.where((p) => selected.contains(p.id))) {
      await musicService.updatePlaylist(
        playlist.copyWith(trackIds: [...playlist.trackIds, currentTrack.id]),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added to ${selected.length} playlist${selected.length == 1 ? '' : 's'}',
          ),
        ),
      );
    }
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
