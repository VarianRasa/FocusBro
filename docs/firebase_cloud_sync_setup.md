# Firebase Cloud Sync Setup

FocusBro uses Firebase Auth for identity and Cloud Firestore for cross-device
sync. Local SQLite remains the offline cache.

## Firebase Console

1. Open the Firebase project used by `lib/firebase_options.dart`.
2. Enable Authentication > Sign-in method > Email/Password.
3. Enable Cloud Firestore.
4. Publish Firestore rules that restrict each user to their own sync data:

```js
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null
        && request.auth.uid == userId;
    }
  }
}
```

## App Flow

1. Open FocusBro > Settings > Cloud Sync.
2. Tap Configure Backend.
3. Choose Firebase.
4. Save. Project ID is optional when `firebase_options.dart` is present.
5. Sign in with email and password. If the email is not registered yet, the app
   creates the Firebase Auth account.
6. Tap Sync Now.

## Firestore Layout

Synced data is stored under the signed-in user's UID:

```text
users/{uid}
users/{uid}/sync/v1/timer_presets/{itemId}
users/{uid}/sync/v1/focus_sessions/{itemId}
users/{uid}/sync/v1/settings/current
users/{uid}/sync/v1/notes/{itemId}
users/{uid}/sync/v1/tasks/{itemId}
users/{uid}/sync/v1/goals/{itemId}
```

Each item document stores the original payload plus sync metadata:

```json
{
  "payload": {},
  "updatedAt": "2026-05-14T00:00:00.000",
  "syncedAt": "server timestamp"
}
```

## Quick Checks

- Cloud Sync readiness should show Firebase ready after app startup.
- Signing in should create or reuse a Firebase Auth user.
- Sync Now should create documents under `users/{uid}/sync/v1`.
- If Firestore rules are missing, the app should show a sync error instead of
  crashing.
