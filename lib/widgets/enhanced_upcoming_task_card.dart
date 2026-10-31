import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';

/// Enhanced task card specifically designed for upcoming tasks
class EnhancedUpcomingTaskCard extends StatelessWidget {
  final Task task;
  final TaskProvider taskProvider;
  final VoidCallback? onTap;
  final VoidCallback? onStartEarly;
  final VoidCallback? onReschedule;
  final VoidCallback? onEdit;

  const EnhancedUpcomingTaskCard({
    super.key,
    required this.task,
    required this.taskProvider,
    this.onTap,
    this.onStartEarly,
    this.onReschedule,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgency = task.urgencyLevel;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: task.needsAttention ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: task.needsAttention
            ? BorderSide(color: urgency.color, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with urgency indicator and actions
              Row(
                children: [
                  // Urgency indicator
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: urgency.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Task title and category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: task.needsAttention
                                ? urgency.color
                                : theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              task.category.icon,
                              size: 16,
                              color: task.category.color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.category.displayName,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: task.category.color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: task.priority.color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: task.priority.color.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                task.priority.displayName,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: task.priority.color,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Quick actions menu
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'start':
                          onStartEarly?.call();
                          break;
                        case 'reschedule':
                          onReschedule?.call();
                          break;
                        case 'edit':
                          onEdit?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'start',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow, size: 18),
                            const SizedBox(width: 8),
                            Text('Start Early'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'reschedule',
                        child: Row(
                          children: [
                            Icon(Icons.schedule, size: 18),
                            const SizedBox(width: 8),
                            Text('Reschedule'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 18),
                            const SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Description (if available)
              if (task.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  task.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Progress indicator (if task has progress)
              if (task.progress > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: task.progress,
                        backgroundColor:
                            theme.colorScheme.outline.withOpacity(0.2),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(task.priority.color),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(task.progress * 100).toInt()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: task.priority.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],

              // Footer with due date and additional info
              Row(
                children: [
                  // Due date with enhanced formatting
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: urgency.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: urgency.color.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 14,
                          color: urgency.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.enhancedTimeUntilDue,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: urgency.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Focus sessions info
                  if (task.estimatedFocusSessions > 0) ...[
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${task.completedFocusSessions}/${task.estimatedFocusSessions} sessions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  // Tags indicator
                  if (task.tags.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.local_offer,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${task.tags.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
