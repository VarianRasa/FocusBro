import 'package:flutter/material.dart';
import '../models/note.dart';

/// Dialog for creating and editing note templates
class TemplateEditorDialog extends StatefulWidget {
  final NoteTemplate? template; // null for create, non-null for edit
  final Function(String name, String title, String content, String category,
      String description, List<String> tags) onSave;

  const TemplateEditorDialog({
    super.key,
    this.template,
    required this.onSave,
  });

  @override
  State<TemplateEditorDialog> createState() => _TemplateEditorDialogState();
}

class _TemplateEditorDialogState extends State<TemplateEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
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
    _nameController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _initializeFields() {
    if (widget.template != null) {
      // Edit mode - populate with existing template data
      _nameController.text = widget.template!.name;
      _titleController.text = widget.template!.title;
      _contentController.text = widget.template!.content;
      _selectedCategory = widget.template!.category;
      _descriptionController.text = widget.template!.description;
      _tagsController.text = widget.template!.tags.join(', ');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isEdit = widget.template != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(theme, colorScheme, isEdit),

            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildForm(theme, colorScheme),
              ),
            ),

            // Action buttons
            _buildActionButtons(theme, colorScheme, isEdit),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colorScheme, bool isEdit) {
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
              isEdit ? Icons.edit_rounded : Icons.add_rounded,
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
                  isEdit ? 'Edit Template' : 'Create Template',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  isEdit
                      ? 'Modify your template'
                      : 'Create a new reusable template',
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
            controller: _nameController,
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

          // Template title
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Default Title *',
              hintText: 'Default title for notes created from this template',
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Default title is required';
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

          // Template content
          TextFormField(
            controller: _contentController,
            decoration: InputDecoration(
              labelText: 'Template Content',
              hintText: 'Enter the default content for this template',
              prefixIcon: const Icon(Icons.description_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              alignLabelWithHint: true,
            ),
            maxLines: 6,
            minLines: 3,
          ),
          const SizedBox(height: 16),

          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe what this template is for',
              prefixIcon: const Icon(Icons.info_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
            maxLines: 2,
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
        ],
      ),
    );
  }

  Widget _buildActionButtons(
      ThemeData theme, ColorScheme colorScheme, bool isEdit) {
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
                : Icon(isEdit ? Icons.save_rounded : Icons.add_rounded),
            label: Text(_isLoading
                ? 'Saving...'
                : isEdit
                    ? 'Update Template'
                    : 'Create Template'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTemplate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Parse tags
      final tags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Call the save callback
      widget.onSave(
        _nameController.text.trim(),
        _titleController.text.trim(),
        _contentController.text.trim(),
        _selectedCategory,
        _descriptionController.text.trim(),
        tags,
      );

      if (mounted) {
        Navigator.of(context).pop();
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
