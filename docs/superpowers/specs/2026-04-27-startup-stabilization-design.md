# FocusBro Startup Stabilization Design

## Goal

Make the Flutter app safer to start and easier to recover when local initialization fails. The first release-readiness pass should prevent silent splash-screen stalls, make database schema problems diagnosable, and give us a repeatable manual verification loop.

## Scope

This stabilization pass covers:

- database startup resilience for local SQLite schema issues
- splash-screen error and retry behavior
- main initialization error handling for critical and non-critical services
- basic smoke coverage for startup assumptions
- manual verification commands run by the developer from their terminal

This pass does not cover:

- rich text notes
- voice notes UI
- PDF annotation expansion
- recurring task UI
- Android release signing
- Play Store packaging
- large data-layer refactors

## Current Context

The Android build now runs, but the app recently got stuck at splash because SQLite initialization failed. The root symptom was an insert into `timer_presets` using columns that did not exist in the table. The app also does substantial async work before showing the main UI, including cache initialization, database initialization, provider initialization, onboarding checks, and app-lock checks.

The app can tolerate resetting local emulator or development data during this stabilization pass. We do not need a full production-grade migration path for every old schema variant yet.

The developer will run Flutter and Dart commands locally and paste command output into the chat. Codex will not run `flutter` or `dart` commands during this pass.

## Proposed Architecture

Keep the current Provider-based app architecture and improve startup behavior around the existing boundaries:

- `main.dart` remains the high-level bootstrapper.
- `AppInitializationService` remains the database and migration entry point.
- `DatabaseHelper` owns schema creation, versioning, and recovery helpers.
- `SplashScreen` owns user-facing loading, retry, and recovery UI.
- Providers remain responsible for feature-specific initialization.

The stabilization work should prefer small, targeted changes over moving initialization into a new framework or introducing new dependencies.

## Database Startup Design

`DatabaseHelper` should expose a safe initialization path that can:

- open the database normally
- detect known schema mismatch failures during development
- provide a controlled reset path for local/dev data
- keep table creation and default data insertion consistent

The schema and default data should use the same column names. For `timer_presets`, the canonical schema is:

- `id INTEGER PRIMARY KEY AUTOINCREMENT`
- `name`
- `work_duration`
- `break_duration`
- `total_sessions`
- `is_built_in`
- `is_active`
- `created_at`
- `updated_at`

Any future default preset insert must use those same column names.

## Splash-Screen Design

The splash screen should never remain indefinitely stuck on a progress message. If initialization throws, the screen should show:

- a short error title
- a concise developer-friendly error detail in debug builds
- a retry action
- a reset local data action for dev/emulator recovery

The reset action should be explicit and should only clear the local app database and startup state needed to recover. It should not be hidden behind automatic destructive behavior.

## Main Initialization Design

Initialization should distinguish critical services from non-critical services.

Critical failures should route to the splash error UI:

- database open/create failure
- unrecoverable migration failure
- missing required startup storage

Non-critical failures should be logged and allow the app to continue:

- note provider initialization failure
- goal provider initialization failure
- app lock initialization failure when app lock is not required for routing
- cache preload failure

This keeps the first screen reachable while preserving enough logs for debugging.

## Testing Design

Add focused tests where the current test harness supports them:

- verify `TimerPreset.toMap()` uses the canonical schema keys
- verify no default timer preset insert path references old keys such as `focus_duration`
- replace stale counter-template smoke tests with a FocusBro app smoke test

If a full widget test is blocked by plugin initialization, prefer a smaller static or model-level test first and document the remaining gap.

## Manual Verification

The developer will run these commands locally after implementation:

```powershell
flutter analyze
flutter test
flutter run
```

If `flutter run` fails, the developer will paste the terminal output back into the chat. Codex will inspect the failure and iterate without running Flutter or Dart commands directly.

## Acceptance Criteria

- App startup does not silently hang on splash after an initialization exception.
- A failed initialization gives visible retry and local reset options.
- `timer_presets` schema and default data are aligned.
- Known local/dev schema corruption can be recovered without manual file hunting.
- Flutter analyzer and tests are run by the developer and reviewed from pasted output.
- The Android app reaches the main UI after `flutter run` on the developer machine.
