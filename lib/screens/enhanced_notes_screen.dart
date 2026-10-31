import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../widgets/voice_notes_demo_dialog.dart';
import '../widgets/template_management_dialog.dart';
import '../widgets/save_to_template_dialog.dart';
import '../services/note_template_service.dart';
import 'enhanced_note_editor_v2.dart';
import '../utils/accessibility_helper.dart';
import '../utils/validation_helper.dart';

/// Enhanced Notes Screen with advanced features and real data integration
class EnhancedNotesScreen extends StatefulWidget {
  const EnhancedNotesScreen({super.key});

  @override
  State<EnhancedNotesScreen> createState() => _EnhancedNotesScreenState();
}

class _EnhancedNotesScreenState extends State<EnhancedNotesScreen>
    with TickerProviderStateMixin {
  final List<String> _sortOptions = ['updated', 'title', 'created', 'category'];

  // Advanced search state
  String _advancedSearchQuery = '';
  List<String> _selectedCategories = [];
  List<String> _selectedTags = [];
  bool _favoritesOnly = false;
  bool _pinnedOnly = false;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Tag input controller
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tagInputController = TextEditingController();

  // Expandable FAB state
  AnimationController? _fabAnimationController;
  Animation<double>? _fabAnimation;
  Animation<double>? _fabRotationAnimation;
  bool _isFabExpanded = false;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
    _initializeFabAnimation();
  }

  void _initializeFabAnimation() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController!,
      curve: Curves.easeOutCubic,
    );

    _fabRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.125, // 45 degrees (1/8 turn)
    ).animate(_fabAnimation!);
  }

  Future<void> _initializeProvider() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    if (!noteProvider.isInitialized) {
      await noteProvider.initialize();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tagInputController.dispose();
    _fabAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<NoteProvider>(
      builder: (context, noteProvider, child) {
        if (noteProvider.isLoading && !noteProvider.isInitialized) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (noteProvider.error != null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading notes',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    noteProvider.error!,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => noteProvider.initialize(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Smart Notes'),
            elevation: 0,
            actions: [
              // View Toggle
              IconButton(
                onPressed: () => noteProvider.toggleViewMode(),
                icon: Icon(noteProvider.isGridView
                    ? Icons.view_list
                    : Icons.grid_view),
                tooltip: noteProvider.isGridView ? 'List View' : 'Grid View',
              ),

              // More Options
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'templates',
                    child: ListTile(
                      leading: Icon(Icons.library_books),
                      title: Text('Manage Templates'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Export Notes'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.upload),
                      title: Text('Import Notes'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings),
                      title: Text('Note Settings'),
                    ),
                  ),
                ],
                onSelected: (value) => _handleMenuAction(value, noteProvider),
              ),
            ],
          ),
          body: Column(
            children: [
              // Enhanced Filter Bar
              _buildEnhancedFilterBar(theme, noteProvider),

              // Notes Content
              Expanded(
                child: _buildNotesContent(theme, noteProvider),
              ),
            ],
          ),
          floatingActionButton: _buildSmartFAB(context),
        );
      },
    );
  }

  Widget _buildEnhancedFilterBar(ThemeData theme, NoteProvider noteProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search Bar with Advanced Search
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: Consumer<NoteProvider>(
              builder: (context, noteProvider, child) {
                return TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search notes, tags, or content...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Clear button (show only when there's text)
                        if (noteProvider.searchQuery.isNotEmpty)
                          IconButton(
                            onPressed: () {
                              _searchController.clear();
                              noteProvider.setSearchQuery('');
                            },
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear Search',
                          ),
                        // Advanced Search button
                        IconButton(
                          onPressed: () => _showAdvancedSearch(context),
                          icon: const Icon(Icons.tune),
                          tooltip: 'Advanced Search',
                        ),
                      ],
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    // Real-time search
                    noteProvider.setSearchQuery(value);
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // Filter Chips
          Row(
            children: [
              // Category Filter
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: noteProvider.categories.map((category) {
                      final isSelected =
                          noteProvider.selectedCategory == category;
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            noteProvider.setCategory(category);
                          },
                          backgroundColor: theme.colorScheme.surface,
                          selectedColor:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                          checkmarkColor: theme.colorScheme.primary,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Sort Dropdown
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: noteProvider.sortBy,
                  underline: const SizedBox(),
                  items: _sortOptions.map((option) {
                    String displayName;
                    switch (option) {
                      case 'updated':
                        displayName = 'Recent';
                        break;
                      case 'title':
                        displayName = 'Alphabetical';
                        break;
                      case 'created':
                        displayName = 'Created';
                        break;
                      case 'category':
                        displayName = 'Category';
                        break;
                      default:
                        displayName = option;
                    }
                    return DropdownMenuItem(
                      value: option,
                      child: Text(displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      noteProvider.setSortBy(value);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesContent(ThemeData theme, NoteProvider noteProvider) {
    final notes = noteProvider.filteredNotes;

    if (notes.isEmpty) {
      return _buildEmptyState(theme);
    }

    return noteProvider.isGridView
        ? _buildGridView(notes, theme)
        : _buildListView(notes, theme);
  }

  Widget _buildGridView(List<Note> notes, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.8,
      ),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return _buildNoteGridCard(note, theme);
      },
    );
  }

  Widget _buildListView(List<Note> notes, ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: notes.length,
      itemBuilder: (context, index) {
        final note = notes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildNoteListCard(note, theme),
        );
      },
    );
  }

  Widget _buildNoteGridCard(Note note, ThemeData theme) {
    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'Note: ${note.title}',
      semanticHint: 'Double tap to open note',
      onTap: () => _openNote(note),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Note Header
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(note.category),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Pinned indicator
                          if (note.isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 12,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              note.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Tags display
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: note.tags.take(2).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList()
                            ..addAll(note.tags.length > 2
                                ? [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.outline
                                            .withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${note.tags.length - 2}',
                                        style: TextStyle(
                                          fontSize: 8,
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.7),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ]
                                : []),
                        ),
                      ],
                    ],
                  ),
                ),
                // Compact action row
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note.isFavorite)
                      const Icon(
                        Icons.favorite,
                        size: 14,
                        color: Colors.red,
                      ),
                    PopupMenuButton(
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'pin',
                          child: Row(
                            children: [
                              Icon(note.isPinned
                                  ? Icons.push_pin_outlined
                                  : Icons.push_pin),
                              const SizedBox(width: 8),
                              Text(note.isPinned ? 'Unpin' : 'Pin'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'favorite',
                          child: Row(
                            children: [
                              Icon(note.isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border),
                              const SizedBox(width: 8),
                              Text(note.isFavorite ? 'Unfavorite' : 'Favorite'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                            value: 'save_template',
                            child: Text('Save as Template')),
                        const PopupMenuItem(
                            value: 'share', child: Text('Share')),
                        const PopupMenuItem(
                            value: 'duplicate', child: Text('Duplicate')),
                        const PopupMenuItem(
                            value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (value) => _handleNoteAction(value, note),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Note Content Preview
            Expanded(
              child: Text(
                note.content,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 12),

            // Note Footer
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatDate(note.updatedAt),
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(note.category),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteListCard(Note note, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: InkWell(
        onTap: () => _openNote(note),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(note.category),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Pinned indicator
                          if (note.isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              note.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (note.isFavorite) ...[
                            const Icon(
                              Icons.favorite,
                              size: 12,
                              color: Colors.red,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            _formatDate(note.updatedAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  padding: EdgeInsets.zero,
                  iconSize: 20,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(note.isPinned
                              ? Icons.push_pin_outlined
                              : Icons.push_pin),
                          const SizedBox(width: 8),
                          Text(note.isPinned ? 'Unpin' : 'Pin'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'favorite',
                      child: Row(
                        children: [
                          Icon(note.isFavorite
                              ? Icons.favorite
                              : Icons.favorite_border),
                          const SizedBox(width: 8),
                          Text(note.isFavorite ? 'Unfavorite' : 'Favorite'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(
                        value: 'save_template',
                        child: Text('Save as Template')),
                    const PopupMenuItem(value: 'share', child: Text('Share')),
                    const PopupMenuItem(
                        value: 'duplicate', child: Text('Duplicate')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onSelected: (value) => _handleNoteAction(value, note),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              note.content,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),

            // Tags and Category Row
            Row(
              children: [
                // Category badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    note.category,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                // Tags
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: note.tags.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList()
                        ..addAll(note.tags.length > 3
                            ? [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '+${note.tags.length - 3}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ]
                            : []),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No notes found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first note to get started',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _createNewNote(),
            icon: const Icon(Icons.add),
            label: const Text('Create Note'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartFAB(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Transparent backdrop for closing FAB when tapped outside
        if (_isFabExpanded && _fabAnimation != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: _toggleFab,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // FAB Column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Sub-action buttons with animations
            if (_fabAnimation != null) ...[
              _buildAnimatedSubButton(
                icon: Icons.library_books,
                color: Colors.purple,
                label: 'Template',
                onPressed: () {
                  _toggleFab();
                  _showTemplateSelector();
                },
                heroTag: 'template_note',
                delay: 0,
              ),
              const SizedBox(height: 12),
              _buildAnimatedSubButton(
                icon: Icons.mic,
                color: Colors.orange,
                label: 'Voice Note',
                onPressed: () {
                  _toggleFab();
                  _createVoiceNote();
                },
                heroTag: 'voice_note',
                delay: 50,
              ),
              const SizedBox(height: 12),
              _buildAnimatedSubButton(
                icon: Icons.note_add,
                color: Colors.green,
                label: 'Quick Note',
                onPressed: () {
                  _toggleFab();
                  _createQuickNote();
                },
                heroTag: 'quick_note',
                delay: 100,
              ),
              const SizedBox(height: 12),
              _buildAnimatedSubButton(
                icon: Icons.edit,
                color: null,
                label: 'New Note',
                onPressed: () {
                  _toggleFab();
                  _createNewNote();
                },
                heroTag: 'regular_note',
                delay: 150,
              ),
              const SizedBox(height: 12),
            ],

            // Main FAB with rotation animation
            FloatingActionButton(
              heroTag: 'main_fab',
              onPressed: _toggleFab,
              elevation: _isFabExpanded ? 8 : 6,
              child: _fabRotationAnimation != null
                  ? AnimatedBuilder(
                      animation: _fabRotationAnimation!,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _fabRotationAnimation!.value *
                              0.75, // 3/4 rotation
                          child: Icon(_isFabExpanded ? Icons.close : Icons.add),
                        );
                      },
                    )
                  : Icon(_isFabExpanded ? Icons.close : Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedSubButton({
    required IconData icon,
    required Color? color,
    required String label,
    required VoidCallback onPressed,
    required String heroTag,
    required int delay,
  }) {
    return AnimatedBuilder(
      animation: _fabAnimation!,
      builder: (context, child) {
        // Calculate staggered animation value with bounce effect
        final delayedValue = (_fabAnimation!.value * 300 - delay) / 300;
        final clampedValue = delayedValue.clamp(0.0, 1.0);
        final animationValue = Curves.elasticOut.transform(clampedValue);
        final slideValue = Curves.easeOutCubic.transform(clampedValue);

        return Transform.translate(
          offset: Offset(0, 30 * (1 - slideValue)), // Slide up animation
          child: Transform.scale(
            scale: animationValue,
            child: Opacity(
              opacity: slideValue,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated label with enhanced styling
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Animated FAB with enhanced styling
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (color ?? Theme.of(context).colorScheme.primary)
                                  .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      heroTag: heroTag,
                      onPressed: onPressed,
                      backgroundColor: color,
                      mini: true,
                      elevation: 6,
                      child: Icon(
                        icon,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
    });

    if (_isFabExpanded) {
      _fabAnimationController?.forward();
    } else {
      _fabAnimationController?.reverse();
    }
  }

  void _showTemplateSelector() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final builtInTemplates = noteProvider.getNoteTemplates();

    // Load custom templates
    final templateService = NoteTemplateService();
    await templateService.initialize();
    final allTemplates = templateService.getAllTemplates(builtInTemplates);

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildTemplateSelector(allTemplates),
      );
    }
  }

  Widget _buildTemplateSelector(List<NoteTemplate> templates) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Separate built-in and custom templates
    final builtInTemplates = templates.where((t) => t.isBuiltIn).toList();
    final customTemplates = templates.where((t) => !t.isBuiltIn).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Enhanced Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.3),
                  colorScheme.secondaryContainer.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.library_books_rounded,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose Template',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${templates.length} templates available',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _showTemplateManager,
                      icon: Icon(
                        Icons.settings_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Manage Templates',
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Templates content with tabs
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Enhanced Tab bar
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: TabBar(
                      indicator: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary,
                            colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      labelColor: colorScheme.onPrimary,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      labelStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle:
                          theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      dividerColor: Colors.transparent,
                      indicatorPadding: const EdgeInsets.all(4),
                      tabs: [
                        Tab(
                          height: 48,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_rounded, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Built-in (${builtInTemplates.length})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tab(
                          height: 48,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_rounded, size: 18),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Custom (${customTemplates.length})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildTemplateList(
                            builtInTemplates, theme, colorScheme),
                        _buildTemplateList(customTemplates, theme, colorScheme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateList(
      List<NoteTemplate> templates, ThemeData theme, ColorScheme colorScheme) {
    if (templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_books_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No templates found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first custom template',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: _buildEnhancedTemplateCard(template, theme, colorScheme),
        );
      },
    );
  }

  Widget _buildEnhancedTemplateCard(
      NoteTemplate template, ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          _createNoteFromTemplate(template);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Template icon
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(template.category)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(template.category),
                      color: _getCategoryColor(template.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Template info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                template.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (template.isFavorite)
                              Icon(
                                Icons.favorite,
                                size: 16,
                                color: Colors.red,
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              template.isBuiltIn
                                  ? Icons.verified
                                  : Icons.person,
                              size: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              template.category,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Arrow icon
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              // Description
              if (template.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  template.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags
              if (template.tags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: template.tags.take(3).map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            colorScheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tag,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Work':
        return Icons.work;
      case 'Personal':
        return Icons.person;
      case 'Study':
        return Icons.school;
      case 'Project':
        return Icons.folder;
      case 'Meeting':
        return Icons.meeting_room;
      case 'Ideas':
        return Icons.lightbulb;
      case 'Quick Note':
        return Icons.note;
      default:
        return Icons.note;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Work':
        return Colors.blue;
      case 'Personal':
        return Colors.green;
      case 'Study':
        return Colors.teal;
      case 'Project':
        return Colors.indigo;
      case 'Meeting':
        return Colors.orange;
      case 'Ideas':
        return Colors.purple;
      case 'Quick Note':
        return Colors.amber;
      case 'Voice Notes':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  Future<void> _createNoteFromTemplate(NoteTemplate template) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedNoteEditorV2(template: template),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note created from ${template.name} template!')),
      );
    }
  }

  // Helper methods

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showAdvancedSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAdvancedSearchSheet(context),
    );
  }

  void _handleMenuAction(String action, NoteProvider noteProvider) {
    switch (action) {
      case 'templates':
        _showTemplateManager();
        break;
      case 'export':
        _exportNotes(noteProvider);
        break;
      case 'import':
        _importNotes(noteProvider);
        break;
      case 'settings':
        _showNotesSettings();
        break;
      case 'backup':
        _backupNotes();
        break;
    }
  }

  void _openNote(Note note) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnhancedNoteEditorV2(note: note),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note updated successfully!')),
      );
    }
  }

  void _handleNoteAction(String action, Note note) {
    switch (action) {
      case 'edit':
        _openNote(note);
        break;
      case 'save_template':
        _saveNoteAsTemplate(note);
        break;
      case 'share':
        _shareNote(note);
        break;
      case 'delete':
        _deleteNote(note);
        break;
      case 'duplicate':
        _duplicateNote(note);
        break;
      case 'pin':
        _togglePin(note);
        break;
      case 'favorite':
        _toggleFavorite(note);
        break;
    }
  }

  void _createNewNote() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedNoteEditorV2(),
      ),
    );
    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note created successfully!')),
      );
    }
  }

  void _createVoiceNote() {
    showDialog(
      context: context,
      builder: (context) => VoiceNotesDemoDialog(
        onTranscriptionComplete: (transcription) {
          // Create a new note with the transcription
          _createNoteFromTranscription(transcription);
        },
      ),
    );
  }

  void _createNoteFromTranscription(String transcription) async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);

      // Create a new note with the transcription using NoteProvider
      final note = await noteProvider.createNote(
        title: 'Voice Note ${DateTime.now().day}/${DateTime.now().month}',
        content: transcription,
        category: 'Voice Notes',
        tags: ['voice', 'audio', 'transcription'],
      );

      if (mounted && note != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voice note created successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create voice note'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create note: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _createQuickNote() {
    showDialog(
      context: context,
      builder: (context) => _buildQuickNoteDialog(context),
    );
  }

  // Helper methods for note operations
  Future<bool> _showImportConfirmationDialog(String fileName) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Import Notes'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import notes from "$fileName"?'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Duplicate notes will be skipped automatically.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Import'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _exportNotes(NoteProvider noteProvider) async {
    try {
      // Show enhanced export options dialog
      final exportOptions = await _showEnhancedExportDialog();
      if (exportOptions == null) return;

      final format = exportOptions['format'] ?? 'JSON';
      final method = exportOptions['method'] ?? 'save';

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Preparing export...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      List<int> exportData;
      String fileName;
      String fileExtension;

      // Generate export data based on format
      switch (format) {
        case 'JSON':
          exportData = utf8.encode(await noteProvider.exportNotes() ?? '');
          fileExtension = 'json';
          fileName =
              'focusbro_notes_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
          break;
        case 'PDF':
          exportData = await _generatePDFExport(noteProvider);
          fileExtension = 'pdf';
          fileName =
              'focusbro_notes_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
          break;
        case 'TXT':
          exportData = utf8.encode(await _generateTextExport(noteProvider));
          fileExtension = 'txt';
          fileName =
              'focusbro_notes_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
          break;
        case 'MD':
          exportData = utf8.encode(await _generateMarkdownExport(noteProvider));
          fileExtension = 'md';
          fileName =
              'focusbro_notes_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
          break;
        default:
          exportData = utf8.encode(await noteProvider.exportNotes() ?? '');
          fileExtension = 'json';
          fileName =
              'focusbro_notes_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      if (method == 'share') {
        await _shareExportedData(exportData, fileName, format);
      } else {
        await _saveExportedDataToFile(exportData, fileName, format);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _selectedExportFormat = 'JSON';

  Future<Map<String, String>?> _showEnhancedExportDialog() async {
    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Export Notes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Choose export format and method:'),
              const SizedBox(height: 16),

              // Format Selection
              const Text(
                'Format:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // Format Options
              _buildFormatOption(
                  'JSON', 'Complete data with metadata', Icons.code, setState),
              _buildFormatOption(
                  'PDF', 'Formatted document', Icons.picture_as_pdf, setState),
              _buildFormatOption(
                  'TXT', 'Plain text format', Icons.text_fields, setState),
              _buildFormatOption(
                  'MD', 'Markdown format', Icons.article, setState),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context,
                  {'format': _selectedExportFormat, 'method': 'share'}),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.share, size: 18),
                  SizedBox(width: 8),
                  Text('Share'),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, {'format': _selectedExportFormat, 'method': 'save'}),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.save, size: 18),
                  SizedBox(width: 8),
                  Text('Save File'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatOption(
      String format, String description, IconData icon, StateSetter setState) {
    return RadioListTile<String>(
      value: format,
      groupValue: _selectedExportFormat,
      onChanged: (value) {
        setState(() {
          _selectedExportFormat = value!;
        });
      },
      title: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(format),
        ],
      ),
      subtitle: Text(description),
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  // Export format generators
  Future<Uint8List> _generatePDFExport(NoteProvider noteProvider) async {
    final notes = noteProvider.filteredNotes;
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 16),
          child: pw.Text(
            'FocusBro Notes Export',
            style: pw.TextStyle(
              color: PdfColors.blueGrey700,
              fontSize: 10,
            ),
          ),
        ),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 16),
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ),
        build: (context) => [
          pw.Text(
            'FocusBro Notes Export',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${DateTime.now().toLocal()}'),
          pw.Text('Total notes: ${notes.length}'),
          pw.Divider(),
          if (notes.isEmpty) pw.Text('No notes match the current filters.'),
          ...notes.map(
            (note) => pw.Container(
              margin: const pw.EdgeInsets.only(top: 12, bottom: 12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    note.title,
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${note.category} • Created ${_formatDate(note.createdAt)} • Updated ${_formatDate(note.updatedAt)}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.blueGrey700,
                    ),
                  ),
                  if (note.tags.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 3),
                      child: pw.Text(
                        'Tags: ${note.tags.join(', ')}',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ),
                  pw.SizedBox(height: 8),
                  pw.Text(note.content.isEmpty ? '(No content)' : note.content),
                  pw.Divider(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    return document.save();
  }

  Future<String> _generateTextExport(NoteProvider noteProvider) async {
    final notes = noteProvider.filteredNotes;
    final buffer = StringBuffer();

    buffer.writeln('FocusBro Notes Export');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total Notes: ${notes.length}');
    buffer.writeln('\n${'=' * 50}\n');

    for (final note in notes) {
      buffer.writeln('📝 ${note.title}');
      buffer.writeln('📂 Category: ${note.category}');
      buffer.writeln('📅 Created: ${_formatDate(note.createdAt)}');
      if (note.tags.isNotEmpty) {
        buffer.writeln('🏷️ Tags: ${note.tags.join(', ')}');
      }
      buffer.writeln('\n${note.content}');
      buffer.writeln('\n${'─' * 40}\n');
    }

    return buffer.toString();
  }

  Future<String> _generateMarkdownExport(NoteProvider noteProvider) async {
    final notes = noteProvider.filteredNotes;
    final buffer = StringBuffer();

    buffer.writeln('# FocusBro Notes Export\n');
    buffer.writeln('**Generated:** ${DateTime.now()}');
    buffer.writeln('**Total Notes:** ${notes.length}\n');
    buffer.writeln('---\n');

    for (final note in notes) {
      buffer.writeln('## ${note.title}\n');
      buffer.writeln('- **Category:** ${note.category}');
      buffer.writeln('- **Created:** ${_formatDate(note.createdAt)}');
      buffer.writeln('- **Updated:** ${_formatDate(note.updatedAt)}');
      if (note.tags.isNotEmpty) {
        buffer.writeln(
            '- **Tags:** ${note.tags.map((tag) => '`$tag`').join(', ')}');
      }
      buffer.writeln('\n### Content\n');
      buffer.writeln(note.content);
      buffer.writeln('\n---\n');
    }

    return buffer.toString();
  }

  Future<void> _shareExportedData(
      List<int> exportData, String fileName, String format) async {
    try {
      // Create temporary file for sharing
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(exportData, flush: true);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'FocusBro Notes Export - $format Format',
        subject: 'My Notes from FocusBro',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notes shared successfully as $format!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveExportedDataToFile(
      List<int> exportData, String fileName, String format) async {
    try {
      // Get documents directory
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');

      // Write data to file
      await file.writeAsBytes(exportData, flush: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notes saved as $format to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: () async {
                await Share.shareXFiles([XFile(file.path)]);
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importNotes(NoteProvider noteProvider) async {
    try {
      // Show file picker for JSON files
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'txt'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      String jsonData;

      // Read file content
      if (file.bytes != null) {
        // Web or when file is loaded as bytes
        jsonData = String.fromCharCodes(file.bytes!);
      } else if (file.path != null) {
        // Mobile/Desktop with file path
        final fileContent = await File(file.path!).readAsString();
        jsonData = fileContent;
      } else {
        throw Exception('Unable to read file content');
      }

      // Validate JSON format
      if (jsonData.trim().isEmpty) {
        throw Exception('File is empty');
      }

      // Show import confirmation dialog
      final confirmed = await _showImportConfirmationDialog(file.name);
      if (!confirmed) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Importing notes...'),
              ],
            ),
            duration: Duration(seconds: 30),
          ),
        );
      }

      // Import notes
      final importedCount = await noteProvider.importNotes(jsonData);

      if (mounted) {
        // Hide loading indicator
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (importedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully imported $importedCount notes!'),
              backgroundColor: Colors.green,
              action: SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () {
                  // Refresh the view to show new notes
                  // Notes will automatically appear at the top due to sorting
                },
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new notes were imported (duplicates skipped)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _importNotes(noteProvider),
            ),
          ),
        );
      }
    }
  }

  void _showNotesSettings() {
    showDialog(
      context: context,
      builder: (context) => _buildNotesSettingsDialog(context),
    );
  }

  void _backupNotes() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backing up notes...')),
    );
    // Implement backup functionality
  }

  void _shareNote(Note note) async {
    try {
      // Format note content for sharing
      final shareText = _formatNoteForSharing(note);

      // Show share options dialog
      final shareOption = await _showShareOptionsDialog(note.title);
      if (shareOption == null) return;

      if (shareOption == 'text') {
        // Share as plain text
        await Share.share(
          shareText,
          subject: 'Note: ${note.title}',
        );
      } else if (shareOption == 'file') {
        // Share as JSON file
        await _shareNoteAsFile(note);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Note "${note.title}" shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatNoteForSharing(Note note) {
    final buffer = StringBuffer();
    buffer.writeln('📝 ${note.title}');
    buffer.writeln('');

    if (note.category.isNotEmpty) {
      buffer.writeln('📂 Category: ${note.category}');
    }

    buffer.writeln('📅 Created: ${_formatDate(note.createdAt)}');
    buffer.writeln('');
    buffer.writeln('Content:');
    buffer.writeln(note.content);
    buffer.writeln('');
    buffer.writeln('---');
    buffer.writeln('Shared from FocusBro Notes');

    return buffer.toString();
  }

  Future<String?> _showShareOptionsDialog(String noteTitle) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Share "$noteTitle"'),
        content: const Text('How would you like to share this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'text'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.text_fields, size: 18),
                SizedBox(width: 8),
                Text('As Text'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, 'file'),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.file_present, size: 18),
                SizedBox(width: 8),
                Text('As File'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareNoteAsFile(Note note) async {
    try {
      // Create JSON data for single note
      final noteData = {
        'version': '1.0',
        'exportDate': DateTime.now().toIso8601String(),
        'note': note.toMap(),
      };

      final jsonData = jsonEncode(noteData);
      final fileName =
          'note_${ValidationHelper.sanitizeFileName(note.title)}_${DateTime.now().millisecondsSinceEpoch}.json';

      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsString(jsonData);

      // Share the file
      await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: 'Note: ${note.title}',
        subject: 'FocusBro Note Export',
      );
    } catch (e) {
      rethrow;
    }
  }

  void _deleteNote(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: Text('Are you sure you want to delete "${note.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      final success = await noteProvider.deleteNote(note.id);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully')),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete note')),
        );
      }
    }
  }

  void _duplicateNote(Note note) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final duplicatedNote = await noteProvider.duplicateNote(note.id);

    if (duplicatedNote != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${note.title}"')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to duplicate note')),
      );
    }
  }

  void _togglePin(Note note) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final success = await noteProvider.togglePinned(note.id);

    if (success && mounted) {
      final action = note.isPinned ? 'unpinned' : 'pinned';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note $action successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update pin status')),
      );
    }
  }

  void _toggleFavorite(Note note) async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final success = await noteProvider.toggleFavorite(note.id);

    if (success && mounted) {
      final action = note.isFavorite ? 'removed from' : 'added to';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Note $action favorites')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update favorite status')),
      );
    }
  }

  // UI Builder methods

  Widget _buildAdvancedSearchSheet(BuildContext context) {
    final theme = Theme.of(context);
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Advanced Search',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),

          // Search Options
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text Search Section
                  Text(
                    'Search Text',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _advancedSearchQuery,
                    decoration: InputDecoration(
                      labelText: 'Search Text',
                      hintText: 'Search in title, content, and tags...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onChanged: (value) => _advancedSearchQuery = value,
                  ),

                  const SizedBox(height: 24),

                  // Tags Section
                  Text(
                    'Tags',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Consumer<NoteProvider>(
                    builder: (context, noteProvider, child) {
                      final allTags = noteProvider.getAllTags();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Tag Input Field
                          TextFormField(
                            controller: _tagInputController,
                            decoration: InputDecoration(
                              labelText: 'Add Tag Filter',
                              hintText: 'Type tag name and press Enter...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(Icons.tag),
                              suffixIcon: IconButton(
                                onPressed: () {
                                  final tag = _tagInputController.text
                                      .trim()
                                      .toLowerCase();
                                  if (tag.isNotEmpty &&
                                      !_selectedTags.contains(tag)) {
                                    setState(() {
                                      _selectedTags.add(tag);
                                      _tagInputController.clear();
                                    });
                                  }
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ),
                            onFieldSubmitted: (value) {
                              final tag = value.trim().toLowerCase();
                              if (tag.isNotEmpty &&
                                  !_selectedTags.contains(tag)) {
                                setState(() {
                                  _selectedTags.add(tag);
                                  _tagInputController.clear();
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 12),

                          // Selected Tags
                          if (_selectedTags.isNotEmpty) ...[
                            Text(
                              'Selected Tags:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: _selectedTags.map((tag) {
                                return Chip(
                                  label: Text(tag),
                                  deleteIcon: const Icon(Icons.close, size: 18),
                                  onDeleted: () {
                                    setState(() {
                                      _selectedTags.remove(tag);
                                    });
                                  },
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Available Tags
                          if (allTags.isNotEmpty) ...[
                            Text(
                              'Available Tags:',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: allTags
                                  .where((tag) => !_selectedTags.contains(tag))
                                  .map((tag) {
                                return FilterChip(
                                  label: Text(tag),
                                  selected: false,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _selectedTags.add(tag);
                                      });
                                    }
                                  },
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Categories Section
                  Text(
                    'Categories',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: noteProvider.categories.map((category) {
                      return FilterChip(
                        label: Text(category),
                        selected: _selectedCategories.contains(category),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedCategories.add(category);
                            } else {
                              _selectedCategories.remove(category);
                            }
                          });
                        },
                        backgroundColor: _selectedCategories.contains(category)
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        labelStyle: TextStyle(
                          color: _selectedCategories.contains(category)
                              ? theme.colorScheme.onPrimaryContainer
                              : theme.colorScheme.onSurface,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Filter Options Section
                  Text(
                    'Filter Options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      CheckboxListTile(
                        title: const Text('Favorites Only'),
                        subtitle: const Text('Show only favorite notes'),
                        value: _favoritesOnly,
                        onChanged: (value) {
                          setState(() {
                            _favoritesOnly = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                      CheckboxListTile(
                        title: const Text('Pinned Only'),
                        subtitle: const Text('Show only pinned notes'),
                        value: _pinnedOnly,
                        onChanged: (value) {
                          setState(() {
                            _pinnedOnly = value ?? false;
                          });
                        },
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Date Range
                  Text(
                    'Date Range',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'From Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, true),
                          controller: TextEditingController(
                            text: _fromDate != null
                                ? '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}'
                                : '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'To Date',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, false),
                          controller: TextEditingController(
                            text: _toDate != null
                                ? '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}'
                                : '',
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _clearAdvancedSearch,
                          child: const Text('Clear'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _performAdvancedSearch(noteProvider),
                          child: const Text('Search'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  void _clearAdvancedSearch() {
    setState(() {
      _advancedSearchQuery = '';
      _selectedCategories.clear();
      _selectedTags.clear();
      _favoritesOnly = false;
      _pinnedOnly = false;
      _fromDate = null;
      _toDate = null;
    });
  }

  Future<void> _performAdvancedSearch(NoteProvider noteProvider) async {
    Navigator.pop(context);

    // Use the new advanced search with tags support
    final results = await noteProvider.searchNotesAdvanced(
      _advancedSearchQuery,
      filterTags: _selectedTags.isNotEmpty ? _selectedTags : null,
    );

    // Apply additional filters
    List<Note> filteredResults = results;

    // Filter by categories
    if (_selectedCategories.isNotEmpty) {
      filteredResults = filteredResults
          .where((note) => _selectedCategories.contains(note.category))
          .toList();
    }

    // Filter by favorites
    if (_favoritesOnly) {
      filteredResults =
          filteredResults.where((note) => note.isFavorite).toList();
    }

    // Filter by pinned
    if (_pinnedOnly) {
      filteredResults = filteredResults.where((note) => note.isPinned).toList();
    }

    // Filter by date range
    if (_fromDate != null) {
      filteredResults = filteredResults
          .where((note) =>
              note.createdAt.isAfter(_fromDate!) ||
              note.createdAt.isAtSameMomentAs(_fromDate!))
          .toList();
    }

    if (_toDate != null) {
      final endOfDay =
          DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
      filteredResults = filteredResults
          .where((note) =>
              note.createdAt.isBefore(endOfDay) ||
              note.createdAt.isAtSameMomentAs(endOfDay))
          .toList();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Found ${filteredResults.length} notes'),
          backgroundColor:
              filteredResults.isNotEmpty ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Widget _buildNotesSettingsDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Notes Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Auto-save'),
            subtitle: const Text('Automatically save notes'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // Handle auto-save toggle
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_sync),
            title: const Text('Cloud Sync'),
            subtitle: const Text('Sync notes across devices'),
            trailing: Switch(
              value: false,
              onChanged: (value) {
                // Handle cloud sync toggle
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildQuickNoteDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    return AlertDialog(
      title: const Text('Quick Note'),
      content: TextField(
        controller: controller,
        maxLines: 5,
        decoration: const InputDecoration(
          hintText: 'Type your quick note here...',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (controller.text.isNotEmpty) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quick note saved!')),
              );
              // Save the quick note
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// Show template management dialog
  void _showTemplateManager() {
    showDialog(
      context: context,
      builder: (context) => const TemplateManagementDialog(),
    );
  }

  /// Save note as template
  void _saveNoteAsTemplate(Note note) {
    showDialog(
      context: context,
      builder: (context) => SaveToTemplateDialog(
        note: note,
        onTemplateSaved: (template) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Template "${template.name}" saved successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }
}

// Placeholder for NoteEditorScreen
class NoteEditorScreen extends StatelessWidget {
  final Map<String, dynamic>? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(note != null ? 'Edit Note' : 'New Note'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note saved!')),
              );
            },
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              controller: TextEditingController(text: note?['title'] ?? ''),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: null,
                expands: true,
                controller: TextEditingController(text: note?['content'] ?? ''),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
