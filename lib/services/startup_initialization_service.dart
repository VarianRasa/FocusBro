import 'dart:async';

import 'package:flutter/foundation.dart';

import '../providers/focus_provider.dart';
import '../providers/goal_provider.dart';
import '../providers/note_provider.dart';
import '../providers/task_provider.dart';
import '../screens/language_selection_screen.dart';
import '../services/app_lock_service.dart';
import '../services/cloud_sync_service.dart';

class StartupInitializationService {
  const StartupInitializationService();

  Future<void> runSteps(List<StartupInitializationStep> steps) async {
    for (final step in steps) {
      await _runStep(step);
    }
  }

  Future<void> _runStep(StartupInitializationStep step) async {
    final startedAt = DateTime.now();
    debugPrint('Main: Initializing ${step.name}...');
    try {
      await step.action().timeout(step.timeout);
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint('Main: ${step.name} initialized successfully in ${elapsed}ms');
    } catch (error) {
      final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
      debugPrint(
        'Main: ${step.name} initialization failed after ${elapsed}ms: $error',
      );
      if (step.isCritical) {
        rethrow;
      }
    }
  }
}

class StartupInitializationStep {
  final String name;
  final Duration timeout;
  final bool isCritical;
  final Future<void> Function() action;

  const StartupInitializationStep({
    required this.name,
    required this.timeout,
    required this.action,
    this.isCritical = true,
  });
}

/// Startup steps for FocusBro providers, in execution order.
List<StartupInitializationStep> focusBroProviderStartupSteps({
  required LanguageProvider languageProvider,
  required FocusProvider focusProvider,
  required TaskProvider taskProvider,
  required NoteProvider noteProvider,
  required GoalProvider goalProvider,
  required AppLockService appLockService,
}) {
  return [
    StartupInitializationStep(
      name: 'CloudSyncService',
      timeout: const Duration(seconds: 10),
      action: () => CloudSyncService().initialize(),
      isCritical: false,
    ),
    StartupInitializationStep(
      name: 'LanguageProvider',
      timeout: const Duration(seconds: 10),
      action: () => languageProvider.initialize(),
    ),
    StartupInitializationStep(
      name: 'FocusProvider',
      timeout: const Duration(seconds: 15),
      action: () => focusProvider.initialize(),
    ),
    StartupInitializationStep(
      name: 'TaskProvider',
      timeout: const Duration(seconds: 15),
      action: () => taskProvider.initialize(),
    ),
    StartupInitializationStep(
      name: 'NoteProvider',
      timeout: const Duration(seconds: 12),
      action: () => noteProvider.initialize(),
      isCritical: false,
    ),
    StartupInitializationStep(
      name: 'GoalProvider',
      timeout: const Duration(seconds: 12),
      action: () => goalProvider.initialize(),
      isCritical: false,
    ),
    StartupInitializationStep(
      name: 'AppLockService',
      timeout: const Duration(seconds: 8),
      action: () => appLockService.initialize(),
      isCritical: false,
    ),
  ];
}

/// Initializes app providers in a deterministic order with per-step timeouts.
Future<void> runFocusBroProviderStartup({
  required LanguageProvider languageProvider,
  required FocusProvider focusProvider,
  required TaskProvider taskProvider,
  required NoteProvider noteProvider,
  required GoalProvider goalProvider,
  required AppLockService appLockService,
  StartupInitializationService startupInitializationService =
      const StartupInitializationService(),
}) {
  return startupInitializationService.runSteps(
    focusBroProviderStartupSteps(
      languageProvider: languageProvider,
      focusProvider: focusProvider,
      taskProvider: taskProvider,
      noteProvider: noteProvider,
      goalProvider: goalProvider,
      appLockService: appLockService,
    ),
  );
}
