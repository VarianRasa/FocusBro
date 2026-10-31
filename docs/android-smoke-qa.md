# Android Smoke QA

Tanggal QA: 2026-06-15

## Scope

Tahap ini memverifikasi FocusBro bisa dipasang dan dijalankan sebagai Android debug app di emulator, lalu mengecek flow inti tanpa menyentuh Firebase production, Play Store, signing production, atau package name.

## Device

| Item | Nilai |
| --- | --- |
| Emulator | Pixel 8 Pro API 33 |
| Flutter device id | `emulator-5554` |
| Android | Android 13, API 33 |
| Package | `com.example.focusbro` |
| Artifact manual launch | `build/app/outputs/flutter-apk/app-debug.apk` |

`flutter devices` awalnya hanya melihat Windows/Chrome/Edge. `flutter emulators` menemukan `Pixel_8_Pro_API_33`, lalu emulator diluncurkan dan terdeteksi sebagai Android mobile device.

## Commands

```powershell
flutter devices
flutter emulators
flutter emulators --launch Pixel_8_Pro_API_33
.\tool\android_qa.ps1 -Action wait -DeviceId emulator-5554
flutter test integration_test\android_smoke_test.dart -d emulator-5554
flutter test integration_test\android_wave_1_test.dart -d emulator-5554
flutter test integration_test\android_core_runtime_smoke_test.dart -d emulator-5554
flutter build apk --debug
adb -s emulator-5554 install -r build\app\outputs\flutter-apk\app-debug.apk
adb -s emulator-5554 shell am start -n com.example.focusbro/.MainActivity
.\tool\android_qa.ps1 -Action screenshot -DeviceId emulator-5554
.\tool\android_qa.ps1 -Action logcat -DeviceId emulator-5554
```

Catatan: `adb` dijalankan dari Android SDK lokal di `%LOCALAPPDATA%\Android\sdk\platform-tools\adb.exe`.

## Flow Results

| Flow | Evidence | Result |
| --- | --- | --- |
| Debug launch | Explicit install of `app-debug.apk`, `am start` to `.MainActivity`, process pid observed | PASS |
| Startup to home | `android_smoke_test.dart`, manual onboarding `Skip`, screenshot | PASS |
| Primary navigation | `android_smoke_test.dart` visits Focus, Agenda, Notes, PDF, Settings | PASS |
| Task create/edit/delete | `android_wave_1_test.dart` creates via Agenda UI, edits through provider, completes/reopens/deletes | PASS |
| Agenda basic | `android_wave_1_test.dart` opens list/calendar/matrix/kanban | PASS |
| Focus timer basic | `android_wave_1_test.dart` start/pause/resume/skip/reset | PASS |
| Notes basic | `android_core_runtime_smoke_test.dart` creates note through Android runtime service path and verifies SQLite row | PASS |
| Backup/restore basic | `android_core_runtime_smoke_test.dart` creates backup file, deletes note, restores from file path, verifies note row | PASS |
| App lock PIN | `android_core_runtime_smoke_test.dart` sets PIN, locks, rejects wrong PIN, unlocks correct PIN, timeout lock | PASS |
| Cloud sync no-auth/local snapshot | `android_core_runtime_smoke_test.dart` configures local snapshot, signs out, verifies force sync exits false, renders Cloud Sync screen | PASS |
| Log crash scan | `build/android-qa/logcat.txt` scanned for `FATAL EXCEPTION`, `E/flutter`, `PlatformException`, `MissingPluginException`, `No implementation found`, `Force finishing` | PASS |

Screenshot evidence: `build/android-qa/screenshot.png`

Logcat evidence: `build/android-qa/logcat.txt`

## Runtime Bug Fixed

Finding: after skipping onboarding on a fresh Android install, two first-visit help tips could appear simultaneously on the Focus screen (`Voice Commands` and `Focus Timer`). This did not crash the app, but it blocked a clean first-run home experience.

Fix: `HelpTipWidget` now has a single active global tip guard so only one first-visit overlay can be visible at a time. Added a widget regression test for this behavior.

Files:

- `lib/widgets/help_tip_widget.dart`
- `test/help_tip_widget_test.dart`

## Tests Added

- `integration_test/android_core_runtime_smoke_test.dart`
  - Notes create/persist smoke.
  - Backup create and restore from explicit path, avoiding file picker.
  - App lock PIN set/lock/wrong PIN/correct PIN/timeout/disable.
  - Cloud sync local snapshot/no-auth behavior and Cloud Sync screen render.
- `test/help_tip_widget_test.dart`
  - Prevents multiple first-visit help tips from stacking.

## Known Remaining Risks

- Wave 2 native media/voice/PDF and Wave 3 special-access flows were not part of this core runtime pass. They exist as integration tests, but microphone recording, DND access, and Accessibility app blocking still need dedicated manual permission QA on emulator/device.
- Manual debug launch starts onboarding on a fresh install. This is expected. Automated smoke bypasses onboarding to verify home/navigation deterministically.
- `flutter pub` continues to report many outdated packages and `id3` discontinued. Dependencies were not upgraded in this phase.
- Firebase SDK initialized during app startup, but no Firebase Auth sign-in, Firestore writes, rules changes, deploy, or production data mutation were performed.
