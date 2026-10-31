# Task Data Flow

FocusBro currently has two task model paths:

- `lib/models/task_model.dart` with `lib/services/task_service.dart` and `lib/providers/task_provider.dart`
- `lib/models/task.dart` with `lib/repositories/task_repository.dart` and `lib/services/migration_service.dart`

The active task UI uses `task_model.dart`, `TaskService`, `TaskTemplateService`, and `TaskProvider`. That path stores tasks and templates in `SharedPreferences` as JSON lists.

The SQLite `TaskRepository` path is still used by migration code and older repository abstractions. New task UI features should use the active `TaskProvider`/`TaskService` path unless a migration task explicitly moves task storage to SQLite.

Before changing task persistence, create a separate migration plan that maps every `task_model.dart` field to the SQLite schema and defines how existing `SharedPreferences` data will be moved without data loss.
