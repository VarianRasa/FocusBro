# Android Wave 0 Baseline And Test Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish a deterministic Android emulator baseline, modern integration smoke test, and feature-status matrix that can drive all subsequent local/native Android completion work.

**Architecture:** Keep the production app unchanged except for stable automation keys on primary navigation. Use Flutter's `integration_test` package for UI smoke coverage, a PowerShell helper for repeatable emulator/ADB operations, and a tracked feature matrix for evidence and prioritization. The legacy Flutter Driver flow is replaced because it references a missing driver target and contains stale external-service scenarios.

**Tech Stack:** Flutter 3.41.6, Dart 3.11.4, Provider, `integration_test`, PowerShell, Android SDK/ADB, Pixel 8 Pro API 33 emulator.

---

## File Structure

- Modify: `lib/main.dart`
  - Adds stable keys to the primary Android navigation surface.
- Create: `test/main_navigation_test.dart`
  - Verifies keys, destination order, and navigation behavior without an emulator.
- Create: `integration_test/android_smoke_test.dart`
  - Verifies cold startup and all five primary destinations on Android.
- Modify: `test_runner.dart`
  - Runs the modern integration test command against an explicitly selected device.
- Delete: `test_driver/app_test.dart`
  - Removes the obsolete Flutter Driver suite that references missing/stale controls.
- Create: `tool/android_qa.ps1`
  - Provides repeatable emulator launch, wait, reset, permission, screenshot, and logcat commands.
- Create: `docs/android/feature-matrix.md`
  - Tracks included local/native Android feature status and evidence.
- Create: `docs/android/wave-0-baseline.md`
  - Records exact Wave 0 environment, command results, failures, and next-wave blockers.

### Task 1: Add Stable Primary Navigation Identifiers

**Files:**
- Create: `test/main_navigation_test.dart`
- Modify: `lib/main.dart:255-329`

- [ ] **Step 1: Write the failing navigation identifier test**

Create `test/main_navigation_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart';
import 'package:focusbro/providers/focus_provider.dart';
import 'package:focusbro/providers/goal_provider.dart';
import 'package:focusbro/providers/note_provider.dart';
import 'package:focusbro/providers/task_provider.dart';
import 'package:focusbro/services/app_lock_service.dart';
import 'package:focusbro/theme/theme_provider.dart';
import 'package:focusbro/screens/language_selection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'has_seen_onboarding': true,
      'default_view': 'focus',
    });
  });

  testWidgets('primary destinations expose stable Android QA keys',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => FocusProvider()),
          ChangeNotifierProvider(create: (_) => TaskProvider()),
          ChangeNotifierProvider(create: (_) => NoteProvider()),
          ChangeNotifierProvider(create: (_) => GoalProvider()),
          ChangeNotifierProvider.value(value: AppLockService.instance),
        ],
        child: const MaterialApp(home: MainScreen()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(find.byKey(const ValueKey('main_navigation')), findsOneWidget);
    for (final destination in ['focus', 'agenda', 'notes', 'pdf', 'settings']) {
      expect(find.byKey(ValueKey('nav_$destination')), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('nav_settings')));
    await tester.pumpAndSettle();

    final navigation =
        tester.widget<NavigationBar>(find.byKey(const ValueKey('main_navigation')));
    expect(navigation.selectedIndex, 4);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run:

```powershell
flutter test test\main_navigation_test.dart
```

Expected: FAIL because `main_navigation` and `nav_*` keys do not exist.

- [ ] **Step 3: Add keys to production navigation**

Insert this line as the first argument of the existing `NavigationBar`:

```dart
key: const ValueKey('main_navigation'),
```

Insert these lines as the first argument of each destination, in current
destination order:

```dart
key: const ValueKey('nav_focus'),
key: const ValueKey('nav_agenda'),
key: const ValueKey('nav_notes'),
key: const ValueKey('nav_pdf'),
key: const ValueKey('nav_settings'),
```

- [ ] **Step 4: Format and verify the test passes**

Run:

```powershell
dart format lib\main.dart test\main_navigation_test.dart
flutter test test\main_navigation_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit the stable identifiers**

```powershell
git add -- lib/main.dart test/main_navigation_test.dart
git commit --only -m "test: add stable primary navigation identifiers" -- lib/main.dart test/main_navigation_test.dart
```

### Task 2: Add The Android Integration Smoke Test

**Files:**
- Create: `integration_test/android_smoke_test.dart`

- [ ] **Step 1: Write a smoke test that starts from clean local preferences**

Create `integration_test/android_smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('cold start reaches and visits every primary destination',
      (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
    await preferences.setBool('has_seen_onboarding', true);
    await preferences.setBool('show_onboarding', false);
    await preferences.setString('default_view', 'focus');

    await app.main();
    await waitFor(tester, find.byKey(const ValueKey('main_navigation')));

    for (final destination in ['focus', 'agenda', 'notes', 'pdf', 'settings']) {
      await tester.tap(find.byKey(ValueKey('nav_$destination')));
      await tester.pump(const Duration(milliseconds: 750));

      final navigation = tester.widget<NavigationBar>(
        find.byKey(const ValueKey('main_navigation')),
      );
      expect(
        navigation.selectedIndex,
        ['focus', 'agenda', 'notes', 'pdf', 'settings'].indexOf(destination),
      );
    }
  });
}
```

- [ ] **Step 2: Run without an Android device and confirm the environment gate**

Run:

```powershell
flutter test integration_test\android_smoke_test.dart -d emulator-5554
```

Expected before the emulator is running: command fails because `emulator-5554`
is unavailable. This confirms the test requires real Android execution.

- [ ] **Step 3: Launch the emulator and wait for boot**

Run:

```powershell
flutter emulators --launch Pixel_8_Pro_API_33
adb wait-for-device
adb shell getprop sys.boot_completed
```

Expected: final command prints `1`.

- [ ] **Step 4: Run the integration smoke test**

Run:

```powershell
flutter test integration_test\android_smoke_test.dart -d emulator-5554
```

Expected: PASS. If startup or a destination fails, record the exact failure in
`docs/android/wave-0-baseline.md` and fix only the blocking startup/navigation
issue before proceeding.

- [ ] **Step 5: Commit the smoke test**

```powershell
git add -- integration_test/android_smoke_test.dart
git commit --only -m "test: add Android primary navigation smoke test" -- integration_test/android_smoke_test.dart
```

### Task 3: Replace The Obsolete Integration Runner

**Files:**
- Modify: `test_runner.dart:215-270`
- Delete: `test_driver/app_test.dart`

- [ ] **Step 1: Update the integration runner contract**

Replace `_runIntegrationTests()` with:

```dart
Future<int> _runIntegrationTests() async {
  print('\nRunning Android integration tests');
  print(_subSeparator);

  const integrationTestFile = 'integration_test/android_smoke_test.dart';
  if (!await File(integrationTestFile).exists()) {
    print('Integration test file not found: $integrationTestFile');
    return 1;
  }

  final deviceId =
      Platform.environment['FOCUSBRO_ANDROID_DEVICE'] ?? 'emulator-5554';
  final stopwatch = Stopwatch()..start();
  final result = await Process.run(
    'flutter',
    ['test', integrationTestFile, '-d', deviceId],
    workingDirectory: Directory.current.path,
  );
  stopwatch.stop();

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  print('Integration test time: ${stopwatch.elapsed.inSeconds}s');
  return result.exitCode;
}
```

Delete `test_driver/app_test.dart`; it uses deprecated Flutter Driver APIs,
references `test_driver/app.dart` which does not exist, and tests deferred cloud
flows.

- [ ] **Step 2: Format and run the modern runner**

Run:

```powershell
dart format test_runner.dart
$env:FOCUSBRO_ANDROID_DEVICE='emulator-5554'
dart test_runner.dart --integration
```

Expected: the Android smoke test runs and passes.

- [ ] **Step 3: Commit the runner migration**

```powershell
git add -- test_runner.dart test_driver/app_test.dart
git commit --only -m "test: replace obsolete Flutter Driver integration flow" -- test_runner.dart test_driver/app_test.dart
```

### Task 4: Add Repeatable Android Emulator And Evidence Commands

**Files:**
- Create: `tool/android_qa.ps1`

- [ ] **Step 1: Add the PowerShell Android QA helper**

Create `tool/android_qa.ps1`:

```powershell
param(
    [ValidateSet('launch', 'wait', 'reset-app', 'grant-basic', 'screenshot', 'logcat', 'status')]
    [string]$Action = 'status',
    [string]$DeviceId = 'emulator-5554',
    [string]$EmulatorId = 'Pixel_8_Pro_API_33',
    [string]$PackageName = 'com.example.focusbro'
)

$ErrorActionPreference = 'Stop'

function Invoke-Adb {
    param([string[]]$Arguments)
    & adb -s $DeviceId @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "adb failed: $($Arguments -join ' ')"
    }
}

switch ($Action) {
    'launch' {
        flutter emulators --launch $EmulatorId
    }
    'wait' {
        adb -s $DeviceId wait-for-device
        do {
            Start-Sleep -Seconds 2
            $booted = (& adb -s $DeviceId shell getprop sys.boot_completed).Trim()
        } until ($booted -eq '1')
        Write-Output "$DeviceId booted"
    }
    'reset-app' {
        Invoke-Adb @('shell', 'pm', 'clear', $PackageName)
    }
    'grant-basic' {
        Invoke-Adb @('shell', 'pm', 'grant', $PackageName, 'android.permission.POST_NOTIFICATIONS')
        Invoke-Adb @('shell', 'pm', 'grant', $PackageName, 'android.permission.RECORD_AUDIO')
    }
    'screenshot' {
        New-Item -ItemType Directory -Force -Path 'build\android-qa' | Out-Null
        Invoke-Adb @('shell', 'screencap', '-p', '/sdcard/focusbro-qa.png')
        Invoke-Adb @('pull', '/sdcard/focusbro-qa.png', 'build\android-qa\screenshot.png')
        Invoke-Adb @('shell', 'rm', '/sdcard/focusbro-qa.png')
    }
    'logcat' {
        New-Item -ItemType Directory -Force -Path 'build\android-qa' | Out-Null
        & adb -s $DeviceId logcat -d |
            Set-Content 'build\android-qa\logcat.txt'
    }
    'status' {
        flutter devices
        Invoke-Adb @('shell', 'getprop', 'ro.build.version.sdk')
        Invoke-Adb @('shell', 'settings', 'get', 'secure', 'enabled_accessibility_services')
        Invoke-Adb @('shell', 'settings', 'get', 'global', 'zen_mode')
    }
}
```

- [ ] **Step 2: Exercise every non-destructive helper action**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tool\android_qa.ps1 -Action launch
powershell -ExecutionPolicy Bypass -File tool\android_qa.ps1 -Action wait
powershell -ExecutionPolicy Bypass -File tool\android_qa.ps1 -Action status
powershell -ExecutionPolicy Bypass -File tool\android_qa.ps1 -Action screenshot
powershell -ExecutionPolicy Bypass -File tool\android_qa.ps1 -Action logcat
```

Expected:

- Emulator boots.
- Status prints API 33 and current native permission state.
- `build/android-qa/screenshot.png` and `build/android-qa/logcat.txt` exist.

- [ ] **Step 3: Commit the helper**

```powershell
git add -- tool/android_qa.ps1
git commit --only -m "test: add repeatable Android emulator QA helper" -- tool/android_qa.ps1
```

### Task 5: Create The Android Feature Matrix

**Files:**
- Create: `docs/android/feature-matrix.md`

- [ ] **Step 1: Add the matrix with explicit status rules**

Create `docs/android/feature-matrix.md` with these status definitions:

```markdown
# Android Local/Native Feature Matrix

Emulator: Pixel 8 Pro API 33

Status:
- `PASS`: verified through UI on Android and relevant automated checks pass.
- `FAIL`: included feature is broken, fake, or incomplete.
- `BLOCKED_PERMISSION`: implementation exists but Android permission is not granted.
- `DEFERRED_EXTERNAL`: requires a remote service, credential, or OAuth provider.
- `NOT_TESTED`: included feature has not yet been exercised.

| Wave | Area | Flow | Status | Evidence / Failure |
|---|---|---|---|---|
| 0 | Startup | Cold start reaches main navigation | PASS | `flutter test integration_test/android_smoke_test.dart -d emulator-5554` |
| 0 | Navigation | Focus, Agenda, Notes, PDF, Settings | PASS | Integration smoke visits five keyed destinations |
| 1 | Tasks | Create, edit, complete, delete, restart persistence | NOT_TESTED | Scheduled for Wave 1 |
| 1 | Agenda | List, calendar, matrix, kanban | NOT_TESTED | Scheduled for Wave 1 |
| 1 | Focus | Start, pause, resume, skip, complete | NOT_TESTED | Scheduled for Wave 1 |
| 1 | Reminders | Schedule and display local reminder | NOT_TESTED | Scheduled for Wave 1 |
| 1 | Goals | Create, update, delete, progress | NOT_TESTED | Scheduled for Wave 1 |
| 2 | Notes | Create, edit, auto-save, attachments, export | NOT_TESTED | Scheduled for Wave 2 |
| 2 | Voice | Record, play, delete, device speech recognition | NOT_TESTED | Scheduled for Wave 2 |
| 2 | Music | Import, metadata, playback, playlists | NOT_TESTED | Scheduled for Wave 2 |
| 2 | PDF | Open, search, annotate, edit, save, export | NOT_TESTED | Scheduled for Wave 2 |
| 3 | App lock | PIN, timeout, failed attempts, biometric fallback | NOT_TESTED | Scheduled for Wave 3 |
| 3 | DND | Permission status, enable, disable | NOT_TESTED | Scheduled for Wave 3 |
| 3 | App blocking | Accessibility status, block, unblock | NOT_TESTED | Scheduled for Wave 3 |
| 3 | Files | Pick, save to downloads, share | NOT_TESTED | Scheduled for Wave 3 |
| 4 | Reliability | Restart, denied permission, corrupt local data | NOT_TESTED | Scheduled for Wave 4 |
| D | Cloud sync | Firebase remote synchronization | DEFERRED_EXTERNAL | Requires remote Firebase service |
| D | Integrations | OAuth providers | DEFERRED_EXTERNAL | Requires provider credentials and OAuth backend |
| D | Transcription | Remote transcription backend | DEFERRED_EXTERNAL | Requires configured remote endpoint |
```

- [ ] **Step 2: Verify the Wave 0 evidence matches the emulator result**

If the integration smoke test does not pass, do not create the matrix commit.
Fix the blocking startup/navigation failure and rerun the smoke test. Do not
mark later waves `PASS` based only on code inspection.

- [ ] **Step 3: Commit the matrix**

```powershell
git add -- docs/android/feature-matrix.md
git commit --only -m "docs: add Android local native feature matrix" -- docs/android/feature-matrix.md
```

### Task 6: Record And Gate The Wave 0 Baseline

**Files:**
- Create: `docs/android/wave-0-baseline.md`

- [ ] **Step 1: Run baseline quality commands**

Run:

```powershell
flutter pub get
flutter analyze
flutter test test\main_navigation_test.dart test\startup_boot_resilience_test.dart test\startup_initialization_service_test.dart
flutter test integration_test\android_smoke_test.dart -d emulator-5554
flutter build apk --release
flutter build appbundle --release
```

Expected:

- Every command exits `0`.
- APK exists at `build/app/outputs/flutter-apk/app-release.apk`.
- AAB exists at `build/app/outputs/bundle/release/app-release.aab`.

- [ ] **Step 2: Inspect Android runtime logs for startup failures**

Run:

```powershell
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am force-stop com.example.focusbro
adb -s emulator-5554 shell monkey -p com.example.focusbro 1
Start-Sleep -Seconds 8
adb -s emulator-5554 logcat -d |
  Select-String -Pattern 'FATAL EXCEPTION|AndroidRuntime|E/flutter|PlatformException'
```

Expected: no unhandled startup exception. Any relevant failure becomes a Wave 0
blocking fix and is recorded verbatim in the baseline.

- [ ] **Step 3: Write the Wave 0 baseline report**

Create `docs/android/wave-0-baseline.md`:

```markdown
# Android Wave 0 Baseline

- Date: 2026-06-09
- Emulator: Pixel 8 Pro API 33
- Device ID: emulator-5554
- Package: com.example.focusbro
- Flutter: 3.41.6
- Dart: 3.11.4

| Gate | Result | Evidence |
|---|---|---|
| flutter pub get | PASS | Exit code 0 |
| flutter analyze | PASS | No issues found |
| targeted startup/navigation tests | PASS | All selected tests passed |
| Android integration smoke | PASS | Five primary destinations visited on emulator-5554 |
| startup logcat | PASS | No unhandled startup exception matched |
| release APK | PASS | `build/app/outputs/flutter-apk/app-release.apk` |
| release AAB | PASS | `build/app/outputs/bundle/release/app-release.aab` |

## Wave 1 Blocking Findings

- None discovered during Wave 0 startup/navigation baseline.
```

If a command fails, fix the Wave 0 blocker, rerun the gate, and record the
successful final result. Add any reproducible non-blocking included-scope
finding under `Wave 1 Blocking Findings`.

- [ ] **Step 4: Run the complete Wave 0 verification again**

Run:

```powershell
flutter analyze
flutter test test\main_navigation_test.dart test\startup_boot_resilience_test.dart test\startup_initialization_service_test.dart
flutter test integration_test\android_smoke_test.dart -d emulator-5554
```

Expected: all pass.

- [ ] **Step 5: Commit Wave 0 evidence**

```powershell
git add -- docs/android/feature-matrix.md docs/android/wave-0-baseline.md
git commit --only -m "docs: record Android Wave 0 baseline" -- docs/android/feature-matrix.md docs/android/wave-0-baseline.md
```

## Wave 0 Completion Gate

Wave 0 is complete only when:

- `Pixel_8_Pro_API_33` boots and is visible to Flutter.
- Modern integration smoke test passes on Android.
- All five primary destinations are reachable.
- Startup logcat contains no unhandled exception.
- Analyze, targeted tests, APK, and AAB pass.
- The feature matrix and baseline contain actual evidence.
- Reproducible failures discovered during baseline are listed as inputs for the
  Wave 1 Core Productivity plan.
