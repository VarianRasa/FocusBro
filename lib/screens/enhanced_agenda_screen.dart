import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';
import '../models/task_model.dart';

import '../models/notification_settings.dart';
import '../providers/task_provider.dart';
import '../services/upcoming_task_service.dart';
import '../services/task_service.dart';
import '../services/calendar_export_service.dart';
import '../widgets/task_templates_dialog.dart';
import '../widgets/enhanced_upcoming_task_card.dart';
import '../widgets/task_dialogs.dart';
import '../utils/accessibility_helper.dart';
import '../utils/navigation_helper.dart';
import 'enhanced_analytics_screen.dart';
import 'task_details_screen.dart';

/// Enhanced Agenda Screen with multiple views and smart features
class EnhancedAgendaScreen extends StatefulWidget {
  const EnhancedAgendaScreen({super.key});

  @override
  State<EnhancedAgendaScreen> createState() => _EnhancedAgendaScreenState();
}

class _EnhancedAgendaScreenState extends State<EnhancedAgendaScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _currentView = 'list'; // list, kanban, calendar, matrix

  // Calendar state
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Force refresh to ensure badges are up to date when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      taskProvider.refreshTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        // Debug logging for Consumer rebuild with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        debugPrint(
            'EnhancedAgendaScreen: Consumer rebuilding at $timestamp...');
        debugPrint(
            'EnhancedAgendaScreen: Total tasks: ${taskProvider.tasks.length}');

        // Calculate badge counts in real-time
        final todayCount = taskProvider.tasksDueToday.length;
        final upcomingCount = taskProvider.upcomingTasks.length;
        final inProgressCount = taskProvider.inProgressTasks.length;
        final completedCount = taskProvider.completedTasks.length;

        debugPrint(
            'EnhancedAgendaScreen: Badge counts - Today: $todayCount, Upcoming: $upcomingCount, InProgress: $inProgressCount, Completed: $completedCount');
        debugPrint(
            'EnhancedAgendaScreen: Is loading: ${taskProvider.isLoading}');
        debugPrint('EnhancedAgendaScreen: Error: ${taskProvider.error}');

        // Debug individual tasks
        for (int i = 0; i < taskProvider.tasks.length && i < 5; i++) {
          final task = taskProvider.tasks[i];
          debugPrint(
              'EnhancedAgendaScreen: Task $i: "${task.title}" - Status: ${task.status} - Due: ${task.dueDate} - isDueToday: ${task.isDueToday}');
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Smart Agenda'),
            elevation: 0,
            actions: [
              // View Selector
              PopupMenuButton<String>(
                initialValue: _currentView,
                onSelected: (value) => setState(() => _currentView = value),
                tooltip: 'Switch View',
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'list',
                    child: ListTile(
                      leading: Icon(Icons.list),
                      title: Text('List View'),
                      subtitle: Text('Tab-based task lists'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'calendar',
                    child: ListTile(
                      leading: Icon(Icons.calendar_month),
                      title: Text('Calendar View'),
                      subtitle: Text('Monthly calendar with tasks'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'matrix',
                    child: ListTile(
                      leading: Icon(Icons.grid_view),
                      title: Text('Priority Matrix'),
                      subtitle: Text('Eisenhower decision matrix'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'kanban',
                    child: ListTile(
                      leading: Icon(Icons.view_column),
                      title: Text('Kanban Board'),
                      subtitle: Text('Status-based columns'),
                    ),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getViewIcon(_currentView)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),

              // Search
              IconButton(
                onPressed: () => _showSearchDialog(taskProvider),
                icon: const Icon(Icons.search),
                tooltip: 'Search Tasks',
              ),

              // More Options
              PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Export Tasks'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.upload),
                      title: Text('Import Tasks'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'analytics',
                    child: ListTile(
                      leading: Icon(Icons.analytics),
                      title: Text('Task Analytics'),
                    ),
                  ),
                ],
                onSelected: _handleMenuAction,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  text: 'Today',
                  icon: Badge(
                    label: Text('$todayCount'),
                    child: const Icon(Icons.today),
                  ),
                ),
                Tab(
                  text: 'Upcoming',
                  icon: Badge(
                    label: Text('$upcomingCount'),
                    child: const Icon(Icons.schedule),
                  ),
                ),
                Tab(
                  text: 'In Progress',
                  icon: Badge(
                    label: Text('$inProgressCount'),
                    child: const Icon(Icons.play_circle),
                  ),
                ),
                Tab(
                  text: 'Completed',
                  icon: Badge(
                    label: Text('$completedCount'),
                    child: const Icon(Icons.check_circle),
                  ),
                ),
              ],
            ),
          ),
          body: taskProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _currentView == 'list'
                  ? TabBarView(
                      controller: _tabController,
                      children: [
                        _TodayTasksView(taskProvider: taskProvider),
                        _UpcomingTasksView(taskProvider: taskProvider),
                        _InProgressTasksView(taskProvider: taskProvider),
                        _CompletedTasksView(taskProvider: taskProvider),
                      ],
                    )
                  : _buildAlternativeView(taskProvider),
          floatingActionButton: _buildSmartFAB(taskProvider),
        );
      },
    );
  }

  /// Get icon for current view
  IconData _getViewIcon(String view) {
    switch (view) {
      case 'calendar':
        return Icons.calendar_month;
      case 'matrix':
        return Icons.grid_view;
      case 'kanban':
        return Icons.view_column;
      case 'list':
      default:
        return Icons.list;
    }
  }

  /// Build alternative views (Calendar, Matrix, Kanban)
  Widget _buildAlternativeView(TaskProvider taskProvider) {
    final allTasks = taskProvider.tasks;

    switch (_currentView) {
      case 'calendar':
        return _buildCalendarView(allTasks, taskProvider);
      case 'matrix':
        return _buildMatrixView(allTasks, taskProvider);
      case 'kanban':
        return _buildKanbanView(allTasks, taskProvider);
      default:
        return const Center(child: Text('View not implemented'));
    }
  }

  Widget _buildTaskView(List<Task> tasks, TaskProvider taskProvider) {
    // Tasks are already filtered and sorted by the provider
    final displayTasks = tasks;

    // Debug logging for UI
    debugPrint(
        'EnhancedAgendaScreen: Building task view with ${displayTasks.length} tasks');
    debugPrint('EnhancedAgendaScreen: Current view: $_currentView');
    debugPrint('EnhancedAgendaScreen: Current tab: ${_tabController.index}');

    // Log task details for debugging
    for (int i = 0; i < displayTasks.length && i < 3; i++) {
      final task = displayTasks[i];
      debugPrint(
          'EnhancedAgendaScreen: Task $i - ${task.title} (${task.status})');
    }

    switch (_currentView) {
      case 'kanban':
        return _buildKanbanView(displayTasks, taskProvider);
      case 'calendar':
        return _buildCalendarView(displayTasks, taskProvider);
      case 'matrix':
        return _buildMatrixView(displayTasks, taskProvider);
      default:
        return _buildListView(displayTasks, taskProvider);
    }
  }

  Widget _buildListView(List<Task> tasks, TaskProvider taskProvider) {
    debugPrint(
        'EnhancedAgendaScreen: _buildListView called with ${tasks.length} tasks');

    if (tasks.isEmpty) {
      debugPrint(
          'EnhancedAgendaScreen: No tasks to display, showing empty state');
      return _buildEmptyState();
    }

    debugPrint(
        'EnhancedAgendaScreen: Building ListView with ${tasks.length} tasks');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        debugPrint(
            'EnhancedAgendaScreen: Building task card for: ${task.title}');
        return _buildTaskCard(task, taskProvider);
      },
    );
  }

  Widget _buildTaskCard(Task task, TaskProvider taskProvider) {
    return _buildUnifiedTaskCard(
      task: task,
      taskProvider: taskProvider,
      onTap: () => _openTaskDetails(task),
      showDragHandle: false,
      contextMenuActions: _getTaskContextMenuActions(task),
      tabContext: 'general',
    );
  }

  List<PopupMenuEntry<String>> _getTaskContextMenuActions(Task task) {
    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text('Edit Task'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'complete',
        child: Row(
          children: [
            Icon(
              task.status == TaskStatus.completed ? Icons.undo : Icons.check,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(task.status == TaskStatus.completed
                ? 'Mark Incomplete'
                : 'Mark Complete'),
          ],
        ),
      ),
      if (task.status != TaskStatus.inProgress)
        PopupMenuItem(
          value: 'start',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18),
              const SizedBox(width: 8),
              Text('Start Task'),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'focus',
        child: Row(
          children: [
            Icon(Icons.timer, size: 18),
            const SizedBox(width: 8),
            Text('Focus Session'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            const SizedBox(width: 8),
            Text('Duplicate'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Task', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  /// Unified task card design for all Enhanced Agenda Screen tabs
  /// This ensures consistent UI/UX across Today, Upcoming, In Progress, and Completed tabs
  Widget _buildUnifiedTaskCard({
    required Task task,
    required TaskProvider taskProvider,
    VoidCallback? onTap,
    bool showDragHandle = false,
    List<PopupMenuEntry<String>>? contextMenuActions,
    String? tabContext, // 'today', 'upcoming', 'inprogress', 'completed'
  }) {
    final theme = Theme.of(context);

    // Determine card styling based on task state and tab context
    final isCompleted = task.status == TaskStatus.completed;
    final cardElevation = task.isOverdue || task.needsAttention ? 4.0 : 2.0;

    BorderSide? cardBorder;
    if (isCompleted && tabContext == 'completed') {
      cardBorder = BorderSide(color: Colors.green.withAlpha(77), width: 1);
    } else if (task.isOverdue) {
      cardBorder = BorderSide(color: Colors.red, width: 2);
    } else if (task.needsAttention) {
      cardBorder = BorderSide(color: task.urgencyLevel.color, width: 2);
    }

    return AccessibilityHelper.accessibleCard(
      semanticLabel: '${isCompleted ? 'Completed ' : ''}Task: ${task.title}',
      semanticHint: 'Double tap to open task details',
      onTap: showDragHandle ? null : onTap, // Disable tap when draggable
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: cardBorder ?? BorderSide.none,
        ),
        child: showDragHandle
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Drag handle for reorderable items
                    ReorderableDragStartListener(
                      index:
                          0, // This will be set properly in the calling widget
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.drag_handle,
                          color: theme.colorScheme.onSurface.withAlpha(128),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Main content (tappable)
                    Expanded(
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(8),
                        child: _buildUnifiedTaskCardContent(
                          task: task,
                          theme: theme,
                          contextMenuActions: contextMenuActions,
                          taskProvider: taskProvider,
                          tabContext: tabContext,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _buildUnifiedTaskCardContent(
                    task: task,
                    theme: theme,
                    contextMenuActions: contextMenuActions,
                    taskProvider: taskProvider,
                    tabContext: tabContext,
                  ),
                ),
              ),
      ),
    );
  }

  /// Unified task card content that provides consistent information display
  /// across all Enhanced Agenda Screen tabs
  Widget _buildUnifiedTaskCardContent({
    required Task task,
    required ThemeData theme,
    List<PopupMenuEntry<String>>? contextMenuActions,
    required TaskProvider taskProvider,
    String? tabContext,
  }) {
    final isCompleted = task.status == TaskStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, priority, and context menu
        Row(
          children: [
            // Urgency/Status indicator
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: task.isOverdue
                    ? Colors.red
                    : task.needsAttention
                        ? task.urgencyLevel.color
                        : task.priority.color,
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
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : isCompleted
                                  ? theme.colorScheme.onSurface.withAlpha(153)
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
                          color: task.priority.color.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: task.priority.color.withAlpha(77),
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

            // Context menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              onSelected: (value) =>
                  _handleTaskAction(value, task, taskProvider),
              itemBuilder: (context) =>
                  contextMenuActions ?? _getTaskContextMenuActions(task),
            ),
          ],
        ),

        // Description (if available)
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        // Progress indicator (if task has progress and not completed)
        if (task.progress > 0 && !isCompleted) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: theme.colorScheme.outline.withAlpha(51),
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
        ],

        const SizedBox(height: 8),

        // Footer with due date and additional info
        Row(
          children: [
            // Due date with enhanced formatting
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.isOverdue
                      ? Colors.red.withAlpha(26)
                      : task.needsAttention
                          ? task.urgencyLevel.color.withAlpha(26)
                          : theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.isOverdue
                        ? Colors.red.withAlpha(77)
                        : task.needsAttention
                            ? task.urgencyLevel.color.withAlpha(77)
                            : theme.colorScheme.primary.withAlpha(77),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.enhancedTimeUntilDue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: task.isOverdue
                            ? Colors.red
                            : task.needsAttention
                                ? task.urgencyLevel.color
                                : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Focus sessions info (if applicable)
            if (task.estimatedFocusSessions > 0) ...[
              Icon(
                Icons.timer,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${task.completedFocusSessions}/${task.estimatedFocusSessions}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Tags indicator (if applicable)
            if (task.tags.isNotEmpty) ...[
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
              const SizedBox(width: 8),
            ],

            // Creation/Update timestamp
            Text(
              _formatTaskTimestamp(task),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKanbanView(List<Task> tasks, TaskProvider taskProvider) {
    final todoTasks = tasks.where((t) => t.status == TaskStatus.todo).toList();
    final inProgressTasks =
        tasks.where((t) => t.status == TaskStatus.inProgress).toList();
    final completedTasks =
        tasks.where((t) => t.status == TaskStatus.completed).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildKanbanColumn(
              'To Do', todoTasks, TaskStatus.todo, Colors.grey, taskProvider),
          const SizedBox(width: 16),
          _buildKanbanColumn('In Progress', inProgressTasks,
              TaskStatus.inProgress, Colors.blue, taskProvider),
          const SizedBox(width: 16),
          _buildKanbanColumn('Completed', completedTasks, TaskStatus.completed,
              Colors.green, taskProvider),
        ],
      ),
    );
  }

  Widget _buildKanbanColumn(String title, List<Task> tasks, TaskStatus status,
      Color color, TaskProvider taskProvider) {
    final theme = Theme.of(context);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tasks List
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'No tasks',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _buildKanbanTaskCard(tasks[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildKanbanTaskCard(Task task) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Task Header
          Row(
            children: [
              Container(
                width: 3,
                height: 20,
                decoration: BoxDecoration(
                  color: task.priority.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                task.category.icon,
                size: 16,
                color: task.category.color,
              ),
            ],
          ),

          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              task.description,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Progress Bar
          if (task.progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: theme.colorScheme.outline.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(task.priority.color),
            ),
          ],

          // Task Footer
          const SizedBox(height: 8),
          Row(
            children: [
              if (task.dueDate != null) ...[
                Icon(
                  Icons.schedule,
                  size: 12,
                  color: task.isOverdue ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  task.timeUntilDue,
                  style: TextStyle(
                    fontSize: 10,
                    color: task.isOverdue ? Colors.red : Colors.grey,
                  ),
                ),
              ],
              const Spacer(),
              if (task.completedFocusSessions > 0) ...[
                Icon(
                  Icons.timer,
                  size: 12,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 2),
                Text(
                  '${task.completedFocusSessions}',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(List<Task> tasks, TaskProvider taskProvider) {
    return Column(
      children: [
        // Calendar Header with Month Navigation
        _buildCalendarHeader(),

        // Calendar Grid
        Expanded(
          child: _buildCalendarGrid(tasks, taskProvider),
        ),

        // Selected Date Tasks
        if (_selectedDate != null) _buildSelectedDateTasks(tasks, taskProvider),
      ],
    );
  }

  Widget _buildMatrixView(List<Task> tasks, TaskProvider taskProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Matrix Header
          Text(
            'Eisenhower Priority Matrix',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Matrix Grid
          Expanded(
            child: _buildPriorityMatrix(tasks, taskProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No tasks found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Text('Create your first task to get started'),
        ],
      ),
    );
  }

  Widget _buildSmartFAB(TaskProvider taskProvider) {
    return FloatingActionButton.extended(
      onPressed: () => _showCreateTaskDialog(taskProvider),
      icon: const Icon(Icons.add),
      label: const Text('New Task'),
    );
  }

  // Helper methods

  /// Format creation/update date in a user-friendly relative format
  String _formatTaskTimestamp(Task task) {
    final now = DateTime.now();

    // Check if task has been updated (updatedAt is different from createdAt)
    final isUpdated = task.updatedAt.isAfter(task.createdAt);
    final timestampToUse = isUpdated ? task.updatedAt : task.createdAt;

    final difference = now.difference(timestampToUse);
    final prefix = isUpdated ? 'Updated' : 'Created';

    if (difference.inMinutes < 1) {
      return '$prefix just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$prefix $minutes minute${minutes != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$prefix $hours hour${hours != 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return '$prefix yesterday';
    } else if (difference.inDays < 7) {
      return '$prefix ${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$prefix $weeks week${weeks != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$prefix $months month${months != 1 ? 's' : ''} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$prefix $years year${years != 1 ? 's' : ''} ago';
    }
  }

  /// Get sorted tasks for specific tab with tab-specific sorting logic
  List<Task> _getSortedTasksForTab(
      List<Task> tasks, int tabIndex, TaskProvider taskProvider) {
    List<Task> filtered = List.from(tasks);

    // Debug logging for tab-specific sorting
    final tabNames = ['Today', 'Upcoming', 'In Progress', 'Completed'];
    final tabName = tabIndex < tabNames.length ? tabNames[tabIndex] : 'Unknown';
    debugPrint(
        'EnhancedAgendaScreen: Sorting tasks for $tabName tab (index: $tabIndex)');
    debugPrint('EnhancedAgendaScreen: Input tasks count: ${tasks.length}');

    // Apply separate priority filter
    if (taskProvider.priorityFilter != null) {
      filtered = filtered
          .where((task) => task.priority == taskProvider.priorityFilter)
          .toList();
    }

    // Apply separate category filter
    if (taskProvider.categoryFilter != null) {
      filtered = filtered
          .where((task) => task.category == taskProvider.categoryFilter)
          .toList();
    }

    // Apply search filter
    if (taskProvider.searchQuery.isNotEmpty) {
      filtered = filtered
          .where((task) =>
              task.title
                  .toLowerCase()
                  .contains(taskProvider.searchQuery.toLowerCase()) ||
              task.description
                  .toLowerCase()
                  .contains(taskProvider.searchQuery.toLowerCase()) ||
              task.tags.any((tag) => tag
                  .toLowerCase()
                  .contains(taskProvider.searchQuery.toLowerCase())))
          .toList();
    }

    debugPrint(
        'EnhancedAgendaScreen: Filtered tasks count: ${filtered.length}');

    // Apply tab-specific sorting
    switch (tabIndex) {
      case 0: // Today tab - newest first by default
        final sortBy =
            taskProvider.sortBy == 'dueDate' ? 'created' : taskProvider.sortBy;
        debugPrint(
            'EnhancedAgendaScreen: Today tab using sort: $sortBy (original: ${taskProvider.sortBy})');
        return _sortTasksManually(filtered, sortBy);
      case 2: // In Progress tab - newest updated first by default
        final inProgressSortBy = taskProvider.sortBy == 'dueDate' ||
                taskProvider.sortBy == 'alphabetical' ||
                taskProvider.sortBy == 'priority'
            ? 'updated'
            : taskProvider.sortBy;
        debugPrint(
            'EnhancedAgendaScreen: In Progress tab using sort: $inProgressSortBy (original: ${taskProvider.sortBy})');
        final sortedInProgress = _sortTasksManually(filtered, inProgressSortBy);
        debugPrint(
            'EnhancedAgendaScreen: In Progress sorted tasks: ${sortedInProgress.take(3).map((t) => '${t.title} (${t.updatedAt})').join(', ')}');
        return sortedInProgress;
      case 3: // Completed tab - newest updated first by default
        final completedSortBy = taskProvider.sortBy == 'dueDate' ||
                taskProvider.sortBy == 'alphabetical' ||
                taskProvider.sortBy == 'priority'
            ? 'updated'
            : taskProvider.sortBy;
        debugPrint(
            'EnhancedAgendaScreen: Completed tab using sort: $completedSortBy (original: ${taskProvider.sortBy})');
        final sortedCompleted = _sortTasksManually(filtered, completedSortBy);
        debugPrint(
            'EnhancedAgendaScreen: Completed sorted tasks: ${sortedCompleted.take(3).map((t) => '${t.title} (${t.updatedAt})').join(', ')}');
        return sortedCompleted;
      default:
        debugPrint(
            'EnhancedAgendaScreen: Default tab using sort: ${taskProvider.sortBy}');
        return _sortTasksManually(filtered, taskProvider.sortBy);
    }
  }

  /// Manual sorting method to handle tab-specific logic
  List<Task> _sortTasksManually(List<Task> tasks, String sortBy) {
    debugPrint(
        'EnhancedAgendaScreen: _sortTasksManually called with sortBy: $sortBy, tasks count: ${tasks.length}');

    switch (sortBy) {
      case 'dueDate':
        debugPrint('EnhancedAgendaScreen: Sorting by due date');
        return tasks
          ..sort((a, b) {
            if (a.dueDate == null && b.dueDate == null) return 0;
            if (a.dueDate == null) return 1;
            if (b.dueDate == null) return -1;
            return a.dueDate!.compareTo(b.dueDate!);
          });
      case 'priority':
        debugPrint('EnhancedAgendaScreen: Sorting by priority');
        return tasks
          ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
      case 'created':
        debugPrint(
            'EnhancedAgendaScreen: Sorting by created date (newest first)');
        final sorted = tasks
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        debugPrint(
            'EnhancedAgendaScreen: After created sort, first 3 tasks: ${sorted.take(3).map((t) => '${t.title} (${t.createdAt})').join(', ')}');
        return sorted;
      case 'updated':
        debugPrint(
            'EnhancedAgendaScreen: Sorting by updated date (newest first)');
        final sorted = tasks
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        debugPrint(
            'EnhancedAgendaScreen: After updated sort, first 3 tasks: ${sorted.take(3).map((t) => '${t.title} (${t.updatedAt})').join(', ')}');
        return sorted;
      case 'alphabetical':
        debugPrint('EnhancedAgendaScreen: Sorting alphabetically');
        return tasks..sort((a, b) => a.title.compareTo(b.title));
      case 'progress':
        debugPrint('EnhancedAgendaScreen: Sorting by progress');
        return tasks..sort((a, b) => b.progress.compareTo(a.progress));
      default:
        debugPrint('EnhancedAgendaScreen: No sorting applied (default)');
        return tasks;
    }
  }

  // These methods are now handled by TaskProvider

  void _showSearchDialog(TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => _buildAdvancedSearchDialog(taskProvider),
    );
  }

  Widget _buildAdvancedSearchDialog(TaskProvider taskProvider) {
    final searchController = TextEditingController();
    TaskPriority? selectedPriority;
    TaskCategory? selectedCategory;
    TaskStatus? selectedStatus;
    DateTime? startDate;
    DateTime? endDate;
    bool includeCompleted = true;
    bool includeOverdue = true;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.search, color: Colors.blue),
              SizedBox(width: 8),
              Text('Advanced Search'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Search text
                  TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search tasks...',
                      hintText: 'Enter title, description, or tags',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Priority filter
                  const Text('Priority',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Any'),
                        selected: selectedPriority == null,
                        onSelected: (selected) =>
                            setState(() => selectedPriority = null),
                      ),
                      ...TaskPriority.values.map((priority) => FilterChip(
                            label: Text(priority.displayName),
                            selected: selectedPriority == priority,
                            onSelected: (selected) => setState(() =>
                                selectedPriority = selected ? priority : null),
                            avatar: Icon(priority.icon,
                                size: 16, color: priority.color),
                          )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Category filter
                  const Text('Category',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Any'),
                        selected: selectedCategory == null,
                        onSelected: (selected) =>
                            setState(() => selectedCategory = null),
                      ),
                      ...TaskCategory.values.map((category) => FilterChip(
                            label: Text(category.displayName),
                            selected: selectedCategory == category,
                            onSelected: (selected) => setState(() =>
                                selectedCategory = selected ? category : null),
                            avatar: Icon(category.icon,
                                size: 16, color: category.color),
                          )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Status filter
                  const Text('Status',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Any'),
                        selected: selectedStatus == null,
                        onSelected: (selected) =>
                            setState(() => selectedStatus = null),
                      ),
                      ...TaskStatus.values.map((status) => FilterChip(
                            label: Text(status.displayName),
                            selected: selectedStatus == status,
                            onSelected: (selected) => setState(() =>
                                selectedStatus = selected ? status : null),
                            avatar: Icon(_getStatusIcon(status),
                                size: 16, color: status.color),
                          )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Date range
                  const Text('Date Range',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => startDate = date);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(startDate != null
                              ? 'From: ${startDate!.day}/${startDate!.month}/${startDate!.year}'
                              : 'Start Date'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => endDate = date);
                          },
                          icon: const Icon(Icons.calendar_today),
                          label: Text(endDate != null
                              ? 'To: ${endDate!.day}/${endDate!.month}/${endDate!.year}'
                              : 'End Date'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Additional options
                  const Text('Options',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Include Completed Tasks'),
                    value: includeCompleted,
                    onChanged: (value) =>
                        setState(() => includeCompleted = value ?? true),
                    dense: true,
                  ),
                  CheckboxListTile(
                    title: const Text('Include Overdue Tasks'),
                    value: includeOverdue,
                    onChanged: (value) =>
                        setState(() => includeOverdue = value ?? true),
                    dense: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // Clear all filters
                searchController.clear();
                setState(() {
                  selectedPriority = null;
                  selectedCategory = null;
                  selectedStatus = null;
                  startDate = null;
                  endDate = null;
                  includeCompleted = true;
                  includeOverdue = true;
                });
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _performAdvancedSearch(
                  taskProvider,
                  searchController.text,
                  selectedPriority,
                  selectedCategory,
                  selectedStatus,
                  startDate,
                  endDate,
                  includeCompleted,
                  includeOverdue,
                );
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }

  void _performAdvancedSearch(
    TaskProvider taskProvider,
    String searchText,
    TaskPriority? priority,
    TaskCategory? category,
    TaskStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    bool includeCompleted,
    bool includeOverdue,
  ) {
    final results = taskProvider.tasks.where((task) {
      // Text search
      if (searchText.isNotEmpty) {
        final searchLower = searchText.toLowerCase();
        final titleMatch = task.title.toLowerCase().contains(searchLower);
        final descMatch = task.description.toLowerCase().contains(searchLower);
        final tagMatch =
            task.tags.any((tag) => tag.toLowerCase().contains(searchLower));

        if (!titleMatch && !descMatch && !tagMatch) return false;
      }

      // Priority filter
      if (priority != null && task.priority != priority) return false;

      // Category filter
      if (category != null && task.category != category) return false;

      // Status filter
      if (status != null && task.status != status) return false;

      // Completed filter
      if (!includeCompleted && task.status == TaskStatus.completed)
        return false;

      // Overdue filter
      if (!includeOverdue && task.isOverdue) return false;

      // Date range filter
      if (startDate != null || endDate != null) {
        final taskDate = task.dueDate ?? task.createdAt;
        if (startDate != null && taskDate.isBefore(startDate)) return false;
        if (endDate != null &&
            taskDate.isAfter(endDate.add(const Duration(days: 1))))
          return false;
      }

      return true;
    }).toList();

    _showSearchResults(results, searchText);
  }

  void _showSearchResults(List<Task> results, String searchQuery) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.search_off, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Search Results (${results.length})'),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: results.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No tasks found'),
                      Text('Try adjusting your search criteria'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final task = results[index];
                    return ListTile(
                      leading: Icon(
                        task.category.icon,
                        color: task.category.color,
                      ),
                      title: Text(task.title),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (task.description.isNotEmpty)
                            Text(
                              task.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Row(
                            children: [
                              Icon(task.priority.icon,
                                  size: 12, color: task.priority.color),
                              const SizedBox(width: 4),
                              Text(task.priority.displayName,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 8),
                              Icon(_getStatusIcon(task.status),
                                  size: 12, color: task.status.color),
                              const SizedBox(width: 4),
                              Text(task.status.displayName,
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      trailing: task.dueDate != null
                          ? Text(
                              task.timeUntilDue,
                              style: TextStyle(
                                fontSize: 12,
                                color: task.isOverdue ? Colors.red : null,
                              ),
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        _openTaskDetails(task);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog(TaskProvider taskProvider) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => const CreateTaskDialog(),
    );

    if (result != null && mounted) {
      // Task was created successfully, show success message
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Task "${result.title}" created successfully!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showTemplateSelectionDialog(
    BuildContext context,
    TaskProvider taskProvider,
    TextEditingController titleController,
    TextEditingController descriptionController,
    StateSetter setState,
    Function(TaskPriority) setPriority,
    Function(TaskCategory) setCategory,
  ) {
    showDialog(
      context: context,
      builder: (context) => TaskTemplatesDialog(
        onTemplateSelected: (template) {
          // Fill form with template data
          titleController.text = template.name;
          descriptionController.text = template.description;
          setState(() {
            setPriority(template.priority);
            setCategory(template.category);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Template "${template.name}" applied!')),
          );
        },
      ),
    );
  }

  void _openTaskDetails(Task task) {
    // For now, use simple navigation until we resolve model conflicts
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportTasks();
        break;
      case 'import':
        _importTasks();
        break;
      case 'settings':
        _showTaskSettings();
        break;
      case 'analytics':
        _showTaskAnalytics();
        break;
    }
  }

  void _handleTaskAction(String action, Task task, TaskProvider taskProvider) {
    switch (action) {
      case 'edit':
        _editTask(task, taskProvider);
        break;
      case 'start':
        _startTask(task, taskProvider);
        break;
      case 'complete':
        _completeTask(task, taskProvider);
        break;
      case 'status':
        _changeTaskStatus(task, taskProvider);
        break;
      case 'delete':
        _deleteTask(task, taskProvider);
        break;
      case 'duplicate':
        _duplicateTask(task, taskProvider);
        break;
      case 'focus':
        _startFocusSession(task);
        break;
    }
  }

  // Helper methods for task operations
  void _exportTasks() {
    showDialog(
      context: context,
      builder: (context) => _buildExportDialog(),
    );
  }

  Widget _buildExportDialog() {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.download, color: Colors.blue),
          SizedBox(width: 8),
          Text('Export Tasks'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose export format:'),
          const SizedBox(height: 16),

          // Export options
          ListTile(
            leading: const Icon(Icons.description, color: Colors.green),
            title: const Text('Export as CSV'),
            subtitle: const Text('Spreadsheet format for data analysis'),
            onTap: () {
              Navigator.pop(context);
              _exportAsCSV();
            },
          ),

          ListTile(
            leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
            title: const Text('Export as PDF'),
            subtitle: const Text('Formatted document for printing'),
            onTap: () {
              Navigator.pop(context);
              _exportAsPDF();
            },
          ),

          ListTile(
            leading: const Icon(Icons.code, color: Colors.orange),
            title: const Text('Export as JSON'),
            subtitle: const Text('Raw data format for backup'),
            onTap: () {
              Navigator.pop(context);
              _exportAsJSON();
            },
          ),

          ListTile(
            leading: const Icon(Icons.text_snippet, color: Colors.purple),
            title: const Text('Export as Text'),
            subtitle: const Text('Simple text format for sharing'),
            onTap: () {
              Navigator.pop(context);
              _exportAsText();
            },
          ),
          ListTile(
            leading: const Icon(Icons.event, color: Colors.teal),
            title: const Text('Export due dates to calendar'),
            subtitle: const Text('Create an .ics file for calendar apps'),
            onTap: () {
              Navigator.pop(context);
              _exportCalendarEvents();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _exportCalendarEvents() async {
    final tasks = context.read<TaskProvider>().tasks;
    try {
      final count = await CalendarExportService().shareDueTasks(tasks);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(count == 0
              ? 'No tasks with due dates to export'
              : 'Shared $count calendar event${count == 1 ? '' : 's'}'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not export calendar events: $error')),
        );
      }
    }
  }

  void _exportAsCSV() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final tasks = taskProvider.tasks;
      final csvContent = _generateCSVContent(tasks);

      // For now, show the content in a dialog (file saving would require additional packages)
      _showExportPreview('CSV Export', csvContent, 'csv');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ CSV content generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportAsPDF() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final tasks = taskProvider.tasks;
      final pdfContent = _generatePDFContent(tasks);

      _showExportPreview('PDF Export', pdfContent, 'pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF content generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportAsJSON() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final tasks = taskProvider.tasks;
      final jsonContent = _generateJSONContent(tasks);

      _showExportPreview('JSON Export', jsonContent, 'json');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ JSON content generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportAsText() async {
    try {
      final taskProvider = Provider.of<TaskProvider>(context, listen: false);
      final tasks = taskProvider.tasks;
      final textContent = _generateTextContent(tasks);

      _showExportPreview('Text Export', textContent, 'text');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Text content generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Content generation methods
  String _generateCSVContent(List<Task> tasks) {
    final buffer = StringBuffer();

    // CSV Header
    buffer.writeln(
        'Title,Description,Priority,Category,Status,Due Date,Created At,Updated At,Tags');

    // CSV Data
    for (final task in tasks) {
      final row = [
        _escapeCsvField(task.title),
        _escapeCsvField(task.description),
        task.priority.displayName,
        task.category.displayName,
        task.status.displayName,
        task.dueDate?.toIso8601String() ?? '',
        task.createdAt.toIso8601String(),
        task.updatedAt.toIso8601String(),
        task.tags.join(';'),
      ];
      buffer.writeln(row.join(','));
    }

    return buffer.toString();
  }

  String _generateJSONContent(List<Task> tasks) {
    final tasksJson = tasks
        .map((task) => {
              'id': task.id,
              'title': task.title,
              'description': task.description,
              'priority': task.priority.name,
              'category': task.category.name,
              'status': task.status.name,
              'dueDate': task.dueDate?.toIso8601String(),
              'createdAt': task.createdAt.toIso8601String(),
              'updatedAt': task.updatedAt.toIso8601String(),
              'completedAt': task.completedAt?.toIso8601String(),
              'tags': task.tags,
              'estimatedFocusSessions': task.estimatedFocusSessions,
            })
        .toList();

    return const JsonEncoder.withIndent('  ').convert({
      'exportDate': DateTime.now().toIso8601String(),
      'totalTasks': tasks.length,
      'tasks': tasksJson,
    });
  }

  String _generateTextContent(List<Task> tasks) {
    final buffer = StringBuffer();

    buffer.writeln('FocusBro Task Export');
    buffer.writeln('Generated: ${DateTime.now().toString()}');
    buffer.writeln('Total Tasks: ${tasks.length}');
    buffer.writeln('${'=' * 50}');
    buffer.writeln();

    for (int i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      buffer.writeln('${i + 1}. ${task.title}');
      buffer.writeln('   Priority: ${task.priority.displayName}');
      buffer.writeln('   Category: ${task.category.displayName}');
      buffer.writeln('   Status: ${task.status.displayName}');

      if (task.description.isNotEmpty) {
        buffer.writeln('   Description: ${task.description}');
      }

      if (task.dueDate != null) {
        buffer.writeln('   Due Date: ${task.dueDate.toString()}');
      }

      if (task.tags.isNotEmpty) {
        buffer.writeln('   Tags: ${task.tags.join(', ')}');
      }

      buffer.writeln('   Created: ${task.createdAt.toString()}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  String _generatePDFContent(List<Task> tasks) {
    // For now, return formatted text that could be converted to PDF
    final buffer = StringBuffer();

    buffer.writeln('FOCUSBRO TASK REPORT');
    buffer.writeln('Generated: ${DateTime.now().toString()}');
    buffer.writeln();

    // Summary
    final totalTasks = tasks.length;
    final completedTasks =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgressTasks =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final todoTasks = tasks.where((t) => t.status == TaskStatus.todo).length;

    buffer.writeln('SUMMARY');
    buffer.writeln('Total Tasks: $totalTasks');
    buffer.writeln('Completed: $completedTasks');
    buffer.writeln('In Progress: $inProgressTasks');
    buffer.writeln('To Do: $todoTasks');
    buffer.writeln();

    // Task details
    buffer.writeln('TASK DETAILS');
    buffer.writeln('-' * 50);

    for (final task in tasks) {
      buffer.writeln('Title: ${task.title}');
      buffer.writeln('Priority: ${task.priority.displayName}');
      buffer.writeln('Status: ${task.status.displayName}');
      buffer.writeln('Category: ${task.category.displayName}');

      if (task.description.isNotEmpty) {
        buffer.writeln('Description: ${task.description}');
      }

      if (task.dueDate != null) {
        buffer.writeln('Due Date: ${task.dueDate.toString()}');
      }

      buffer.writeln('Created: ${task.createdAt.toString()}');
      buffer.writeln('-' * 30);
    }

    return buffer.toString();
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  void _showExportPreview(String title, String content, String format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              format == 'csv'
                  ? Icons.table_chart
                  : format == 'json'
                      ? Icons.code
                      : format == 'pdf'
                          ? Icons.picture_as_pdf
                          : Icons.text_snippet,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareExportContent(title, content, format);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareExportContent(
    String title,
    String content,
    String format,
  ) async {
    try {
      if (format == 'pdf') {
        final document = pw.Document();
        document.addPage(
          pw.MultiPage(
            pageFormat: pw.PdfPageFormat.a4,
            build: (context) => [
              pw.Header(level: 0, child: pw.Text(title)),
              pw.Text(content, style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
        );
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/focusbro_tasks_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
        await file.writeAsBytes(await document.save(), flush: true);
        await Share.shareXFiles(
          [XFile(file.path, mimeType: 'application/pdf')],
          text: title,
        );
      } else if (kIsWeb) {
        await Share.share(content, subject: title);
      } else {
        final extension = switch (format) {
          'csv' => 'csv',
          'json' => 'json',
          _ => 'txt',
        };
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/focusbro_tasks_${DateTime.now().millisecondsSinceEpoch}.$extension',
        );
        await file.writeAsString(content, flush: true);
        await Share.shareXFiles([XFile(file.path)], text: title);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not share export: $error')),
        );
      }
    }
  }

  void _importTasks() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Importing tasks...')),
    );
  }

  void _showTaskSettings() {
    showDialog(
      context: context,
      builder: (context) => _buildTaskSettingsDialog(context),
    );
  }

  void _showTaskAnalytics() {
    showDialog(
      context: context,
      builder: (context) => _buildAnalyticsDialog(),
    );
  }

  Widget _buildAnalyticsDialog() {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final tasks = taskProvider.tasks;

    // Calculate analytics
    final totalTasks = tasks.length;
    final completedTasks =
        tasks.where((t) => t.status == TaskStatus.completed).length;
    final inProgressTasks =
        tasks.where((t) => t.status == TaskStatus.inProgress).length;
    final todoTasks = tasks.where((t) => t.status == TaskStatus.todo).length;
    final overdueTasks = tasks.where((t) => t.isOverdue).length;

    final completionRate =
        totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0.0;

    // Priority distribution
    final urgentTasks =
        tasks.where((t) => t.priority == TaskPriority.urgent).length;
    final highTasks =
        tasks.where((t) => t.priority == TaskPriority.high).length;
    final mediumTasks =
        tasks.where((t) => t.priority == TaskPriority.medium).length;
    final lowTasks = tasks.where((t) => t.priority == TaskPriority.low).length;

    // Today's tasks
    final today = DateTime.now();
    final todayTasks = tasks
        .where((t) =>
            t.dueDate != null &&
            t.dueDate!.year == today.year &&
            t.dueDate!.month == today.month &&
            t.dueDate!.day == today.day)
        .length;

    final todayCompleted = tasks
        .where((t) =>
            t.status == TaskStatus.completed &&
            t.completedAt != null &&
            t.completedAt!.year == today.year &&
            t.completedAt!.month == today.month &&
            t.completedAt!.day == today.day)
        .length;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.analytics, color: Colors.blue),
          SizedBox(width: 8),
          Text('Task Analytics'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Overall Statistics
              _buildAnalyticsSection(
                'Overall Statistics',
                [
                  _buildAnalyticsItem(
                      'Total Tasks', totalTasks.toString(), Icons.task),
                  _buildAnalyticsItem(
                      'Completion Rate',
                      '${completionRate.toStringAsFixed(1)}%',
                      Icons.check_circle),
                  _buildAnalyticsItem(
                      'Overdue Tasks', overdueTasks.toString(), Icons.warning,
                      color: overdueTasks > 0 ? Colors.red : null),
                ],
              ),

              const SizedBox(height: 16),

              // Status Distribution
              _buildAnalyticsSection(
                'Status Distribution',
                [
                  _buildAnalyticsItem('Completed', completedTasks.toString(),
                      Icons.check_circle,
                      color: Colors.green),
                  _buildAnalyticsItem('In Progress', inProgressTasks.toString(),
                      Icons.play_circle,
                      color: Colors.blue),
                  _buildAnalyticsItem('To Do', todoTasks.toString(),
                      Icons.radio_button_unchecked,
                      color: Colors.grey),
                ],
              ),

              const SizedBox(height: 16),

              // Priority Distribution
              _buildAnalyticsSection(
                'Priority Distribution',
                [
                  _buildAnalyticsItem(
                      'Urgent', urgentTasks.toString(), Icons.priority_high,
                      color: Colors.red),
                  _buildAnalyticsItem(
                      'High', highTasks.toString(), Icons.keyboard_arrow_up,
                      color: Colors.orange),
                  _buildAnalyticsItem(
                      'Medium', mediumTasks.toString(), Icons.remove,
                      color: Colors.yellow[700]),
                  _buildAnalyticsItem(
                      'Low', lowTasks.toString(), Icons.keyboard_arrow_down,
                      color: Colors.green),
                ],
              ),

              const SizedBox(height: 16),

              // Today's Performance
              _buildAnalyticsSection(
                'Today\'s Performance',
                [
                  _buildAnalyticsItem(
                      'Due Today', todayTasks.toString(), Icons.today),
                  _buildAnalyticsItem(
                      'Completed Today', todayCompleted.toString(), Icons.check,
                      color: Colors.green),
                  _buildAnalyticsItem(
                      'Today\'s Rate',
                      todayTasks > 0
                          ? '${(todayCompleted / todayTasks * 100).toStringAsFixed(1)}%'
                          : '0%',
                      Icons.trending_up),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(this.context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EnhancedAnalyticsScreen(),
              ),
            );
          },
          child: const Text('View Details'),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...items,
      ],
    );
  }

  Widget _buildAnalyticsItem(String label, String value, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _editTask(Task task, TaskProvider taskProvider) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      // Update the task using TaskProvider
      final success = await taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _completeTask(Task task, TaskProvider taskProvider) async {
    final success = await taskProvider.toggleTaskCompletion(task.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Completed "${task.title}"')),
      );
    }
  }

  void _deleteTask(Task task, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await taskProvider.deleteTask(task.id);
              if (success && mounted) {
                // Force immediate badge refresh
                await taskProvider.refreshTasks();
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Task deleted')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _duplicateTask(Task task, TaskProvider taskProvider) async {
    final newTask = await taskProvider.createTask(
      title: '${task.title} (Copy)',
      description: task.description,
      category: task.category,
      priority: task.priority,
      dueDate: task.dueDate,
      tags: task.tags,
      estimatedFocusSessions: task.estimatedFocusSessions,
    );

    if (newTask != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Duplicated "${task.title}"')),
      );
    }
  }

  void _startTask(Task task, TaskProvider taskProvider) async {
    final success = await taskProvider.startTask(task.id);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Started "${task.title}"')),
      );
    }
  }

  void _changeTaskStatus(Task task, TaskProvider taskProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Task Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskStatus.values.map((status) {
            return ListTile(
              leading: Icon(
                _getStatusIcon(status),
                color: status.color,
              ),
              title: Text(status.displayName),
              onTap: () async {
                Navigator.pop(context);
                final success =
                    await taskProvider.changeTaskStatus(task.id, status);
                if (success && mounted) {
                  // Force immediate badge refresh
                  await taskProvider.refreshTasks();
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                        content: Text(
                            'Changed "${task.title}" to ${status.displayName}')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.play_circle;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  void _startFocusSession(Task task) {
    // Navigate to main screen and switch to focus tab
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Focus session started for "${task.title}"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Calendar View Methods
  Widget _buildCalendarHeader() {
    final theme = Theme.of(context);
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _currentMonth =
                    DateTime(_currentMonth.year, _currentMonth.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(List<Task> tasks, TaskProvider taskProvider) {
    final theme = Theme.of(context);
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withAlpha(179),
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                final dayOffset = index - firstDayOfWeek;
                final day = dayOffset + 1;

                if (dayOffset < 0 || day > daysInMonth) {
                  return const SizedBox(); // Empty cell
                }

                final date =
                    DateTime(_currentMonth.year, _currentMonth.month, day);
                final tasksForDay = _getTasksForDate(tasks, date);
                final isSelected = _selectedDate != null &&
                    _selectedDate!.year == date.year &&
                    _selectedDate!.month == date.month &&
                    _selectedDate!.day == date.day;
                final isToday = _isToday(date);

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary.withAlpha(51)
                          : isToday
                              ? theme.colorScheme.primary.withAlpha(26)
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: theme.colorScheme.primary)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: TextStyle(
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (tasksForDay.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (tasksForDay.length <= 3)
                                ...tasksForDay.take(3).map((task) => Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      decoration: BoxDecoration(
                                        color: task.priority.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ))
                              else ...[
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(
                                  '+${tasksForDay.length - 1}',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateTasks(List<Task> tasks, TaskProvider taskProvider) {
    if (_selectedDate == null) return const SizedBox();

    final tasksForDate = _getTasksForDate(tasks, _selectedDate!);
    final theme = Theme.of(context);

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasks for ${_formatDate(_selectedDate!)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: tasksForDate.isEmpty
                ? Center(
                    child: Text(
                      'No tasks for this date',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(153),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: tasksForDate.length,
                    itemBuilder: (context, index) {
                      final task = tasksForDate[index];
                      return _buildCompactTaskCard(task, taskProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTaskCard(Task task, TaskProvider taskProvider) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          // Priority indicator
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: task.priority.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Task content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: task.status == TaskStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => taskProvider.toggleTaskCompletion(task.id),
                icon: Icon(
                  task.status == TaskStatus.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task.status == TaskStatus.completed
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Task> _getTasksForDate(List<Task> tasks, DateTime date) {
    return tasks.where((task) {
      if (task.dueDate == null) return false;
      final taskDate = task.dueDate!;
      return taskDate.year == date.year &&
          taskDate.month == date.month &&
          taskDate.day == date.day;
    }).toList();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDate(DateTime date) {
    final monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  // Priority Matrix Methods
  Widget _buildPriorityMatrix(List<Task> tasks, TaskProvider taskProvider) {
    final theme = Theme.of(context);

    // Categorize tasks based on Eisenhower Matrix
    final urgentImportant = tasks
        .where(
            (task) => task.priority == TaskPriority.urgent && task.isDueToday)
        .toList();
    final notUrgentImportant = tasks
        .where((task) => task.priority == TaskPriority.high && !task.isDueToday)
        .toList();
    final urgentNotImportant = tasks
        .where(
            (task) => task.priority == TaskPriority.medium && task.isDueToday)
        .toList();
    final notUrgentNotImportant = tasks
        .where((task) => task.priority == TaskPriority.low && !task.isDueToday)
        .toList();

    return Column(
      children: [
        // Matrix Labels
        Row(
          children: [
            const SizedBox(width: 80), // Space for left labels
            Expanded(
              child: Center(
                child: Text(
                  'URGENT',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'NOT URGENT',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Matrix Grid
        Expanded(
          child: Row(
            children: [
              // Left labels
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            'IMPORTANT',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: Text(
                            'NOT IMPORTANT',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Matrix quadrants
              Expanded(
                child: Column(
                  children: [
                    // Top row: Important
                    Expanded(
                      child: Row(
                        children: [
                          // Q1: Urgent & Important (Do First)
                          Expanded(
                            child: _buildMatrixQuadrant(
                              'DO FIRST',
                              'Urgent & Important',
                              urgentImportant,
                              Colors.red,
                              taskProvider,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Q2: Not Urgent & Important (Schedule)
                          Expanded(
                            child: _buildMatrixQuadrant(
                              'SCHEDULE',
                              'Important, Not Urgent',
                              notUrgentImportant,
                              Colors.green,
                              taskProvider,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Bottom row: Not Important
                    Expanded(
                      child: Row(
                        children: [
                          // Q3: Urgent & Not Important (Delegate)
                          Expanded(
                            child: _buildMatrixQuadrant(
                              'DELEGATE',
                              'Urgent, Not Important',
                              urgentNotImportant,
                              Colors.orange,
                              taskProvider,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Q4: Not Urgent & Not Important (Eliminate)
                          Expanded(
                            child: _buildMatrixQuadrant(
                              'ELIMINATE',
                              'Not Urgent, Not Important',
                              notUrgentNotImportant,
                              Colors.grey,
                              taskProvider,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixQuadrant(
    String title,
    String subtitle,
    List<Task> tasks,
    Color color,
    TaskProvider taskProvider,
  ) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77), width: 2),
      ),
      child: Column(
        children: [
          // Quadrant header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withAlpha(51),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Column(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color.withAlpha(204),
                  ),
                  textAlign: TextAlign.center,
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(77),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tasks list
          Expanded(
            child: tasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withAlpha(128),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildMatrixTaskCard(task, taskProvider);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixTaskCard(Task task, TaskProvider taskProvider) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withAlpha(51),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    decoration: task.status == TaskStatus.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => taskProvider.toggleTaskCompletion(task.id),
                child: Icon(
                  task.status == TaskStatus.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 16,
                  color: task.status == TaskStatus.completed
                      ? Colors.green
                      : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          if (task.dueDate != null) ...[
            const SizedBox(height: 4),
            Text(
              task.timeUntilDue,
              style: TextStyle(
                fontSize: 10,
                color: task.isOverdue
                    ? Colors.red
                    : theme.colorScheme.onSurface.withAlpha(153),
              ),
            ),
          ],
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: task.progress,
            backgroundColor: theme.colorScheme.outline.withAlpha(51),
            valueColor: AlwaysStoppedAnimation<Color>(task.priority.color),
            minHeight: 2,
          ),
        ],
      ),
    );
  }

  // UI Builder methods
  Widget _buildSearchDialog(BuildContext context, TaskProvider taskProvider) {
    return AlertDialog(
      title: const Text('Search Tasks'),
      content: TextField(
        decoration: const InputDecoration(
          labelText: 'Search tasks...',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: (value) {
          taskProvider.setSearchQuery(value);
        },
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildTaskSettingsDialog(BuildContext context) {
    return AlertDialog(
      title: const Text('Task Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Task Notifications'),
            subtitle: const Text('Enable task reminders'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // Handle notification toggle
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Smart Suggestions'),
            subtitle: const Text('AI-powered task suggestions'),
            trailing: Switch(
              value: false,
              onChanged: (value) {
                // Handle smart suggestions toggle
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
}

// Enhanced TaskDetailScreen with edit functionality
class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.task.title),
            actions: [
              IconButton(
                onPressed: () => _editTask(widget.task, taskProvider),
                icon: const Icon(Icons.edit),
                tooltip: 'Edit Task',
              ),
              IconButton(
                onPressed: () =>
                    _showMoreOptions(context, widget.task, taskProvider),
                icon: const Icon(Icons.more_vert),
                tooltip: 'More Options',
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(widget.task.description.isEmpty
                    ? 'No description'
                    : widget.task.description),
                const SizedBox(height: 24),
                Text(
                  'Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: const Text('Priority'),
                  subtitle: Text(widget.task.priority.name.toUpperCase()),
                  contentPadding: EdgeInsets.zero,
                ),
                ListTile(
                  leading: const Icon(Icons.category),
                  title: const Text('Category'),
                  subtitle: Text(widget.task.category.name),
                  contentPadding: EdgeInsets.zero,
                ),
                if (widget.task.dueDate != null)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: const Text('Due Date'),
                    subtitle: Text(widget.task.timeUntilDue),
                    contentPadding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              // Start focus session for this task
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/main',
                (route) => false,
              );

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      '🎯 Focus session started for "${widget.task.title}"'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.timer),
            label: const Text('Focus'),
          ),
        );
      },
    );
  }

  /// Edit task functionality for TaskDetailScreen
  void _editTask(Task task, TaskProvider taskProvider) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      // Update the task using TaskProvider
      final success = await taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Navigate back to refresh the previous screen
          Navigator.pop(context);
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  /// Show more options menu for TaskDetailScreen
  void _showMoreOptions(
      BuildContext context, Task task, TaskProvider taskProvider) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Task'),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Task'),
                  content:
                      Text('Are you sure you want to delete "${task.title}"?'),
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
                final success = await taskProvider.deleteTask(task.id);
                if (mounted) {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  if (success) {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(
                          content: Text('Task deleted successfully')),
                    );
                    Navigator.pop(context); // Go back to previous screen
                  } else {
                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Failed to delete task')),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Dedicated widget for today's tasks with consolidated filter bar
class _TodayTasksView extends StatefulWidget {
  final TaskProvider taskProvider;

  const _TodayTasksView({required this.taskProvider});

  @override
  State<_TodayTasksView> createState() => _TodayTasksViewState();
}

class _TodayTasksViewState extends State<_TodayTasksView> {
  // Filter state
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  TaskPriority? _selectedPriority;
  TodayTaskFilter _currentFilter = TodayTaskFilter.all;
  String _sortBy = 'created';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayTasks = widget.taskProvider.tasksDueToday;

    // Apply filters
    final filteredTasks = _applyFilters(todayTasks);
    final sortedTasks = _applySorting(filteredTasks);

    // Calculate stats
    final stats = _calculateTodayStats(todayTasks);

    return Column(
      children: [
        // Consolidated filter and stats bar
        _buildTodayFilterBar(theme, stats),

        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await widget.taskProvider.refreshTasks();
            },
            child: sortedTasks.isEmpty
                ? _buildEmptyState(theme)
                : _buildDraggableTaskList(sortedTasks, 'today'),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayFilterBar(ThemeData theme, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        children: [
          // Interactive stats row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter = _currentFilter == TodayTaskFilter.all
                        ? TodayTaskFilter.all
                        : TodayTaskFilter.all;
                  }),
                  child: _buildInteractiveStatChip(
                    'Today',
                    '${stats['total']}',
                    Colors.blue,
                    Icons.today,
                    isActive: _currentFilter == TodayTaskFilter.all,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter = _currentFilter == TodayTaskFilter.overdue
                        ? TodayTaskFilter.all
                        : TodayTaskFilter.overdue;
                  }),
                  child: _buildInteractiveStatChip(
                    'Overdue',
                    '${stats['overdue']}',
                    Colors.red,
                    Icons.warning,
                    isActive: _currentFilter == TodayTaskFilter.overdue,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == TodayTaskFilter.completedToday
                            ? TodayTaskFilter.all
                            : TodayTaskFilter.completedToday;
                  }),
                  child: _buildInteractiveStatChip(
                    'Completed',
                    '${stats['completedToday']}',
                    Colors.green,
                    Icons.check_circle,
                    isActive: _currentFilter == TodayTaskFilter.completedToday,
                  ),
                ),
                const SizedBox(width: 16),
                // Advanced filters button
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list,
                    color:
                        _hasActiveFilters() ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Filters & Sort',
                  onSelected: (value) => _handleFilterAction(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'category',
                      child: Row(
                        children: [
                          Icon(Icons.category, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'priority',
                      child: Row(
                        children: [
                          Icon(Icons.priority_high, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Priority'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Clear Filters',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search and sort controls
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search today\'s tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              const SizedBox(width: 12),

              // Compact sort controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort type
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (sort) => setState(() => _sortBy = sort),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 18),
                            const SizedBox(width: 4),
                            Text(_getSortLabel(_sortBy),
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'created', child: Text('Newest First')),
                        PopupMenuItem(
                            value: 'dueDate', child: Text('Due Date')),
                        PopupMenuItem(
                            value: 'priority', child: Text('Priority')),
                        PopupMenuItem(
                            value: 'alphabetical', child: Text('A-Z')),
                        PopupMenuItem(
                            value: 'progress', child: Text('Progress')),
                        PopupMenuItem(
                            value: 'custom', child: Text('Custom Order')),
                      ],
                    ),
                    // Sort direction
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline,
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      tooltip:
                          _sortAscending ? 'Sort Descending' : 'Sort Ascending',
                      padding: const EdgeInsets.all(8),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods will be implemented in the next chunk
  Map<String, dynamic> _calculateTodayStats(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdueTasks = tasks
        .where((task) =>
            task.dueDate != null &&
            task.dueDate!.isBefore(today) &&
            task.status != TaskStatus.completed)
        .length;

    final completedTodayTasks = tasks
        .where((task) =>
            task.status == TaskStatus.completed &&
            task.completedAt != null &&
            DateTime(task.completedAt!.year, task.completedAt!.month,
                    task.completedAt!.day)
                .isAtSameMomentAs(today))
        .length;

    return {
      'total': tasks.length,
      'overdue': overdueTasks,
      'completedToday': completedTodayTasks,
    };
  }

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks.where((task) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!task.title.toLowerCase().contains(query) &&
            !task.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && task.category != _selectedCategory) {
        return false;
      }

      // Priority filter
      if (_selectedPriority != null && task.priority != _selectedPriority) {
        return false;
      }

      // Today-specific filters
      switch (_currentFilter) {
        case TodayTaskFilter.overdue:
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          return task.dueDate != null &&
              task.dueDate!.isBefore(today) &&
              task.status != TaskStatus.completed;
        case TodayTaskFilter.completedToday:
          if (task.status != TaskStatus.completed || task.completedAt == null) {
            return false;
          }
          final today = DateTime.now();
          final completedDate = DateTime(task.completedAt!.year,
              task.completedAt!.month, task.completedAt!.day);
          final todayDate = DateTime(today.year, today.month, today.day);
          return completedDate.isAtSameMomentAs(todayDate);
        case TodayTaskFilter.all:
        default:
          return true;
      }
    }).toList();

    return filtered;
  }

  List<Task> _applySorting(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'dueDate':
          if (a.dueDate == null && b.dueDate == null)
            comparison = 0;
          else if (a.dueDate == null)
            comparison = 1;
          else if (b.dueDate == null)
            comparison = -1;
          else
            comparison = a.dueDate!.compareTo(b.dueDate!);
          break;
        case 'priority':
          comparison = b.priority.index.compareTo(a.priority.index);
          break;
        case 'alphabetical':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'progress':
          comparison = b.progress.compareTo(a.progress);
          break;
        case 'custom':
          // Sort by custom order (sortOrder field)
          comparison = a.sortOrder.compareTo(b.sortOrder);
          break;
        case 'created':
        default:
          comparison = b.createdAt.compareTo(a.createdAt);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildInteractiveStatChip(
      String label, String value, Color color, IconData icon,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(51) : color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : color.withAlpha(77),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : color.withAlpha(179),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : color.withAlpha(204),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? color.withAlpha(179) : color.withAlpha(128),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
        _selectedPriority != null ||
        _searchQuery.isNotEmpty ||
        _currentFilter != TodayTaskFilter.all;
  }

  void _handleFilterAction(String action) {
    switch (action) {
      case 'category':
        _showCategoryFilterDialog();
        break;
      case 'priority':
        _showPriorityFilterDialog();
        break;
      case 'clear':
        _clearAllFilters();
        break;
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              leading: Radio<TaskCategory?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskCategory.values.map((category) => ListTile(
                  title: Text(category.displayName),
                  leading: Radio<TaskCategory?>(
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(category.icon, color: category.color),
                )),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Priorities'),
              leading: Radio<TaskPriority?>(
                value: null,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskPriority.values.map((priority) => ListTile(
                  title: Text(priority.displayName),
                  leading: Radio<TaskPriority?>(
                    value: priority,
                    groupValue: _selectedPriority,
                    onChanged: (value) {
                      setState(() => _selectedPriority = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(priority.icon, color: priority.color),
                )),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _currentFilter = TodayTaskFilter.all;
      _selectedCategory = null;
      _selectedPriority = null;
      _searchQuery = '';
    });
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'created':
        return 'Newest';
      case 'dueDate':
        return 'Due Date';
      case 'priority':
        return 'Priority';
      case 'alphabetical':
        return 'A-Z';
      case 'progress':
        return 'Progress';
      case 'custom':
        return 'Custom';
      default:
        return 'Sort';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.today,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks for today',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a new task to get started',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableTaskList(List<Task> tasks, String tabType) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) {
        _reorderTasks(tasks, oldIndex, newIndex, tabType);
      },
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildDraggableTaskCard(task, index);
      },
    );
  }

  Widget _buildDraggableTaskCard(Task task, int index) {
    return Container(
      key: ValueKey(task.id),
      child: ReorderableDragStartListener(
        index: index,
        child: _buildTodayTaskCard(task),
      ),
    );
  }

  Widget _buildTodayTaskCard(Task task) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;
    final cardElevation = task.isOverdue || task.needsAttention ? 4.0 : 2.0;

    BorderSide? cardBorder;
    if (task.isOverdue) {
      cardBorder = BorderSide(color: Colors.red, width: 2);
    } else if (task.needsAttention) {
      cardBorder = BorderSide(color: task.urgencyLevel.color, width: 2);
    }

    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'Task: ${task.title}',
      semanticHint: 'Double tap to open task details',
      onTap: null, // Disabled for drag handle
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: cardBorder ?? BorderSide.none,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Drag handle
              Container(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.drag_handle,
                  color: theme.colorScheme.onSurface.withAlpha(128),
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              // Main content (tappable)
              Expanded(
                child: InkWell(
                  onTap: () => _openTaskDetails(task),
                  borderRadius: BorderRadius.circular(8),
                  child: _buildTodayTaskContent(task, theme),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Unified task content for Today tab that matches the main design
  Widget _buildTodayTaskContent(Task task, ThemeData theme) {
    final isCompleted = task.status == TaskStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, priority, and context menu
        Row(
          children: [
            // Urgency/Status indicator
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: task.isOverdue
                    ? Colors.red
                    : task.needsAttention
                        ? task.urgencyLevel.color
                        : task.priority.color,
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
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : isCompleted
                                  ? theme.colorScheme.onSurface.withAlpha(153)
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
                          color: task.priority.color.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: task.priority.color.withAlpha(77),
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

            // Context menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              onSelected: (value) =>
                  _handleTaskAction(value, task, widget.taskProvider),
              itemBuilder: (context) => _getTodayTaskContextMenuActions(task),
            ),
          ],
        ),

        // Description (if available)
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        // Progress indicator (if task has progress and not completed)
        if (task.progress > 0 && !isCompleted) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: theme.colorScheme.outline.withAlpha(51),
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
        ],

        const SizedBox(height: 8),

        // Footer with due date and additional info
        Row(
          children: [
            // Due date with enhanced formatting
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.isOverdue
                      ? Colors.red.withAlpha(26)
                      : task.needsAttention
                          ? task.urgencyLevel.color.withAlpha(26)
                          : theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.isOverdue
                        ? Colors.red.withAlpha(77)
                        : task.needsAttention
                            ? task.urgencyLevel.color.withAlpha(77)
                            : theme.colorScheme.primary.withAlpha(77),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.enhancedTimeUntilDue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: task.isOverdue
                            ? Colors.red
                            : task.needsAttention
                                ? task.urgencyLevel.color
                                : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Focus sessions info (if applicable)
            if (task.estimatedFocusSessions > 0) ...[
              Icon(
                Icons.timer,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${task.completedFocusSessions}/${task.estimatedFocusSessions}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Tags indicator (if applicable)
            if (task.tags.isNotEmpty) ...[
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
              const SizedBox(width: 8),
            ],

            // Creation/Update timestamp
            Text(
              _formatTaskTimestamp(task),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _getTodayTaskContextMenuActions(Task task) {
    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text('Edit Task'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'complete',
        child: Row(
          children: [
            Icon(
              task.status == TaskStatus.completed ? Icons.undo : Icons.check,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(task.status == TaskStatus.completed
                ? 'Mark Incomplete'
                : 'Mark Complete'),
          ],
        ),
      ),
      if (task.status != TaskStatus.completed)
        PopupMenuItem(
          value: 'start',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18),
              const SizedBox(width: 8),
              Text('Start Task'),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'focus',
        child: Row(
          children: [
            Icon(Icons.timer, size: 18),
            const SizedBox(width: 8),
            Text('Focus Session'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            const SizedBox(width: 8),
            Text('Duplicate'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Task', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _openTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _reorderTasks(
      List<Task> tasks, int oldIndex, int newIndex, String tabType) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    // Create a copy of the list to avoid modifying the original
    final reorderedTasks = List<Task>.from(tasks);
    final task = reorderedTasks.removeAt(oldIndex);
    reorderedTasks.insert(newIndex, task);

    try {
      // Switch to custom sort first to prevent interference
      setState(() {
        _sortBy = 'custom';
        _sortAscending = true;
      });

      // Update task order in provider
      final success = await widget.taskProvider.reorderTasks(reorderedTasks);

      if (success) {
        // Force a complete refresh to ensure the new order is reflected
        await widget.taskProvider.refreshTasks();

        if (mounted) {
          // Show success feedback
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Moved "${task.title}" to position ${newIndex + 1}'),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        // Show error feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to move "${task.title}"'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error moving task: $e'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildEnhancedTaskCard({
    required Task task,
    required TaskProvider taskProvider,
    VoidCallback? onTap,
    bool showDragHandle = false,
    List<PopupMenuEntry<String>>? contextMenuActions,
  }) {
    final theme = Theme.of(context);

    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'Task: ${task.title}',
      semanticHint: 'Double tap to open task details',
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: task.isOverdue || task.needsAttention ? 4 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: task.isOverdue
              ? BorderSide(color: Colors.red, width: 2)
              : task.needsAttention
                  ? BorderSide(color: task.urgencyLevel.color, width: 2)
                  : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Optional drag handle
                if (showDragHandle) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.drag_handle,
                      color: theme.colorScheme.onSurface.withAlpha(128),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Main task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title, priority, and context menu
                      Row(
                        children: [
                          // Urgency/Status indicator
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: task.isOverdue
                                  ? Colors.red
                                  : task.needsAttention
                                      ? task.urgencyLevel.color
                                      : task.priority.color,
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
                                    decoration:
                                        task.status == TaskStatus.completed
                                            ? TextDecoration.lineThrough
                                            : null,
                                    color: task.isOverdue
                                        ? Colors.red
                                        : task.needsAttention
                                            ? task.urgencyLevel.color
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
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
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
                                        color:
                                            task.priority.color.withAlpha(26),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              task.priority.color.withAlpha(77),
                                        ),
                                      ),
                                      child: Text(
                                        task.priority.displayName,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
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

                          // Context menu
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: theme.colorScheme.onSurface.withAlpha(153),
                            ),
                            onSelected: (value) =>
                                _handleTaskAction(value, task, taskProvider),
                            itemBuilder: (context) =>
                                contextMenuActions ??
                                _getTaskContextMenuActions(task),
                          ),
                        ],
                      ),

                      // Description (if available)
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          task.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withAlpha(179),
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
                                    theme.colorScheme.outline.withAlpha(51),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    task.priority.color),
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
                          if (task.dueDate != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: task.isOverdue
                                    ? Colors.red.withAlpha(26)
                                    : task.needsAttention
                                        ? task.urgencyLevel.color.withAlpha(26)
                                        : theme.colorScheme.primary
                                            .withAlpha(26),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: task.isOverdue
                                      ? Colors.red.withAlpha(77)
                                      : task.needsAttention
                                          ? task.urgencyLevel.color
                                              .withAlpha(77)
                                          : theme.colorScheme.primary
                                              .withAlpha(77),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.schedule,
                                    size: 14,
                                    color: task.isOverdue
                                        ? Colors.red
                                        : task.needsAttention
                                            ? task.urgencyLevel.color
                                            : theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    task.enhancedTimeUntilDue,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: task.isOverdue
                                          ? Colors.red
                                          : task.needsAttention
                                              ? task.urgencyLevel.color
                                              : theme.colorScheme.primary,
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
                              '${task.completedFocusSessions}/${task.estimatedFocusSessions}',
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

                      // Creation/Update timestamp
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: theme.colorScheme.onSurface.withAlpha(128),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTaskTimestamp(task),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurface.withAlpha(128),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _getTaskContextMenuActions(Task task) {
    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text('Edit Task'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'complete',
        child: Row(
          children: [
            Icon(
              task.status == TaskStatus.completed ? Icons.undo : Icons.check,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(task.status == TaskStatus.completed
                ? 'Mark Incomplete'
                : 'Mark Complete'),
          ],
        ),
      ),
      if (task.status != TaskStatus.inProgress)
        PopupMenuItem(
          value: 'start',
          child: Row(
            children: [
              Icon(Icons.play_arrow, size: 18),
              const SizedBox(width: 8),
              Text('Start Task'),
            ],
          ),
        ),
      PopupMenuItem(
        value: 'focus',
        child: Row(
          children: [
            Icon(Icons.timer, size: 18),
            const SizedBox(width: 8),
            Text('Focus Session'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            const SizedBox(width: 8),
            Text('Duplicate'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Task', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _handleTaskAction(String action, Task task, TaskProvider taskProvider) {
    switch (action) {
      case 'edit':
        _editTask(task);
        break;
      case 'complete':
        taskProvider.toggleTaskCompletion(task.id);
        break;
      case 'start':
        taskProvider.changeTaskStatus(task.id, TaskStatus.inProgress);
        break;
      case 'focus':
        _startFocusSession(task);
        break;
      case 'duplicate':
        _duplicateTask(task);
        break;
      case 'delete':
        _showDeleteConfirmation(task);
        break;
    }
  }

  void _duplicateTask(Task task) async {
    try {
      final taskService = TaskService();
      await taskService.createTask(
        title: '${task.title} (Copy)',
        description: task.description,
        priority: task.priority,
        category: task.category,
        dueDate: task.dueDate,
        estimatedFocusSessions: task.estimatedFocusSessions,
        tags: task.tags,
      );

      // Refresh the task provider to show the new task
      await widget.taskProvider.refreshTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${task.title}" duplicated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate task: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      final success = await widget.taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _showStatusChangeDialog(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Task Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: TaskStatus.values.map((status) {
            return ListTile(
              leading: Icon(
                _getStatusIcon(status),
                color: status.color,
              ),
              title: Text(status.displayName),
              trailing: task.status == status
                  ? Icon(Icons.check, color: status.color)
                  : null,
              onTap: () async {
                Navigator.pop(context);
                if (task.status != status) {
                  final success = await widget.taskProvider
                      .changeTaskStatus(task.id, status);
                  if (success && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Changed "${task.title}" to ${status.displayName}'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.todo:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.play_circle;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }

  void _startFocusSession(Task task) {
    // Navigate to main screen and switch to focus tab
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Focus session started for "${task.title}"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.taskProvider.deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task "${task.title}" deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Format creation/update date in a user-friendly relative format
  String _formatTaskTimestamp(Task task) {
    final now = DateTime.now();

    // Check if task has been updated (updatedAt is different from createdAt)
    final isUpdated = task.updatedAt.isAfter(task.createdAt);
    final timestampToUse = isUpdated ? task.updatedAt : task.createdAt;

    final difference = now.difference(timestampToUse);
    final prefix = isUpdated ? 'Updated' : 'Created';

    if (difference.inMinutes < 1) {
      return '$prefix just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$prefix ${minutes}m ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$prefix ${hours}h ago';
    } else if (difference.inDays == 1) {
      return '$prefix yesterday';
    } else if (difference.inDays < 7) {
      return '$prefix ${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$prefix ${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$prefix ${months}mo ago';
    }
  }
}

// Enum for Today task filters
enum TodayTaskFilter { all, overdue, completedToday }

/// Dedicated widget for enhanced upcoming tasks functionality
class _UpcomingTasksView extends StatefulWidget {
  final TaskProvider taskProvider;

  const _UpcomingTasksView({required this.taskProvider});

  @override
  State<_UpcomingTasksView> createState() => _UpcomingTasksViewState();
}

class _UpcomingTasksViewState extends State<_UpcomingTasksView> {
  // Filter and sort state - these are mutable and change based on user interaction
  // ignore: prefer_final_fields
  UpcomingTaskFilter _currentFilter = UpcomingTaskFilter.all;
  UpcomingTaskSort _currentSort = UpcomingTaskSort.dueDate;
  // ignore: prefer_final_fields
  UpcomingTaskGrouping _currentGrouping = UpcomingTaskGrouping.none;
  bool _sortAscending = true;
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  TaskPriority? _selectedPriority;
  TimeRangeFilter? _timeRangeFilter;
  // ignore: prefer_final_fields
  bool _showOnlyNeedsAttention = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final upcomingTasks = widget.taskProvider.upcomingTasks;

    // Apply filters and sorting
    final filteredTasks = UpcomingTaskService.filterTasks(
      upcomingTasks,
      filter: _currentFilter,
      category: _selectedCategory,
      priority: _selectedPriority,
      timeRange: _timeRangeFilter,
      searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      onlyNeedsAttention: _showOnlyNeedsAttention,
    );

    final sortedTasks = UpcomingTaskService.sortTasks(
      filteredTasks,
      _currentSort,
      ascending: _sortAscending,
    );

    final groupedTasks = UpcomingTaskService.groupTasks(
      sortedTasks,
      _currentGrouping,
    );

    final stats = UpcomingTaskService.getUpcomingTaskStats(upcomingTasks);
    final suggestions = UpcomingTaskService.getSuggestedActions(upcomingTasks);

    return Column(
      children: [
        // Consolidated filter and stats bar
        _buildConsolidatedFilterBar(theme, stats),

        // Suggestions bar (if any)
        if (suggestions.isNotEmpty) _buildSuggestionsBar(theme, suggestions),

        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await widget.taskProvider.refreshTasks();
            },
            child: sortedTasks.isEmpty
                ? _buildEmptyState(theme)
                : _currentGrouping == UpcomingTaskGrouping.none
                    ? _buildTaskList(sortedTasks)
                    : _buildGroupedTaskList(groupedTasks),
          ),
        ),
      ],
    );
  }

  Widget _buildConsolidatedFilterBar(
      ThemeData theme, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        children: [
          // Interactive stats row with filtering capabilities
          Row(
            children: [
              // Clickable stat chips that act as filters
              GestureDetector(
                onTap: () => setState(() {
                  _currentFilter = _currentFilter == UpcomingTaskFilter.all
                      ? UpcomingTaskFilter.all
                      : UpcomingTaskFilter.all;
                }),
                child: _buildInteractiveStatChip(
                  'Total',
                  '${stats['total']}',
                  Colors.blue,
                  Icons.task,
                  isActive: _currentFilter == UpcomingTaskFilter.all,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _currentFilter = _currentFilter == UpcomingTaskFilter.thisWeek
                      ? UpcomingTaskFilter.all
                      : UpcomingTaskFilter.thisWeek;
                }),
                child: _buildInteractiveStatChip(
                  'This Week',
                  '${stats['thisWeek']}',
                  Colors.green,
                  Icons.calendar_today,
                  isActive: _currentFilter == UpcomingTaskFilter.thisWeek,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _currentFilter =
                      _currentFilter == UpcomingTaskFilter.needsAttention
                          ? UpcomingTaskFilter.all
                          : UpcomingTaskFilter.needsAttention;
                }),
                child: _buildInteractiveStatChip(
                  'Attention',
                  '${stats['needsAttention']}',
                  Colors.red,
                  Icons.warning,
                  isActive: _currentFilter == UpcomingTaskFilter.needsAttention,
                ),
              ),
              const Spacer(),
              // Advanced filters button
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.filter_list,
                  color: _hasActiveFilters() ? theme.colorScheme.primary : null,
                ),
                tooltip: 'Filters & Sort',
                onSelected: (value) => _handleFilterAction(value),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'category',
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 18),
                        const SizedBox(width: 8),
                        Text('Filter by Category'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority',
                    child: Row(
                      children: [
                        Icon(Icons.priority_high, size: 18),
                        const SizedBox(width: 8),
                        Text('Filter by Priority'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'timeRange',
                    child: Row(
                      children: [
                        Icon(Icons.date_range, size: 18),
                        const SizedBox(width: 8),
                        Text('Time Range'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.clear_all, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Text('Clear Filters',
                            style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Search and sort controls
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search upcoming tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              const SizedBox(width: 12),

              // Compact sort controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort type
                    PopupMenuButton<UpcomingTaskSort>(
                      initialValue: _currentSort,
                      onSelected: (sort) => setState(() => _currentSort = sort),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 18),
                            const SizedBox(width: 4),
                            Text(_currentSort.label,
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => UpcomingTaskSort.values
                          .map((sort) => PopupMenuItem(
                                value: sort,
                                child: Text(sort.label),
                              ))
                          .toList(),
                    ),
                    // Sort direction
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline,
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      tooltip:
                          _sortAscending ? 'Sort Descending' : 'Sort Ascending',
                      padding: const EdgeInsets.all(8),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveStatChip(
      String label, String value, Color color, IconData icon,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(51) : color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : color.withAlpha(77),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : color.withAlpha(179),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : color.withAlpha(204),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? color.withAlpha(179) : color.withAlpha(128),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleFilterAction(String action) {
    switch (action) {
      case 'category':
        _showCategoryFilterDialog();
        break;
      case 'priority':
        _showPriorityFilterDialog();
        break;
      case 'timeRange':
        _showTimeRangeFilterDialog();
        break;
      case 'clear':
        _clearAllFilters();
        break;
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              leading: Radio<TaskCategory?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskCategory.values.map((category) => ListTile(
                  title: Text(category.displayName),
                  leading: Radio<TaskCategory?>(
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(category.icon, color: category.color),
                )),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Priorities'),
              leading: Radio<TaskPriority?>(
                value: null,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskPriority.values.map((priority) => ListTile(
                  title: Text(priority.displayName),
                  leading: Radio<TaskPriority?>(
                    value: priority,
                    groupValue: _selectedPriority,
                    onChanged: (value) {
                      setState(() => _selectedPriority = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(priority.icon, color: priority.color),
                )),
          ],
        ),
      ),
    );
  }

  void _showTimeRangeFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Time Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Time'),
              leading: Radio<TimeRangeFilter?>(
                value: null,
                groupValue: _timeRangeFilter,
                onChanged: (value) {
                  setState(() => _timeRangeFilter = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Next Week'),
              leading: Radio<TimeRangeFilter?>(
                value: TimeRangeFilter.nextWeek,
                groupValue: _timeRangeFilter,
                onChanged: (value) {
                  setState(() => _timeRangeFilter = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('This Month'),
              leading: Radio<TimeRangeFilter?>(
                value: TimeRangeFilter.thisMonth,
                groupValue: _timeRangeFilter,
                onChanged: (value) {
                  setState(() => _timeRangeFilter = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('Next Month'),
              leading: Radio<TimeRangeFilter?>(
                value: TimeRangeFilter.nextMonth,
                groupValue: _timeRangeFilter,
                onChanged: (value) {
                  setState(() => _timeRangeFilter = value);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _currentFilter = UpcomingTaskFilter.all;
      _selectedCategory = null;
      _selectedPriority = null;
      _timeRangeFilter = null;
      _searchQuery = '';
      _showOnlyNeedsAttention = false;
    });
  }

  Widget _buildSuggestionsBar(ThemeData theme, List<String> suggestions) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Text(
                'Suggestions',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...suggestions.map((suggestion) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $suggestion',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildTaskList(List<Task> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return EnhancedUpcomingTaskCard(
          task: task,
          taskProvider: widget.taskProvider,
          onTap: () => _openTaskDetails(task),
          onStartEarly: () => _startTaskEarly(task),
          onReschedule: () => _rescheduleTask(task),
          onEdit: () => _editTask(task),
        );
      },
    );
  }

  Widget _buildGroupedTaskList(Map<String, List<Task>> groupedTasks) {
    final sortedGroups = groupedTasks.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sortedGroups.length,
      itemBuilder: (context, index) {
        final group = sortedGroups[index];
        return _buildTaskGroup(group.key, group.value);
      },
    );
  }

  Widget _buildTaskGroup(String groupName, List<Task> tasks) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Group header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Text(
                groupName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${tasks.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Group tasks
        ...tasks.map((task) => EnhancedUpcomingTaskCard(
              task: task,
              taskProvider: widget.taskProvider,
              onTap: () => _openTaskDetails(task),
              onStartEarly: () => _startTaskEarly(task),
              onReschedule: () => _rescheduleTask(task),
              onEdit: () => _editTask(task),
            )),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.schedule,
            size: 64,
            color: theme.colorScheme.outline.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No upcoming tasks',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks with future due dates will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline.withAlpha(179),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _currentFilter != UpcomingTaskFilter.all ||
        _selectedCategory != null ||
        _selectedPriority != null ||
        _timeRangeFilter != null ||
        _showOnlyNeedsAttention ||
        _searchQuery.isNotEmpty;
  }

  void _openTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _startTaskEarly(Task task) async {
    final success = await widget.taskProvider.startTask(task.id);
    if (success && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Started "${task.title}" early!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Focus',
            textColor: Colors.white,
            onPressed: () {
              // Navigate to main screen and switch to focus tab
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/main',
                (route) => false,
              );

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🎯 Focus session started for "${task.title}"'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      );
    } else if (mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to start "${task.title}"'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _rescheduleTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      final success = await widget.taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" rescheduled successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to reschedule task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _editTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      // Update the task using TaskProvider
      final success = await widget.taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

/// Dedicated widget for in-progress tasks with consolidated filter bar
class _InProgressTasksView extends StatefulWidget {
  final TaskProvider taskProvider;

  const _InProgressTasksView({required this.taskProvider});

  @override
  State<_InProgressTasksView> createState() => _InProgressTasksViewState();
}

class _InProgressTasksViewState extends State<_InProgressTasksView> {
  // Filter state
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  TaskPriority? _selectedPriority;
  InProgressTaskFilter _currentFilter = InProgressTaskFilter.all;
  String _sortBy = 'updated';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inProgressTasks = widget.taskProvider.inProgressTasks;

    // Apply filters
    final filteredTasks = _applyFilters(inProgressTasks);
    final sortedTasks = _applySorting(filteredTasks);

    // Calculate stats
    final stats = _calculateInProgressStats(inProgressTasks);

    return Column(
      children: [
        // Consolidated filter and stats bar
        _buildInProgressFilterBar(theme, stats),

        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await widget.taskProvider.refreshTasks();
            },
            child: sortedTasks.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInProgressFilterBar(
      ThemeData theme, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        children: [
          // Interactive stats row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter = _currentFilter == InProgressTaskFilter.all
                        ? InProgressTaskFilter.all
                        : InProgressTaskFilter.all;
                  }),
                  child: _buildInteractiveStatChip(
                    'Active',
                    '${stats['total']}',
                    Colors.blue,
                    Icons.play_circle,
                    isActive: _currentFilter == InProgressTaskFilter.all,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == InProgressTaskFilter.highPriority
                            ? InProgressTaskFilter.all
                            : InProgressTaskFilter.highPriority;
                  }),
                  child: _buildInteractiveStatChip(
                    'Priority',
                    '${stats['highPriority']}',
                    Colors.red,
                    Icons.priority_high,
                    isActive:
                        _currentFilter == InProgressTaskFilter.highPriority,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == InProgressTaskFilter.nearDeadline
                            ? InProgressTaskFilter.all
                            : InProgressTaskFilter.nearDeadline;
                  }),
                  child: _buildInteractiveStatChip(
                    'Deadline',
                    '${stats['nearDeadline']}',
                    Colors.orange,
                    Icons.warning,
                    isActive:
                        _currentFilter == InProgressTaskFilter.nearDeadline,
                  ),
                ),
                const SizedBox(width: 16),
                // Advanced filters button
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list,
                    color:
                        _hasActiveFilters() ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Filters & Sort',
                  onSelected: (value) => _handleFilterAction(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'category',
                      child: Row(
                        children: [
                          Icon(Icons.category, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'priority',
                      child: Row(
                        children: [
                          Icon(Icons.priority_high, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Priority'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Clear Filters',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search and sort controls
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search active tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              const SizedBox(width: 12),

              // Compact sort controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort type
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (sort) => setState(() => _sortBy = sort),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 18),
                            const SizedBox(width: 4),
                            Text(_getSortLabel(_sortBy),
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'updated', child: Text('Recently Updated')),
                        PopupMenuItem(
                            value: 'created', child: Text('Newest First')),
                        PopupMenuItem(
                            value: 'dueDate', child: Text('Due Date')),
                        PopupMenuItem(
                            value: 'priority', child: Text('Priority')),
                        PopupMenuItem(
                            value: 'progress', child: Text('Progress')),
                      ],
                    ),
                    // Sort direction
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline,
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      tooltip:
                          _sortAscending ? 'Sort Descending' : 'Sort Ascending',
                      padding: const EdgeInsets.all(8),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods will be implemented in the next chunk
  Map<String, dynamic> _calculateInProgressStats(List<Task> tasks) {
    final highPriorityTasks = tasks
        .where((task) =>
            task.priority == TaskPriority.high ||
            task.priority == TaskPriority.urgent)
        .length;

    final now = DateTime.now();
    final nearDeadlineTasks = tasks
        .where((task) =>
            task.dueDate != null &&
            task.dueDate!.difference(now).inDays <= 3 &&
            task.dueDate!.isAfter(now))
        .length;

    return {
      'total': tasks.length,
      'highPriority': highPriorityTasks,
      'nearDeadline': nearDeadlineTasks,
    };
  }

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks.where((task) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!task.title.toLowerCase().contains(query) &&
            !task.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && task.category != _selectedCategory) {
        return false;
      }

      // Priority filter
      if (_selectedPriority != null && task.priority != _selectedPriority) {
        return false;
      }

      // In Progress-specific filters
      switch (_currentFilter) {
        case InProgressTaskFilter.highPriority:
          return task.priority == TaskPriority.high ||
              task.priority == TaskPriority.urgent;
        case InProgressTaskFilter.nearDeadline:
          if (task.dueDate == null) return false;
          final now = DateTime.now();
          return task.dueDate!.difference(now).inDays <= 3 &&
              task.dueDate!.isAfter(now);
        case InProgressTaskFilter.all:
          return true;
      }
    }).toList();

    return filtered;
  }

  List<Task> _applySorting(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'dueDate':
          if (a.dueDate == null && b.dueDate == null) {
            comparison = 0;
          } else if (a.dueDate == null) {
            comparison = 1;
          } else if (b.dueDate == null) {
            comparison = -1;
          } else {
            comparison = a.dueDate!.compareTo(b.dueDate!);
          }
          break;
        case 'priority':
          comparison = b.priority.index.compareTo(a.priority.index);
          break;
        case 'created':
          comparison = b.createdAt.compareTo(a.createdAt);
          break;
        case 'progress':
          comparison = b.progress.compareTo(a.progress);
          break;
        case 'custom':
          // Sort by custom order (sortOrder field)
          comparison = a.sortOrder.compareTo(b.sortOrder);
          break;
        case 'updated':
        default:
          comparison = b.updatedAt.compareTo(a.updatedAt);
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildInteractiveStatChip(
      String label, String value, Color color, IconData icon,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(51) : color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : color.withAlpha(77),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : color.withAlpha(179),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : color.withAlpha(204),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? color.withAlpha(179) : color.withAlpha(128),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
        _selectedPriority != null ||
        _searchQuery.isNotEmpty ||
        _currentFilter != InProgressTaskFilter.all;
  }

  void _handleFilterAction(String action) {
    switch (action) {
      case 'category':
        _showCategoryFilterDialog();
        break;
      case 'priority':
        _showPriorityFilterDialog();
        break;
      case 'clear':
        _clearAllFilters();
        break;
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              leading: Radio<TaskCategory?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskCategory.values.map((category) => ListTile(
                  title: Text(category.displayName),
                  leading: Radio<TaskCategory?>(
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(category.icon, color: category.color),
                )),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Priorities'),
              leading: Radio<TaskPriority?>(
                value: null,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskPriority.values.map((priority) => ListTile(
                  title: Text(priority.displayName),
                  leading: Radio<TaskPriority?>(
                    value: priority,
                    groupValue: _selectedPriority,
                    onChanged: (value) {
                      setState(() => _selectedPriority = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(priority.icon, color: priority.color),
                )),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _currentFilter = InProgressTaskFilter.all;
      _selectedCategory = null;
      _selectedPriority = null;
      _searchQuery = '';
    });
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'updated':
        return 'Recent';
      case 'created':
        return 'Newest';
      case 'dueDate':
        return 'Due Date';
      case 'priority':
        return 'Priority';
      case 'progress':
        return 'Progress';
      default:
        return 'Sort';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No active tasks',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start working on a task to see it here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return _buildInProgressTaskCard(task);
  }

  Widget _buildInProgressTaskCard(Task task) {
    final theme = Theme.of(context);
    final isCompleted = task.status == TaskStatus.completed;
    final cardElevation = task.isOverdue || task.needsAttention ? 4.0 : 2.0;

    BorderSide? cardBorder;
    if (task.isOverdue) {
      cardBorder = BorderSide(color: Colors.red, width: 2);
    } else if (task.needsAttention) {
      cardBorder = BorderSide(color: task.urgencyLevel.color, width: 2);
    }

    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'In Progress Task: ${task.title}',
      semanticHint: 'Double tap to open task details',
      onTap: () => _openTaskDetails(task),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: cardBorder ?? BorderSide.none,
        ),
        child: InkWell(
          onTap: () => _openTaskDetails(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildInProgressTaskContent(task, theme),
          ),
        ),
      ),
    );
  }

  /// Unified task content for In Progress tab that matches the main design
  Widget _buildInProgressTaskContent(Task task, ThemeData theme) {
    final isCompleted = task.status == TaskStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, priority, and context menu
        Row(
          children: [
            // Urgency/Status indicator
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: task.isOverdue
                    ? Colors.red
                    : task.needsAttention
                        ? task.urgencyLevel.color
                        : task.priority.color,
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
                      decoration:
                          isCompleted ? TextDecoration.lineThrough : null,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : isCompleted
                                  ? theme.colorScheme.onSurface.withAlpha(153)
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
                          color: task.priority.color.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: task.priority.color.withAlpha(77),
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

            // Context menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              onSelected: (value) =>
                  _handleTaskAction(value, task, widget.taskProvider),
              itemBuilder: (context) =>
                  _getInProgressTaskContextMenuActions(task),
            ),
          ],
        ),

        // Description (if available)
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(179),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        // Progress indicator (if task has progress and not completed)
        if (task.progress > 0 && !isCompleted) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: theme.colorScheme.outline.withAlpha(51),
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
        ],

        const SizedBox(height: 8),

        // Footer with due date and additional info
        Row(
          children: [
            // Due date with enhanced formatting
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.isOverdue
                      ? Colors.red.withAlpha(26)
                      : task.needsAttention
                          ? task.urgencyLevel.color.withAlpha(26)
                          : theme.colorScheme.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: task.isOverdue
                        ? Colors.red.withAlpha(77)
                        : task.needsAttention
                            ? task.urgencyLevel.color.withAlpha(77)
                            : theme.colorScheme.primary.withAlpha(77),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: task.isOverdue
                          ? Colors.red
                          : task.needsAttention
                              ? task.urgencyLevel.color
                              : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.enhancedTimeUntilDue,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: task.isOverdue
                            ? Colors.red
                            : task.needsAttention
                                ? task.urgencyLevel.color
                                : theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),

            // Focus sessions info (if applicable)
            if (task.estimatedFocusSessions > 0) ...[
              Icon(
                Icons.timer,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                '${task.completedFocusSessions}/${task.estimatedFocusSessions}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Tags indicator (if applicable)
            if (task.tags.isNotEmpty) ...[
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
              const SizedBox(width: 8),
            ],

            // Creation/Update timestamp
            Text(
              _formatTaskTimestamp(task),
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withAlpha(128),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _getInProgressTaskContextMenuActions(Task task) {
    return [
      PopupMenuItem(
        value: 'edit',
        child: Row(
          children: [
            Icon(Icons.edit, size: 18),
            const SizedBox(width: 8),
            Text('Edit Task'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'complete',
        child: Row(
          children: [
            Icon(Icons.check, size: 18),
            const SizedBox(width: 8),
            Text('Mark Complete'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'pause',
        child: Row(
          children: [
            Icon(Icons.pause, size: 18),
            const SizedBox(width: 8),
            Text('Pause Task'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'focus',
        child: Row(
          children: [
            Icon(Icons.timer, size: 18),
            const SizedBox(width: 8),
            Text('Focus Session'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            const SizedBox(width: 8),
            Text('Duplicate'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Task', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _openTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _handleTaskAction(String action, Task task, TaskProvider taskProvider) {
    switch (action) {
      case 'edit':
        _editTask(task);
        break;
      case 'complete':
        taskProvider.toggleTaskCompletion(task.id);
        break;
      case 'pause':
        _pauseTask(task);
        break;
      case 'focus':
        _startFocusSession(task);
        break;
      case 'duplicate':
        _duplicateTask(task);
        break;
      case 'delete':
        _showDeleteConfirmation(task);
        break;
    }
  }

  void _duplicateTask(Task task) async {
    try {
      final taskService = TaskService();
      await taskService.createTask(
        title: '${task.title} (Copy)',
        description: task.description,
        priority: task.priority,
        category: task.category,
        dueDate: task.dueDate,
        estimatedFocusSessions: task.estimatedFocusSessions,
        tags: task.tags,
      );

      // Refresh the task provider to show the new task
      await widget.taskProvider.refreshTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${task.title}" duplicated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate task: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _editTask(Task task) async {
    final result = await showDialog<Task>(
      context: context,
      builder: (context) => CreateTaskDialog(editingTask: task),
    );

    if (result != null && mounted) {
      final success = await widget.taskProvider.updateTask(result);
      if (mounted) {
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        if (success != null) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Task "${result.title}" updated successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Failed to update task "${task.title}"'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _pauseTask(Task task) async {
    final success =
        await widget.taskProvider.changeTaskStatus(task.id, TaskStatus.todo);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "${task.title}" paused'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _startFocusSession(Task task) {
    // Navigate to main screen and switch to focus tab
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/main',
      (route) => false,
    );

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎯 Focus session started for "${task.title}"'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.taskProvider.deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task "${task.title}" deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Format creation/update date in a user-friendly relative format
  String _formatTaskTimestamp(Task task) {
    final now = DateTime.now();

    // Check if task has been updated (updatedAt is different from createdAt)
    final isUpdated = task.updatedAt.isAfter(task.createdAt);
    final timestampToUse = isUpdated ? task.updatedAt : task.createdAt;

    final difference = now.difference(timestampToUse);
    final prefix = isUpdated ? 'Updated' : 'Created';

    if (difference.inMinutes < 1) {
      return '$prefix just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$prefix ${minutes}m ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$prefix ${hours}h ago';
    } else if (difference.inDays == 1) {
      return '$prefix yesterday';
    } else if (difference.inDays < 7) {
      return '$prefix ${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$prefix ${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$prefix ${months}mo ago';
    }
  }
}

// Enum for In Progress task filters
enum InProgressTaskFilter { all, highPriority, nearDeadline }

// Enum for Completed task filters
enum CompletedTaskFilter { all, completedToday, thisWeek, thisMonth }

/// Dedicated widget for completed tasks with consolidated filter bar
class _CompletedTasksView extends StatefulWidget {
  final TaskProvider taskProvider;

  const _CompletedTasksView({required this.taskProvider});

  @override
  State<_CompletedTasksView> createState() => _CompletedTasksViewState();
}

class _CompletedTasksViewState extends State<_CompletedTasksView> {
  // Filter state
  String _searchQuery = '';
  TaskCategory? _selectedCategory;
  TaskPriority? _selectedPriority;
  CompletedTaskFilter _currentFilter = CompletedTaskFilter.all;
  String _sortBy = 'updated';
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedTasks = widget.taskProvider.completedTasks;

    // Apply filters
    final filteredTasks = _applyFilters(completedTasks);
    final sortedTasks = _applySorting(filteredTasks);

    // Calculate stats
    final stats = _calculateCompletedStats(completedTasks);

    return Column(
      children: [
        // Consolidated filter and stats bar
        _buildCompletedFilterBar(theme, stats),

        // Main content
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await widget.taskProvider.refreshTasks();
            },
            child: sortedTasks.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedFilterBar(ThemeData theme, Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
        ),
      ),
      child: Column(
        children: [
          // Interactive stats row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == CompletedTaskFilter.completedToday
                            ? CompletedTaskFilter.all
                            : CompletedTaskFilter.completedToday;
                  }),
                  child: _buildInteractiveStatChip(
                    'Today',
                    '${stats['completedToday']}',
                    Colors.green,
                    Icons.check_circle,
                    isActive:
                        _currentFilter == CompletedTaskFilter.completedToday,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == CompletedTaskFilter.thisWeek
                            ? CompletedTaskFilter.all
                            : CompletedTaskFilter.thisWeek;
                  }),
                  child: _buildInteractiveStatChip(
                    'Week',
                    '${stats['thisWeek']}',
                    Colors.blue,
                    Icons.calendar_today,
                    isActive: _currentFilter == CompletedTaskFilter.thisWeek,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    _currentFilter =
                        _currentFilter == CompletedTaskFilter.thisMonth
                            ? CompletedTaskFilter.all
                            : CompletedTaskFilter.thisMonth;
                  }),
                  child: _buildInteractiveStatChip(
                    'Month',
                    '${stats['thisMonth']}',
                    Colors.purple,
                    Icons.calendar_month,
                    isActive: _currentFilter == CompletedTaskFilter.thisMonth,
                  ),
                ),
                const SizedBox(width: 16),
                // Advanced filters button
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list,
                    color:
                        _hasActiveFilters() ? theme.colorScheme.primary : null,
                  ),
                  tooltip: 'Filters & Sort',
                  onSelected: (value) => _handleFilterAction(value),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'category',
                      child: Row(
                        children: [
                          Icon(Icons.category, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Category'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'priority',
                      child: Row(
                        children: [
                          Icon(Icons.priority_high, size: 18),
                          const SizedBox(width: 8),
                          Text('Filter by Priority'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'clear',
                      child: Row(
                        children: [
                          Icon(Icons.clear_all, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text('Clear Filters',
                              style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Search and sort controls
          Row(
            children: [
              // Search field
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search completed tasks...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _searchQuery = ''),
                          )
                        : null,
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),

              const SizedBox(width: 12),

              // Compact sort controls
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sort type
                    PopupMenuButton<String>(
                      initialValue: _sortBy,
                      onSelected: (sort) => setState(() => _sortBy = sort),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sort, size: 18),
                            const SizedBox(width: 4),
                            Text(_getSortLabel(_sortBy),
                                style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                            value: 'updated',
                            child: Text('Recently Completed')),
                        PopupMenuItem(
                            value: 'created', child: Text('Newest First')),
                        PopupMenuItem(
                            value: 'priority', child: Text('Priority')),
                        PopupMenuItem(
                            value: 'alphabetical', child: Text('A-Z')),
                      ],
                    ),
                    // Sort direction
                    Container(
                      width: 1,
                      height: 24,
                      color: theme.colorScheme.outline,
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _sortAscending = !_sortAscending),
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 18,
                      ),
                      tooltip:
                          _sortAscending ? 'Sort Descending' : 'Sort Ascending',
                      padding: const EdgeInsets.all(8),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods will be implemented in the next chunk
  Map<String, dynamic> _calculateCompletedStats(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final completedTodayTasks = tasks
        .where((task) =>
            task.completedAt != null &&
            DateTime(task.completedAt!.year, task.completedAt!.month,
                    task.completedAt!.day)
                .isAtSameMomentAs(today))
        .length;

    final completedThisWeekTasks = tasks
        .where((task) =>
            task.completedAt != null &&
            task.completedAt!
                .isAfter(weekStart.subtract(const Duration(days: 1))))
        .length;

    final completedThisMonthTasks = tasks
        .where((task) =>
            task.completedAt != null &&
            task.completedAt!
                .isAfter(monthStart.subtract(const Duration(days: 1))))
        .length;

    return {
      'total': tasks.length,
      'completedToday': completedTodayTasks,
      'thisWeek': completedThisWeekTasks,
      'thisMonth': completedThisMonthTasks,
    };
  }

  List<Task> _applyFilters(List<Task> tasks) {
    var filtered = tasks.where((task) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!task.title.toLowerCase().contains(query) &&
            !task.description.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Category filter
      if (_selectedCategory != null && task.category != _selectedCategory) {
        return false;
      }

      // Priority filter
      if (_selectedPriority != null && task.priority != _selectedPriority) {
        return false;
      }

      // Completed-specific filters
      switch (_currentFilter) {
        case CompletedTaskFilter.completedToday:
          if (task.completedAt == null) return false;
          final today = DateTime.now();
          final completedDate = DateTime(task.completedAt!.year,
              task.completedAt!.month, task.completedAt!.day);
          final todayDate = DateTime(today.year, today.month, today.day);
          return completedDate.isAtSameMomentAs(todayDate);
        case CompletedTaskFilter.thisWeek:
          if (task.completedAt == null) return false;
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          return task.completedAt!
              .isAfter(weekStart.subtract(const Duration(days: 1)));
        case CompletedTaskFilter.thisMonth:
          if (task.completedAt == null) return false;
          final now = DateTime.now();
          final monthStart = DateTime(now.year, now.month, 1);
          return task.completedAt!
              .isAfter(monthStart.subtract(const Duration(days: 1)));
        case CompletedTaskFilter.all:
          return true;
      }
    }).toList();

    return filtered;
  }

  List<Task> _applySorting(List<Task> tasks) {
    final sorted = List<Task>.from(tasks);

    sorted.sort((a, b) {
      int comparison = 0;

      switch (_sortBy) {
        case 'priority':
          comparison = b.priority.index.compareTo(a.priority.index);
          break;
        case 'alphabetical':
          comparison = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 'created':
          comparison = b.createdAt.compareTo(a.createdAt);
          break;
        case 'custom':
          // Sort by custom order (sortOrder field)
          comparison = a.sortOrder.compareTo(b.sortOrder);
          break;
        case 'updated':
        default:
          // For completed tasks, sort by completion date if available
          if (a.completedAt != null && b.completedAt != null) {
            comparison = b.completedAt!.compareTo(a.completedAt!);
          } else {
            comparison = b.updatedAt.compareTo(a.updatedAt);
          }
          break;
      }

      return _sortAscending ? comparison : -comparison;
    });

    return sorted;
  }

  Widget _buildInteractiveStatChip(
      String label, String value, Color color, IconData icon,
      {bool isActive = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? color.withAlpha(51) : color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? color : color.withAlpha(77),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isActive ? color : color.withAlpha(179),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isActive ? color : color.withAlpha(204),
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? color.withAlpha(179) : color.withAlpha(128),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedCategory != null ||
        _selectedPriority != null ||
        _searchQuery.isNotEmpty ||
        _currentFilter != CompletedTaskFilter.all;
  }

  void _handleFilterAction(String action) {
    switch (action) {
      case 'category':
        _showCategoryFilterDialog();
        break;
      case 'priority':
        _showPriorityFilterDialog();
        break;
      case 'clear':
        _clearAllFilters();
        break;
    }
  }

  void _showCategoryFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Categories'),
              leading: Radio<TaskCategory?>(
                value: null,
                groupValue: _selectedCategory,
                onChanged: (value) {
                  setState(() => _selectedCategory = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskCategory.values.map((category) => ListTile(
                  title: Text(category.displayName),
                  leading: Radio<TaskCategory?>(
                    value: category,
                    groupValue: _selectedCategory,
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(category.icon, color: category.color),
                )),
          ],
        ),
      ),
    );
  }

  void _showPriorityFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Priority'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Priorities'),
              leading: Radio<TaskPriority?>(
                value: null,
                groupValue: _selectedPriority,
                onChanged: (value) {
                  setState(() => _selectedPriority = value);
                  Navigator.pop(context);
                },
              ),
            ),
            ...TaskPriority.values.map((priority) => ListTile(
                  title: Text(priority.displayName),
                  leading: Radio<TaskPriority?>(
                    value: priority,
                    groupValue: _selectedPriority,
                    onChanged: (value) {
                      setState(() => _selectedPriority = value);
                      Navigator.pop(context);
                    },
                  ),
                  trailing: Icon(priority.icon, color: priority.color),
                )),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    setState(() {
      _currentFilter = CompletedTaskFilter.all;
      _selectedCategory = null;
      _selectedPriority = null;
      _searchQuery = '';
    });
  }

  String _getSortLabel(String sortBy) {
    switch (sortBy) {
      case 'updated':
        return 'Recent';
      case 'created':
        return 'Newest';
      case 'priority':
        return 'Priority';
      case 'alphabetical':
        return 'A-Z';
      default:
        return 'Sort';
    }
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 64,
            color: theme.colorScheme.onSurface.withAlpha(128),
          ),
          const SizedBox(height: 16),
          Text(
            'No completed tasks',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete some tasks to see them here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(102),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Task task) {
    return _buildCompletedTaskCard(task);
  }

  Widget _buildCompletedTaskCard(Task task) {
    final theme = Theme.of(context);
    final cardElevation = 2.0;

    BorderSide cardBorder =
        BorderSide(color: Colors.green.withAlpha(77), width: 1);

    return AccessibilityHelper.accessibleCard(
      semanticLabel: 'Completed Task: ${task.title}',
      semanticHint: 'Double tap to open task details',
      onTap: () => _openTaskDetails(task),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: cardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: cardBorder,
        ),
        child: InkWell(
          onTap: () => _openTaskDetails(task),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildCompletedTaskContent(task, theme),
          ),
        ),
      ),
    );
  }

  /// Unified task content for Completed tab that matches the main design
  Widget _buildCompletedTaskContent(Task task, ThemeData theme) {
    final isCompleted = task.status == TaskStatus.completed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with title, priority, and context menu
        Row(
          children: [
            // Completion indicator (green for completed tasks)
            Container(
              width: 4,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.green,
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
                      decoration: TextDecoration.lineThrough,
                      color: theme.colorScheme.onSurface.withAlpha(153),
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
                          color: Colors.green.withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withAlpha(77),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 12,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Completed',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Context menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withAlpha(153),
              ),
              onSelected: (value) =>
                  _handleTaskAction(value, task, widget.taskProvider),
              itemBuilder: (context) =>
                  _getCompletedTaskContextMenuActions(task),
            ),
          ],
        ),

        // Description (if available)
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withAlpha(128),
              decoration: TextDecoration.lineThrough,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],

        const SizedBox(height: 8),

        // Footer with completion date and additional info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // First row: Completion date
            if (task.completedAt != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withAlpha(77),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Completed ${_formatCompletionTime(task.completedAt!)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 8),

            // Second row: Additional info and timestamp
            Row(
              children: [
                // Focus sessions info (if applicable)
                if (task.estimatedFocusSessions > 0) ...[
                  Icon(
                    Icons.timer,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${task.completedFocusSessions}/${task.estimatedFocusSessions}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],

                // Tags indicator (if applicable)
                if (task.tags.isNotEmpty) ...[
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
                  const SizedBox(width: 12),
                ],

                // Creation/Update timestamp (flexible to prevent overflow)
                Expanded(
                  child: Text(
                    _formatTaskTimestamp(task),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withAlpha(128),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _getCompletedTaskContextMenuActions(Task task) {
    return [
      PopupMenuItem(
        value: 'view',
        child: Row(
          children: [
            Icon(Icons.visibility, size: 18),
            const SizedBox(width: 8),
            Text('View Details'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'reopen',
        child: Row(
          children: [
            Icon(Icons.undo, size: 18),
            const SizedBox(width: 8),
            Text('Mark Incomplete'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'duplicate',
        child: Row(
          children: [
            Icon(Icons.copy, size: 18),
            const SizedBox(width: 8),
            Text('Duplicate Task'),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete, size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Text('Delete Task', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _openTaskDetails(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  void _handleTaskAction(String action, Task task, TaskProvider taskProvider) {
    switch (action) {
      case 'view':
        _openTaskDetails(task);
        break;
      case 'reopen':
        taskProvider.toggleTaskCompletion(task.id);
        break;
      case 'duplicate':
        _duplicateTask(task);
        break;
      case 'delete':
        _showDeleteConfirmation(task);
        break;
    }
  }

  void _duplicateTask(Task task) async {
    try {
      final taskService = TaskService();
      await taskService.createTask(
        title: '${task.title} (Copy)',
        description: task.description,
        priority: task.priority,
        category: task.category,
        dueDate: task.dueDate,
        tags: task.tags,
        estimatedFocusSessions: task.estimatedFocusSessions,
      );

      if (mounted) {
        // Refresh the task provider to show the new task
        await widget.taskProvider.refreshTasks();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "${task.title}" duplicated successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to duplicate task: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.taskProvider.deleteTask(task.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Task "${task.title}" deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  /// Format creation date in a user-friendly relative format
  String _formatTaskTimestamp(Task task) {
    final now = DateTime.now();
    final difference = now.difference(task.createdAt);

    if (difference.inMinutes < 1) {
      return 'Created just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return 'Created ${minutes}m ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return 'Created ${hours}h ago';
    } else if (difference.inDays == 1) {
      return 'Created yesterday';
    } else if (difference.inDays < 7) {
      return 'Created ${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Created ${weeks}w ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return 'Created ${months}mo ago';
    }
  }

  String _formatCompletionTime(DateTime completedAt) {
    final now = DateTime.now();
    final difference = now.difference(completedAt);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes minute${minutes != 1 ? 's' : ''} ago';
    } else if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours hour${hours != 1 ? 's' : ''} ago';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks != 1 ? 's' : ''} ago';
    } else {
      final months = (difference.inDays / 30).floor();
      return '$months month${months != 1 ? 's' : ''} ago';
    }
  }
}
