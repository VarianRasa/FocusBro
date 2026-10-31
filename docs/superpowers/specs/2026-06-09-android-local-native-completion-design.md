# FocusBro Android Local/Native Completion Design

## Objective

Complete and verify every FocusBro feature that can operate locally or through
Android native APIs. External-service features such as remote Firebase sync,
third-party OAuth, and remote transcription are deferred and must not block the
Android local/native completion milestone.

## Scope

### Included

- App startup, onboarding, navigation, localization, themes, and persistence.
- Tasks, agenda views, subtasks, templates, goals, reminders, exports, imports,
  and task-to-focus workflows.
- Focus timer, presets, audio feedback, local music, session history,
  achievements, statistics, and local notifications.
- Notes, attachments, local voice recording, live device speech recognition,
  import, export, sharing, templates, pinning, favorites, and search.
- PDF reading, navigation, search, bookmarks, annotations, reading sessions,
  local editing, save, export, and sharing.
- Local analytics, diagnostics, backup, restore, data controls, and release
  readiness reporting.
- Android app lock, biometrics, DND access, brightness controls, notification
  policy behavior, app blocking through AccessibilityService, usage access,
  overlay settings, file picker, share sheet, exact alarms, and restart
  persistence.

### Deferred

- Remote Firebase authentication, Firestore synchronization, and cloud backup.
- Third-party OAuth integrations including Spotify, Todoist, Notion, Slack,
  GitHub, and Trello.
- Remote voice transcription backend.
- System-wide website blocking that requires a production VPN/DNS forwarding
  implementation.
- iOS, web, and desktop-specific behavior.

Deferred features must clearly communicate setup requirements or unavailable
state and must not pretend to be connected or successful.

## Definition Of Done

A local/native Android feature is complete only when all applicable conditions
are satisfied:

1. Every visible command performs its advertised action or clearly explains a
   real Android permission/setup requirement.
2. No dummy success responses, fake delays, placeholder data, or silent no-op
   controls remain in the included scope.
3. User-created data survives app restart and malformed stored data fails
   gracefully.
4. Empty, loading, success, denied-permission, cancellation, and error states
   behave coherently.
5. The critical user flow passes on the Android emulator.
6. Relevant domain behavior has focused automated coverage.
7. `flutter analyze`, selected tests, Android emulator smoke tests, and release
   APK/AAB builds pass.

## Selected Approach

Use vertical feature waves. Each wave audits UI, provider/domain behavior,
persistence, Android adapter behavior, and emulator evidence before the next
wave begins.

This is preferred over:

- File-by-file cleanup, which can make code look complete without proving user
  workflows.
- Keyword-only dummy scanning, which misses broken controls and false success
  states that do not contain obvious placeholder text.

## Execution Waves

### Wave 0: Baseline And Test Harness

- Launch `Pixel_8_Pro_API_33`.
- Install a debug build and capture startup logs.
- Add an `integration_test` Android smoke harness.
- Establish reusable emulator reset, permission, screenshot, logcat, and
  restart commands.
- Create a feature-status matrix with `pass`, `fail`, `deferred`, and
  `not-applicable` states.

Exit criteria:

- App reaches the main screen without an unhandled exception.
- The smoke harness can navigate all five primary destinations.
- Baseline analyze, targeted tests, and Android build results are recorded.

### Wave 1: Core Productivity

Validate and repair:

- Task create, edit, delete, complete, duplicate, snooze, filter, search,
  subtasks, templates, import, export, and restart persistence.
- Agenda list, calendar, matrix, and kanban views.
- Task reminders, exact-alarm handling, notification display, and reliability
  history.
- Goal create/update/delete and progress behavior.
- Focus start, pause, resume, skip, complete, presets, linked tasks, session
  persistence, statistics, achievements, and completion notifications.

Exit criteria:

- A created task can drive a focus session and produce persisted statistics.
- Reminder and completion notifications appear on the emulator.

### Wave 2: Content And Media

Validate and repair:

- Note create/edit/auto-save/delete/duplicate/search/filter/template/import/
  export/share and restart persistence.
- Local attachments from files, gallery, and camera when supported by the
  emulator.
- Voice recording, playback, deletion, and device speech recognition.
- Local music import, ID3 metadata, playback, playlist operations, equalizer
  state, and session auto-play.
- PDF open, recent files, navigation, bookmarks, annotations, drawing, search,
  reading sessions, focus reading, local edits, save, export, and share.

Exit criteria:

- Representative note, audio, music, and PDF artifacts survive restart.
- Exported/shared files are valid and readable.

### Wave 3: Android Native And Security

Validate and repair:

- App lock with PIN, timeout, failed attempts, background/foreground behavior,
  and biometric fallback.
- DND permission status, settings navigation, enable, and disable behavior.
- Brightness dim/restore behavior.
- Notification permission, notification policy, exact alarm, and boot-related
  behavior where testable.
- Installed-app listing and app blocking through
  `FocusBroAccessibilityService`.
- Usage access and overlay status/settings navigation.
- File picker, save-to-downloads, share sheet, and Android back behavior.

Permissions that Android intentionally requires the user to approve may be
enabled through emulator settings or ADB when possible. The app must still
handle denial and revocation correctly.

Exit criteria:

- Native status shown in Flutter matches Android state.
- App blocking prevents opening a configured test app while focus blocking is
  active and stops blocking after disable.
- App lock and DND controls have verified success and denial flows.

### Wave 4: Reliability And Release

- Test cold start, warm restart, process restart, offline mode, permission
  denial/revocation, cancellation, malformed local data, and empty state.
- Remove remaining local/native fake success states and debug-only user flows.
- Run the Android integration suite.
- Run focused unit/widget tests and `flutter analyze`.
- Build release APK and AAB.
- Produce a final feature matrix listing verified and deferred features.

Exit criteria:

- No known included-scope feature remains broken or dummy.
- Release APK and AAB build successfully.
- Remaining limitations are exclusively deferred external services or explicit
  Android platform restrictions.

## Architecture And Change Rules

- Preserve the existing Provider, repository, service, and native method-channel
  patterns.
- Keep business rules outside widgets where practical.
- Implement Android-specific behavior behind services or method channels.
- Prefer migration-compatible persistence changes so existing local user data
  is retained.
- Add abstractions only when required for testability or to remove meaningful
  duplicated behavior.
- Do not refactor unrelated code or revert existing worktree changes.

## Emulator Verification Strategy

The emulator is the source of truth for Android behavior.

For every included feature:

1. Prepare deterministic local data.
2. Exercise the user flow through the UI.
3. Inspect visible state, logs, and persisted state.
4. Restart the app and verify persistence.
5. Exercise denial/cancellation where applicable.
6. Record the result in the feature matrix.

Native flows additionally inspect Android permission/status state through ADB
and capture logcat around failures.

## Automated Test Strategy

- Unit tests: persistence parsing, domain rules, repositories, import/export,
  scheduling decisions, and native-channel result handling.
- Widget tests: important validation, empty/error states, and controls where
  platform plugins can be replaced.
- Integration tests: startup, primary navigation, core task-to-focus flow,
  note persistence, settings persistence, and representative PDF flow.
- Emulator smoke tests: permissions, notifications, file/share flows,
  biometrics, DND, accessibility app blocking, and lifecycle behavior.

Tests should be added with each wave rather than postponed until the final wave.

## Error Handling

- User cancellation is not treated as an application error.
- Permission denial presents the required permission and a route to Android
  settings when appropriate.
- Native-channel errors return actionable failure state rather than fake
  success.
- Corrupt local records are skipped or migrated without crashing startup.
- External/deferred features clearly report that setup is required.

## Completion Evidence

The final Android completion report must include:

- Feature matrix with status and evidence.
- Commands and results for analyze, tests, APK, and AAB.
- Emulator/API level used.
- Native permissions and behaviors verified.
- Deferred external-service list.
- Any Android platform limitation that cannot be removed by application code.
