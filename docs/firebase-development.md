# FocusBro Firebase Development

This project is configured for Firebase project `focusbro-35cd2`.

## Local Firebase Files

- `.firebaserc` selects `focusbro-35cd2` as the local default project.
- `firebase.json` keeps the FlutterFire app metadata, points Firestore to local rules and indexes, and defines Auth/Firestore/Storage emulators.
- `firestore.rules` allows authenticated users to access only allowlisted, versioned records beneath their own `users/{uid}/sync/v1` path; unknown paths and hard deletes are denied.
- `firestore.indexes.json` is intentionally minimal until queries require composite indexes.
- `lib/firebase_options.dart` contains generated FlutterFire client configuration for Android, iOS, macOS, web, and Windows.
- `android/app/google-services.json` contains the Android app config for package `com.example.focusbro`.

## App Firebase Usage

Cloud sync uses Firebase Auth email/password sign-in and Firestore.

Firestore paths used by the app:

- `users/{uid}` is reserved for a lightweight profile; root-profile reads and writes remain denied until a profile contract is implemented.
- `users/{uid}/sync/v1/timer_presets/{docId}`
- `users/{uid}/sync/v1/focus_sessions/{docId}`
- `users/{uid}/sync/v1/settings/current`
- `users/{uid}/sync/v1/notes/{docId}`
- `users/{uid}/sync/v1/tasks/{docId}`
- `users/{uid}/sync/v1/goals/{docId}`
- `users/{uid}/sync/v1/music_library/{docId}`
- `users/{uid}/sync/v1/playlists/{docId}`
- `users/{uid}/sync/v1/pdf_reading_state/{docId}`

The `files` collection is not currently allowed. File uploads and metadata sync remain blocked until the file policy is approved.

Analytics and Crashlytics remain controlled by the in-app opt-in settings. Firebase Storage is configured for local emulator development; file transfers remain unavailable until the file policy is approved.

Hosting is not configured in `firebase.json`. Add an explicit Hosting section only when a web deployment plan has been reviewed.

## CLI Setup

Install and sign in to the Firebase CLI:

```powershell
npm install -g firebase-tools
firebase login
firebase use focusbro-35cd2
firebase projects:list
```

`firebase use` should resolve the local default alias from `.firebaserc`.

## Run Emulators

Start only the local Firebase services used by FocusBro:

```powershell
firebase emulators:start --only auth,firestore,storage
```

The emulator UI is configured at `http://127.0.0.1:4000`.

Default ports:

- Auth: `9099`
- Firestore: `8080`
- Storage: `9199`
- Emulator UI: `4000`

## Run Flutter Against Emulators

Production Firebase remains the default. Any app or cloud-behavior test that must use local emulators must pass the explicit Dart define below. Do not run a cloud-behavior test without it.

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATORS=true
```

Optional overrides:

```powershell
flutter run `
  --dart-define=USE_FIREBASE_EMULATORS=true `
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 `
  --dart-define=FIREBASE_AUTH_EMULATOR_PORT=9099 `
  --dart-define=FIRESTORE_EMULATOR_PORT=8080 `
  --dart-define=FIREBASE_STORAGE_EMULATOR_PORT=9199
```

Without a host override, Android Emulator uses `10.0.2.2`; other platforms use `localhost`. For a physical device, set `FIREBASE_EMULATOR_HOST` to the host machine IP address or set up port forwarding before running the app.

Run Firestore ownership tests only against the local emulators:

```powershell
flutter test --no-pub test/firebase_sync_rules_emulator_test.dart --dart-define=USE_FIREBASE_EMULATORS=true
```

The ownership test pins HTTP traffic to `127.0.0.1`, regardless of app host overrides.

## Local Verification

Use these commands before changing Firebase config:

```powershell
firebase use
firebase projects:list
flutter analyze
flutter test
```

The JSON files can also be parsed locally:

```powershell
node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); JSON.parse(require('fs').readFileSync('firestore.indexes.json','utf8')); JSON.parse(require('fs').readFileSync('.firebaserc','utf8')); console.log('Firebase JSON config OK')"
```

## Before Any Production Deploy

Do not deploy rules, indexes, hosting, or functions until the deploy is explicitly approved.

Checklist:

- Confirm `.firebaserc` points to the intended project.
- Review `firestore.rules` for least privilege.
- Run the app against Auth and Firestore emulators.
- Create a test user in the Auth emulator.
- Verify user A cannot read or write user B data in the emulator.
- Confirm no Storage or Hosting deploy is included accidentally.
- Run `flutter analyze` and `flutter test`.
- Use an explicit deploy command only after approval, for example `firebase deploy --only firestore:rules,firestore:indexes`.
