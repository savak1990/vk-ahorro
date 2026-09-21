---
id: "CORE-100"
status: "DRAFT"
updated: "2026-09-21"
---
# 100 — Flutter on Android, iOS, and web

**Status note:** Draft.

**Complexity:** Medium
**Risk:** Medium — iOS signing and Android minSdk are the usual blockers; Amplify needs minSdk 24 and iOS 13+.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** 080-flutter-config-and-hello, 090-local-toolchain
**Lifecycle class(es) touched:** None.

## Scope

Make the trimmed app run on an Android emulator, an iOS simulator, and
Chrome, each through a Make target, and make the web build servable from
the `web` image locally.

Excludes: store distribution, release signing, real-device provisioning
profiles (documented, not required), the cluster deployment (060).

## Requirements

1. Application id and bundle id MUST be `dev.viacheslav.ahorro` on Android and iOS; display name "Ahorro". `web/index.html` and `web/manifest.json` MUST say "Ahorro", not "ahorro_ui" or "A new Flutter project".
2. Android: `minSdk` ≥ 24, `targetSdk` 35, Kotlin and Gradle versions the current Flutter stable template ships. `make ui-run-android ENV=lab` MUST start the `ahorro` AVD when it is not running and run the app with `--dart-define-from-file=config/lab.json`. `make ui-build-android` produces a debug APK.
3. iOS: `pod install` runs inside `make ui-run-ios`; the target runs on the booted simulator or boots the newest iPhone simulator. Signing team is left empty; the spec documents how to set `DEVELOPMENT_TEAM` for a real device.
4. Web: `make ui-run-web` runs `flutter run -d chrome --web-port 3000` and expects `make go-run` on `:8080` (CORS origin `http://localhost:3000` allowed by default in `go-run`). `make ui-build-web` produces `flutter-ui/build/web`. `make web-serve-local` runs the `web` image on `:8081` with `flutter-ui/web/config.json` mounted.
5. The platform-specific folders `macos/`, `linux/`, `windows/` MUST be deleted; this repository targets three platforms.
6. Every target above MUST be listed in `make help` with its `ENV` variable.

## Implementation hints

- Rename the Android id with `flutter pub run change_app_package_name:main dev.viacheslav.ahorro` or by hand in `android/app/build.gradle`, `AndroidManifest.xml`, and the Kotlin package path; on iOS edit `PRODUCT_BUNDLE_IDENTIFIER` in `Runner.xcodeproj/project.pbxproj`.
- `flutter emulators --launch ahorro` starts the AVD; wait with `adb wait-for-device`.
- For the simulator: `xcrun simctl boot "iPhone 16"` then `flutter run -d "iPhone 16"`.
- Keep `flutter_platform_widgets` `PlatformProvider` defaults so the same code renders Cupertino on iOS and Material elsewhere.

## Testing / acceptance criteria

- `make ui-run-android ENV=lab`: the app opens on the emulator, shows the Authenticator, signs in against the lab pool, shows three tabs and the "+" button.
- `make ui-run-ios ENV=lab`: same on the simulator, with Cupertino tab bar and app-bar "+" action.
- `make ui-run-web` with `make go-run`: same in Chrome with the navigation rail; "+" shows "Hello, anonymous".
- `make ui-build-web && make web-serve-local`: `curl -I localhost:8081/` → 200, `curl localhost:8081/config.json` returns the local file, a deep link `localhost:8081/anything` returns `index.html`.
- `flutter analyze` and `flutter test` still green after the id changes.
- `git status` is clean after `make ui-build-web`. This confirms the ignore rules
  of spec 010, which were verified with `git check-ignore` alone because Flutter
  was not installed then.
