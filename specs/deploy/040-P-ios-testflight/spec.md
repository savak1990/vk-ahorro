---
id: "DEPLOY-040"
status: "DRAFT"
updated: "2026-09-26"
---
# 040 — iOS: signed build to the TestFlight internal group

**Status note:** Draft. The Apple Developer Program membership does not exist
yet; enrollment comes first and can take days.

**Complexity:** Medium
**Risk:** Medium — code signing on a runner is the classic failure point; manual signing with a committed export options file is the most predictable form.
**Estimated cost:** ~1 day plus enrollment time · Cost: $99 per year.
**Recommended model:** Sonnet.
**Depends on:** [020-deploy-button](../020-P-deploy-button/spec.md), [030-flutter-gates](../../ci/030-P-flutter-gates/spec.md), [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** None here. The App Store Connect record is external state.

## Scope

From a merged or dispatched build to an installable app in a tester's
TestFlight: a distribution certificate and profile held as secrets, a
manual-signing export, and the upload to an internal group (up to 100 App
Store Connect users, no Beta App Review).

Excludes: external TestFlight groups and Beta App Review, App Store
submission, Xcode Cloud.

## Requirements

1. Runbook, once, by hand: enroll as an individual (legal name, two-factor Apple ID); create the app record for `com.vkdev1.ahorro` in App Store Connect; create an App Store Connect API key with the App Manager role and download the `.p8` once; create an Apple Distribution certificate and export it as `.p12` with a password; create an App Store provisioning profile for the bundle id; create an internal tester group and add the testers as App Store Connect users.
2. `release` Environment secrets, by name: `APPSTORE_ISSUER_ID`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_PRIVATE_KEY` (the `.p8` text), `IOS_DIST_CERT_BASE64`, `IOS_DIST_CERT_PASSWORD`, `IOS_PROFILE_BASE64`.
3. `flutter-ui/ios/ExportOptions.plist` MUST be committed with `method: app-store-connect`, `signingStyle: manual`, `teamID`, and the profile name for the bundle id. The team id is already in the Xcode project and is a public identifier; core 100 req 3's "team is left empty" is amended by this spec.
4. `make ui-build-ipa` runs `flutter build ipa --release --export-options-plist=ios/ExportOptions.plist` and accepts `BUILD_NUMBER=`.
5. `mobile-ios.yml` on `macos-latest` MUST: import the certificate into a temporary keychain with `apple-actions/import-codesign-certs` (SHA-pinned); install the profile under `~/Library/MobileDevice/Provisioning Profiles/`; run `make ui-build-ipa BUILD_NUMBER=${{ github.run_number }}`; upload with `apple-actions/upload-testflight-build` (SHA-pinned, default App Store Connect API backend) using the three `APPSTORE_*` secrets; remove the keychain and the profile in an `always()` step.
6. The build number rule is 030 req 6: `github.run_number` of `deploy.yml`, passed in as an input, shared by both stores, so one run yields one number on both. The rename hazard is the same.
7. The step summary MUST print the build number and the version name.

## Implementation hints

- The pull-request build (ci/030) uses `--no-codesign` and needs none of this.
- `apple-actions/upload-testflight-build` with `wait-for-processing: true` makes the job wait until the build is visible to testers; leave it off for a faster job and check the App Store Connect email.
- Xcode 26 gotcha: when several apps share a bundle-id prefix, pass the numeric app id to the uploader.

## Testing / acceptance criteria

- `make ui-build-ipa` on a laptop with the certificate and profile installed produces `build/ios/ipa/*.ipa`.
- A dispatch with `ios` checked ends with a build in TestFlight under the internal group, build number equal to the run number; a tester's phone shows it in the TestFlight app.
- A second dispatch produces a higher build number; App Store Connect accepts it.
- No step log contains the certificate password or the `.p8`.
