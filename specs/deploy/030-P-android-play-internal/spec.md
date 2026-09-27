---
id: "DEPLOY-030"
status: "DRAFT"
updated: "2026-09-26"
---
# 030 — Android: signed bundle to the Play internal testing track

**Status note:** Draft. The account does not exist yet; the first
requirements are a runbook, and nothing in CI can be verified before it is
done.

**Complexity:** Medium
**Risk:** Medium — Play rejects a reused `versionCode` and a bundle signed with the wrong key; both are caught on the first upload, not in CI.
**Estimated cost:** ~1 day plus account verification time · Cost: $25 once.
**Recommended model:** Sonnet.
**Depends on:** [020-deploy-button](../020-P-deploy-button/spec.md), [030-flutter-gates](../../ci/030-P-flutter-gates/spec.md), [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** None here. The Play listing is external state.

## Scope

From a merged or dispatched build to an installable app on a tester's
phone: signing with an upload key, a monotonic build number, and the upload
to the internal testing track, where up to 100 testers install from a link
with no review and no Data Safety form.

Excludes: closed or open testing, production, the 12-tester rule (which
gates production only), store listing content.

## Requirements

1. Runbook, once, by hand, in this order: create the Play Console account ($25, card, identity verification); create the app `com.vkdev1.ahorro`; generate the upload keystore locally with `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`; keep the keystore and its passwords in a password manager, never in Git; accept Play App Signing (Google holds the app signing key, the upload key can be reset if lost); build one bundle locally and upload it through the Console to the internal track, because the Play API refuses the first upload; add the testers' emails to the internal list and copy the opt-in link.
2. Service account: in a Google Cloud project, enable the Google Play Android Developer API, create a service account with a JSON key, and invite its email in Play Console with the single permission "Release apps to testing tracks". It MUST NOT hold production release rights.
3. `release` Environment secrets, by name: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`.
4. `flutter-ui/android/app/build.gradle` MUST read `android/key.properties` when the file exists and sign `release` with it; when it does not exist, `release` keeps the debug key so `flutter run --release` and the pull-request build (ci/030) still work. `key.properties` and `*.jks` are already ignored.
5. `mobile-android.yml` MUST: write the keystore and `key.properties` from the secrets into the workspace; run `make ui-build-aab BUILD_NUMBER=${{ github.run_number }}`; upload with `r0adkll/upload-google-play` (SHA-pinned) to `tracks: internal`, `status: completed`; delete the keystore file in an `always()` step.
6. The build number is `github.run_number` of `deploy.yml`, passed into the reusable workflow as an input and never read there: inside a `workflow_call` the context belongs to the caller, and `deploy.yml` is the one file that runs on every merge and every dispatch, so its number increases and never repeats. Renaming `deploy.yml` resets the counter to 1 and Play rejects the next upload; a rename needs a one-time offset. The version name stays the `x.y.z` in `pubspec.yaml`; bumping it is a normal pull request.
7. The workflow MUST print the run number and the version name into the step summary, so a tester's "which build is this" has an answer.

## Implementation hints

- `signingConfigs { release { ... } }` reads `storeFile file(keystoreProperties['storeFile'])`; the Flutter Android deployment page has the exact block.
- The JSON key is passed as `serviceAccountJsonPlainText`; never write it to a file that survives the job.
- Android developer verification (government id) starts enforcing in some countries from 2026-09-30 for sideloaded apps; Play distribution is unaffected, which is one more reason to use the track rather than an APK link.

## Testing / acceptance criteria

- `make ui-build-aab` on a laptop with `key.properties` present produces a bundle whose signer is the upload key (`jarsigner -verify -verbose`); without the file, the debug key.
- A dispatch with `android` checked ends with a new release on the internal track carrying `versionCode` equal to the run number; the tester's phone offers the update from the opt-in link within minutes.
- A second dispatch produces a higher `versionCode`; Play accepts it.
- No step log contains the keystore password or the JSON key (both are masked and never echoed).
