# Agent Guide

## Project layout

- The root is the primary Flutter application. Dart application code is in `lib/`, unit/widget tests in `test/`, and device integration tests in `integration_test/`.
- `web_app/` is a separate Flutter package. Keep its dependencies and test changes scoped to that package unless a shared contract requires otherwise.
- Android emulator QA steps are in `docs/android-smoke-qa.md`. Firebase emulator setup and safeguards are in `docs/firebase-development.md`.

## Setup and development

Install Flutter/Dart compatible with the SDK constraints in `pubspec.yaml`, then run `flutter pub get` at the repository root. For the standalone web package, run `flutter pub get` from `web_app/`.

Run the root app with `flutter run`. Run its tests and analyzer with `flutter test` and `flutter analyze`. Run `flutter run` and `flutter test` from `web_app/` to work with the standalone web package. Device-specific integration tests require the emulator setup described in `docs/android-smoke-qa.md`.

Build an Android release APK with `flutter build apk --release --no-tree-shake-icons`. Do not deploy Firebase rules or access production data during local development. Use the Firebase emulator instructions in `docs/firebase-development.md` when testing cloud behavior.

## Formatting and conventions

Format Dart changes with `dart format <changed-dart-files>`. Before submitting, verify all Dart packages with:

```bash
dart format --output=none --set-exit-if-changed lib test integration_test test_driver web_app/lib
```

Use Dart conventions: `UpperCamelCase` for types, `lowerCamelCase` for members and variables, and `lower_snake_case.dart` for file names. Follow the configured `flutter_lints` rules in `analysis_options.yaml`; do not silence a lint without a specific, documented reason.

A repository pre-commit hook checks staged Dart files. Configure it once per clone with `git config core.hooksPath .githooks`.

## Change safety

- Preserve user data and existing local edits. Avoid broad formatting or generated-file updates unless needed for the change.
- Add focused tests for behavior changes. Prefer pure unit/widget tests for local logic; use integration tests for device-specific flows.
- Never deploy Firebase configuration or change production settings without explicit approval.
