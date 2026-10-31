import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_track.dart';
import '../providers/focus_provider.dart';

/// Dialog for creating new music playlists
class CreatePlaylistDialog extends StatefulWidget {
  final List<MusicTrack>? initialTracks;
  final MusicCategory? suggestedCategory;

  const CreatePlaylistDialog({
    super.key,
    this.initialTracks,
    this.suggestedCategory,
  });

  @override
  State<CreatePlaylistDialog> createState() => _CreatePlaylistDialogState();
}

class _CreatePlaylistDialogState extends State<CreatePlaylistDialog>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  MusicCategory _selectedCategory = MusicCategory.custom;
  List<MusicTrack> _selectedTracks = [];
  bool _isCreating = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Initialize with provided data
    if (widget.initialTracks != null) {
      _selectedTracks = List.from(widget.initialTracks!);
    }

    if (widget.suggestedCategory != null) {
      _selectedCategory = widget.suggestedCategory!;
    }

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(
              maxHeight: 700,
              maxWidth: 500,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                _buildHeader(theme),

                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Playlist Name
                          _buildNameField(theme),

                          const SizedBox(height: 16),

                          // Description
                          _buildDescriptionField(theme),

                          const SizedBox(height: 16),

                          // Category Selection
                          _buildCategorySelection(theme),

                          const SizedBox(height: 20),

                          // Track Selection
                          _buildTrackSelection(theme),

                          const SizedBox(height: 16),

                          // Selected Tracks Preview
                          if (_selectedTracks.isNotEmpty)
                            _buildSelectedTracksPreview(theme),
                        ],
                      ),
                    ),
                  ),
                ),

                // Actions
                _buildActions(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.playlist_add,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Playlist',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'Organize your music for better focus',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!_isCreating)
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Close',
            ),
        ],
      ),
    );
  }

  Widget _buildNameField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Playlist Name *',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameController,
          enabled: !_isCreating,
          decoration: InputDecoration(
            hintText: 'Enter playlist name',
            prefixIcon: const Icon(Icons.music_note),
            errorText: _nameError,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Playlist name is required';
            }
            if (value.trim().length < 2) {
              return 'Playlist name must be at least 2 characters';
            }
            if (value.trim().length > 50) {
              return 'Playlist name must be less than 50 characters';
            }
            return null;
          },
          onChanged: (value) {
            if (_nameError != null) {
              setState(() {
                _nameError = null;
              });
            }
          },
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
        ),
      ],
    );
  }

  Widget _buildDescriptionField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description (Optional)',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          enabled: !_isCreating,
          decoration: InputDecoration(
            hintText: 'Describe your playlist...',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          maxLines: 3,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  Widget _buildCategorySelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
          ),
          child: DropdownButtonFormField<MusicCategory>(
            value: _selectedCategory,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.category),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: MusicCategory.values.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(category),
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(category.displayName),
                  ],
                ),
              );
            }).toList(),
            onChanged: _isCreating
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackSelection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Add Tracks',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _isCreating ? null : _showTrackSelectionDialog,
              icon: const Icon(Icons.add),
              label: const Text('Browse'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedTracks.isEmpty
                      ? 'No tracks selected. You can add tracks now or later.'
                      : '${_selectedTracks.length} track${_selectedTracks.length == 1 ? '' : 's'} selected',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedTracksPreview(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selected Tracks (${_selectedTracks.length})',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _selectedTracks.length,
            itemBuilder: (context, index) {
              final track = _selectedTracks[index];
              return _buildTrackTile(track, theme, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrackTile(MusicTrack track, ThemeData theme, int index) {
    return Container(
      decoration: BoxDecoration(
        border: index > 0
            ? Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              )
            : null,
      ),
      child: ListTile(
        dense: true,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
          child: Icon(
            _getCategoryIcon(track.category),
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          track.title,
          style: const TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          track.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _isCreating
            ? null
            : IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => _removeTrack(index),
                tooltip: 'Remove track',
              ),
      ),
    );
  }

  Widget _buildActions(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createPlaylist,
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Playlist'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTrackSelectionDialog() {
    final musicService =
        Provider.of<FocusProvider>(context, listen: false).musicService;

    showDialog(
      context: context,
      builder: (context) => _TrackSelectionDialog(
        availableTracks: musicService.allTracks,
        selectedTracks: _selectedTracks,
        onTracksSelected: (tracks) {
          setState(() {
            _selectedTracks = tracks;
          });
        },
      ),
    );
  }

  void _removeTrack(int index) {
    setState(() {
      _selectedTracks.removeAt(index);
    });
  }

  Future<void> _createPlaylist() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() {
      _isCreating = true;
      _nameError = null;
    });

    try {
      final musicService =
          Provider.of<FocusProvider>(context, listen: false).musicService;

      // Check for duplicate names
      final existingPlaylists = musicService.allPlaylists;
      if (existingPlaylists
          .any((p) => p.name.toLowerCase() == name.toLowerCase())) {
        setState(() {
          _nameError = 'A playlist with this name already exists';
          _isCreating = false;
        });
        return;
      }

      // Create the playlist
      final playlist = await musicService.createPlaylist(
        name: name,
        description: description.isEmpty ? null : description,
        trackIds: _selectedTracks.map((track) => track.id).toList(),
        category: _selectedCategory,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child:
                      Text('Playlist "${playlist.name}" created successfully!'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Close dialog
        Navigator.of(context).pop(playlist);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nameError = 'Failed to create playlist: $e';
          _isCreating = false;
        });
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

/// Dialog for selecting tracks to add to playlist
class _TrackSelectionDialog extends StatefulWidget {
  final List<MusicTrack> availableTracks;
  final List<MusicTrack> selectedTracks;
  final Function(List<MusicTrack>) onTracksSelected;

  const _TrackSelectionDialog({
    required this.availableTracks,
    required this.selectedTracks,
    required this.onTracksSelected,
  });

  @override
  State<_TrackSelectionDialog> createState() => _TrackSelectionDialogState();
}

class _TrackSelectionDialogState extends State<_TrackSelectionDialog> {
  late List<MusicTrack> _tempSelectedTracks;
  String _searchQuery = '';
  MusicCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    _tempSelectedTracks = List.from(widget.selectedTracks);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredTracks = _getFilteredTracks();

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
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.library_add,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Select Tracks',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    '${_tempSelectedTracks.length} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // Search and Filter
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tracks...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surface,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  // Category filter
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('All'),
                          selected: _filterCategory == null,
                          onSelected: (selected) {
                            setState(() {
                              _filterCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        ...MusicCategory.values.map((category) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(category.displayName),
                              selected: _filterCategory == category,
                              onSelected: (selected) {
                                setState(() {
                                  _filterCategory = selected ? category : null;
                                });
                              },
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Track list
            Expanded(
              child: ListView.builder(
                itemCount: filteredTracks.length,
                itemBuilder: (context, index) {
                  final track = filteredTracks[index];
                  final isSelected =
                      _tempSelectedTracks.any((t) => t.id == track.id);

                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _tempSelectedTracks.add(track);
                        } else {
                          _tempSelectedTracks
                              .removeWhere((t) => t.id == track.id);
                        }
                      });
                    },
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      ),
                      child: Icon(
                        _getCategoryIcon(track.category),
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      track.title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle:
                        Text('${track.artist} • ${track.category.displayName}'),
                  );
                },
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _tempSelectedTracks.clear();
                      });
                    },
                    child: const Text('Clear All'),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onTracksSelected(_tempSelectedTracks);
                      Navigator.of(context).pop();
                    },
                    child: Text('Add ${_tempSelectedTracks.length} Tracks'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<MusicTrack> _getFilteredTracks() {
    var tracks = widget.availableTracks;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      tracks = tracks.where((track) {
        return track.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            track.artist.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Filter by category
    if (_filterCategory != null) {
      tracks =
          tracks.where((track) => track.category == _filterCategory).toList();
    }

    return tracks;
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
