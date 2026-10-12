---
id: "DEPLOY-020"
status: "DRAFT"
updated: "2026-10-11"
---
# 020 — Mobile artifacts on every channel

**Status note:** Draft. The Android half is delivered (2026-10-11); the iOS
half waits on [`deploy/040`](../040-P-ios-testflight/spec.md) req 0.

**This spec changed shape twice, and the second time its premise went.** It was
"the deploy button and the release labels": a `workflow_dispatch` with
checkboxes, plus two labels deciding whether a merge produced a mobile build.
ADR 0009 removed the `web` box. Then ADR 0011 split `deploy.yml` into a merge
workflow and a release workflow, and the remaining question answered itself.

`deploy.yml`'s header states the invariant the whole delivery scheme rests on:
*"Every component is published on every channel, whether or not it changed, so
one number names everything an environment runs."* Android is a component. A
release that published images and charts but no phone artifact would make
`0.2.2` name the web build and nothing installable. So there is **no trigger
surface at all** — no checkbox, no label, no gate. A merge builds dev
artifacts; a release builds prod artifacts; both happen because the channel
happened. Four requirements below are superseded by that one sentence, and the
folder was renamed from `020-P-deploy-button` to match.

**Complexity:** Small
**Risk:** Low — the reusable workflow is the only new surface, and the signing
path is exercised by `deploy/015` locally.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [060-versioned-delivery](../060-D-versioned-delivery/spec.md), [070-preview-environments](../070-D-preview-environments/spec.md) and [015-local-release-builds](../015-D-local-release-builds/spec.md)
**Lifecycle class(es) touched:** Disposable.

## Scope

How a mobile artifact reaches each channel: which workflow builds it, against
which backend, signed with which key, kept for how long. One reusable workflow
serves both channels so the two paths cannot drift.

Excludes: what happens to the artifact afterwards — the Play upload is
[030](../030-P-android-play-internal/spec.md), TestFlight is
[040](../040-P-ios-testflight/spec.md). Also excludes the pull-request build of
[`ci/030`](../../ci/030-P-flutter-gates/spec.md), which proves compilation only.

## Requirements

1. ~~This spec owns the two mobile `workflow_dispatch` inputs.~~ **Superseded.** There are no mobile dispatch inputs. A release builds a mobile artifact because it is a release, the same way it publishes an image for a component whose code did not change. *(Amended three times, and finally removed. ADR 0009 dropped the `web` box; `deploy/060` req 8 delivered the release half as `bump`; and treating mobile as a component removed the remaining two. An input here would let a release publish a version with no phone artifact behind it, which the invariant in the status note forbids.)*

1a. ~~`bump` is `required: true`, so a dispatch that wants only an Android tester build cannot be expressed.~~ **Moot.** There is no mobile-only dispatch: every dispatch is a release and every release builds mobile. The requirement also rested on a wrong reading of the code — `release` is computed from `github.event_name`, never from `bump` — so relaxing `bump` would not have produced the shape it wanted. *(Verified against `deploy.yml` on 2026-10-11, before ADR 0011 moved the job to `release.yml`.)*

2. A release MUST publish the clean `<version>` for every component and MUST NOT deploy anything. Promotion into `ahorro` stays a pull request against `vk-lab-platform` (`deploy/060` req 9). The mobile analogue of that pin is the Play track: the release produces the artifact, and promoting it is a separate human act (030).

3. ~~`android` runs when the merged pull request carried `ci:release-android`.~~ **Superseded, for two independent reasons.** The labels cannot work for a dispatch at all: `gh api repos/{owner}/{repo}/commits/{sha}/pulls` on a commit on `main` returns whichever pull request merged last, so a release would build Android or not by accident. And once mobile is unconditional, nothing needs them. Both labels MUST be removed from `scripts/repo-settings.sh`; `ci:preview-web` stays.

3a. ~~**Open decision: what triggers a mobile build on a merge.**~~ **Answered: nothing does.** Every merge that reaches `deploy.yml` at all builds a dev-pointed artifact. The open decision assumed a merge build would cost a store upload and a build number that can never be reused. It does not: a merge build is an artifact on the run page that nobody uploads. The cost of the label model — a tester build for every typo — was real for *publishing* and is simply absent for *building*. *(Amended 2026-10-11. The first implementation gated this job on the `flutter` path filter, which contradicted the invariant in the status note: on the merge of `deploy/020`'s own follow-up, `images`, `charts` and `deploy-dev` all ran and published `0.2.3-main.e8d4aeb`, while `artifacts-android` skipped — so that version named a deployed backend and no installable build. It was also the only job in either workflow carrying an `if:`. The gate is removed; the filter now decides only whether an image is rebuilt or copied.)*

4. The mobile jobs MUST be reusable workflows called with `workflow_call`, so both channels run identical code. `mobile-android.yml` is delivered. `mobile-ios.yml` waits on `deploy/040` req 0 and MUST join the same way when it lands: unconditional, one call per channel, no input deciding whether it runs.

5. A mobile job MUST declare an `environment:`, because that is the only scope the four signing secrets live in. It MUST NOT be the same Environment on both channels. **`release`** is the store-publishing boundary and is where a protection rule belongs; **`mobile-dev`** carries the merge channel, because a required reviewer on `release` — the obvious thing to add to a store gate — would otherwise stall every merge to `main`. *(Amended: this said both jobs declare `environment: release`, written when there was no merge-channel job to stall. Both Environments hold the **same** key, so a phone never needs an uninstall moving between a merge build and a release build.)*

6. `make repo-settings` MUST create both Environments. `make android-keystore` (`deploy/015` req 8a) MUST publish all four secrets to both. Neither creates a release label any more.

7. ~~A dispatch that selects no work MUST fail fast.~~ **Cannot arise.** A dispatch always publishes every component and always tags, so there is no empty selection. *(Amended twice and then removed: it counted three boxes, then two, and now none exist.)*

8. Both channels MUST build **APK and AAB**. The second format costs seconds — Gradle keeps the native libraries, the resources and the packaging, and only the Dart kernel and the AOT snapshot re-run — so building one format and regretting it is the more expensive choice. What is done with either artifact is decided after it exists, not by the trigger. *(Added 2026-10-11 at the operator's request.)*

9. Neither channel's mobile job MUST carry an `if:`. A merge builds dev artifacts and a release builds prod artifacts because the channel ran, exactly as `charts` republishes and `deploy-dev` upgrades without consulting a filter. The merge channel MUST point at `dev` and keep its artifact **30 days**; the release channel MUST point at `prod` and keep its artifact **90 days**, the repository ceiling. A release artifact has to outlive the decision to publish it.

10. The mobile job MUST hold an AWS role and read its backend configuration from SSM, not from an `FQDN` override. That is the whole difference from `ci/030` req 7a's pull-request build: this artifact names a host that resolves, so it is installable, and that is the only reason it is worth keeping for 30 days. A fork never reaches this workflow — it runs on `push` to `main` and on dispatch, neither of which a fork can trigger.

11. The version name MUST be the repository version passed in by the caller, never computed inside the mobile workflow. `Makefile`'s `VERSION ?=` default runs `version.sh base`, which needs the tag history and **exits 1** without it; on a release it would also compute the wrong number, because only the caller knows the bump. A merge artifact therefore carries `0.2.2-main.<sha>`, which is legal: Android's `versionName` is free text.

12. The release tag MUST NOT be pushed until the mobile artifact exists. `tag` lists `release-android` in its `needs:`, extending the rule already stated above that job — *"the tag is written only after every artifact exists, so a failed publish never leaves a tag naming a version nobody can pull"* — to cover the phone. A broken Android build blocks the release tag.

13. There MUST be one command that puts a CI artifact on a device without building anything: `make ui-install-ci ENV=<dev|prod> [VERSION=<version>] DEVICE=<serial>`. It carries `require-deployed-env`, because no channel produces a `local` artifact. It MUST NOT run `ui-config` and MUST NOT set up an `adb reverse`: nothing is compiled, and a CI artifact never points at this machine. Omitting `VERSION` MUST install the newest build for that backend; naming one MUST install that exact build, so an earlier merge or a particular release is reachable. `VERSION` MUST be treated as unset when it merely holds the `Makefile` default, which is the repository version and names no artifact. It MUST report which version it installed, and on failure it MUST list what is installable. A second target, `make ui-list-ci`, MUST print that list on demand. *(Added 2026-10-11. Without it the flow was: open the run page, find the artifact, download, unzip, locate the APK, `adb install -r` by hand.)*

13a. The workflow MUST name the artifact files `ahorro-<env>-<version>.apk` and `.aab`, and MUST collect them in one directory before upload. Flutter calls both `app-release`, on every backend and every version; the artifact name carries the difference and is lost the moment anybody extracts the zip or forwards the file to a tester, which is exactly the sideload flow these builds exist for. Collecting them also flattens the artifact, because `upload-artifact` otherwise keeps the common prefix of the two source paths and the APK lands under `flutter-apk/`. *(Added 2026-10-11, after the first artifact shipped with two anonymous `app-release` files in a build tree. The installer reads the version from the artifact directory rather than the file, so it keeps working for artifacts built before this.)*

## Implementation hints

- A reusable workflow inherits no `permissions`; each caller grants `contents: read` and `id-token: write`, and the called workflow declares its own.
- `secrets: inherit` is narrow here rather than broad: `gh secret list` is empty, so the repository holds no repository-level secrets, and Environment secrets reach only a job that names that Environment.
- `scripts/android-keystore-restore.sh` is the CI mirror of `android-keystore.sh`. `umask 177` goes **before** the first write, or the keystore is created world-readable and chmod is too late.
- `apksigner verify --print-certs` is the check. `jarsigner` reads v1 JAR signatures only and reports a correctly signed release APK as `jar is unsigned`.

## Testing / acceptance criteria

- `scripts/android-keystore-restore.sh` with a throwaway keystore writes both files mode 600, and the APK built after it is signed by the throwaway certificate rather than `CN=Android Debug`. *(Verified 2026-10-11: `V2 Signer: certificate DN: CN=throwaway, …`.)*
- `make ui-build-apk VERSION=9.9.9 BUILD_NUMBER=4242` produces an APK that `aapt2 dump badging` reports as `versionCode='4242' versionName='9.9.9'`. *(Verified 2026-10-11. Before this spec, `ui-build-apk` ignored `BUILD_NUMBER` entirely and only `ui-build-aab` passed it.)*
- **Any** merge that starts `deploy.yml` produces a run with `artifacts-android`, uploading `ahorro-android-dev-<version>` containing both an APK and an AAB. *(Verified 2026-10-11 on the merge of this spec's own pull request: `ahorro-android-dev-0.2.2-main.8e7138f`, 93MB, expiring in 30 days. The APK inside reports `V2 Signer: certificate DN: CN=Ahorro, O=Ahorro, C=ES` — the real upload key, not `CN=Android Debug` — with `versionCode='233'` and `versionName='0.2.2-main.8e7138f'`.)*
- `make ui-install-ci ENV=dev` downloads that artifact and installs it, naming the version. `VERSION=<v>` installs that exact build instead. Both fail with a readable message, and a list of what is installable, when no such artifact exists or it has expired. *(Amended 2026-10-11 after a second dev artifact existed. `gh run download --pattern` does **not** mean newest: it keeps the newest run per artifact **name**, and every version is its own name, so a pattern downloaded every unexpired build and left the choice to whichever `find` hit first - the older one. The newest is resolved from the artifacts API by `created_at` and then fetched by exact name, so both paths now download exactly one artifact. A single `--name` extracts into the root with no artifact directory, so the resolved name is also the only record of which build it is.)*
- `make ui-list-ci` prints one group per channel, dev then prod, each with the 20 newest unexpired builds as a bare version and a build date, read from every page of the artifacts API; `ENV=dev` or `ENV=prod` prints that group alone. The bare version is what `VERSION=` takes. *(Verified 2026-10-11; amended 2026-10-12. One page holds the newest 100 artifacts of any kind, and the repository already had 124, so the pull-request builds would have pushed mobile ones off the list.)*
- That APK installs over the build already on the device with **no uninstall**, which is the proof the key matched, and the running app reports the dev host.
- A `workflow_dispatch` asks for a bump level and nothing else, runs `release-android`, and `tag` does not start until it finishes.
- The prod artifact's `versionCode` is higher than the dev artifact's from an earlier merge, so a release installs over a merge build rather than being refused as a downgrade.
