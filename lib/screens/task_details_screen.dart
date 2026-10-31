import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/navigation_context.dart';
import '../providers/task_provider.dart';
import '../utils/error_handler.dart';
import '../utils/accessibility_helper.dart';
import '../utils/navigation_helper.dart';
import '../widgets/breadcrumb_navigation.dart';
import 'edit_task_screen.dart';

/// Comprehensive Task Details Screen with Material Design 3
class TaskDetailsScreen extends StatefulWidget {
  final Task task;
  final NavigationContext? navigationContext;
  final bool enableQuickActions;
  final Map<String, dynamic>? additionalData;

  const TaskDetailsScreen({
    super.key,
    required this.task,
    this.navigationContext,
    this.enableQuickActions = true,
    this.additionalData,
  });

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  Task? _currentTask;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(theme, colorScheme),
      body: _currentTask == null
          ? _buildErrorState(theme)
          : Column(
              children: [
                // Breadcrumb navigation
                if (widget.navigationContext != null)
                  BreadcrumbNavigation.fromContext(
                    navigationContext: widget.navigationContext!,
                    currentPageTitle: _currentTask!.title,
                    onBack: () => _handleBackNavigation(),
                  ),

                // Main content
                Expanded(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildBody(theme, colorScheme),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _currentTask != null && widget.enableQuickActions
          ? _buildFAB(colorScheme)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return AppBar(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      title: Text(
        'Task Details',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        if (_currentTask != null) ...[
          IconButton(
            onPressed: _editTask,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Task',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_outlined),
                    SizedBox(width: 12),
                    Text('Duplicate'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_outlined),
                    SizedBox(width: 12),
                    Text('Share'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: colorScheme.error),
                    const SizedBox(width: 12),
                    Text('Delete', style: TextStyle(color: colorScheme.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTaskHeader(theme, colorScheme),
          const SizedBox(height: 24),
          _buildTaskInfo(theme, colorScheme),
          const SizedBox(height: 24),
          _buildProgressSection(theme, colorScheme),
          const SizedBox(height: 24),
          _buildSubtasksSection(theme, colorScheme),
          const SizedBox(height: 24),
          _buildFocusSessionsSection(theme, colorScheme),
          const SizedBox(height: 24),
          _buildActionButtons(theme, colorScheme),
          const SizedBox(height: 100), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildTaskHeader(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _currentTask!.priority.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _currentTask!.priority.icon,
                    color: _currentTask!.priority.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _currentTask!.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                _buildStatusChip(theme, colorScheme),
              ],
            ),
            if (_currentTask!.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                _currentTask!.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, ColorScheme colorScheme) {
    final status = _currentTask!.status;
    Color chipColor;
    Color textColor;

    switch (status) {
      case TaskStatus.completed:
        chipColor = Colors.green.withValues(alpha: 0.1);
        textColor = Colors.green;
        break;
      case TaskStatus.inProgress:
        chipColor = Colors.blue.withValues(alpha: 0.1);
        textColor = Colors.blue;
        break;
      case TaskStatus.cancelled:
        chipColor = Colors.red.withValues(alpha: 0.1);
        textColor = Colors.red;
        break;
      default:
        chipColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTaskInfo(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              'Category',
              _currentTask!.category.displayName,
              _currentTask!.category.icon,
              _currentTask!.category.color,
              theme,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              'Priority',
              _currentTask!.priority.displayName,
              _currentTask!.priority.icon,
              _currentTask!.priority.color,
              theme,
            ),
            if (_currentTask!.dueDate != null) ...[
              const SizedBox(height: 12),
              _buildInfoRow(
                'Due Date',
                _currentTask!.formattedDueDate,
                Icons.schedule_outlined,
                _currentTask!.isOverdue ? Colors.red : colorScheme.primary,
                theme,
              ),
            ],
            const SizedBox(height: 12),
            _buildInfoRow(
              'Created',
              _currentTask!.formattedCreatedAt,
              Icons.calendar_today_outlined,
              colorScheme.onSurfaceVariant,
              theme,
            ),
            if (_currentTask!.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Tags',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentTask!.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progress',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(_currentTask!.progress * 100).toInt()}%',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _currentTask!.progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubtasksSection(ThemeData theme, ColorScheme colorScheme) {
    if (_currentTask!.subTasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Subtasks (${_currentTask!.subTasks.length})',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...(_currentTask!.subTasks.map((subtask) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      subtask.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: subtask.isCompleted
                          ? Colors.green
                          : colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        subtask.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: subtask.isCompleted
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList()),
          ],
        ),
      ),
    );
  }

  Widget _buildFocusSessionsSection(ThemeData theme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Focus Sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSessionStat(
                  'Completed',
                  '${_currentTask!.completedFocusSessions}',
                  Icons.check_circle_outline,
                  Colors.green,
                  theme,
                ),
                const SizedBox(width: 24),
                _buildSessionStat(
                  'Estimated',
                  '${_currentTask!.estimatedFocusSessions}',
                  Icons.timer_outlined,
                  colorScheme.primary,
                  theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStat(
    String label,
    String value,
    IconData icon,
    Color color,
    ThemeData theme,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        if (_currentTask!.status != TaskStatus.completed) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _startFocusSession,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Focus Session'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _toggleTaskStatus,
                icon: Icon(_getToggleIcon()),
                label: Text(_getToggleText()),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _editTask,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFAB(ColorScheme colorScheme) {
    return FloatingActionButton.extended(
      onPressed: _startFocusSession,
      icon: const Icon(Icons.timer),
      label: const Text('Focus'),
      backgroundColor: colorScheme.primary,
      foregroundColor: colorScheme.onPrimary,
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
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
            'Task not found',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The task you\'re looking for doesn\'t exist or has been deleted.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  IconData _getToggleIcon() {
    switch (_currentTask!.status) {
      case TaskStatus.completed:
        return Icons.undo;
      case TaskStatus.cancelled:
        return Icons.restore;
      default:
        return Icons.check;
    }
  }

  String _getToggleText() {
    switch (_currentTask!.status) {
      case TaskStatus.completed:
        return 'Reopen';
      case TaskStatus.cancelled:
        return 'Restore';
      default:
        return 'Complete';
    }
  }

  void _editTask() async {
    final result = await Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (context) => EditTaskScreen(task: _currentTask!),
      ),
    );

    if (result != null) {
      setState(() {
        _currentTask = result;
      });
    }
  }

  void _handleBackNavigation() {
    NavigationHelper.navigateBack(
      context: context,
      navigationContext: widget.navigationContext,
      result: NavigationResult.success(
        data: _currentTask,
        action: 'viewed',
      ),
    );
  }

  void _startFocusSession() {
    // Navigate to main screen and switch to focus tab
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Focus session started for "${_currentTask!.title}"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleTaskStatus() async {
    if (_currentTask == null) return;

    setState(() => _isLoading = true);

    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      Task updatedTask;

      switch (_currentTask!.status) {
        case TaskStatus.completed:
          updatedTask = _currentTask!.copyWith(
            status: TaskStatus.todo,
            completedAt: null,
          );
          break;
        case TaskStatus.cancelled:
          updatedTask = _currentTask!.copyWith(
            status: TaskStatus.todo,
          );
          break;
        default:
          updatedTask = _currentTask!.copyWith(
            status: TaskStatus.completed,
            completedAt: DateTime.now(),
            progress: 1.0,
          );
      }

      await taskProvider.updateTask(updatedTask);
      setState(() {
        _currentTask = updatedTask;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Task ${_getToggleText().toLowerCase()}d successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to update task: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleMenuAction(String action) async {
    switch (action) {
      case 'duplicate':
        await _duplicateTask();
        break;
      case 'share':
        await _shareTask();
        break;
      case 'delete':
        await _deleteTask();
        break;
    }
  }

  Future<void> _duplicateTask() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);

      final duplicatedTask = _currentTask!.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: '${_currentTask!.title} (Copy)',
        status: TaskStatus.todo,
        progress: 0.0,
        completedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await taskProvider.createTask(
        title: duplicatedTask.title,
        description: duplicatedTask.description,
        priority: duplicatedTask.priority,
        category: duplicatedTask.category,
        dueDate: duplicatedTask.dueDate,
        tags: duplicatedTask.tags,
        estimatedFocusSessions: duplicatedTask.estimatedFocusSessions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Task duplicated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, 'Failed to duplicate task: $e');
      }
    }
  }

  Future<void> _shareTask() async {
    try {
      final taskText = '''
📋 ${_currentTask!.title}

📝 Description: ${_currentTask!.description.isNotEmpty ? _currentTask!.description : 'No description'}

🎯 Priority: ${_currentTask!.priority.displayName}
📂 Category: ${_currentTask!.category.displayName}
📊 Status: ${_currentTask!.status.displayName}
📈 Progress: ${(_currentTask!.progress * 100).toInt()}%

${_currentTask!.dueDate != null ? '📅 Due: ${_currentTask!.formattedDueDate}' : ''}
${_currentTask!.tags.isNotEmpty ? '🏷️ Tags: ${_currentTask!.tags.join(', ')}' : ''}

Created with FocusBro 🎯
''';

      await Share.share(
        taskText.trim(),
        subject: 'FocusBro task: ${_currentTask!.title}',
      );
    } catch (e) {
      ErrorHandler.showError(context, 'Failed to share task: $e');
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text(
          'Are you sure you want to delete "${_currentTask!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final taskProvider = Provider.of<TaskProvider>(context, listen: false);
        await taskProvider.deleteTask(_currentTask!.id);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🗑️ Task deleted successfully'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorHandler.showError(context, 'Failed to delete task: $e');
        }
      }
    }
  }
}
