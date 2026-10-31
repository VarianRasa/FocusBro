import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../providers/focus_provider.dart';

/// Dialog for confirming playlist deletion
class DeletePlaylistDialog extends StatefulWidget {
  final MusicPlaylist playlist;

  const DeletePlaylistDialog({
    super.key,
    required this.playlist,
  });

  @override
  State<DeletePlaylistDialog> createState() => _DeletePlaylistDialogState();
}

class _DeletePlaylistDialogState extends State<DeletePlaylistDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final musicService =
        Provider.of<FocusProvider>(context, listen: false).musicService;
    final tracks = musicService.getTracksFromPlaylist(widget.playlist);
    final isCurrentlyPlaying =
        musicService.currentPlaylist?.id == widget.playlist.id;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Playlist',
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber,
                      color: Colors.red,
                      size: 24,
                    ),
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

              // Playlist information
              Text(
                'You are about to delete:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.playlist_play,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.playlist.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.playlist.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.playlist.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.music_note,
                          size: 16,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${tracks.length} track${tracks.length == 1 ? '' : 's'}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        if (widget.playlist.category != null) ...[
                          const SizedBox(width: 16),
                          Icon(
                            _getCategoryIcon(widget.playlist.category!),
                            size: 16,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.playlist.category!.displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Currently playing warning
              if (isCurrentlyPlaying) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_filled,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This playlist is currently playing. Deleting it will stop playback.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isDeleting ? null : _deletePlaylist,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePlaylist() async {
    setState(() {
      _isDeleting = true;
    });

    try {
      final musicService =
          Provider.of<FocusProvider>(context, listen: false).musicService;

      // Stop playback if this playlist is currently playing
      if (musicService.currentPlaylist?.id == widget.playlist.id) {
        await musicService.stop();
      }

      // Delete the playlist
      await musicService.deletePlaylist(widget.playlist.id);

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                      'Playlist "${widget.playlist.name}" deleted successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Close dialog
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });

        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Failed to delete playlist: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
