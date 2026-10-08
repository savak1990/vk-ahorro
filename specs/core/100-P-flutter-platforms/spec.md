---
id: "CORE-100"
status: "DRAFT"
updated: "2026-10-08"
---
# 100 — Flutter on Android, iOS, and web

**Status note:** Partially delivered. Requirements 1, 2 and 5 are done, and
4 is done except `make web-serve-local`.

The `--dart-define-from-file=config/$(ENV).json` argument landed with 080 on
2026-10-08, and `ENV` now exists with the four values 080 req 4a names. That
makes requirement 6 meetable: before it, `ENV` appeared in this spec and
nowhere in the Makefile, so no target could list a variable that did not
exist. Requirement 6 is done.

The two sign-in acceptance checks are done (2026-10-08), on the operator's own
devices, together with 080's.

Still open: `make web-serve-local`, which runs the `web` image that 105
delivers; requirements 2a, 2b and 3a, which are new here and carry the real
device; and one older gap found while writing them - requirement 3's
`flutter build ios --config-only --no-codesign` before `pod install` is in
neither the target nor `scripts/ios-simulator.sh`. The simulator works anyway,
because a previous build left `Generated.xcconfig` behind, so this bites on a
fresh clone alone.

**Complexity:** Medium
**Risk:** Medium — iOS signing and Android minSdk are the usual blockers; Amplify needs minSdk 24 and iOS 13+.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** 080-flutter-config-and-hello, 090-local-toolchain
**Lifecycle class(es) touched:** None.

## Scope

Make the trimmed app run on an Android emulator, an iOS simulator, a real
Android or iOS device, and Chrome, each through a Make target, and make the
web build servable from the `web` image locally.

Excludes: store distribution, release signing and the local release build
flow (015), the cluster deployment (060). *(Amended: real devices were
excluded as "provisioning profiles, documented, not required". A device
pointed at a deployed backend is the only way to exercise mobile against real
infrastructure, and it needs no provisioning profile on Android at all, so the
run belongs here beside the emulator. Release signing stays out.)*

## Requirements

1. Application id and bundle id MUST be `com.vkdev1.ahorro` on Android and iOS, and the iOS test target `com.vkdev1.ahorro.RunnerTests`; display name "Ahorro". `web/index.html` and `web/manifest.json` MUST say "Ahorro", not "ahorro_ui" or "A new Flutter project".
2. Android: `minSdk` MUST be at least 24 and `targetSdk` MUST be 35. The Gradle, Android Gradle Plugin and Kotlin versions MUST be Gradle 9.3.1, AGP 9.1.0 and Kotlin 2.2.20.
   - The imported project carried Gradle 8.10.2. It cannot run under the Java 25 that Android Studio now bundles, and the build fails with "Unsupported class file major version 69". Upgrading the wrapper fixes it for every developer; pinning the toolchain back to Java 17 only moves the problem onto each machine.
   - Kotlin 2.2.20 is the one deviation from the current Flutter template, which ships 2.4.0. The Amplify plugins apply their own Kotlin Gradle Plugin, and 2.4.0's build-tools API then fails with `NoClassDefFoundError: kotlin/concurrent/atomics/AtomicsKt`. Revisit when Amplify supports Flutter's built-in Kotlin, which the build already warns about.
   - `make ui-run-android` MUST run the app on the target named by `DEVICE`, starting an emulator when it is not already attached. `make ui-build-android` MUST produce a debug APK. *(Amended: the variable was `AVD` and named an emulator only. See 2a.)*
2a. `DEVICE` MUST select the Android target and accept either an AVD name or an `adb` serial, so one variable names an emulator or a handset and `make help` carries one line. `AVD` MUST keep working as an alias for the emulator case. `scripts/android-emulator.sh` MUST pass a serial through unchanged: it filters `adb devices` through `awk '/^emulator-/'`, so a handset's serial never matches and the script launches an emulator instead of using the attached phone. *(Added: nothing owned a physical device, and the emulator-only assumption is in the script, not just in the prose.)*

2b. With a handset, `make ui-run-android` MUST run `adb reverse tcp:$(PORT) tcp:$(PORT)`, and `API_BASE_URL` for `ENV=local` MUST then be `http://localhost:$(PORT)`. The reverse forward makes the phone's own loopback reach this machine, so the device uses the same address iOS already uses and 080 req 4a needs no new value. `10.0.2.2` is the emulator's alias for the host and resolves to nothing on a phone, so it MUST apply to the emulator case alone. *(Added: `ENV=local` on a real phone was broken by construction, silently - the client built, started, and reached nothing.)*

3. iOS: `make ui-run-ios` MUST run `flutter build ios --config-only --no-codesign` before `pod install`, because CocoaPods reads `ios/Flutter/Generated.xcconfig` and only a build writes it. The target runs on the booted simulator, or boots the one named by `IOS_DEVICE`. *(Amended: this said the signing team is left empty. `ios/Runner.xcodeproj` carries `DEVELOPMENT_TEAM = 47Y43AMN4K` with `CODE_SIGN_STYLE = Automatic`, which deploy/040 req 3 already noted in writing while this spec, the one a reader reaches first, kept the stale claim. A committed team id proves a team exists; it does not prove a paid Developer Program membership, which deploy/040 req 0 checks.)*
3a. `DEVICE` MUST also select the iOS target, taking a device id or name from `flutter devices`, so one variable covers the simulator and a real iPhone. iOS has no `adb reverse` equivalent, so `ENV=local` with a physical iPhone MUST fail with one message naming a deployed `ENV`, rather than build a client that can reach nothing. *(Added: the same gap as 2a, on the platform where the workaround does not exist.)*

4. Web: `make ui-run-web` runs `flutter run -d chrome --web-port 3000` and expects `make go-run` on `:8080` (CORS origin `http://localhost:3000` allowed by default in `go-run`). `make ui-build-web` produces `flutter-ui/build/web`. `make web-serve-local` runs the `web` image on `:8081` with `flutter-ui/web/config.json` mounted.
5. The platform-specific folders `macos/`, `linux/`, `windows/` MUST be deleted; this repository targets three platforms.
6. Every target above MUST be listed in `make help` with its `ENV` variable. `ui-build-web` is the exception: it produces a bundle the `web` chart configures at runtime, so it takes no backend. *(Amended twice: `ENV` did not exist when this was written, and a first pass exempted both web targets while `ENV` steered mobile alone. 080 req 4b now makes `ui-run-web ENV=<env>` work too.)*

## Implementation hints

- Rename the Android id with `flutter pub run change_app_package_name:main dev.viacheslav.ahorro` or by hand in `android/app/build.gradle`, `AndroidManifest.xml`, and the Kotlin package path; on iOS edit `PRODUCT_BUNDLE_IDENTIFIER` in `Runner.xcodeproj/project.pbxproj`.
- `flutter emulators --launch pixel_phone` starts the AVD; wait with `adb wait-for-device`. *(Amended: this named an AVD `ahorro`, as did 090 req 2. The committed default is `pixel_phone`, and a spec that names an AVD nobody created is a spec that fails on the first run.)*
- A handset shows up in `adb devices` with its own serial, never `emulator-*`, and in `flutter devices` with a name. `adb reverse tcp:8080 tcp:8080` is per-device and survives a `flutter run` restart but not a replug.
- For the simulator: `xcrun simctl boot "iPhone 16"` then `flutter run -d "iPhone 16"`.
- Keep `flutter_platform_widgets` `PlatformProvider` defaults so the same code renders Cupertino on iOS and Material elsewhere.

## Testing / acceptance criteria

- `make ui-run-android ENV=dev`: the app opens on the emulator, shows the Authenticator, signs in against the platform's pool, shows three tabs and the "+" button. *(Amended: `ENV=lab` named the one deployed backend that existed; see 080 req 4a.)*
- `make ui-run-ios ENV=dev`: same on the simulator, with Cupertino tab bar and app-bar "+" action.
- `make ui-run-android DEVICE=<serial> ENV=dev` on a USB-attached phone: the same sign-in and the same answer, with no emulator started.
- `make ui-run-android DEVICE=<serial>` with `make go-run`: `adb reverse` is in place and "+" is answered by this machine. The same command with `DEVICE` naming an AVD still reaches `10.0.2.2`.
- `make ui-run-ios DEVICE=<id>` with `ENV=local` fails and names a deployed `ENV`. It does not start a build.
- `make help` lists `$ENV` on `ui-config`, `ui-run-android`, `ui-run-ios` and `ui-build-android`, and `$DEVICE` on the two run targets. *(The `$ENV` half verified 2026-10-08.)*
- `make ui-run-web` with `make go-run`: same in Chrome with the navigation rail; "+" shows "Hola, anonymous".
- `make ui-run-web ENV=dev`: the Authenticator in Chrome, sign-in against the platform's pool, and "+" answering from `ahorro-dev` with no CORS error.
- `make ui-build-web && make web-serve-local`: `curl -I localhost:8081/` → 200, `curl localhost:8081/config.json` returns the local file, a deep link `localhost:8081/anything` returns `index.html`.
- `flutter analyze` and `flutter test` still green after the id changes.
- `git status` is clean after `make ui-build-web`. This confirms the ignore rules
  of spec 010, which were verified with `git check-ignore` alone because Flutter
  was not installed then.
