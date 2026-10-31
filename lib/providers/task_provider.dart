import 'dart:async';
import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../models/task_template.dart';
import '../services/task_service.dart';
import '../services/task_template_service.dart';

/// Task Provider for state management with robust initialization and real-time updates
class TaskProvider extends ChangeNotifier {
  final TaskService _taskService = TaskService();
  final TaskTemplateService _templateService = TaskTemplateService();

  List<Task> _tasks = [];
  List<TaskTemplate> _templates = [];
  Map<String, dynamic> _taskStats = {};
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  // Filters and sorting
  String _sortBy = 'dueDate';
  String _filterBy = 'all';
  String _searchQuery = '';

  // Separate priority and category filters
  TaskPriority? _priorityFilter;
  TaskCategory? _categoryFilter;

  // Stream subscriptions
  StreamSubscription<List<Task>>? _tasksSubscription;
  StreamSubscription<List<TaskTemplate>>? _templatesSubscription;

  // Initialization retry mechanism
  int _initRetryCount = 0;
  static const int _maxRetryAttempts = 3;
  Timer? _retryTimer;

  // Getters
  List<Task> get tasks => _tasks;
  List<TaskTemplate> get templates => _templates;
  List<TaskTemplate> get builtInTemplates =>
      _templates.where((t) => t.isBuiltIn).toList();
  List<TaskTemplate> get customTemplates =>
      _templates.where((t) => !t.isBuiltIn).toList();
  Map<String, dynamic> get taskStats => _taskStats;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String get sortBy => _sortBy;
  String get filterBy => _filterBy;
  String get searchQuery => _searchQuery;
  TaskPriority? get priorityFilter => _priorityFilter;
  TaskCategory? get categoryFilter => _categoryFilter;

  // Filtered and sorted tasks
  List<Task> get filteredTasks => _getFilteredAndSortedTasks();

  // Task categories with debugging
  List<Task> get tasksDueToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final result = _tasks.where((task) {
      // Exclude completed and cancelled tasks
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      // Include tasks due today
      if (task.dueDate != null) {
        final taskDate = DateTime(
            task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
        if (taskDate.isAtSameMomentAs(today)) {
          return true;
        }
      }

      // Include tasks without due date (default to today) that are todo or inProgress
      if (task.dueDate == null &&
          (task.status == TaskStatus.todo ||
              task.status == TaskStatus.inProgress)) {
        return true;
      }

      return false;
    }).toList();

    debugPrint(
        'TaskProvider: tasksDueToday called - found ${result.length} incomplete tasks');
    debugPrint('TaskProvider: Current date: $today');

    for (final task in result.take(5)) {
      debugPrint(
          'TaskProvider: Today task: "${task.title}" - Status: ${task.status} - Due: ${task.dueDate} - isDueToday: ${task.isDueToday}');
    }

    // Also log tasks that might be filtered out for debugging
    final allIncompleteTasks = _tasks
        .where((task) =>
            task.status != TaskStatus.completed &&
            task.status != TaskStatus.cancelled)
        .toList();
    debugPrint(
        'TaskProvider: Total incomplete tasks: ${allIncompleteTasks.length}');

    for (final task in allIncompleteTasks.take(3)) {
      final taskDate = task.dueDate != null
          ? DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day)
          : null;
      debugPrint(
          'TaskProvider: All incomplete task: "${task.title}" - Status: ${task.status} - Due: ${task.dueDate} - TaskDate: $taskDate - Today: $today');
    }

    return result;
  }

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    final result = _tasks.where((task) {
      // Exclude completed and cancelled tasks
      if (task.status == TaskStatus.completed ||
          task.status == TaskStatus.cancelled) {
        return false;
      }

      // Must have a due date to be "upcoming"
      if (task.dueDate == null) {
        return false;
      }

      // Must be in the future (not today, not overdue)
      final isInFuture = task.dueDate!.isAfter(now);
      final isNotToday = !task.isDueToday;

      return isInFuture && isNotToday;
    }).toList();

    debugPrint(
        'TaskProvider: upcomingTasks called - found ${result.length} incomplete tasks');

    // Enhanced debug logging
    for (final task in result.take(3)) {
      final daysUntilDue = task.dueDate!.difference(now).inDays;
      debugPrint(
          'TaskProvider: Upcoming task: "${task.title}" - ${task.status} - Due in $daysUntilDue days (${task.dueDate})');
    }

    // Log filtering statistics
    final totalWithDueDate = _tasks.where((t) => t.dueDate != null).length;
    final completedWithDueDate = _tasks
        .where((t) => t.dueDate != null && t.status == TaskStatus.completed)
        .length;
    final overdueCount = _tasks
        .where((t) => t.isOverdue && t.status != TaskStatus.completed)
        .length;

    debugPrint(
        'TaskProvider: Upcoming filter stats - Total with due date: $totalWithDueDate, Completed: $completedWithDueDate, Overdue: $overdueCount');

    return result;
  }

  List<Task> get inProgressTasks {
    final result =
        _tasks.where((task) => task.status == TaskStatus.inProgress).toList();

    debugPrint(
        'TaskProvider: inProgressTasks called - found ${result.length} tasks');

    // Enhanced debug logging with progress and timing information
    for (final task in result.take(3)) {
      final progressPercent = (task.progress * 100).toStringAsFixed(1);
      final dueInfo = task.dueDate != null
          ? (task.isOverdue
              ? 'OVERDUE'
              : task.isDueToday
                  ? 'DUE TODAY'
                  : 'Due ${task.timeUntilDue}')
          : 'No due date';

      debugPrint(
          'TaskProvider: InProgress task: "${task.title}" - ${task.status} - Progress: $progressPercent% - $dueInfo');
    }

    // Log in-progress task statistics
    if (result.isNotEmpty) {
      final averageProgress =
          result.fold<double>(0, (sum, task) => sum + task.progress) /
              result.length;
      final overdueInProgress = result.where((t) => t.isOverdue).length;
      final dueTodayInProgress = result.where((t) => t.isDueToday).length;

      debugPrint(
          'TaskProvider: InProgress stats - Average progress: ${(averageProgress * 100).toStringAsFixed(1)}%, Overdue: $overdueInProgress, Due today: $dueTodayInProgress');
    }

    return result;
  }

  List<Task> get completedTasks {
    final result =
        _tasks.where((task) => task.status == TaskStatus.completed).toList();
    debugPrint(
        'TaskProvider: completedTasks called - found ${result.length} tasks');
    for (final task in result.take(3)) {
      debugPrint(
          'TaskProvider: Completed task: "${task.title}" - ${task.status}');
    }
    return result;
  }

  /// Initialize the provider with robust error handling and retry mechanism
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('TaskProvider: Already initialized, skipping...');
      return;
    }

    _setLoading(true);
    _clearError();

    try {
      debugPrint(
          'TaskProvider: Starting initialization (attempt ${_initRetryCount + 1})...');

      // Initialize services with timeout
      await _initializeServices();

      // Load data with verification
      await _loadAllData();

      // Set up real-time subscriptions
      await _setupSubscriptions();

      // Mark as successfully initialized
      _isInitialized = true;
      _initRetryCount = 0;
      _retryTimer?.cancel();

      debugPrint('TaskProvider: Initialization completed successfully');
      debugPrint(
          'TaskProvider: Loaded ${_tasks.length} tasks and ${_templates.length} templates');
    } catch (e) {
      debugPrint('TaskProvider: Initialization failed: $e');
      await _handleInitializationFailure(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Initialize all required services with timeout
  Future<void> _initializeServices() async {
    debugPrint('TaskProvider: Initializing TaskService...');
    await _taskService.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('TaskService initialization timeout'),
        );

    debugPrint('TaskProvider: Initializing TemplateService...');
    await _templateService.initialize().timeout(
          const Duration(seconds: 5),
          onTimeout: () =>
              throw TimeoutException('TemplateService initialization timeout'),
        );
  }

  /// Load all data with verification
  Future<void> _loadAllData() async {
    debugPrint('TaskProvider: Loading tasks...');
    await _loadTasks();

    debugPrint('TaskProvider: Loading templates...');
    await _loadTemplates();

    debugPrint('TaskProvider: Loading task statistics...');
    await _loadTaskStats();

    // Verify data was loaded correctly
    if (_tasks.isEmpty && _templates.isEmpty) {
      debugPrint(
          'TaskProvider: Warning - No tasks or templates loaded, this might be expected for new users');
    }
  }

  /// Set up real-time subscriptions with error handling
  Future<void> _setupSubscriptions() async {
    debugPrint('TaskProvider: Setting up real-time subscriptions...');

    try {
      _subscribeToTaskUpdates();
      _subscribeToTemplateUpdates();
    } catch (e) {
      debugPrint('TaskProvider: Warning - Failed to set up subscriptions: $e');
      // Don't fail initialization if subscriptions fail, but log the error
    }
  }

  /// Handle initialization failure with retry mechanism
  Future<void> _handleInitializationFailure(dynamic error) async {
    _initRetryCount++;

    if (_initRetryCount < _maxRetryAttempts) {
      debugPrint(
          'TaskProvider: Retrying initialization in 2 seconds (attempt ${_initRetryCount + 1}/$_maxRetryAttempts)...');

      _retryTimer = Timer(const Duration(seconds: 2), () {
        initialize();
      });
    } else {
      debugPrint(
          'TaskProvider: Max retry attempts reached, initialization failed permanently');
      _setError(
          'Failed to initialize tasks after $_maxRetryAttempts attempts: ${error.toString()}');
    }
  }

  /// Load tasks from service with verification
  Future<void> _loadTasks() async {
    try {
      final loadedTasks = _taskService.tasks;
      _tasks = List.from(
          loadedTasks); // Create a copy to ensure proper state management

      debugPrint('TaskProvider: Successfully loaded ${_tasks.length} tasks');

      // Verify task data integrity
      for (final task in _tasks) {
        if (task.id.isEmpty || task.title.isEmpty) {
          debugPrint(
              'TaskProvider: Warning - Found task with invalid data: ${task.id}');
        }
      }

      _clearError();
    } catch (e) {
      debugPrint('TaskProvider: Failed to load tasks: $e');
      _setError('Failed to load tasks: ${e.toString()}');
      _tasks = []; // Ensure we have a valid empty list
    }
  }

  /// Load templates from service with verification
  Future<void> _loadTemplates() async {
    try {
      final loadedTemplates = _templateService.templates;
      _templates = List.from(
          loadedTemplates); // Create a copy to ensure proper state management

      debugPrint(
          'TaskProvider: Successfully loaded ${_templates.length} templates');
      _clearError();
    } catch (e) {
      debugPrint('TaskProvider: Failed to load templates: $e');
      _setError('Failed to load templates: ${e.toString()}');
      _templates = []; // Ensure we have a valid empty list
    }
  }

  /// Load task statistics with error handling
  Future<void> _loadTaskStats() async {
    try {
      _taskStats = await _taskService.getTaskStatistics();
      debugPrint('TaskProvider: Successfully loaded task statistics');
      _clearError();
    } catch (e) {
      debugPrint('TaskProvider: Failed to load task statistics: $e');
      _setError('Failed to load task statistics: ${e.toString()}');
      _taskStats = {}; // Ensure we have a valid empty map
    }
  }

  /// Subscribe to task updates with robust error handling
  void _subscribeToTaskUpdates() {
    _tasksSubscription?.cancel(); // Cancel any existing subscription

    _tasksSubscription = _taskService.tasksStream.listen(
      (tasks) async {
        try {
          debugPrint(
              'TaskProvider: Received task update - ${tasks.length} tasks');

          // Update tasks with proper state management
          _tasks = List.from(tasks);

          // Refresh statistics
          await _loadTaskStats();

          // Notify UI of changes
          notifyListeners();

          debugPrint('TaskProvider: Task update processed successfully');
        } catch (e) {
          debugPrint('TaskProvider: Error processing task update: $e');
          _setError('Failed to process task update: ${e.toString()}');
        }
      },
      onError: (error) {
        debugPrint('TaskProvider: Task stream error: $error');
        _setError('Task stream error: ${error.toString()}');
      },
      onDone: () {
        debugPrint(
            'TaskProvider: Task stream closed, attempting to reconnect...');
        // Attempt to reconnect after a delay
        Timer(const Duration(seconds: 2), () {
          if (!_isInitialized) return;
          try {
            _subscribeToTaskUpdates();
          } catch (e) {
            debugPrint('TaskProvider: Failed to reconnect task stream: $e');
          }
        });
      },
    );
  }

  /// Subscribe to template updates with robust error handling
  void _subscribeToTemplateUpdates() {
    _templatesSubscription?.cancel(); // Cancel any existing subscription

    _templatesSubscription = _templateService.templatesStream.listen(
      (templates) {
        try {
          debugPrint(
              'TaskProvider: Received template update - ${templates.length} templates');

          // Update templates with proper state management
          _templates = List.from(templates);

          // Notify UI of changes
          notifyListeners();

          debugPrint('TaskProvider: Template update processed successfully');
        } catch (e) {
          debugPrint('TaskProvider: Error processing template update: $e');
          _setError('Failed to process template update: ${e.toString()}');
        }
      },
      onError: (error) {
        debugPrint('TaskProvider: Template stream error: $error');
        _setError('Template stream error: ${error.toString()}');
      },
      onDone: () {
        debugPrint(
            'TaskProvider: Template stream closed, attempting to reconnect...');
        // Attempt to reconnect after a delay
        Timer(const Duration(seconds: 2), () {
          if (!_isInitialized) return;
          try {
            _subscribeToTemplateUpdates();
          } catch (e) {
            debugPrint('TaskProvider: Failed to reconnect template stream: $e');
          }
        });
      },
    );
  }

  /// Create a new task with robust error handling and immediate UI updates
  Future<Task?> createTask({
    required String title,
    String description = '',
    TaskCategory category = TaskCategory.personal,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    List<String> tags = const [],
    int estimatedFocusSessions = 1,
  }) async {
    if (!_isInitialized) {
      debugPrint('TaskProvider: Cannot create task - provider not initialized');
      _setError(
          'Task provider not initialized. Please wait for initialization to complete.');
      return null;
    }

    try {
      _setLoading(true);
      debugPrint('TaskProvider: Creating task with title: "$title"');

      final task = await _taskService.createTask(
        title: title,
        description: description,
        category: category,
        priority: priority,
        dueDate: dueDate,
        tags: tags,
        estimatedFocusSessions: estimatedFocusSessions,
      );

      debugPrint('TaskProvider: Task created successfully with ID: ${task.id}');

      // Force immediate refresh to ensure UI updates
      await _forceRefreshTasks();

      _clearError();

      debugPrint(
          'TaskProvider: Task creation completed, total tasks: ${_tasks.length}');
      return task;
    } catch (e) {
      debugPrint('TaskProvider: Failed to create task: $e');
      _setError('Failed to create task: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Create task from template
  Future<Task?> createTaskFromTemplate(
    String templateId, {
    DateTime? dueDate,
    String? customTitle,
    String? customDescription,
  }) async {
    try {
      final template = _templateService.getTemplate(templateId);
      if (template == null) {
        throw Exception('Template not found');
      }

      final task = template.createTask(
        dueDate: dueDate,
        customTitle: customTitle,
        customDescription: customDescription,
      );

      return await createTask(
        title: task.title,
        description: task.description,
        category: task.category,
        priority: task.priority,
        dueDate: task.dueDate,
        tags: task.tags,
        estimatedFocusSessions: task.estimatedFocusSessions,
      );
    } catch (e) {
      _setError('Failed to create task from template: ${e.toString()}');
      return null;
    }
  }

  /// Update an existing task
  Future<Task?> updateTask(Task updatedTask) async {
    try {
      _setLoading(true);

      final task = await _taskService.updateTask(updatedTask);

      // Force immediate refresh with double notification for real-time updates
      await _forceRefreshTasks();
      _clearError();
      return task;
    } catch (e) {
      _setError('Failed to update task: ${e.toString()}');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Delete a task
  Future<bool> deleteTask(String taskId) async {
    try {
      debugPrint('TaskProvider: Deleting task: $taskId');

      final taskToDelete = _tasks.firstWhere((t) => t.id == taskId,
          orElse: () => throw Exception('Task not found'));
      debugPrint(
          'TaskProvider: Deleting task "${taskToDelete.title}" with status: ${taskToDelete.status}');

      final beforeCounts = {
        'today': tasksDueToday.length,
        'upcoming': upcomingTasks.length,
        'inProgress': inProgressTasks.length,
        'completed': completedTasks.length,
      };

      _setLoading(true);

      await _taskService.deleteTask(taskId);

      // Force immediate refresh with double notification for real-time updates
      await _forceRefreshTasks();

      final afterCounts = {
        'today': tasksDueToday.length,
        'upcoming': upcomingTasks.length,
        'inProgress': inProgressTasks.length,
        'completed': completedTasks.length,
      };

      debugPrint('TaskProvider: Task deleted successfully');
      debugPrint('TaskProvider: Badge counts before: $beforeCounts');
      debugPrint('TaskProvider: Badge counts after: $afterCounts');

      _clearError();
      return true;
    } catch (e) {
      debugPrint('TaskProvider: Error deleting task: $e');
      _setError('Failed to delete task: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Complete a task
  Future<bool> completeTask(String taskId) async {
    final task = _tasks.firstWhere((t) => t.id == taskId);
    final now = DateTime.now();
    final updatedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: now,
      progress: 1.0,
      updatedAt: now, // Update timestamp for proper sorting
    );

    final result = await updateTask(updatedTask);
    return result != null;
  }

  /// Toggle task completion
  Future<bool> toggleTaskCompletion(String taskId) async {
    try {
      debugPrint('TaskProvider: Toggling completion for task: $taskId');

      final task = _tasks.firstWhere((t) => t.id == taskId);
      final isCompleted = task.status == TaskStatus.completed;

      debugPrint(
          'TaskProvider: Task "${task.title}" current status: ${task.status}');
      debugPrint(
          'TaskProvider: Will change to: ${isCompleted ? 'todo' : 'completed'}');

      final beforeCounts = {
        'today': tasksDueToday.length,
        'upcoming': upcomingTasks.length,
        'inProgress': inProgressTasks.length,
        'completed': completedTasks.length,
      };

      final now = DateTime.now();
      final updatedTask = task.copyWith(
        status: isCompleted ? TaskStatus.todo : TaskStatus.completed,
        completedAt: isCompleted ? null : now,
        progress: isCompleted ? 0.0 : 1.0,
        updatedAt: now, // Update timestamp for proper sorting
      );

      final result = await updateTask(updatedTask);

      if (result != null) {
        final afterCounts = {
          'today': tasksDueToday.length,
          'upcoming': upcomingTasks.length,
          'inProgress': inProgressTasks.length,
          'completed': completedTasks.length,
        };

        debugPrint('TaskProvider: Task status updated successfully');
        debugPrint('TaskProvider: Badge counts before: $beforeCounts');
        debugPrint('TaskProvider: Badge counts after: $afterCounts');
      } else {
        debugPrint('TaskProvider: Failed to update task status');
      }

      return result != null;
    } catch (e) {
      debugPrint('TaskProvider: Error toggling task completion: $e');
      return false;
    }
  }

  /// Change task status to In Progress
  Future<bool> startTask(String taskId) async {
    try {
      debugPrint('TaskProvider: Starting task: $taskId');

      final task = _tasks.firstWhere((t) => t.id == taskId);
      debugPrint(
          'TaskProvider: Task "${task.title}" current status: ${task.status}');
      debugPrint('TaskProvider: Will change to: inProgress');

      final beforeCounts = {
        'today': tasksDueToday.length,
        'upcoming': upcomingTasks.length,
        'inProgress': inProgressTasks.length,
        'completed': completedTasks.length,
      };

      final updatedTask = task.copyWith(
        status: TaskStatus.inProgress,
        progress: task.progress > 0
            ? task.progress
            : 0.1, // Minimal progress to indicate started
        updatedAt: DateTime.now(), // Update timestamp for proper sorting
      );

      final result = await updateTask(updatedTask);

      if (result != null) {
        final afterCounts = {
          'today': tasksDueToday.length,
          'upcoming': upcomingTasks.length,
          'inProgress': inProgressTasks.length,
          'completed': completedTasks.length,
        };

        debugPrint(
            'TaskProvider: Task status updated to inProgress successfully');
        debugPrint('TaskProvider: Badge counts before: $beforeCounts');
        debugPrint('TaskProvider: Badge counts after: $afterCounts');
      } else {
        debugPrint('TaskProvider: Failed to update task status to inProgress');
      }

      return result != null;
    } catch (e) {
      debugPrint('TaskProvider: Error starting task: $e');
      return false;
    }
  }

  /// Change task status (comprehensive status transitions)
  Future<bool> changeTaskStatus(String taskId, TaskStatus newStatus) async {
    try {
      debugPrint('TaskProvider: Changing task status: $taskId to $newStatus');

      final task = _tasks.firstWhere((t) => t.id == taskId);
      debugPrint(
          'TaskProvider: Task "${task.title}" current status: ${task.status}');
      debugPrint('TaskProvider: Will change to: $newStatus');

      final beforeCounts = {
        'today': tasksDueToday.length,
        'upcoming': upcomingTasks.length,
        'inProgress': inProgressTasks.length,
        'completed': completedTasks.length,
      };

      Task updatedTask;
      final now = DateTime.now();
      switch (newStatus) {
        case TaskStatus.todo:
          updatedTask = task.copyWith(
            status: TaskStatus.todo,
            completedAt: null,
            progress: 0.0,
            updatedAt: now, // Update timestamp for proper sorting
          );
          break;
        case TaskStatus.inProgress:
          updatedTask = task.copyWith(
            status: TaskStatus.inProgress,
            completedAt: null,
            progress: task.progress > 0 ? task.progress : 0.1,
            updatedAt: now, // Update timestamp for proper sorting
          );
          break;
        case TaskStatus.completed:
          updatedTask = task.copyWith(
            status: TaskStatus.completed,
            completedAt: now,
            progress: 1.0,
            updatedAt: now, // Update timestamp for proper sorting
          );
          break;
        case TaskStatus.cancelled:
          updatedTask = task.copyWith(
            status: TaskStatus.cancelled,
            completedAt: null,
            updatedAt: now, // Update timestamp for proper sorting
          );
          break;
      }

      final result = await updateTask(updatedTask);

      if (result != null) {
        final afterCounts = {
          'today': tasksDueToday.length,
          'upcoming': upcomingTasks.length,
          'inProgress': inProgressTasks.length,
          'completed': completedTasks.length,
        };

        debugPrint(
            'TaskProvider: Task status updated to $newStatus successfully');
        debugPrint('TaskProvider: Badge counts before: $beforeCounts');
        debugPrint('TaskProvider: Badge counts after: $afterCounts');
      } else {
        debugPrint('TaskProvider: Failed to update task status to $newStatus');
      }

      return result != null;
    } catch (e) {
      debugPrint('TaskProvider: Error changing task status: $e');
      return false;
    }
  }

  /// Set sorting criteria
  void setSortBy(String sortBy) {
    _sortBy = sortBy;
    notifyListeners();
  }

  /// Set filter criteria
  void setFilterBy(String filterBy) {
    _filterBy = filterBy;
    notifyListeners();
  }

  /// Set search query
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Set priority filter
  void setPriorityFilter(TaskPriority? priority) {
    _priorityFilter = priority;
    notifyListeners();
  }

  /// Set category filter
  void setCategoryFilter(TaskCategory? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  /// Reorder tasks and persist the new order
  Future<bool> reorderTasks(List<Task> reorderedTasks) async {
    try {
      _setLoading(true);
      debugPrint('TaskProvider: Reordering ${reorderedTasks.length} tasks');

      await _taskService.reorderTasks(reorderedTasks);

      // Force immediate refresh with double notification for real-time updates
      await _forceRefreshTasks();
      _clearError();

      debugPrint('TaskProvider: Task reordering completed successfully');
      return true;
    } catch (e) {
      debugPrint('TaskProvider: Error reordering tasks: $e');
      _setError('Failed to reorder tasks: ${e.toString()}');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Clear all filters
  void clearFilters() {
    _priorityFilter = null;
    _categoryFilter = null;
    _filterBy = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  /// Get filtered and sorted tasks
  List<Task> _getFilteredAndSortedTasks() {
    List<Task> filtered = _tasks;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((task) =>
              task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              task.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              task.tags.any((tag) =>
                  tag.toLowerCase().contains(_searchQuery.toLowerCase())))
          .toList();
    }

    // Apply separate priority filter
    if (_priorityFilter != null) {
      filtered =
          filtered.where((task) => task.priority == _priorityFilter).toList();
    }

    // Apply separate category filter
    if (_categoryFilter != null) {
      filtered =
          filtered.where((task) => task.category == _categoryFilter).toList();
    }

    // Apply legacy combined filter for backward compatibility
    if (_filterBy != 'all') {
      filtered = filtered.where((task) {
        switch (_filterBy) {
          case 'work':
            return task.category == TaskCategory.work;
          case 'personal':
            return task.category == TaskCategory.personal;
          case 'high':
            return task.priority == TaskPriority.high;
          case 'urgent':
            return task.priority == TaskPriority.urgent;
          default:
            return true;
        }
      }).toList();
    }

    // Apply sorting
    return _taskService.sortTasks(filtered, _sortBy);
  }

  /// Refresh tasks from both sources
  Future<void> refreshTasks() async {
    await _refreshTasks();
  }

  /// Standard refresh method
  Future<void> _refreshTasks() async {
    try {
      await _loadTasks();
      await _loadTaskStats();
      notifyListeners();
    } catch (e) {
      debugPrint('TaskProvider: Error during refresh: $e');
      _setError('Failed to refresh tasks: ${e.toString()}');
    }
  }

  /// Force refresh with immediate UI update - used after critical operations
  Future<void> _forceRefreshTasks() async {
    try {
      debugPrint('TaskProvider: Force refreshing tasks...');

      // Load fresh data from service
      await _loadTasks();
      await _loadTaskStats();

      // Force immediate UI notification
      notifyListeners();

      // Small delay to ensure UI has time to process
      await Future.delayed(const Duration(milliseconds: 100));

      // Second notification to ensure all listeners are updated
      notifyListeners();

      debugPrint('TaskProvider: Force refresh completed');
    } catch (e) {
      debugPrint('TaskProvider: Error during force refresh: $e');
      _setError('Failed to force refresh tasks: ${e.toString()}');
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Set error state
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// Clear error state
  void _clearError() {
    _error = null;
    notifyListeners();
  }

  /// Create a new template
  Future<TaskTemplate?> createTemplate({
    required String name,
    required String description,
    required TaskPriority priority,
    required TaskCategory category,
    required List<String> tags,
    required int estimatedFocusSessions,
    Duration? estimatedDuration,
    required IconData icon,
    required Color color,
  }) async {
    try {
      final template = await _templateService.createTemplate(
        name: name,
        description: description,
        priority: priority,
        category: category,
        tags: tags,
        estimatedFocusSessions: estimatedFocusSessions,
        estimatedDuration: estimatedDuration,
        icon: icon,
        color: color,
      );
      return template;
    } catch (e) {
      _setError('Failed to create template: ${e.toString()}');
      return null;
    }
  }

  /// Update a template
  Future<TaskTemplate?> updateTemplate(TaskTemplate template) async {
    try {
      final updatedTemplate = await _templateService.updateTemplate(template);
      return updatedTemplate;
    } catch (e) {
      _setError('Failed to update template: ${e.toString()}');
      return null;
    }
  }

  /// Delete a template
  Future<bool> deleteTemplate(String templateId) async {
    try {
      await _templateService.deleteTemplate(templateId);
      return true;
    } catch (e) {
      _setError('Failed to delete template: ${e.toString()}');
      return false;
    }
  }

  /// Search templates
  List<TaskTemplate> searchTemplates(String query) {
    return _templateService.searchTemplates(query);
  }

  /// Get templates by category
  List<TaskTemplate> getTemplatesByCategory(TaskCategory category) {
    return _templateService.getTemplatesByCategory(category);
  }

  @override
  void dispose() {
    debugPrint('TaskProvider: Disposing resources...');

    // Cancel timers
    _retryTimer?.cancel();

    // Cancel stream subscriptions
    _tasksSubscription?.cancel();
    _templatesSubscription?.cancel();

    // Reset state
    _isInitialized = false;
    _initRetryCount = 0;

    super.dispose();
  }

  /// Force re-initialization (useful for debugging or recovery)
  Future<void> forceReinitialize() async {
    debugPrint('TaskProvider: Force re-initialization requested...');

    // Reset initialization state
    _isInitialized = false;
    _initRetryCount = 0;

    // Cancel existing subscriptions
    _tasksSubscription?.cancel();
    _templatesSubscription?.cancel();

    // Re-initialize
    await initialize();
  }
}
