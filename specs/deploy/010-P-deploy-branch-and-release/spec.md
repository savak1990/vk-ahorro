---
id: "DEPLOY-010"
status: "DRAFT"
updated: "2026-09-26"
---
# 010 — The `deploy` branch and release on merge

**Status note:** Draft. Replaces core 060 requirement 8 (the `[skip ci]`
commit to `main`) and core 030 requirement 6's `release.yml`. See
[ADR 0007](../../../docs/adr/0007-argo-tracks-a-bot-owned-deploy-branch.md).

**Complexity:** Medium
**Risk:** Medium — a wrong values commit deploys nothing; a force-push to the wrong branch rewrites history. The branch name is a constant and `main` is protected.
**Estimated cost:** ~1 day
**Recommended model:** Opus for the workflow, Sonnet for the script.
**Depends on:** [010-change-aware-checks](../../ci/010-P-change-aware-checks/spec.md), [060-gitops-and-platform-link](../../core/060-A-gitops-and-platform-link/spec.md), [105-web-delivery](../../core/105-A-web-delivery/spec.md)
**Lifecycle class(es) touched:** Persistent (GHCR packages); Disposable (what Argo creates from the new tags).

## Scope

How a merged pull request becomes a running deployment with no human step
and no cluster credential: build what changed, push it, write the SHAs into
`gitops/values.yaml`, and publish that as the `deploy` branch Argo tracks.

Excludes: the button and the labels (020); mobile artifacts (030, 040);
verification after the push (050).

## Requirements

1. `.github/workflows/deploy.yml` replaces `release.yml`. The merge path triggers on `push` to `main`, so `github.sha` is always the new tip and the ref exists; a `pull_request: closed` trigger would run against a head branch that `delete_branch_on_merge` removes, and two merges a minute apart would race for `deploy`. The `v*` tag trigger is dropped, nothing used it. `workflow_dispatch` is added by 020.
2. `main` is protected (ci/010), so nothing MUST ever commit to it from a workflow. Branch protection with required checks rejects a push whose commits carry no passing check run, and `enforce_admins` removes the bypass.
3. Argo's pointer in the platform MUST track `targetRevision: deploy` (amends core 060 req 5, where it said `main`). `deploy` is owned by the workflow: force-pushed, never protected, never edited by hand.
4. `gitops/values.yaml` on `main` MUST keep `services.ahorro-api.tag: ""` and `web.tag: ""`. `gitops/templates/validate.yaml` MUST `fail` when any image tag is empty, the way it fails on an empty `fqdn` (core 060 req 2), so `main` can never render.
5. A `changes` job MUST run `dorny/paths-filter` with `base: main`, which on a push compares against the commit before the push, and the `go`, `flutter`, `helm` filters from ci/010. `image-api` runs on `go`, `image-web` on `flutter`, `charts` on `helm`. Each image is pushed as `<service>:<merge sha>` and `<service>:main` (core 030 rules). A chart is pushed only when its folder changed, because a published version is immutable.
6. A final job `deploy-branch` MUST carry `concurrency: {group: deploy-branch, cancel-in-progress: false}` so two runs never interleave their pushes. It MUST: check out `main` at the merge commit; read the current tags from `origin/deploy`'s `gitops/values.yaml`; overwrite only the tags whose image was built in this run; commit with the message `Deploy ahorro-api@<sha> ahorro-web@<sha> from #<pr>` listing every tag; force-push the result to `deploy`. On the first run, when `deploy` does not exist, a missing tag is an error, not an empty string.
7. Permissions: `contents: write` on `deploy-branch` only, `packages: write` on the image and chart jobs, nothing else, no AWS. `persist-credentials: false` on every checkout except the one that pushes.
8. `scripts/deploy-branch.sh` MUST hold the Git logic and MUST be runnable from a laptop with `IMAGE_TAG_API=`/`IMAGE_TAG_WEB=`, so a hand deploy uses the same code. `make deploy-branch` wraps it.

## Implementation hints

- Reading a file from another branch without checking it out: `git fetch origin deploy` then `git show origin/deploy:gitops/values.yaml`; a default shallow checkout has no `origin/deploy`. `git ls-remote --exit-code origin deploy` first, to tell a missing branch (first run) from a failed fetch.
- The commit author is the workflow token's bot identity; the message carries the pull request number, which is the audit trail.
- Rollback is `git push --force origin <previous deploy sha>:deploy`, documented in the script's usage line.

## Testing / acceptance criteria

- Merging a pull request that touched only `internal/` produces one `deploy.yml` run in which `image-web` and `charts` are skipped, and `git log origin/deploy -1` shows a commit on top of the merge with only `services.ahorro-api.tag` changed.
- `git diff main origin/deploy` shows exactly the two tag lines.
- `helm template gitops` on `main` fails with the empty-tag message; on `deploy` it renders.
- After the platform's `make up`, `argocd app get vk-ahorro` reports the `deploy` revision and the pods run the merge SHA.
- `make deploy-branch IMAGE_TAG_API=<sha>` from a laptop produces the same commit shape.
