import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/navigation_context.dart';
import '../screens/task_details_screen.dart';

/// Helper class for managing task-related navigation with context preservation
class NavigationHelper {
  static const String _taskDetailsRoute = '/task-details';

  /// Navigate to task details with context preservation
  static Future<NavigationResult?> navigateToTaskDetails({
    required BuildContext context,
    required Task task,
    NavigationContext? navigationContext,
    bool enableQuickActions = true,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Create default context if none provided
      final navContext = navigationContext ?? NavigationContext.direct();

      // Prepare arguments for task details screen
      final arguments = {
        'task': task,
        'navigationContext': navContext,
        'enableQuickActions': enableQuickActions,
        'additionalData': additionalData,
      };

      // Navigate to task details screen
      final result = await Navigator.of(context).push<NavigationResult>(
        MaterialPageRoute(
          builder: (context) => TaskDetailsScreen(
            task: task,
            navigationContext: navContext,
            enableQuickActions: enableQuickActions,
            additionalData: additionalData,
          ),
          settings: RouteSettings(
            name: _taskDetailsRoute,
            arguments: arguments,
          ),
        ),
      );

      return result;
    } catch (e) {
      debugPrint('NavigationHelper: Error navigating to task details: $e');
      return null;
    }
  }

  /// Navigate to task details from agenda screen
  static Future<NavigationResult?> navigateFromAgenda({
    required BuildContext context,
    required Task task,
    required String agendaTab,
    String? currentFilter,
    Map<String, dynamic>? agendaData,
  }) async {
    final navContext = NavigationContext.fromAgenda(
      tab: agendaTab,
      filter: currentFilter,
      data: agendaData,
    );

    return navigateToTaskDetails(
      context: context,
      task: task,
      navigationContext: navContext,
    );
  }

  /// Navigate to task details from search screen
  static Future<NavigationResult?> navigateFromSearch({
    required BuildContext context,
    required Task task,
    String? searchQuery,
    Map<String, dynamic>? searchFilters,
  }) async {
    final navContext = NavigationContext.fromSearch(
      query: searchQuery,
      filters: searchFilters,
    );

    return navigateToTaskDetails(
      context: context,
      task: task,
      navigationContext: navContext,
    );
  }

  /// Navigate to task details from focus screen
  static Future<NavigationResult?> navigateFromFocus({
    required BuildContext context,
    required Task task,
    Map<String, dynamic>? sessionData,
  }) async {
    final navContext = NavigationContext.fromFocus(
      sessionData: sessionData,
    );

    return navigateToTaskDetails(
      context: context,
      task: task,
      navigationContext: navContext,
    );
  }

  /// Navigate to task details from notification
  static Future<NavigationResult?> navigateFromNotification({
    required BuildContext context,
    required Task task,
    required String notificationType,
    Map<String, dynamic>? notificationData,
  }) async {
    final navContext = NavigationContext.fromNotification(
      notificationType: notificationType,
      notificationData: notificationData,
    );

    return navigateToTaskDetails(
      context: context,
      task: task,
      navigationContext: navContext,
    );
  }

  /// Smart back navigation based on context
  static void navigateBack({
    required BuildContext context,
    NavigationContext? navigationContext,
    NavigationResult? result,
  }) {
    try {
      if (navigationContext == null) {
        // Default back navigation
        Navigator.of(context).pop(result);
        return;
      }

      final returnRoute = navigationContext.getReturnRoute();
      final returnArgs = navigationContext.getReturnArguments();

      // Handle different return scenarios
      switch (navigationContext.sourceScreen) {
        case 'agenda':
          _navigateBackToAgenda(context, navigationContext, result);
          break;
        case 'search':
          _navigateBackToSearch(context, navigationContext, result);
          break;
        case 'focus':
          _navigateBackToFocus(context, navigationContext, result);
          break;
        case 'notification':
          _navigateBackFromNotification(context, navigationContext, result);
          break;
        default:
          Navigator.of(context).pop(result);
      }
    } catch (e) {
      debugPrint('NavigationHelper: Error in smart back navigation: $e');
      Navigator.of(context).pop(result);
    }
  }

  /// Navigate back to specific breadcrumb level
  static void navigateToBreadcrumb({
    required BuildContext context,
    required int breadcrumbIndex,
    NavigationContext? navigationContext,
  }) {
    if (navigationContext == null) {
      Navigator.of(context).pop();
      return;
    }

    final trail = navigationContext.breadcrumbTrail;
    if (breadcrumbIndex >= trail.length - 1) {
      // Already at or beyond current level
      return;
    }

    // Navigate back to specific level
    if (breadcrumbIndex == 0) {
      // Navigate to root of the source
      navigateBack(context: context, navigationContext: navigationContext);
    } else {
      // Pop to specific level
      Navigator.of(context).pop();
    }
  }

  /// Check if current route is task details
  static bool isTaskDetailsRoute(BuildContext context) {
    final route = ModalRoute.of(context);
    return route?.settings.name == _taskDetailsRoute;
  }

  /// Get current navigation context from route arguments
  static NavigationContext? getCurrentNavigationContext(BuildContext context) {
    final route = ModalRoute.of(context);
    final args = route?.settings.arguments as Map<String, dynamic>?;
    return args?['navigationContext'] as NavigationContext?;
  }

  /// Show task quick preview dialog
  static Future<void> showTaskQuickPreview({
    required BuildContext context,
    required Task task,
    NavigationContext? navigationContext,
  }) async {
    await showDialog(
      context: context,
      builder: (context) => TaskQuickPreviewDialog(
        task: task,
        onViewDetails: () {
          Navigator.of(context).pop();
          navigateToTaskDetails(
            context: context,
            task: task,
            navigationContext: navigationContext,
          );
        },
      ),
    );
  }

  // Private helper methods
  static void _navigateBackToAgenda(
    BuildContext context,
    NavigationContext navContext,
    NavigationResult? result,
  ) {
    // Pop back to agenda with preserved tab
    Navigator.of(context).pop(result);
  }

  static void _navigateBackToSearch(
    BuildContext context,
    NavigationContext navContext,
    NavigationResult? result,
  ) {
    // Pop back to search results
    Navigator.of(context).pop(result);
  }

  static void _navigateBackToFocus(
    BuildContext context,
    NavigationContext navContext,
    NavigationResult? result,
  ) {
    // Pop back to focus screen
    Navigator.of(context).pop(result);
  }

  static void _navigateBackFromNotification(
    BuildContext context,
    NavigationContext navContext,
    NavigationResult? result,
  ) {
    // Navigate to main screen or last visited
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/main',
      (route) => false,
      arguments: navContext.getReturnArguments(),
    );
  }
}

/// Quick preview dialog for tasks
class TaskQuickPreviewDialog extends StatelessWidget {
  final Task task;
  final VoidCallback onViewDetails;

  const TaskQuickPreviewDialog({
    super.key,
    required this.task,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.task_alt,
                  color: colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Task Preview',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Task Title
            Text(
              task.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Task Description
            if (task.description.isNotEmpty) ...[
              Text(
                task.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
            ],

            // Task Info
            Row(
              children: [
                // Priority
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _getPriorityColor(task.priority).withValues(alpha: 0.1),
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

                // Category
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    task.category.displayName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: onViewDetails,
                  child: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
}
