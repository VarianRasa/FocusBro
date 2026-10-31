# FocusBro Security Notes

## App Lock PIN

Older FocusBro builds stored the app lock PIN as a plain SHA-256 digest in the
local `app_lock_settings.hashed_pin` SQLite column. Current builds store a
versioned JSON envelope in the same column:

- `version`: hash format version.
- `algorithm`: `pbkdf2_sha256`.
- `iterations`: PBKDF2 iteration count.
- `salt`: per-PIN random salt.
- `hash`: derived key.

Legacy SHA-256 hashes remain accepted so existing users are not locked out. The
normal PIN unlock flow upgrades a matching legacy hash to the new salted PBKDF2
format after a successful unlock.

## Public Config vs Secret Credentials

Firebase client API keys in `lib/firebase_options.dart` and platform Firebase
config files are public client identifiers. They are protected by Firebase Auth,
Firestore rules, and product-level restrictions, not by secrecy in the client.

Supabase anon keys can also be public when they are paired with restrictive row
level security. Custom backend API keys, bearer tokens, service-role keys,
private transcription keys, refresh tokens, and any user credential are secrets.

Secrets must not be committed to the repository. They should not be stored in
SharedPreferences, logs, analytics events, diagnostics output, or backup files.
FocusBro stores backend API keys and voice transcription API keys with
`flutter_secure_storage` and keeps only non-secret metadata such as endpoint
URLs and project IDs in SharedPreferences.

## Backup Behavior

Local backup intentionally filters sensitive SharedPreferences keys such as API
keys, tokens, credentials, passwords, passcodes, secrets, and legacy PIN hashes.
Backups are for user data and non-secret preferences, not credential export.

## Product Risks To Decide

- SQLite itself is not encrypted. The app lock PIN protects app entry, but it is
  not a full encrypted database boundary.
- Four to six digit PINs have low entropy even with PBKDF2. Longer passcodes or
  OS-backed credentials would reduce offline guessing risk.
- Any custom backend should prefer short-lived tokens issued by a backend
  service over long-lived static API keys in the client.
