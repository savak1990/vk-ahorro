---
id: "DEPLOY-020"
status: "DRAFT"
updated: "2026-09-26"
---
# 020 — The deploy button and the release labels

**Status note:** Draft.

**Complexity:** Small
**Risk:** Low — the button reuses 010's jobs; the only new surface is three boolean inputs and two labels.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [010-deploy-branch-and-release](../010-P-deploy-branch-and-release/spec.md)
**Lifecycle class(es) touched:** Disposable.

## Scope

One place to press: `deploy.yml` gains `workflow_dispatch` with three
checkboxes, `web`, `android`, `ios`, run against the branch chosen in the
GitHub UI. The same three outcomes on a merge are selected by the merge
itself (`web`) and by two labels (`android`, `ios`).

Excludes: what the mobile jobs do (030, 040).

## Requirements

1. `workflow_dispatch` inputs: `web` (boolean, default `true`), `android` (boolean, default `false`), `ios` (boolean, default `false`). The ref is the branch the operator picks; no `ref` input.
2. `web` on dispatch MUST run 010's image, chart and `deploy-branch` jobs from the chosen ref, with the `changes` job comparing against `origin/main` so an unchanged service is not rebuilt. The lab then runs that branch until the next merge, which is the intended single-slot behaviour.
3. On a push to `main`, `web` always runs (010). `android` runs when the merged pull request carried the label `release:android`, `ios` when it carried `release:ios`. A push event carries no labels, so a first step recovers them with one call, `gh api repos/{owner}/{repo}/commits/{sha}/pulls`, and exposes two boolean outputs. No `pull_request_target`, ever.
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
