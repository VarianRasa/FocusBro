import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/voice_recording_service.dart';
import '../models/voice_note.dart';

/// Voice note player widget with playback controls
class VoiceNotePlayer extends StatefulWidget {
  final VoiceNote voiceNote;
  final Function(VoiceNote)? onDelete;
  final Function(VoiceNote)? onEdit;
  final Function(String)? onShare;
  final bool showControls;
  final bool showTranscription;
  final bool compact;

  const VoiceNotePlayer({
    super.key,
    required this.voiceNote,
    this.onDelete,
    this.onEdit,
    this.onShare,
    this.showControls = true,
    this.showTranscription = true,
    this.compact = false,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer>
    with TickerProviderStateMixin {
  late VoiceRecordingService _recordingService;
  late AnimationController _playButtonController;
  late Animation<double> _playButtonAnimation;

  bool _isCurrentlyPlaying = false;
  double _playbackSpeed = 1.0;
  bool _showTranscription = false;

  @override
  void initState() {
    super.initState();
    _recordingService = VoiceRecordingService();
    _showTranscription =
        widget.showTranscription && widget.voiceNote.transcription != null;

    // Setup animations
    _playButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _playButtonAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _playButtonController, curve: Curves.easeInOut),
    );

    _recordingService.addListener(_onPlaybackStateChanged);
  }

  @override
  void dispose() {
    _recordingService.removeListener(_onPlaybackStateChanged);
    _playButtonController.dispose();
    super.dispose();
  }

  void _onPlaybackStateChanged() {
    if (mounted) {
      setState(() {
        // Update playing state based on current file
        _isCurrentlyPlaying = _recordingService.isPlaying;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.compact) {
      return _buildCompactPlayer(theme, colorScheme);
    }

    return _buildFullPlayer(theme, colorScheme);
  }

  Widget _buildCompactPlayer(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause Button
          _buildPlayButton(theme, colorScheme, size: 32),
          const SizedBox(width: 12),

          // Title and Duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.voiceNote.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDuration(widget.voiceNote.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Menu Button
          if (widget.showControls)
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'share',
                  child: Row(
                    children: [
                      Icon(Icons.share, size: 18),
                      SizedBox(width: 8),
                      Text('Share'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildFullPlayer(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(theme, colorScheme),
          const SizedBox(height: 16),

          // Playback Controls
          _buildPlaybackControls(theme, colorScheme),
          const SizedBox(height: 16),

          // Progress Section
          _buildProgressSection(theme, colorScheme),

          // Transcription Section
          if (_showTranscription) ...[
            const SizedBox(height: 16),
            _buildTranscriptionSection(theme, colorScheme),
          ],

          // Action Buttons
          if (widget.showControls) ...[
            const SizedBox(height: 16),
            _buildActionButtons(theme, colorScheme),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.audiotrack,
          color: colorScheme.primary,
          size: 24,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.voiceNote.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Created ${_formatDate(widget.voiceNote.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (widget.showControls)
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
              if (widget.voiceNote.transcription != null)
                PopupMenuItem(
                  value: 'toggle_transcription',
                  child: Row(
                    children: [
                      Icon(
                          _showTranscription
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18),
                      const SizedBox(width: 8),
                      Text(_showTranscription
                          ? 'Hide Transcription'
                          : 'Show Transcription'),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 18, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPlaybackControls(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Rewind Button
        IconButton(
          onPressed: _rewind,
          icon: const Icon(Icons.replay_10),
          iconSize: 32,
          color: colorScheme.onSurfaceVariant,
        ),

        const SizedBox(width: 20),

        // Play/Pause Button
        _buildPlayButton(theme, colorScheme, size: 56),

        const SizedBox(width: 20),

        // Fast Forward Button
        IconButton(
          onPressed: _fastForward,
          icon: const Icon(Icons.forward_10),
          iconSize: 32,
          color: colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }

  Widget _buildPlayButton(ThemeData theme, ColorScheme colorScheme,
      {double size = 56}) {
    return AnimatedBuilder(
      animation: _playButtonAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _playButtonAnimation.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IconButton(
              onPressed: _togglePlayback,
              icon: Icon(
                _isCurrentlyPlaying && !_recordingService.isPaused
                    ? Icons.pause
                    : Icons.play_arrow,
                color: Colors.white,
                size: size * 0.6,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressSection(ThemeData theme, ColorScheme colorScheme) {
    return Consumer<VoiceRecordingService>(
      builder: (context, service, child) {
        final progress = service.totalDuration.inMilliseconds > 0
            ? service.playbackPosition.inMilliseconds /
                service.totalDuration.inMilliseconds
            : 0.0;

        return Column(
          children: [
            // Progress Bar
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: progress.clamp(0.0, 1.0),
                onChanged: _onSeek,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),

            // Time Display
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(service.playbackPosition),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                // Playback Speed
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButton<double>(
                    value: _playbackSpeed,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                      return DropdownMenuItem(
                        value: speed,
                        child: Text('${speed}x'),
                      );
                    }).toList(),
                    onChanged: _onSpeedChanged,
                  ),
                ),
                Text(
                  _formatDuration(widget.voiceNote.duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildTranscriptionSection(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.transcribe,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Transcription',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.voiceNote.transcription ?? 'No transcription available',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: widget.voiceNote.transcription != null
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        OutlinedButton.icon(
          onPressed: () => widget.onEdit?.call(widget.voiceNote),
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Edit'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onShare?.call(widget.voiceNote.audioFilePath),
          icon: const Icon(Icons.share, size: 18),
          label: const Text('Share'),
        ),
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(),
          icon: const Icon(Icons.delete, size: 18),
          label: const Text('Delete'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
        ),
      ],
    );
  }

  // Action Methods
  Future<void> _togglePlayback() async {
    _playButtonController.forward().then((_) {
      _playButtonController.reverse();
    });

    if (_isCurrentlyPlaying && !_recordingService.isPaused) {
      await _recordingService.pausePlayback();
    } else if (_recordingService.isPaused) {
      await _recordingService.resumePlayback();
    } else {
      await _recordingService.playAudio(widget.voiceNote.audioFilePath);
    }
  }

  Future<void> _rewind() async {
    final newPosition =
        _recordingService.playbackPosition - const Duration(seconds: 10);
    await _recordingService
        .seekTo(newPosition.isNegative ? Duration.zero : newPosition);
  }

  Future<void> _fastForward() async {
    final newPosition =
        _recordingService.playbackPosition + const Duration(seconds: 10);
    final maxPosition = widget.voiceNote.duration;
    await _recordingService
        .seekTo(newPosition > maxPosition ? maxPosition : newPosition);
  }

  void _onSeek(double value) {
    final position = Duration(
      milliseconds: (value * widget.voiceNote.duration.inMilliseconds).round(),
    );
    _recordingService.seekTo(position);
  }

  void _onSpeedChanged(double? speed) {
    if (speed != null) {
      setState(() {
        _playbackSpeed = speed;
      });
      _recordingService.setPlaybackSpeed(speed);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        widget.onEdit?.call(widget.voiceNote);
        break;
      case 'share':
        widget.onShare?.call(widget.voiceNote.audioFilePath);
        break;
      case 'toggle_transcription':
        setState(() {
          _showTranscription = !_showTranscription;
        });
        break;
      case 'delete':
        _confirmDelete();
        break;
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voice Note'),
        content: const Text(
            'Are you sure you want to delete this voice note? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onDelete?.call(widget.voiceNote);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
