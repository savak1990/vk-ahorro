---
id: "CORE-090"
status: "DRAFT"
updated: "2026-09-21"
---
# 090 — Local toolchain

**Status note:** Draft. Current machine: docker + buildx, terraform 1.15.9, terragrunt 1.1.5, gh 2.100, yq, Xcode, aws-cli present. Missing: flutter, dart, Java, CocoaPods, Android SDK, yamllint, kubeconform; verify go, helm, kubectl.

**Complexity:** Small
**Risk:** Low — install steps only; the Android SDK licence step is interactive.
**Estimated cost:** ~0.5 day (downloads dominate)
**Recommended model:** Sonnet.
**Depends on:** 000-constitution
**Lifecycle class(es) touched:** None.

## Scope

Everything a fresh macOS (Apple silicon) machine needs to build, test, and
run every part of this repository locally, installed with Homebrew where a
formula or cask exists, and one Make target that proves it.

Excludes: cluster access (the platform's `make kubeconfig`), IDE setup.

## Requirements

1. Homebrew MUST install: `flutter` (cask), `openjdk@17`, `android-commandlinetools` (cask), `cocoapods`, `go`, `golangci-lint`, `helm`, `kubectl`, `kubeconform`, `yamllint`, `argocd`, `jq`. Terraform, Terragrunt, Docker, gh, yq are already present and stay as installed.
2. Android SDK packages via `sdkmanager`: `platform-tools`, `platforms;android-35`, `build-tools;35.0.0`, `emulator`, `system-images;android-35;google_apis;arm64-v8a`; one AVD named `ahorro` created with `avdmanager`. `ANDROID_HOME` and `JAVA_HOME` MUST be exported from the shell profile. Licences accepted with `flutter doctor --android-licenses`.
3. iOS: `sudo xcodebuild -license accept`, `xcodebuild -runFirstLaunch`, the current iOS simulator runtime installed (`xcodebuild -downloadPlatform iOS`).
4. `make tools-check` MUST print the version of every tool above and exit non-zero when one is missing. `make tools-install` MUST run the Homebrew and `sdkmanager` steps and be safe to re-run.
5. `flutter doctor -v` MUST show no red items for Flutter, Android toolchain, Xcode, CocoaPods. Chrome and IDE plugins are optional.
6. Versions MUST be recorded in `docs/toolchain.md` after the first successful run, so later drift is visible.

## Implementation hints

- `brew install --cask flutter` installs to `/opt/homebrew/Caskroom/flutter/...`; `flutter` then lands on PATH through Homebrew's `bin`. `flutter --version` on the first run downloads the Dart SDK.
- `android-commandlinetools` cask puts `sdkmanager` under `/opt/homebrew/share/android-commandlinetools/cmdline-tools/latest/bin`; set `ANDROID_HOME=/opt/homebrew/share/android-commandlinetools`.
- `flutter config --android-sdk $ANDROID_HOME` and `flutter config --jdk-dir $(brew --prefix openjdk@17)` stop `flutter doctor` from looking in `~/Library/Android/sdk`.
- Java 17 matches the Gradle version Flutter's Android template pins today; check `flutter-ui/android/settings.gradle` before choosing another.

## Testing / acceptance criteria

- `make tools-check` exits 0 and lists every tool with a version.
- `flutter doctor -v` shows `[✓]` for Flutter, Android toolchain, Xcode, CocoaPods.
- `emulator -list-avds` shows `ahorro`; `xcrun simctl list runtimes` shows an iOS runtime.
- `cd flutter-ui && flutter pub get` succeeds.
- `go version`, `helm version`, `kubectl version --client`, `kubeconform -v`, `argocd version --client` all print.
