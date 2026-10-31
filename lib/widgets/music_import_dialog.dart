import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../services/music_import_service.dart';
import '../services/music_service.dart';

/// Dialog for importing music files from device storage
class MusicImportDialog extends StatefulWidget {
  const MusicImportDialog({super.key});

  @override
  State<MusicImportDialog> createState() => _MusicImportDialogState();
}

class _MusicImportDialogState extends State<MusicImportDialog>
    with SingleTickerProviderStateMixin {
  final MusicImportService _importService = MusicImportService();

  bool _isImporting = false;
  double _importProgress = 0.0;
  String _importStatus = '';
  List<MusicTrack> _importedTracks = [];
  List<String> _errors = [];
  bool _showResults = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
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
                      Icons.upload_file,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Import Music Files',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    if (!_isImporting)
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child:
                      _showResults ? _buildResultsView() : _buildImportView(),
                ),
              ),

              // Actions
              if (!_isImporting && !_showResults)
                Container(
                  padding: const EdgeInsets.all(20),
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
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.cancel),
                          label: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _startImport,
                          icon: const Icon(Icons.file_upload),
                          label: const Text('Select Files'),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportView() {
    final theme = Theme.of(context);

    if (_isImporting) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Progress indicator
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: _importProgress,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  '${(_importProgress * 100).round()}%',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Status text
          Text(
            _importStatus,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Import details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Import Information',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Supported formats: MP3, WAV, M4A, AAC, FLAC\n'
                  'Files will be copied to app storage\n'
                  'Metadata will be extracted automatically',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Initial import view
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Upload icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cloud_upload,
            size: 60,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Import Your Music',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          'Add your favorite tracks to enhance your focus sessions',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        // Supported formats
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.audiotrack,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Supported Formats',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MusicImportService.supportedExtensions.map((ext) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      ext.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultsView() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Results header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _importedTracks.isNotEmpty
                ? Colors.green.withOpacity(0.1)
                : Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _importedTracks.isNotEmpty ? Icons.check_circle : Icons.warning,
                color:
                    _importedTracks.isNotEmpty ? Colors.green : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Import Complete',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_importedTracks.length} tracks imported successfully',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Imported tracks list
        if (_importedTracks.isNotEmpty) ...[
          Text(
            'Imported Tracks',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _importedTracks.length,
              itemBuilder: (context, index) {
                final track = _importedTracks[index];
                return _buildTrackTile(track);
              },
            ),
          ),
        ],

        // Errors list
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Errors (${_errors.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 120),
            child: ListView.builder(
              itemCount: _errors.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• ${_errors[index]}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
            if (_importedTracks.isNotEmpty) ...[
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addTracksToLibrary,
                  child: const Text('Add to Library'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildTrackTile(MusicTrack track) {
    final theme = Theme.of(context);

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
          style: const TextStyle(fontWeight: FontWeight.w600),
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
        trailing: track.duration != null
            ? Text(
                _formatDuration(track.duration!),
                style: theme.textTheme.bodySmall,
              )
            : null,
      ),
    );
  }

  Future<void> _startImport() async {
    setState(() {
      _isImporting = true;
      _importProgress = 0.0;
      _importStatus = 'Preparing...';
    });

    try {
      final result = await _importService.importMusicFiles(
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _importProgress = progress;
              _importStatus = status;
            });
          }
        },
        allowMultiple: true,
      );

      if (mounted) {
        setState(() {
          _isImporting = false;
          _showResults = true;
          _importedTracks = result.importedTracks;
          _errors = result.errors;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isImporting = false;
          _showResults = true;
          _errors = ['Import failed: $e'];
        });
      }
    }
  }

  Future<void> _addTracksToLibrary() async {
    final musicService = Provider.of<MusicService>(context, listen: false);

    try {
      for (final track in _importedTracks) {
        await musicService.addUserTrack(track);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${_importedTracks.length} tracks to library'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding tracks: $e'),
            backgroundColor: Colors.red,
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

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
