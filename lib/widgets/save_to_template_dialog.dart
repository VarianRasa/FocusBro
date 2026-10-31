import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_template_service.dart';

/// Dialog for saving a note as a template
class SaveToTemplateDialog extends StatefulWidget {
  final Note note;
  final Function(NoteTemplate)? onTemplateSaved;

  const SaveToTemplateDialog({
    super.key,
    required this.note,
    this.onTemplateSaved,
  });

  @override
  State<SaveToTemplateDialog> createState() => _SaveToTemplateDialogState();
}

class _SaveToTemplateDialogState extends State<SaveToTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _templateNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedCategory = 'Other';
  bool _isLoading = false;

  final List<String> _categories = [
    'Work',
    'Personal',
    'Study',
    'Project',
    'Meeting',
    'Ideas',
    'Quick Note',
    'Voice Notes',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  @override
  void dispose() {
    _templateNameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    // Pre-fill with note data
    _templateNameController.text = '${widget.note.title} Template';
    _selectedCategory = widget.note.category;
    _descriptionController.text =
        'Template created from note: ${widget.note.title}';
    _tagsController.text = widget.note.tags.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme, colorScheme),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildForm(theme, colorScheme),
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
              Icons.save_as_rounded,
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
                  'Save as Template',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Create a reusable template from this note',
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

  Widget _buildForm(ThemeData theme, ColorScheme colorScheme) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Template name
          TextFormField(
            controller: _templateNameController,
            decoration: InputDecoration(
              labelText: 'Template Name *',
              hintText: 'Enter a name for your template',
              prefixIcon: const Icon(Icons.label_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Template name is required';
              }
              if (value.trim().length < 3) {
                return 'Template name must be at least 3 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Category
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: const Icon(Icons.category_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            items: _categories.map((category) {
              return DropdownMenuItem(
                value: category,
                child: Text(category),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCategory = value ?? 'Other');
            },
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe what this template is for',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),

          // Tags
          TextFormField(
            controller: _tagsController,
            decoration: InputDecoration(
              labelText: 'Tags',
              hintText: 'Enter tags separated by commas',
              prefixIcon: const Icon(Icons.tag),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              helperText: 'Separate multiple tags with commas',
            ),
          ),
          const SizedBox(height: 20),

          // Preview section
          _buildPreviewSection(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(ThemeData theme, ColorScheme colorScheme) {
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
                Icons.preview_rounded,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Template Preview',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Original note info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Source Note: ${widget.note.title}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Category: ${widget.note.category}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (widget.note.content.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Content Preview:',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.note.content.length > 100
                        ? '${widget.note.content.substring(0, 100)}...'
                        : widget.note.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _isLoading ? null : _saveTemplate,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded),
            label: Text(_isLoading ? 'Saving...' : 'Save Template'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final templateService = NoteTemplateService();
      await templateService.initialize();

      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Create template
      final template = await templateService.createTemplateFromNote(
        note: widget.note,
        templateName: _templateNameController.text.trim(),
        description: _descriptionController.text.trim(),
        tags: tags,
      );

      if (mounted) {
        widget.onTemplateSaved?.call(template);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Template "${template.name}" saved successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save template: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
