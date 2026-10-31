import 'dart:async';

import 'package:flutter/foundation.dart';

import 'task_service.dart';
import 'task_template_service.dart';

/// Initializes task-related services used by [TaskProvider].
class TaskProviderBootstrap {
  TaskProviderBootstrap({
    TaskService? taskService,
    TaskTemplateService? templateService,
  })  : _taskService = taskService ?? TaskService(),
        _templateService = templateService ?? TaskTemplateService();

  final TaskService _taskService;
  final TaskTemplateService _templateService;

  TaskService get taskService => _taskService;
  TaskTemplateService get templateService => _templateService;

  Future<void> initializeServices() async {
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
}
