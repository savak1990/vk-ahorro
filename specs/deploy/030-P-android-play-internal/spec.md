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
**Depends on:** [020-mobile-release-channels](../020-P-mobile-release-channels/spec.md), [030-flutter-gates](../../ci/030-P-flutter-gates/spec.md), [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** None here. The Play listing is external state.

## Scope

From a merged or dispatched build to an installable app on a tester's
phone: signing with an upload key, a monotonic build number, and the upload
to the internal testing track, where up to 100 testers install from a link
with no review and no Data Safety form.

Excludes: closed or open testing, production, the 12-tester rule (which
gates production only), store listing content.

## Requirements

1. Runbook, once, by hand, in this order: create the Play Console account ($25, card, identity verification); create the app `com.vkdev1.ahorro`; run `make android-keystore`, which creates the upload key and publishes it to the `release` Environment ([015](../015-D-local-release-builds/spec.md) reqs 8 and 8a) *(Amended: this held the `keytool` command to run by hand. It is a target now, and the hand-run version omitted `-storetype PKCS12` and left the operator to base64 the file themselves.)*; keep the keystore and its passphrase in a password manager as well, never in Git; accept Play App Signing (Google holds the app signing key, the upload key can be reset if lost); build one bundle locally and upload it through the Console to the internal track, because the Play API refuses the first upload; add the testers' emails to the internal list and copy the opt-in link.
2. Service account: in a Google Cloud project, enable the Google Play Android Developer API, create a service account with a JSON key, and invite its email in Play Console with the single permission "Release apps to testing tracks". It MUST NOT hold production release rights.
3. `release` Environment secrets, by name: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `PLAY_SERVICE_ACCOUNT_JSON`. *(Amended twice: the first four are published by `make android-keystore`, [015](../015-D-local-release-builds/spec.md) req 8a, in the same step that creates the key. This requirement named them and left the operator to upload them by hand, which is where a base64 of the wrong file gets in. `PLAY_SERVICE_ACCOUNT_JSON` stays manual: it comes from Google Cloud, not from this repository.*

   *The same four also go to the `mobile-dev` Environment, which [020](../020-P-mobile-release-channels/spec.md) req 5 adds for the merge channel — same key, so a device never needs an uninstall moving between the two. `PLAY_SERVICE_ACCOUNT_JSON` does **not**: only this spec's job uploads, and only `release` carries it, so a merge-channel job that tried to publish would find no credential.)*
4. The Gradle signing config is [015](../015-D-local-release-builds/spec.md) req 6, and the ignore rules its req 7. *(Amended: this requirement held the `key.properties` block. It needs no Play account and no money, so it blocked a local signed build behind a $25 fee for no reason. 015 req 7 also corrects "`key.properties` and `*.jks` are already ignored": the patterns are relative to `flutter-ui/android/`, so a key written anywhere else is not ignored at all.)*
5. `mobile-android.yml` MUST: write the keystore and `key.properties` from the secrets into the workspace; build against `ENV=prod` with the build number of req 6; upload with `r0adkll/upload-google-play` (SHA-pinned) to `tracks: internal`, `status: completed`; delete the keystore file in an `always()` step. *(Partly delivered 2026-10-11 by [020](../020-P-mobile-release-channels/spec.md): the workflow exists and does everything here except the Play upload, which needs the $25 account. The keystore write is `scripts/android-keystore-restore.sh`, not inline, so the same ordering bug cannot be made twice; the `always()` delete is in place. The build is both formats, per 020 req 8, so the AAB this requirement uploads is already produced — the remaining work is one step consuming it.)*
6. The build number is `git rev-list --count HEAD`, computed inside the reusable workflow, which therefore checks out with `fetch-depth: 0`. It is identical in every workflow for the same commit and increases only as `main` grows. *(Amended: it was `github.run_number` of `deploy.yml`, passed in as an input. ADR 0011 split that file in two, and `run_number` is **per workflow file** — `deploy.yml` was near 16 while a new `release.yml` would start at 1, so a prod build would have carried a lower `versionCode` than a dev build already sideloaded and Android would have refused the install as a downgrade. The commit count also removes the rename hazard this requirement used to warn about, and it was already 230 on 2026-10-11, above every `run_number` ever issued, so nothing regresses.)* *(Amended twice. The version name was "the `x.y.z` in `pubspec.yaml`", which contradicted `deploy/060` req 1 — one version number names the whole repository — and would have advertised `1.0.0` for code the pipeline calls `0.2.x`. 015 req 4 settles it: the name is the repository version, always a clean triple. And `ENV=prod` is now explicit above, because without it the Makefile default built a store artifact pointed at `http://localhost:8080`; 015 req 3 makes that failure loud instead.)*
7. The workflow MUST print the run number and the version name into the step summary, so a tester's "which build is this" has an answer.

## Implementation hints

- `signingConfigs { release { ... } }` reads `storeFile file(keystoreProperties['storeFile'])`; the Flutter Android deployment page has the exact block.
- The JSON key is passed as `serviceAccountJsonPlainText`; never write it to a file that survives the job.
- Android developer verification (government id) starts enforcing in some countries from 2026-09-30 for sideloaded apps; Play distribution is unaffected, which is one more reason to use the track rather than an APK link.

## Testing / acceptance criteria

- `make ui-build-aab` on a laptop with `key.properties` present produces a bundle whose signer is the upload key (`apksigner verify --print-certs`); without the file, the debug key. *(Amended: this named `jarsigner`, which reads v1 JAR signatures alone. Measured on the first release APK [015](../015-D-local-release-builds/spec.md) produced: a correctly signed artifact came back as `jar is unsigned`, because the signature is APK Signature Scheme v2 and v3. `apksigner` lives in `$ANDROID_HOME/build-tools/<version>/` and needs a JDK.)*
- A dispatch with `android` checked ends with a new release on the internal track carrying `versionCode` equal to the run number; the tester's phone offers the update from the opt-in link within minutes.
- A second dispatch produces a higher `versionCode`; Play accepts it.
- No step log contains the keystore password or the JSON key (both are masked and never echoed).
