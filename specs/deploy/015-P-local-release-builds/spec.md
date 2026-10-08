---
id: "DEPLOY-015"
status: "DRAFT"
updated: "2026-10-08"
---
# 015 — Local release builds: a signed, installable mobile artifact

**Status note:** Draft, and new. Nothing here needs a store account, a
service account or any money, which is why it is numbered in front of the
deploy button (020) and the two store specs (030, 040) rather than inside
them. `specs/README.md` makes the number the order of work.

It exists because four parts of "build a release and put it on my phone" had
no owning requirement anywhere:

- a release **APK**. `ci/030` req 6 produces an app bundle, and `adb install`
  cannot take one.
- where a built artifact lives. `docs/delivery.md` §5 covers container images
  and Helm charts only; no APK, AAB or IPA appears in the artifact model.
- a build number for a build that no CI run numbered.
- which backend a release build talks to. `deploy/030` req 5 runs
  `make ui-build-aab BUILD_NUMBER=...` with no `ENV`, and the Makefile
  defaults it to `local` — so that requirement, followed exactly, signs and
  uploads an app whose `API_BASE_URL` is `http://localhost:8080`. It installs
  on a tester's phone and does nothing. Requirement 3 below closes it on the
  build target, which covers every caller at once.

**Complexity:** Medium
**Risk:** Medium — a keystore replaced after its first Play upload is a support round trip, and a release build points at the wrong backend silently.
**Estimated cost:** ~0.5 day · Cost: nothing.
**Recommended model:** Sonnet.
**Depends on:** [100-flutter-platforms](../../core/100-P-flutter-platforms/spec.md) for `DEVICE`, [030-flutter-gates](../../ci/030-P-flutter-gates/spec.md) req 6 for `ui-build-aab`
**Lifecycle class(es) touched:** None. The keystore is operator state, held outside Git.

## Scope

One `make` command per step, from a clean tree to a signed, optimized app
installed on the operator's own phone, with no account anywhere. The same
targets are what CI calls later, so getting them right locally is the store
job minus the secrets.

Excludes: the store uploads and their accounts (030, 040); the CI triggers
(020); running a debug build on a device, which is 100 reqs 2a, 2b and 3a;
`ui-build-aab` and `ui-build-ios` themselves, which are `ci/030` req 6.

## Requirements

1. `make ui-build-apk` MUST run `flutter build apk --release` with the mobile
   defines of 080 req 7, and MUST print the output path it wrote. A release
   APK is the only artifact `adb install` accepts; `ci/030` req 6's app bundle
   needs `bundletool` to become installable, and `deploy/030`'s hint argues
   against distributing an APK without owning an alternative for the period
   before a Play account exists. This is that alternative.

2. `make ui-install-android` MUST `adb install -r` the release APK onto the
   target named by `DEVICE` (100 req 2a). The artifact stays on this
   workstation: no upload, no registry, no release asset. Where a **CI** build
   puts its artifact is deliberately left open, and `ci/030` req 7's
   seven-day workflow artifact is the only thing that currently answers it.

3. Every release build target MUST fail unless `ENV` was named on the command
   line, and the message MUST list the four values of 080 req 4a. This applies
   to `ui-build-apk`, and to `ci/030` req 6's `ui-build-aab` and
   `ui-build-ios`. `$(origin ENV)` distinguishes a command-line value
   from the Makefile default, so the check catches a build that never said
   where it points — the `deploy/030` req 5 bug. A debug run keeps the `local`
   default, because the working local loop must not regress.

3a. The intent check of req 3 is not enough on its own, and `local` MUST be
   rejected **by value** for any artifact destined for a store:
   `ui-build-aab` and `ui-build-ipa`. A store build pointed at
   `http://localhost:8080` is never correct, whoever typed it. `ui-build-apk`
   keeps the exemption, because sideloading onto a tethered phone over
   `adb reverse` is a legitimate `ENV=local` case (100 req 2b). *(Added:
   req 3 as first written would have let a Play upload through on an explicit
   `ENV=local`, which is exactly the outcome it claims to prevent.)*

4. `--build-name` MUST be the repository version from `scripts/version.sh`,
   and it MUST always be a clean `x.y.z` triple. This settles the ruling
   `deploy/060` deferred: one version number names the whole repository
   (`deploy/060` req 1), so `flutter-ui/pubspec.yaml`'s `1.0.0` stops being a
   second version track while the tags say `0.2.x`. The triple is not
   optional — iOS `CFBundleShortVersionString` takes one to three
   period-separated integers, so the `-main.<sha>` and `-pr-<n>.<sha>`
   channels `version.sh` also produces would be refused by App Store Connect
   at **upload**, long after a green build. A mobile artifact therefore
   carries no commit identity, and `version.sh base` or the release triple is
   what it gets.

5. A local build MUST keep the `+n` build number committed in
   `flutter-ui/pubspec.yaml`, with no mechanism to make it monotonic. Two
   local builds being indistinguishable costs nothing on either platform, for
   two different reasons: on Android `adb install -r` replaces the installed
   app whatever its `versionCode`, and on iOS a locally installed build never
   meets App Store Connect, which is the only thing that enforces
   uniqueness. Only a store needs a number that never repeats, and that is
   `github.run_number` in `deploy/030` req 6.

6. `flutter-ui/android/app/build.gradle` MUST read `android/key.properties`
   when the file exists and sign `release` with it; when it does not exist,
   `release` MUST keep the debug key, so `flutter run --release` and the
   pull-request build of `ci/030` still work. *(Moved here from `deploy/030`
   req 4, which is amended to point at this spec. The Gradle block needs no
   account and no money, so it belongs in front of the store spec rather than
   inside it.)*

7. The keystore ignore patterns MUST cover the whole repository. Today
   `key.properties`, `**/*.keystore` and `**/*.jks` are ignored by
   `flutter-ui/android/.gitignore` alone, and those patterns are relative to
   that directory — a `.jks` written to the repository root or to
   `flutter-ui/` is **not** ignored. `make domain-check` would not catch it
   either: it looks for the root domain, not for a private key.

8. How the keystore and `key.properties` are created is **an open decision**,
   recorded here rather than settled. The operator asked to understand the
   signing model first. The two candidates:

   8a. By hand, per `deploy/030` req 1's runbook: one `keytool` command,
   copied from the spec, run once. Nothing to maintain and nothing that can
   overwrite a keystore by accident.

   8b. `make android-keystore`, which runs `keytool`, writes
   `key.properties`, and MUST exit 1 when either file already exists. The
   guard is the point, not the convenience — see the hints below for what
   overwriting costs.

   Whichever is chosen, the keystore and its passwords live in a password
   manager and never in Git (`deploy/030` req 1).

## Implementation hints

### What signing actually is, and why the key matters

Android identifies an app by the pair (`applicationId`, signing key). A phone
that installed `com.vkdev1.ahorro` signed with key A refuses an update signed
with key B — not as a warning, as an install failure. The only fix is to
uninstall, which takes the app's data with it.

The Android SDK ships **one debug keystore** shared by every developer on
earth (`~/.android/debug.keystore`, password `android`). That is what
`flutter-ui/android/app/build.gradle` signs `release` with today, on purpose,
so `flutter run --release` works before any of this exists. It is fine for the
operator's own phone. It is rejected by Play, and an app installed from a
debug-signed build cannot later be upgraded by a properly signed one.

### Upload key versus app signing key

With **Play App Signing**, which `deploy/030` req 1 accepts, there are two
keys and they do different jobs:

| Key | Held by | Job | If lost |
|---|---|---|---|
| app signing key | Google | signs what reaches the device | cannot be lost |
| upload key | the operator | proves an upload is from the operator | Google resets it |

Google re-signs every upload with the app signing key, so the key that
actually matters to phones is one the operator never holds and cannot lose.
That is the whole reason to accept Play App Signing.

**Without** it, the upload key *is* the app signing key, and losing it means
the app can never be updated again by anyone, for ever. There is no recovery
and no support path.

### Why a replaced keystore is expensive even with Play App Signing

`keytool -genkey` against a path that already holds a keystore adds an alias
to it; against a new path it creates a new one. Either way, replacing the
upload keystore after Play has registered the first one makes every subsequent
upload fail the signature check until a reset is requested, and a reset is a
support round trip measured in days. That is the cost requirement 8b's guard
buys, and it is why the lazy option here is the one with the extra check.

### The rest

- `flutter build apk --release` writes
  `flutter-ui/build/app/outputs/flutter-apk/app-release.apk`. The app bundle
  goes to `build/app/outputs/bundle/release/app-release.aab`, which `adb` has
  no use for.
- `$(origin ENV)` returns `file` for the Makefile's `ENV ?= local` and
  `command line` for `make ui-build-apk ENV=dev`. `$(error ...)` inside a
  recipe-level `$(if ...)` fires at expansion, so the build never starts.
- One recipe line per target; the logic goes to `scripts/`, which is also
  what lets a workflow call the script directly (`deploy/060` req 11).
- `jarsigner -verify -verbose -certs` names the signer of a built artifact,
  which is how requirement 6's two branches are told apart.

## Testing / acceptance criteria

- `make ui-build-apk ENV=dev` writes `app-release.apk` and prints its path.
  `make ui-build-apk` with no `ENV` exits non-zero, names the four values, and
  starts no build.
- The same guard fires for `make ui-build-aab` and `make ui-build-ios`.
- `make ui-build-aab ENV=local` exits non-zero although `ENV` was named, and
  says a store artifact may not point at this machine. `make ui-build-apk
  ENV=local` builds, because req 3a exempts it.
- `make ui-install-android DEVICE=<serial>` installs that APK, and the app
  signs in against the platform's pool and answers "+" from `ahorro-dev`.
  This is the proof the whole spec exists for.
- `aapt dump badging` on the built APK reports a `versionName` equal to
  `./scripts/version.sh base`, and that string contains no `-` and no `+`.
- `jarsigner -verify -verbose -certs` on the APK names the upload key when
  `android/key.properties` is present, and the Android debug key when it is
  absent. Both cases MUST build.
- A `.jks` file written to the repository root, to `flutter-ui/` and to
  `flutter-ui/android/` is reported by `git check-ignore -v` in all three
  places, each naming the rule that covers it.
- `make ui-test` and `make ui-analyze` stay green. Neither takes a release
  build, so the `ui` job in CI, which has no AWS access, is unaffected.
- `git status` is clean after every target here, which is what `core/100`'s
  last criterion asserts for the web build.
