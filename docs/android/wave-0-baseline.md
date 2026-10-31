# Android Wave 0 Baseline

- Date: 2026-06-09
- Emulator: Pixel 8 Pro API 33
- Device ID: emulator-5554
- Package: com.example.focusbro
- Flutter: 3.41.6
- Dart: 3.11.4

| Gate | Result | Evidence |
|---|---|---|
| `flutter pub get` | PASS | Dependencies resolved; one discontinued package and available upgrades reported |
| `flutter analyze` | PASS | No issues found |
| Targeted startup/navigation/regression tests | PASS | Eight selected tests passed |
| Android integration smoke | PASS | Five primary destinations visited from a wiped emulator |
| Modern integration runner | PASS | `dart test_runner.dart --integration` |
| Android QA helper | PASS | Wait, status, screenshot, and logcat actions exercised |
| Release startup logcat | PASS | No `FATAL EXCEPTION`, `E/flutter`, `PlatformException`, or service initialization error |
| Release notification resource | PASS | `drawable/ic_stat_focusbro` retained in release APK |
| Release APK | PASS | `build/app/outputs/flutter-apk/app-release.apk` (239,897,153 bytes) |
| Release AAB | PASS | `build/app/outputs/bundle/release/app-release.aab` (200,509,764 bytes) |

## Wave 0 Fixes

- Stopped requesting the interactive Android notification-policy permission during startup.
- Initialized timezone data before scheduling local notifications.
- Added stable primary navigation identifiers and an Android integration smoke test.
- Replaced the obsolete Flutter Driver integration flow.
- Added a repeatable PowerShell Android QA helper with automatic ADB discovery.
- Added and retained a valid Android notification small icon; removed references to missing action-icon resources.

## Current Native Permission State

- API level: 33
- Enabled accessibility services: none
- Zen mode: off
- Notification policy access: not granted

## Non-blocking Findings

- `FocusProvider` logs an unsafe ancestor lookup warning during widget disposal.
- The legacy `focus_mode_services_test.dart` suite has five failures caused by singleton state leaking between tests and host-Windows expectations for Android-only blocking behavior.
- Release APK and AAB are large and should be optimized after local/native feature completion.
- A long QA cycle filled emulator storage; wiping the dedicated QA emulator restored the baseline.

## Next Wave

Wave 1 should verify and complete Tasks, Agenda, Focus timer lifecycle, local reminders, and Goals through Android UI flows with restart persistence.
