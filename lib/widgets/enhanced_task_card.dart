import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/navigation_context.dart';
import '../utils/navigation_helper.dart';

/// Enhanced task card with navigation support and quick preview
class EnhancedTaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<PopupMenuEntry<String>>? contextMenuActions;
  final Function(String action)? onMenuAction;
  final NavigationContext? navigationContext;
  final bool enableQuickPreview;
  final bool showNavigationIcon;
  final String? tabContext;

  const EnhancedTaskCard({
    super.key,
    required this.task,
    this.onTap,
    this.onLongPress,
    this.contextMenuActions,
    this.onMenuAction,
    this.navigationContext,
    this.enableQuickPreview = true,
    this.showNavigationIcon = true,
    this.tabContext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine card styling based on task state
    final isCompleted = task.status == TaskStatus.completed;
    final cardElevation = task.isOverdue || task.needsAttention ? 4.0 : 2.0;

    BorderSide? cardBorder;
    if (isCompleted && tabContext == 'completed') {
      cardBorder =
          BorderSide(color: Colors.green.withValues(alpha: 0.3), width: 1);
    } else if (task.isOverdue) {
      cardBorder = BorderSide(color: Colors.red, width: 2);
    } else if (task.needsAttention) {
      cardBorder = BorderSide(color: _getUrgencyColor(task), width: 2);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: cardBorder ?? BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap ?? () => _handleTap(context),
        onLongPress:
            enableQuickPreview ? () => _handleLongPress(context) : onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildCardContent(context, theme, colorScheme),
        ),
      ),
    );
  }

  Widget _buildCardContent(
      BuildContext context, ThemeData theme, ColorScheme colorScheme) {
    final isCompleted = task.status == TaskStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with title and actions
        Row(
          children: [
            // Task completion checkbox
            _buildCompletionCheckbox(colorScheme),
            const SizedBox(width: 12),

            // Task title
            Expanded(
              child: Text(
                task.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  color: isCompleted
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Navigation and menu icons
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showNavigationIcon)
                  IconButton(
                    onPressed: () => _handleTap(context),
                    icon: Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'View Details',
                  ),
                if (contextMenuActions != null)
                  PopupMenuButton<String>(
                    onSelected: onMenuAction,
                    itemBuilder: (context) => contextMenuActions!,
                    child: Icon(
                      Icons.more_vert,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Task description
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 12),

        // Task metadata row
        _buildMetadataRow(theme, colorScheme),

        // Creation and update info
        const SizedBox(height: 8),
        _buildTimestampInfo(theme, colorScheme),
      ],
    );
  }

  Widget _buildCompletionCheckbox(ColorScheme colorScheme) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: task.status == TaskStatus.completed
              ? Colors.green
              : colorScheme.outline,
          width: 2,
        ),
        color: task.status == TaskStatus.completed
            ? Colors.green
            : Colors.transparent,
      ),
      child: task.status == TaskStatus.completed
          ? const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            )
          : null,
    );
  }

  Widget _buildMetadataRow(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        // Priority badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getPriorityColor(task.priority).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            task.priority.name.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getPriorityColor(task.priority),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Category badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getCategoryIcon(task.category),
                size: 12,
                color: colorScheme.onSecondaryContainer,
              ),
              const SizedBox(width: 4),
              Text(
                task.category.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Due date indicator
        if (task.dueDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: task.isOverdue
                  ? Colors.red.withValues(alpha: 0.1)
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: task.isOverdue
                      ? Colors.red
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDueDate(task.dueDate!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: task.isOverdue
                        ? Colors.red
                        : colorScheme.onSurfaceVariant,
                    fontWeight:
                        task.isOverdue ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTimestampInfo(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(
          Icons.access_time,
          size: 12,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 4),
        Text(
          'Created ${_formatTimestamp(task.createdAt)}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        if (task.updatedAt != task.createdAt) ...[
          const SizedBox(width: 8),
          Text(
            '• Updated ${_formatTimestamp(task.updatedAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  void _handleTap(BuildContext context) {
    if (onTap != null) {
      onTap!();
    } else {
      NavigationHelper.navigateToTaskDetails(
        context: context,
        task: task,
        navigationContext: navigationContext,
      );
    }
  }

  void _handleLongPress(BuildContext context) {
    if (onLongPress != null) {
      onLongPress!();
    } else if (enableQuickPreview) {
      NavigationHelper.showTaskQuickPreview(
        context: context,
        task: task,
        navigationContext: navigationContext,
      );
    }
  }

  // Helper methods
  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.urgent:
        return Colors.deepPurple;
    }
  }

  Color _getUrgencyColor(Task task) {
    // Simplified urgency color logic
    if (task.isOverdue) return Colors.red;
    if (task.priority == TaskPriority.high) return Colors.orange;
    return Colors.blue;
  }

  IconData _getCategoryIcon(TaskCategory category) {
    switch (category) {
      case TaskCategory.work:
        return Icons.work;
      case TaskCategory.personal:
        return Icons.person;
      case TaskCategory.health:
        return Icons.favorite;
      case TaskCategory.learning:
        return Icons.school;
      case TaskCategory.shopping:
        return Icons.shopping_cart;
      case TaskCategory.other:
        return Icons.category;
    }
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else if (difference < 7) {
      return '${difference}d';
    } else {
      return '${dueDate.day}/${dueDate.month}';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
