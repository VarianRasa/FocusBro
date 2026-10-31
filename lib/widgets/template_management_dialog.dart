import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../providers/note_provider.dart';
import '../services/note_template_service.dart';
import 'template_editor_dialog.dart';

/// Dialog for managing note templates (view, edit, delete, create)
class TemplateManagementDialog extends StatefulWidget {
  final Function(NoteTemplate)? onTemplateSelected;
  final bool showSelectButton;

  const TemplateManagementDialog({
    super.key,
    this.onTemplateSelected,
    this.showSelectButton = false,
  });

  @override
  State<TemplateManagementDialog> createState() =>
      _TemplateManagementDialogState();
}

class _TemplateManagementDialogState extends State<TemplateManagementDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final NoteTemplateService _templateService = NoteTemplateService();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _favoritesOnly = false;
  bool _isLoading = false;

  List<NoteTemplate> _allTemplates = [];
  List<NoteTemplate> _filteredTemplates = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _templateService.dispose();
    super.dispose();
  }

  Future<void> _initializeTemplates() async {
    setState(() => _isLoading = true);

    try {
      await _templateService.initialize();
      await _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load templates: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTemplates() async {
    final noteProvider = Provider.of<NoteProvider>(context, listen: false);
    final builtInTemplates = noteProvider.getNoteTemplates();

    _allTemplates = _templateService.getAllTemplates(builtInTemplates);
    _categories = _templateService.getTemplateCategories(_allTemplates);
    _filterTemplates();
  }

  void _filterTemplates() {
    _filteredTemplates = _templateService.searchTemplates(
      _allTemplates,
      _searchQuery,
      categoryFilter: _selectedCategory,
      favoritesOnly: _favoritesOnly,
    );

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.88,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
          minHeight: 600,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(theme, colorScheme),

            // Search and filters
            _buildSearchAndFilters(theme, colorScheme),

            // Tab bar
            _buildTabBar(theme, colorScheme),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildBuiltInTemplates(),
                        _buildCustomTemplates(),
                      ],
                    ),
            ),

            // Action buttons
            _buildActionButtons(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withValues(alpha: 0.3),
            colorScheme.secondaryContainer.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  'Template Manager',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Manage your note templates',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search templates...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
              _filterTemplates();
            },
          ),
          const SizedBox(height: 12),

          // Filters row
          Row(
            children: [
              // Category filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedCategory = value ?? 'All');
                    _filterTemplates();
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Favorites filter
              FilterChip(
                label: const Text('Favorites'),
                selected: _favoritesOnly,
                onSelected: (selected) {
                  setState(() => _favoritesOnly = selected);
                  _filterTemplates();
                },
                avatar: Icon(
                  _favoritesOnly ? Icons.favorite : Icons.favorite_border,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
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
        unselectedLabelStyle: theme.textTheme.labelLarge?.copyWith(
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
                    'Built-in Templates',
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
                    'Custom Templates',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltInTemplates() {
    final builtInTemplates =
        _filteredTemplates.where((t) => t.isBuiltIn).toList();

    if (builtInTemplates.isEmpty) {
      return _buildEmptyState('No built-in templates found');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: builtInTemplates.length,
      itemBuilder: (context, index) {
        final template = builtInTemplates[index];
        return _buildTemplateCard(template, showActions: false);
      },
    );
  }

  Widget _buildCustomTemplates() {
    final customTemplates =
        _filteredTemplates.where((t) => !t.isBuiltIn).toList();

    return Column(
      children: [
        // Add template button
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showCreateTemplateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Create New Template'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        // Templates list
        Expanded(
          child: customTemplates.isEmpty
              ? _buildEmptyState('No custom templates yet')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: customTemplates.length,
                  itemBuilder: (context, index) {
                    final template = customTemplates[index];
                    return _buildTemplateCard(template, showActions: true);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTemplateCard(NoteTemplate template,
      {required bool showActions}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.showSelectButton
                ? () => _selectTemplate(template)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      // Enhanced template icon
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getCategoryColor(template.category)
                                  .withValues(alpha: 0.2),
                              _getCategoryColor(template.category)
                                  .withValues(alpha: 0.1),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getCategoryColor(template.category)
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          _getCategoryIcon(template.category),
                          color: _getCategoryColor(template.category),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Enhanced template info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    template.name,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (template.isFavorite)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.favorite,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  template.isBuiltIn
                                      ? Icons.verified
                                      : Icons.person,
                                  size: 12,
                                  color: _getCategoryColor(template.category),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    template.category,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 11,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                if (template.isBuiltIn)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 3, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'Built-in',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.blue,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Actions
                      SizedBox(
                        width: 100,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Favorite button
                            IconButton(
                              onPressed: () => _toggleFavorite(template),
                              icon: Icon(
                                template.isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: template.isFavorite
                                    ? Colors.red
                                    : colorScheme.onSurfaceVariant,
                                size: 18,
                              ),
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),

                            // Actions menu for custom templates
                            if (showActions && template.canEdit)
                              PopupMenuButton<String>(
                                onSelected: (action) =>
                                    _handleTemplateAction(action, template),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 16),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy, size: 16),
                                        SizedBox(width: 8),
                                        Text('Duplicate'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete,
                                            size: 16, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (template.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
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
                      spacing: 4,
                      children: template.tags.take(3).map((tag) {
                        return Chip(
                          label: Text(
                            tag,
                            style: theme.textTheme.bodySmall,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],

                  // Footer info
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        template.isBuiltIn ? Icons.verified : Icons.person,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          template.isBuiltIn
                              ? 'Built-in template'
                              : 'Custom template',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        template.formattedCreatedAt,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
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
      case 'Voice Notes':
        return Icons.mic;
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

  void _selectTemplate(NoteTemplate template) {
    widget.onTemplateSelected?.call(template);
    Navigator.of(context).pop();
  }

  Future<void> _toggleFavorite(NoteTemplate template) async {
    try {
      await _templateService.toggleTemplateFavorite(template.id);
      await _loadTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle favorite: $e')),
        );
      }
    }
  }

  void _handleTemplateAction(String action, NoteTemplate template) {
    switch (action) {
      case 'edit':
        _showEditTemplateDialog(template);
        break;
      case 'duplicate':
        _duplicateTemplate(template);
        break;
      case 'delete':
        _showDeleteConfirmation(template);
        break;
    }
  }

  void _showCreateTemplateDialog() {
    showDialog(
      context: context,
      builder: (context) => TemplateEditorDialog(
        onSave: (name, title, content, category, description, tags) async {
          try {
            await _templateService.createTemplate(
              name: name,
              title: title,
              content: content,
              category: category,
              description: description,
              tags: tags,
            );
            await _loadTemplates();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template created successfully!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to create template: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditTemplateDialog(NoteTemplate template) {
    showDialog(
      context: context,
      builder: (context) => TemplateEditorDialog(
        template: template,
        onSave: (name, title, content, category, description, tags) async {
          try {
            await _templateService.updateTemplate(
              templateId: template.id,
              name: name,
              title: title,
              content: content,
              category: category,
              description: description,
              tags: tags,
            );
            await _loadTemplates();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Template updated successfully!')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to update template: $e')),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _duplicateTemplate(NoteTemplate template) async {
    try {
      await _templateService.createTemplate(
        name: '${template.name} (Copy)',
        title: template.title,
        content: template.content,
        category: template.category,
        description: template.description,
        tags: template.tags,
      );
      await _loadTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template duplicated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to duplicate template: $e')),
        );
      }
    }
  }

  void _showDeleteConfirmation(NoteTemplate template) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _templateService.deleteTemplate(template.id);
                await _loadTemplates();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Template deleted successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete template: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
