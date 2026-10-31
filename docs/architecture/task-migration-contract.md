# Task Migration Contract

Last reviewed: 2026-10-24

## Purpose

FocusBro currently has two task representations:

- `lib/models/task.dart` is the legacy database and notification model.
- `lib/models/task_model.dart` is the canonical application model used by `TaskService` and the task UI.

The migration boundary is the compatibility layer between those representations. It must be stable before the legacy model is removed.

## Canonical storage

The canonical task payload is stored in the SQLite `tasks.task_json` column. Its version is independent from the SQLite database version:

- JSON key: `schemaVersion`
- Current value: `1`
- SQLite database version: managed separately by `DatabaseHelper`

`Task.toJson()` emits `schemaVersion: 1`. Unknown fields are retained by the migration normalizer so future fields are not discarded when an older app rewrites a task.

## Active SQLite migration

SQLite schema version 7 adds nullable `tasks.task_json` to existing databases. The version 6-to-7 migration is additive; it retains the legacy task columns and `subtasks` rows. `TaskService` normalizes both legacy SQLite rows and SharedPreferences entries through `TaskMigrationContract`, copies them to canonical JSON, reads the stored payloads back, and compares them before removing a valid SharedPreferences source. Invalid preference entries remain available, and their issues are exposed through `TaskService.migrationIssues`.

Startup `MigrationService` uses the same contract for canonical JSON and legacy pipe entries, preserves existing SQLite tasks during the merge, and leaves the preference source intact. It sets migration completion only after canonical repository verification succeeds. `cleanupOldData()` removes the task preference key only after that verification and only when the source has no malformed entries; normal startup leaves cleanup disabled so `TaskService` performs the active cutover.

Agenda mutations go through `CanonicalTaskRepository` in `lib/repositories/task_repository.dart`. It writes canonical JSON, compatibility columns, subtasks, and any upsert/delete outbox rows in one SQLite transaction. Initial migration copies do not enqueue work or assign an account; user mutations remain account-unbound until reconciliation. Task progress is not recalculated from focus sessions or subtasks.

If the app must roll back after a successful migration, call `TaskService.restoreLegacyPreferencesForRollback()` before restoring the previous app. It regenerates the legacy `tasks` preference list from the verified canonical SQLite payloads, carries forward malformed legacy entries that were retained for recovery, and leaves SQLite data intact. If migration verification fails, the original preference source is retained and SQLite's existing columns are not dropped.

## Accepted inputs

The contract accepts these inputs at the migration boundary:

1. Canonical JSON objects from `Task.toJson()`.
2. Versionless canonical JSON objects from intermediate app releases.
3. Legacy SharedPreferences pipe arrays.
4. Legacy SQLite or backup maps without `task_json`, through the SQLite normalizer.

Legacy pipe arrays require at least these fields in order: `id`, `title`, `description`, `category`, `priority`, `dueDate`, `isCompleted`, and `createdAt`. Subtasks, notification settings, and favorite state are optional extensions.

## Normalization rules

- `id` is required. An entry without a non-empty ID is rejected and reported.
- Missing titles become `Untitled Task`.
- Missing descriptions become an empty string.
- Invalid or missing dates use the migration reference time; `updatedAt` falls back to `createdAt`.
- Priority accepts enum names, display names, numeric strings, and numeric indexes. Unknown values become `medium`.
- Category accepts canonical names and indexes. Unknown legacy categories become `other`.
- Status accepts `todo`, `inProgress`, `completed`, and `cancelled`, including underscore and space variants. Legacy completion flags map to `completed` or `todo`.
- A completed task without `completedAt` receives its `updatedAt`.
- Subtasks are normalized to `id`, `title`, `isCompleted`, `createdAt`, `completedAt`, and `updatedAt`.
- Legacy notification settings and favorite state remain in canonical extension fields and SQLite bridge columns until the canonical model owns them.
- A future `schemaVersion` is rejected instead of silently downgraded.

## Conflict and error policy

- Entries are deduplicated by task ID.
- The entry with the newest `updatedAt` wins. Equal timestamps use the later entry.
- Duplicate IDs produce a warning in `TaskMigrationBatch.issues`.
- Malformed entries produce an error in `TaskMigrationBatch.issues` and do not stop valid entries from migrating.
- The original SharedPreferences payload is not deleted by the migration contract. Cleanup remains a separate, explicitly verifiable operation.

## Ownership and deprecation sequence

1. Keep `task.dart` read-only at the migration boundary and keep `task_model.dart` canonical for runtime task state.
2. Route all legacy preference and SQLite normalization through `TaskMigrationContract`.
3. Move remaining consumers of `task.dart` to the canonical model, preserving notification and favorite extensions until their replacement fields exist.
4. Add a compatibility test for every remaining legacy consumer, then remove `task.dart` and its repositories.

The legacy model must not be deleted while any import, backup path, or notification path still depends on its field names.

## Verification

The contract is covered by:

- `test/task_migration_contract_test.dart`
- `test/migration_service_test.dart`
- `test/task_sqlite_migration_test.dart`
- `test/task_crud_persistence_test.dart`

Run these focused suites serially:

```text
flutter test test/task_migration_contract_test.dart
flutter test test/migration_service_test.dart
flutter test test/task_sqlite_migration_test.dart
flutter test test/task_crud_persistence_test.dart
```
