# Firebase Observability QA

Use this checklist after changing Analytics, Crashlytics, Cloud Sync, Backup,
Reminder, or Settings privacy behavior.

## Preconditions

- Firebase is configured through `lib/firebase_options.dart`.
- Android app id matches the Firebase app, currently `com.example.focusbro`.
- The app opens successfully on a debug device or emulator.
- Privacy toggles are reachable from Settings > Privacy.
- Diagnostics are reachable from Settings > Advanced > Firebase Observability.

## Analytics DebugView

1. Open Firebase Console > Analytics > DebugView.
2. Enable debug analytics for the app:

   ```powershell
   adb shell setprop debug.firebase.analytics.app com.example.focusbro
   ```

3. Restart FocusBro.
4. In FocusBro, enable Settings > Privacy > Analytics.
5. Open Settings > Advanced > Firebase Observability.
6. Tap Send Analytics Test Event.
7. Confirm `observability_test_event` appears in DebugView.
8. Run Cloud Sync once and confirm `cloud_sync_started` and
   `cloud_sync_completed` appear.
9. Disable Settings > Privacy > Analytics and repeat the test button.
10. Confirm no new Analytics event is expected while collection is disabled.

## Crashlytics Non-Fatal

1. Open Firebase Console > DevOps & Engagement > Crashlytics.
2. In FocusBro, enable Settings > Privacy > Crash Reporting.
3. Open Settings > Advanced > Firebase Observability.
4. Tap Send Non-Fatal Test Error.
5. Confirm a non-fatal event with reason `observability_test_nonfatal` appears
   in Crashlytics.
6. Disable Settings > Privacy > Crash Reporting and repeat the test button.
7. Confirm the app remains stable and no new non-fatal is expected while
   collection is disabled.

## Release Readiness

1. Open Settings > Advanced > Release Readiness.
2. Confirm Firebase observability appears in the checklist.
3. Treat action-required as a blocker.
4. Treat warnings as QA reminders, especially when privacy toggles are disabled.

## Privacy Rule

Do not send email, password, task titles, note content, file paths, raw stack
traces, or document payloads as Analytics parameters.
