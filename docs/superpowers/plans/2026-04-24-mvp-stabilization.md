# FocusBro MVP Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stabilize the FocusBro baseline so future feature work starts from safer platform config, realistic smoke tests, and documented task architecture boundaries.

**Architecture:** Keep the current Provider-based Flutter app intact. Use small platform and test changes first, avoid large screen refactors, and document the existing split between `TaskService`/`task_model.dart` and SQLite task repositories before changing task storage.

**Tech Stack:** Flutter, Dart, Provider, SharedPreferences, sqflite, Android manifest, iOS `Info.plist`, Flutter widget tests.

---

### Task 1: Platform Config Safety

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

- [ ] **Step 1: Write static failing checks**

Run:

```powershell
if (Select-String -Path android\app\src\main\AndroidManifest.xml -Pattern 'flutter_background_service' -Quiet) { Write-Error 'Android manifest references flutter_background_service without a dependency'; exit 1 } else { Write-Output 'PASS: no stale background service manifest entry' }
```

Expected: FAIL while the stale background service entry is still present.

Run:

```powershell
$required = 'NSMicrophoneUsageDescription','NSSpeechRecognitionUsageDescription','NSPhotoLibraryUsageDescription','NSCameraUsageDescription','NSFaceIDUsageDescription'; $missing = $required | Where-Object { -not (Select-String -Path ios\Runner\Info.plist -Pattern $_ -Quiet) }; if ($missing) { Write-Error ('Missing iOS usage descriptions: ' + ($missing -join ', ')); exit 1 } else { Write-Output 'PASS: iOS usage descriptions present' }
```

Expected: FAIL while iOS permission usage descriptions are missing.

- [ ] **Step 2: Remove stale Android service entry**

Delete this block from `android/app/src/main/AndroidManifest.xml` because `pubspec.yaml` does not declare `flutter_background_service`:

```xml
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="dataSync"
            android:enabled="true"
            android:exported="false"
            tools:replace="android:exported" />
```

- [ ] **Step 3: Add iOS usage descriptions**

Add these keys inside the top-level `<dict>` in `ios/Runner/Info.plist`:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>FocusBro uses the microphone to record voice notes and voice input.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>FocusBro uses speech recognition to transcribe voice notes and voice commands.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>FocusBro lets you choose images from your photo library for note attachments.</string>
	<key>NSCameraUsageDescription</key>
	<string>FocusBro lets you capture images for note attachments.</string>
	<key>NSFaceIDUsageDescription</key>
	<string>FocusBro uses Face ID to unlock the app when app lock is enabled.</string>
```

- [ ] **Step 4: Run static checks again**

Run the two commands from Step 1.

Expected: both commands print `PASS`.

- [ ] **Step 5: Commit**

```powershell
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "chore: stabilize platform permission config"
```

### Task 2: Realistic App Smoke Test

**Files:**
- Modify: `test/widget_test.dart`

- [ ] **Step 1: Write static failing check for stale template test**

Run:

```powershell
if (Select-String -Path test\widget_test.dart -Pattern 'Counter increments|find\.text\(''0''\)|Icons\.add' -Quiet) { Write-Error 'widget_test.dart still contains Flutter counter template assertions'; exit 1 } else { Write-Output 'PASS: widget_test.dart no longer uses counter template' }
```

Expected: FAIL while the counter template remains.

- [ ] **Step 2: Replace counter test with FocusBro smoke test**

Replace `test/widget_test.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:focusbro/main.dart';
import 'package:focusbro/screens/language_selection_screen.dart';
import 'package:focusbro/theme/theme_provider.dart';

void main() {
  testWidgets('FocusBro app exposes the configured app title', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
          ),
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

    expect(app.title, 'FocusBro');
    expect(app.debugShowCheckedModeBanner, isFalse);
  });
}
```

- [ ] **Step 3: Run static check again**

Run the command from Step 1.

Expected: `PASS: widget_test.dart no longer uses counter template`.

- [ ] **Step 4: Commit**

```powershell
git add test/widget_test.dart
git commit -m "test: replace template widget smoke test"
```

### Task 3: Task Architecture Note

**Files:**
- Create: `docs/architecture/task-data-flow.md`

- [ ] **Step 1: Write architecture note**

Create `docs/architecture/task-data-flow.md` with:

```markdown
# Task Data Flow

FocusBro currently has two task model paths:

- `lib/models/task_model.dart` with `lib/services/task_service.dart` and `lib/providers/task_provider.dart`
- `lib/models/task.dart` with `lib/repositories/task_repository.dart` and `lib/services/migration_service.dart`

The active task UI uses `task_model.dart`, `TaskService`, `TaskTemplateService`, and `TaskProvider`. That path stores tasks and templates in `SharedPreferences` as JSON lists.

The SQLite `TaskRepository` path is still used by migration code and older repository abstractions. New task UI features should use the active `TaskProvider`/`TaskService` path unless a migration task explicitly moves task storage to SQLite.

Before changing task persistence, create a separate migration plan that maps every `task_model.dart` field to the SQLite schema and defines how existing `SharedPreferences` data will be moved without data loss.
```

- [ ] **Step 2: Verify note references real files**

Run:

```powershell
$paths = 'lib\models\task_model.dart','lib\services\task_service.dart','lib\providers\task_provider.dart','lib\models\task.dart','lib\repositories\task_repository.dart','lib\services\migration_service.dart'; $missing = $paths | Where-Object { -not (Test-Path $_) }; if ($missing) { Write-Error ('Missing documented paths: ' + ($missing -join ', ')); exit 1 } else { Write-Output 'PASS: task architecture note references existing files' }
```

Expected: `PASS: task architecture note references existing files`.

- [ ] **Step 3: Commit**

```powershell
git add docs/architecture/task-data-flow.md
git commit -m "docs: document active task data flow"
```
