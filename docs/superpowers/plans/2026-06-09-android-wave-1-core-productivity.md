# Android Wave 1 Core Productivity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete and verify the local Android Tasks, Agenda, Focus lifecycle, local reminders, and Goals flows with persistence evidence.

**Architecture:** Keep the existing Provider/service/repository boundaries. Repair domain and persistence behavior before adding Android UI automation, then use the existing `integration_test` harness and emulator helper for evidence. External Firebase/OAuth behavior remains deferred.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, Provider, SharedPreferences, SQLite/sqflite, flutter_local_notifications, integration_test, Android API 33.

---

### Task 1: Repair Task Identity And Reopen Semantics

**Files:**
- Modify: `test/task_provider_initialization_test.dart`
- Create: `test/task_model_nullable_copy_test.dart`
- Modify: `lib/services/task_service.dart`
- Modify: `lib/models/task_model.dart`

- [x] Add a failing concurrent-create assertion that all returned task IDs are unique.
- [x] Add failing model tests proving completed tasks and subtasks can clear `completedAt`.
- [x] Replace timestamp-only task/subtask IDs with collision-resistant local IDs.
- [x] Add explicit nullable-field copy semantics and use them when reopening tasks/subtasks.
- [x] Run `flutter test test/task_provider_initialization_test.dart test/task_model_nullable_copy_test.dart`.

### Task 2: Verify Task CRUD And Agenda Persistence

**Files:**
- Create: `test/task_crud_persistence_test.dart`
- Modify: `lib/providers/task_provider.dart`
- Modify: `lib/services/task_service.dart`

- [x] Add a failing test covering create, edit, complete, reopen, delete, and service reinitialize persistence.
- [x] Fix any persistence/cache behavior exposed by the test.
- [x] Verify Agenda list queries return the persisted state.
- [x] Run the task CRUD, provider initialization, list query, reminder planner, and active-focus tests.

### Task 3: Repair Goal Initial Load And Persistence

**Files:**
- Create: `test/goal_provider_persistence_test.dart`
- Modify: `lib/providers/goal_provider.dart`
- Modify: `lib/models/goal.dart`
- Modify: `lib/services/goal_service.dart`

- [x] Add a failing provider test proving persisted goals appear immediately after initialization.
- [x] Add failing tests for create, update, complete by progress, reopen, delete, and restart persistence.
- [x] Seed `GoalProvider` from the service snapshot after subscribing and finish loading deterministically.
- [x] Add explicit nullable-field copy semantics so reopened goals clear `completedAt`.
- [x] Run the goal persistence tests and database schema tests.

### Task 4: Complete Focus Timer Lifecycle

**Files:**
- Create: `test/focus_timer_lifecycle_test.dart`
- Modify: `lib/providers/focus_provider.dart`
- Modify: `lib/screens/enhanced_focus_screen.dart`

- [x] Add focused tests for start, pause, resume, skip, work completion, break completion, and reset.
- [x] Repair timer/session transitions exposed by the tests without changing external-service behavior.
- [x] Remove the unsafe provider listener lookup during disposal.
- [x] Run focus lifecycle and focus screen tests.

### Task 5: Replace Dummy Follow-Up Reminder Scheduling

**Files:**
- Create: `test/session_notification_scheduling_test.dart`
- Modify: `lib/services/session_notification_service.dart`

- [x] Add a failing platform-channel test proving follow-up reminders use `zonedSchedule`.
- [x] Replace `Future.delayed` with persisted Android local-notification scheduling.
- [x] Use the existing timezone and notification resource helpers.
- [x] Run notification scheduling/resource/timezone tests.

### Task 6: Add Android Wave 1 UI Evidence

**Files:**
- Modify: `lib/screens/enhanced_agenda_screen.dart`
- Modify: `lib/screens/enhanced_focus_screen.dart`
- Modify: `lib/screens/enhanced_analytics_screen.dart`
- Create: `integration_test/android_wave_1_test.dart`

- [x] Add stable keys only to controls needed for Task, Agenda, Focus, and Goal QA.
- [x] Add Android integration flows for task CRUD, Agenda views, Focus start/pause/resume/skip/reset, and Goal CRUD/progress.
- [x] Verify local persistence through provider/service reinitialization regressions.
- [x] Run `flutter test integration_test/android_wave_1_test.dart -d emulator-5554`.

### Task 7: Record Wave 1 Evidence

**Files:**
- Modify: `docs/android/feature-matrix.md`
- Create: `docs/android/wave-1-baseline.md`

- [x] Run `flutter pub get`, `flutter analyze`, targeted Wave 1 tests, Android Wave 0/1 integration tests, release APK, and release AAB.
- [x] Inspect release cold-start logcat for unhandled errors.
- [x] Mark only emulator-verified flows as `PASS`; record permission or external blockers explicitly.
