---
id: "CI-030"
status: "DRAFT"
updated: "2026-09-26"
---
# 030 — Flutter quality, architecture and build gates

**Status note:** Draft. The Android slice is delivered (2026-10-11):
requirement 1, requirement 6's `ui-build-aab`, and requirement 7's
`build-android` job, which joins `ci-ok`'s `needs:` list. Before it, nothing
in CI compiled native code at all - the `ui` job ran `ui-get`, `ui-analyze`
and `ui-test`, so a Gradle break or a plugin incompatibility passed cleanly
and surfaced only on someone's laptop.

The rest is deferred deliberately, and named here rather than dropped:

| Deferred | Why |
|---|---|
| reqs 2-5: format check, deps check, import lint, coverage floor | quality gates, not release work, and the 60% floor may need tests written before it can be turned on |
| req 6's `make ui-build-ios` and req 7's `build-ios` job | both wait on `deploy/040` req 0, which establishes whether the committed Apple team is paid or free |
| req 8: Gradle and CocoaPods caches | the job works without them. Revisit if it approaches the 15 minute criterion |
| req 1's `make tools-check` clause | that target does not exist; it is `core/090` req 4, and nothing guards the three Flutter version literals from drifting apart |

**Complexity:** Medium
**Risk:** Medium — the iOS build needs a macOS runner and CocoaPods; the first run is where plugin version drift shows.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [010-change-aware-checks](../010-D-change-aware-checks/spec.md), [070-flutter-shell-trim](../../core/070-D-flutter-shell-trim/spec.md), [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md)
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

1. Every build of this application MUST name one exact Flutter version, and the places that name it MUST agree. Today that is **3.44.0**, in three literals: the `ui` job, the `build-android` job, and `deploy/docker/ahorro-web.Dockerfile`'s base image. `subosito/flutter-action` takes it as `flutter-version`. *(Amended twice, and the shape of this requirement changed.*

   *It said to pin `environment.flutter` in `pubspec.yaml` and have the action read it with `flutter-version-file`, so one file was the single source. That was tried and reverted: a pubspec pin constrains **every** consumer, and the web image cannot comply. `ahorro-web.Dockerfile` copies `pubspec.yaml` and runs `flutter pub get`, and `ghcr.io/cirruslabs/flutter` publishes nothing newer than 3.44.0 - measured against its tag list on 2026-10-11, and instrumentisto has no 3.47.x either. So `environment.flutter: 3.47.5` made `image-web` fail with "Because ahorro_ui requires Flutter SDK version >=3.47.5, version solving failed". The action can fetch any version; a Dockerfile needs one somebody published, and that asymmetry is what defeats the single-source design.*

   *The version therefore sits in the workflow, matched by hand to the image the Dockerfile can get. Three literals that must move together is a real drift risk and there is no guard on it: `make tools-check` would be the place, and that target does not exist - it is `core/090` req 4. Raising the version means finding a published base image first, not editing the workflow.)*
2. `make ui-format-check` runs `dart format -o none --set-exit-if-changed lib test`. `make ui-analyze` becomes `flutter analyze --fatal-infos`.
3. `make ui-deps-check` runs `dart pub get --enforce-lockfile` and `dart run dependency_validator`: the lockfile matches the manifest and no dependency is unused or undeclared.
4. `make ui-lint-imports` runs `import_lint` (Dart 3.10 `plugins:` system) with one rule: files under `lib/src/providers/`, `lib/src/services/`, `lib/src/config/` and `lib/src/constants/` MUST NOT import `lib/src/screens/` or `lib/src/widgets/`. Presentation depends on logic, never the reverse.
5. `make ui-cover` runs `flutter test --coverage` and fails below 60% line coverage, computed from `coverage/lcov.info` `LF:`/`LH:` lines with `awk`; no new tool.
6. `make ui-build-aab` runs `flutter build appbundle --release`; `make ui-build-ios` runs `flutter build ios --release --no-codesign`. Both accept `BUILD_NUMBER=` and pass it as `--build-number`; the default is the `+n` in `pubspec.yaml`. `ui-build-android` (debug APK, core 100) stays for local use. Both MUST also carry the `ENV` guard and the version name of [015](../../deploy/015-D-local-release-builds/spec.md) reqs 3 and 4. *(Amended: without the guard these two targets inherit `ENV=local`, which is how `deploy/030` req 5 came to specify a store upload pointed at `http://localhost:8080`. 015 req 1 adds the release APK these two do not produce.)*
7. CI: the `ui` job runs `ui-get`, `ui-format-check`, `ui-analyze`, `ui-deps-check`, `ui-lint-imports`, `ui-test`, `ui-cover`. Two further jobs gated on the `flutter` filter: `build-android` on `ubuntu-latest` runs `ui-build-aab`; `build-ios` on `macos-latest` runs `ui-build-ios`. Each uploads its output as an artifact with `retention-days: 7`. Both MUST join `ci-ok`'s `needs:` list, which is the single required context `make repo-settings` configures: a job that is not in that list reports its own result and blocks nothing. *(Amended: "join `ci-ok`" did not say where. The list is maintained by hand and a job left out of it is advisory, so a native build break would report red on the run page and still merge.)*

7a. A build job MUST get its backend configuration from `FQDN=example.invalid` and a deployed `ENV`, not from SSM. `ui-build-aab` depends on `ui-config`, which resolves a deployed `ENV`'s host from SSM and exits 1 when it cannot - and a pull request from a fork has no AWS token at all, so a job that needed the real value would fail there by construction. `scripts/ui-config.sh` honours an `FQDN` override and already writes blank Cognito keys rather than failing when the pool is unreachable, so both halves degrade correctly. This is the same placeholder `Makefile` line 62 renders GitOps with and the reason is the same: the root domain is never committed, not even to a workflow file. The job therefore proves native compilation, Gradle resolution and plugin compatibility, and **proves nothing about configuration or signing** - the bundle is debug-signed because `key.properties` never reaches CI. *(Added: requirement 7 said which targets to run and never said where their configuration comes from, which is the one thing that decides whether the job can run on a fork at all.)*
8. Caches: the Flutter SDK and pub cache through the action's `cache: true`; Gradle through `gradle/actions/setup-gradle`; CocoaPods keyed on `ios/Podfile.lock`.

## Implementation hints

- `import_lint` config lives in `analysis_options.yaml` under `import_lint:` with `rules:` naming `target_file_patterns` and `not_allow_import_patterns`.
- `ubuntu-latest` already ships JDK 17 and the Android SDK; `actions/setup-java` only pins the version. `macos-latest` ships Xcode and CocoaPods; neither image ships Flutter.
- Building a second `ENV` in the same job is cheap, which is not obvious: a `--dart-define` change invalidates the Dart kernel and the AOT snapshot, but Gradle keeps the native libraries, the resources and the packaging. Measured on 2026-10-11 against a cold build of several minutes: rebuilding the same `ENV` unchanged took 9s, switching to a second `ENV` took 40s, and switching back took 16s. So two sequential `run` steps in one job beat a matrix, which pays a cold cache twice. `deploy/030` is where that matters, if a dev-pointed bundle is ever wanted beside the prod one.
- The release build type currently signs with debug keys on purpose; `ui-build-aab` therefore produces a debug-signed bundle on a pull request, which Play would reject but Gradle compiles. `deploy/030` adds the real signing config behind `key.properties`.

## Testing / acceptance criteria

- Every target in requirement 7 exits 0 on `main`.
- Adding `import '../screens/main_screen.dart'` to `lib/src/services/api_logger.dart` makes `make ui-lint-imports` fail.
- Editing `pubspec.yaml` without updating `pubspec.lock` makes `make ui-deps-check` fail.
- A pull request touching only `flutter-ui/lib/` runs `ui`, `build-android`, `build-ios` and skips `go`; both build artifacts are downloadable from the run.
- The `ui` job finishes in under 5 minutes and each build job in under 15 minutes with warm caches.
