---
id: "DEPLOY-020"
status: "DRAFT"
updated: "2026-09-26"
---
# 020 — The deploy button and the release labels

**Status note:** Draft, and narrowed by
[ADR 0009](../../../docs/adr/0009-three-environments-and-one-version-track.md).
The `web` half is gone: `deploy/070` deploys a branch with the `ci:preview-web`
label, which is a better fit than a dispatch — it is per pull request rather
than single-slot, and it tears itself down. What remains here is the mobile
half, the two release labels and the `release` Environment. Requirement 8 is
new and carries the release dispatch that `deploy/060` req 8 defines.

**Complexity:** Small
**Risk:** Low — the button reuses 010's jobs; the only new surface is three boolean inputs and two labels.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [060-versioned-delivery](../060-D-versioned-delivery/spec.md) and [070-preview-environments](../070-D-preview-environments/spec.md), which replaced the superseded [010](../010-Z-deploy-branch-and-release/spec.md)
**Lifecycle class(es) touched:** Disposable.

## Scope

One place to press: `deploy.yml` gains `workflow_dispatch` with three
checkboxes, `web`, `android`, `ios`, run against the branch chosen in the
GitHub UI. The same three outcomes on a merge are selected by the merge
itself (`web`) and by two labels (`android`, `ios`).

Excludes: what the mobile jobs do (030, 040).

## Requirements

1. This spec owns the two mobile `workflow_dispatch` inputs and nothing else: `android` (boolean, default `false`) and `ios` (boolean, default `false`), added **beside** the input that already exists. The ref is the branch the operator picks; no `ref` input. *(Amended twice. ADR 0009 removed a `web` box. Then `deploy/060` req 8 shipped the release half as `bump`, a required choice of patch, minor or major — so the `release` boolean this requirement named is delivered in another shape by a DONE spec, and re-specifying it here would have this spec own a clause its sibling already delivers.)*

1a. `bump` is `required: true` today (`deploy.yml`), so a dispatch that wants only an Android tester build is forced to name a release level it does not want. It MUST become possible to dispatch the mobile boxes without cutting a release. *(Added: the collision in req 1 is not only about who owns the input, it leaves a dispatch shape the operator cannot express.)*
2. `release` on dispatch MUST publish the clean `<version>` for each component whose `Chart.yaml` version is not yet published, and MUST NOT deploy anything. Promotion into `ahorro` stays a pull request against `vk-lab-platform` (`deploy/060` req 9).
3. On a push to `main`, the merge path of `deploy/060` req 5 always runs. `android` runs when the merged pull request carried the label `ci:release-android`, `ios` when it carried `ci:release-ios`. A push event carries no labels, so a first step recovers them with one call, `gh api repos/{owner}/{repo}/commits/{sha}/pulls`, and exposes two boolean outputs. No `pull_request_target`, ever.

3a. **Open decision: what triggers a mobile build on a merge.** Req 3 reads the two labels off the merged pull request. The alternative is the `flutter` path filter of `ci/010` req 2, which already exists in `ci.yml` but gates **pull-request** checks, not a merge release — nothing anywhere triggers a mobile release from a merge by path. The label model is the recommendation: a path filter would push a tester build for every typo fix under `flutter-ui/`, and a tester build costs a store upload and a build number that can never be reused. The labels and the `release` Environment are already created by `make repo-settings` (`ci/010` req 6, delivered) and nothing consumes them yet, so neither model has been built and the choice is still free. *(Added: the operator asked for a merge trigger on Flutter changes and flagged their own uncertainty about it in the same sentence.)*
4. The two mobile jobs MUST be reusable workflows, `mobile-android.yml` and `mobile-ios.yml`, called with `workflow_call` from both paths so the button and the label run identical code.
5. Both mobile jobs MUST declare `environment: release`. The Environment holds every signing secret (030, 040) and allows any branch, so a dispatch from a pull request branch can publish a tester build. Who may dispatch is who may push: collaborators only.
6. `make repo-settings` (ci/010) MUST create the two labels and the `release` Environment; secrets are added by hand once and listed by name in 030 and 040.
7. A dispatch that selects no work MUST fail fast with one message, not run an empty workflow. *(Amended: this said "every box unchecked", which counted three boxes. Two remain here, and the third is `bump`; req 1a is what decides when a dispatch counts as empty.)*

## Implementation hints

- Condition for the merge path: `github.event_name == 'push' && needs.labels.outputs.android == 'true'`; for dispatch: `github.event_name == 'workflow_dispatch' && inputs.android`.
- A reusable workflow inherits nothing; pass `build_number` as an input and secrets with `secrets: inherit`.

## Testing / acceptance criteria

- Actions → deploy → Run workflow shows three checkboxes and the branch picker.
- Dispatch with the mobile boxes unchecked publishes the release and runs no mobile job. *(Amended: this criterion dispatched `web` only and asserted that `origin/deploy` moves. ADR 0009 removed the `web` box, and `deploy/010`, which owned the `deploy` branch, is superseded — the branch no longer exists.)*
- Merging a pull request labelled `ci:release-android` runs `mobile-android` on the resulting push; an unlabelled merge does not.
- A dispatch selecting no work at all fails within seconds with the message.
