---
id: "CI-030"
status: "DRAFT"
updated: "2026-09-26"
---
# 030 — Flutter quality, architecture and build gates

**Status note:** Draft.

**Complexity:** Medium
**Risk:** Medium — the iOS build needs a macOS runner and CocoaPods; the first run is where plugin version drift shows.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [010-change-aware-checks](../010-P-change-aware-checks/spec.md), [070-flutter-shell-trim](../../core/070-D-flutter-shell-trim/spec.md), [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

What the `ui` job proves, plus two build jobs that compile the Android
bundle and an unsigned iOS app on every pull request that touches
`flutter-ui/`, so a native build break never waits for a release. A passing
build proves native compilation, Gradle and CocoaPods resolution, and plugin
compatibility; it proves nothing about signing, which only `deploy/030` and
`deploy/040` exercise.

Excludes: signing and store upload (`deploy/030`, `deploy/040`); the
integration test (040); the web image (core 105).

## Requirements

1. `flutter-ui/pubspec.yaml` MUST pin `environment.flutter` to an exact version (today `3.47.5`). `subosito/flutter-action` reads it with `flutter-version-file`, and `make tools-check` (core 090) compares it with the local `flutter --version`. A range is rejected by the action.
2. `make ui-format-check` runs `dart format -o none --set-exit-if-changed lib test`. `make ui-analyze` becomes `flutter analyze --fatal-infos`.
3. `make ui-deps-check` runs `dart pub get --enforce-lockfile` and `dart run dependency_validator`: the lockfile matches the manifest and no dependency is unused or undeclared.
4. `make ui-lint-imports` runs `import_lint` (Dart 3.10 `plugins:` system) with one rule: files under `lib/src/providers/`, `lib/src/services/`, `lib/src/config/` and `lib/src/constants/` MUST NOT import `lib/src/screens/` or `lib/src/widgets/`. Presentation depends on logic, never the reverse.
5. `make ui-cover` runs `flutter test --coverage` and fails below 60% line coverage, computed from `coverage/lcov.info` `LF:`/`LH:` lines with `awk`; no new tool.
6. `make ui-build-aab` runs `flutter build appbundle --release`; `make ui-build-ios` runs `flutter build ios --release --no-codesign`. Both accept `BUILD_NUMBER=` and pass it as `--build-number`; the default is the `+n` in `pubspec.yaml`. `ui-build-android` (debug APK, core 100) stays for local use.
7. CI: the `ui` job runs `ui-get`, `ui-format-check`, `ui-analyze`, `ui-deps-check`, `ui-lint-imports`, `ui-test`, `ui-cover`. Two further jobs gated on the `flutter` filter: `build-android` on `ubuntu-latest` runs `ui-build-aab`; `build-ios` on `macos-latest` runs `ui-build-ios`. Each uploads its output as an artifact with `retention-days: 7`. Both join `ci-ok`.
8. Caches: the Flutter SDK and pub cache through the action's `cache: true`; Gradle through `gradle/actions/setup-gradle`; CocoaPods keyed on `ios/Podfile.lock`.

## Implementation hints

- `import_lint` config lives in `analysis_options.yaml` under `import_lint:` with `rules:` naming `target_file_patterns` and `not_allow_import_patterns`.
- `ubuntu-latest` already ships JDK 17 and the Android SDK; `actions/setup-java` only pins the version. `macos-latest` ships Xcode and CocoaPods; neither image ships Flutter.
- The release build type currently signs with debug keys on purpose; `ui-build-aab` therefore produces a debug-signed bundle on a pull request, which Play would reject but Gradle compiles. `deploy/030` adds the real signing config behind `key.properties`.

## Testing / acceptance criteria

- Every target in requirement 7 exits 0 on `main`.
- Adding `import '../screens/main_screen.dart'` to `lib/src/services/api_logger.dart` makes `make ui-lint-imports` fail.
- Editing `pubspec.yaml` without updating `pubspec.lock` makes `make ui-deps-check` fail.
- A pull request touching only `flutter-ui/lib/` runs `ui`, `build-android`, `build-ios` and skips `go`; both build artifacts are downloadable from the run.
- The `ui` job finishes in under 5 minutes and each build job in under 15 minutes with warm caches.
