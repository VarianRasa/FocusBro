# Android Local/Native Feature Matrix

Emulator: Pixel 8 Pro API 33

Status:
- `PASS`: verified through UI on Android and relevant automated checks pass.
- `FAIL`: included feature is broken, fake, or incomplete.
- `BLOCKED_PERMISSION`: implementation exists but Android permission is not granted.
- `MANUAL_DEVICE`: implementation exists but requires user-approved Android
  special access, enrolled hardware, or a device speech service on a real phone.
- `DEFERRED_EXTERNAL`: requires a remote service, credential, or OAuth provider.
- `NOT_TESTED`: included feature has not yet been exercised.

| Wave | Area | Flow | Status | Evidence / Failure |
|---|---|---|---|---|
| 0 | Startup | Cold start reaches main navigation | PASS | `flutter test integration_test/android_smoke_test.dart -d emulator-5554` |
| 0 | Navigation | Focus, Agenda, Notes, PDF, Settings | PASS | Integration smoke visits five keyed destinations |
| 0 | Notification startup | Initialize without opening DND settings | PASS | Permission regression test and Android smoke pass |
| 0 | Notification timezone | Convert scheduled local times safely | PASS | Timezone regression test and Android smoke pass |
| 0 | Release notifications | Bundled notification icon initializes | PASS | Release APK cold-start logcat has no `invalid_icon` or `PlatformException` |
| 0 | Release startup | Installed release APK opens without unhandled startup error | PASS | Clean emulator cold-start logcat gate |
| 1 | Tasks | Create, edit, complete, reopen, delete, restart persistence | PASS | Android Wave 1 integration plus task CRUD persistence regression |
| 1 | Agenda | List, calendar, matrix, kanban | PASS | Android Wave 1 integration opens all four keyed views |
| 1 | Focus | Start, pause, resume, skip, complete, reset | PASS | Android Wave 1 integration plus focused timer lifecycle regressions |
| 1 | Reminders | Schedule and display local reminder | PASS | Android plugin reports follow-up notification `1004` pending; scheduling regression verifies `zonedSchedule` |
| 1 | Goals | Create, update, delete, progress, reopen | PASS | Android Wave 1 integration plus SQLite CRUD/restart persistence regression |
| 2 | Notes | Create, edit, auto-save, tags, attachments, export/import | PASS | Android Wave 2 integration plus `test/note_local_flows_test.dart` |
| 2 | Voice notes | Record `.m4a`, non-blocking playback, pause/resume/stop, save, delete | PASS | Android Wave 2 records a real file, plays it, persists it, then deletes it |
| 2 | Voice commands | Device speech recognition commands | MANUAL_DEVICE | Requires microphone approval and Android speech service availability |
| 2 | Music | Import metadata, local playback, pause/resume/stop, playlists | PASS | Android Wave 2 plays a local recording through `MusicService`; metadata and playlist regressions pass |
| 2 | PDF | Outline extraction, bookmark storage, page edit/save service | PASS | Android Wave 2 plus PDF outline/edit/bookmark regressions |
| 3 | App lock | PIN, timeout, failed attempts | PASS | Android Wave 3 integration verifies wrong PIN, correct PIN, timeout, and disable |
| 3 | App lock | Biometric fallback | MANUAL_DEVICE | Requires enrolled biometrics on a physical device |
| 3 | DND | Permission status, enable, disable | PASS | Android Wave 3 enables and disables Do Not Disturb after ADB-granted policy access |
| 3 | App blocking | Accessibility status, block, unblock | PASS | Android Wave 3 enables and disables native Accessibility app blocking after ADB-granted service access |
| 3 | Website blocking | System-wide website block list enforcement | DEFERRED_EXTERNAL | Requires VPN/DNS profile or browser-extension integration |
| 3 | Files | Pick backup JSON, save to Downloads, share sheet | PASS | Release UI verified DocumentsUI save and restore picker; `android_share_surface_test.dart` verifies native share invocation |
| 4 | Reliability | Restart, denied permission, corrupt local data | PASS | Smoke startup, clean release cold-start logcat, and corrupt backup regression pass |
| D | Cloud sync | Firebase remote synchronization | DEFERRED_EXTERNAL | Requires remote Firebase service |
| D | Integrations | OAuth providers | DEFERRED_EXTERNAL | Requires provider credentials and OAuth backend |
| D | Transcription | Remote transcription backend | DEFERRED_EXTERNAL | Requires configured remote endpoint |
