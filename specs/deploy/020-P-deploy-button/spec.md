---
id: "DEPLOY-020"
status: "DRAFT"
updated: "2026-09-26"
---
# 020 — The deploy button and the release labels

**Status note:** Draft, and narrowed by
[ADR 0009](../../../docs/adr/0009-three-environments-and-one-version-track.md).
The `web` half is gone: `deploy/070` deploys a branch with the `preview`
label, which is a better fit than a dispatch — it is per pull request rather
than single-slot, and it tears itself down. What remains here is the mobile
half, the two release labels and the `release` Environment. Requirement 8 is
new and carries the release dispatch that `deploy/060` req 8 defines.

**Complexity:** Small
**Risk:** Low — the button reuses 010's jobs; the only new surface is three boolean inputs and two labels.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [060-versioned-delivery](../060-A-versioned-delivery/spec.md) and [070-preview-environments](../070-P-preview-environments/spec.md), which replaced the superseded [010](../010-Z-deploy-branch-and-release/spec.md)
**Lifecycle class(es) touched:** Disposable.

## Scope

One place to press: `deploy.yml` gains `workflow_dispatch` with three
checkboxes, `web`, `android`, `ios`, run against the branch chosen in the
GitHub UI. The same three outcomes on a merge are selected by the merge
itself (`web`) and by two labels (`android`, `ios`).

Excludes: what the mobile jobs do (030, 040).

## Requirements

1. `workflow_dispatch` inputs: `release` (boolean, default `true`), `android` (boolean, default `false`), `ios` (boolean, default `false`). The ref is the branch the operator picks; no `ref` input. *(Amended by ADR 0009: the input was `web` and meant "deploy this branch to the lab". Deploying a branch is now the `preview` label of `deploy/070`, so the box that remains publishes the clean release version per `deploy/060` req 8.)*
2. `release` on dispatch MUST publish the clean `<version>` for each component whose `Chart.yaml` version is not yet published, and MUST NOT deploy anything. Promotion into `ahorro` stays a pull request against `vk-lab-platform` (`deploy/060` req 9).
3. On a push to `main`, the merge path of `deploy/060` req 5 always runs. `android` runs when the merged pull request carried the label `release:android`, `ios` when it carried `release:ios`. A push event carries no labels, so a first step recovers them with one call, `gh api repos/{owner}/{repo}/commits/{sha}/pulls`, and exposes two boolean outputs. No `pull_request_target`, ever.
4. The two mobile jobs MUST be reusable workflows, `mobile-android.yml` and `mobile-ios.yml`, called with `workflow_call` from both paths so the button and the label run identical code.
5. Both mobile jobs MUST declare `environment: release`. The Environment holds every signing secret (030, 040) and allows any branch, so a dispatch from a pull request branch can publish a tester build. Who may dispatch is who may push: collaborators only.
6. `make repo-settings` (ci/010) MUST create the two labels and the `release` Environment; secrets are added by hand once and listed by name in 030 and 040.
7. A dispatch with every box unchecked MUST fail fast with one message, not run an empty workflow.

## Implementation hints

- Condition for the merge path: `github.event_name == 'push' && needs.labels.outputs.android == 'true'`; for dispatch: `github.event_name == 'workflow_dispatch' && inputs.android`.
- A reusable workflow inherits nothing; pass `build_number` as an input and secrets with `secrets: inherit`.

## Testing / acceptance criteria

- Actions → deploy → Run workflow shows three checkboxes and the branch picker.
- Dispatch on a feature branch with `web` only: `origin/deploy` moves to that branch's head plus one commit; the lab serves it.
- Merging a pull request labelled `release:android` runs `mobile-android` on the resulting push; an unlabelled merge does not.
- Dispatch with all three unchecked fails within seconds with the message.
