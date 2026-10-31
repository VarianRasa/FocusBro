import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/task_template.dart';
import '../providers/task_provider.dart';

/// Dialog for selecting and managing task templates
class TaskTemplatesDialog extends StatefulWidget {
  final Function(TaskTemplate)? onTemplateSelected;

  const TaskTemplatesDialog({
    super.key,
    this.onTemplateSelected,
  });

  @override
  State<TaskTemplatesDialog> createState() => _TaskTemplatesDialogState();
}

class _TaskTemplatesDialogState extends State<TaskTemplatesDialog>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.description,
                  size: 28,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Task Templates',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            TextField(
              decoration: InputDecoration(
                hintText: 'Search templates...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Built-in Templates'),
                Tab(text: 'Custom Templates'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBuiltInTemplates(),
                  _buildCustomTemplates(),
                ],
              ),
            ),

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showCreateTemplateDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Template'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBuiltInTemplates() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final templates = _searchQuery.isEmpty
            ? taskProvider.builtInTemplates
            : taskProvider
                .searchTemplates(_searchQuery)
                .where((t) => t.isBuiltIn)
                .toList();

        if (templates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No built-in templates available'
                      : 'No templates found matching "$_searchQuery"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return _buildTemplateCard(template);
          },
        );
      },
    );
  }

  Widget _buildCustomTemplates() {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        final templates = _searchQuery.isEmpty
            ? taskProvider.customTemplates
            : taskProvider
                .searchTemplates(_searchQuery)
                .where((t) => !t.isBuiltIn)
                .toList();

        if (templates.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_task,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No custom templates yet'
                      : 'No custom templates found matching "$_searchQuery"',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 8),
                if (_searchQuery.isEmpty)
                  Text(
                    'Create your first custom template!',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
              ],
            ),
          );
        }

        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: templates.length,
          itemBuilder: (context, index) {
            final template = templates[index];
            return _buildTemplateCard(template, showActions: true);
          },
        );
      },
    );
  }

  Widget _buildTemplateCard(TaskTemplate template, {bool showActions = false}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _selectTemplate(template),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with icon and actions
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: template.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      template.icon,
                      color: template.color,
                      size: 20,
                    ),
                  ),
                  const Spacer(),
                  if (showActions) ...[
                    PopupMenuButton<String>(
                      onSelected: (action) =>
                          _handleTemplateAction(action, template),
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
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 16, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),

              // Template name
              Text(
                template.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Template description
              Text(
                template.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),

              // Template metadata
              Row(
                children: [
                  Icon(
                    template.priority.icon,
                    size: 14,
                    color: template.priority.color,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    template.priority.displayName,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Text(
                    '${template.estimatedFocusSessions} sessions',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectTemplate(TaskTemplate template) {
    Navigator.of(context).pop();
    widget.onTemplateSelected?.call(template);
  }

  void _handleTemplateAction(String action, TaskTemplate template) {
    switch (action) {
      case 'edit':
        _showEditTemplateDialog(template);
        break;
      case 'delete':
        _showDeleteConfirmation(template);
        break;
    }
  }

  void _showCreateTemplateDialog() => _showTemplateEditor();

  void _showEditTemplateDialog(TaskTemplate template) =>
      _showTemplateEditor(template: template);

  Future<void> _showTemplateEditor({TaskTemplate? template}) async {
    var name = template?.name ?? '';
    var description = template?.description ?? '';
    var tagsText = template?.tags.join(', ') ?? '';
    var sessionsText = (template?.estimatedFocusSessions ?? 1).toString();
    var priority = template?.priority ?? TaskPriority.medium;
    var category = template?.category ?? TaskCategory.work;
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(template == null ? 'Create Template' : 'Edit Template'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: name,
                      autofocus: true,
                      onChanged: (value) => name = value,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter a template name'
                              : null,
                    ),
                    TextFormField(
                      initialValue: description,
                      onChanged: (value) => description = value,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                      minLines: 2,
                      maxLines: 4,
                    ),
                    DropdownButtonFormField<TaskPriority>(
                      value: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: TaskPriority.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.displayName),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => priority = value);
                        }
                      },
                    ),
                    DropdownButtonFormField<TaskCategory>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: TaskCategory.values
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value.displayName),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => category = value);
                        }
                      },
                    ),
                    TextFormField(
                      initialValue: tagsText,
                      onChanged: (value) => tagsText = value,
                      decoration: const InputDecoration(
                        labelText: 'Tags',
                        hintText: 'Comma-separated',
                      ),
                    ),
                    TextFormField(
                      initialValue: sessionsText,
                      onChanged: (value) => sessionsText = value,
                      decoration: const InputDecoration(
                        labelText: 'Estimated focus sessions',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final count = int.tryParse(value ?? '');
                        return count == null || count < 1
                            ? 'Enter a number greater than zero'
                            : null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: Text(template == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );

    if (result != true || !mounted) return;
    final tags = tagsText
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();
    final provider = context.read<TaskProvider>();
    final saved = template == null
        ? await provider.createTemplate(
            name: name.trim(),
            description: description.trim(),
            priority: priority,
            category: category,
            tags: tags,
            estimatedFocusSessions: int.parse(sessionsText),
            icon: category.icon,
            color: category.color,
          )
        : await provider.updateTemplate(
            template.copyWith(
              name: name.trim(),
              description: description.trim(),
              priority: priority,
              category: category,
              tags: tags,
              estimatedFocusSessions: int.parse(sessionsText),
              icon: category.icon,
              color: category.color,
            ),
          );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved == null
            ? (provider.error ?? 'Could not save template')
            : template == null
                ? 'Template created'
                : 'Template updated'),
      ),
    );
  }

  void _showDeleteConfirmation(TaskTemplate template) {
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
              final success = await context
                  .read<TaskProvider>()
                  .deleteTemplate(template.id);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Template deleted successfully')),
                );
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
