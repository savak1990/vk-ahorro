---
id: "CI-010"
status: "DRAFT"
updated: "2026-09-26"
---
# 010 — Change-aware checks and branch protection

**Status note:** Draft. First spec of the `ci/` group; every other `ci/` and
`deploy/` spec adds jobs to the workflow this one shapes.

**Complexity:** Small
**Risk:** Low — a wrong filter skips a check silently; the acceptance list covers each filter with a one-file pull request.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [030-images-and-registry](../../core/030-D-images-and-registry/spec.md), [040-helm-charts](../../core/040-D-helm-charts/spec.md), [070-flutter-shell-trim](../../core/070-D-flutter-shell-trim/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

The shape of `.github/workflows/ci.yml`: which paths start which jobs, the
one status check `main` requires, and the repository settings that make
squash-and-merge the only way onto `main`.

Excludes: what each job checks (020 Go, 030 Flutter, 040 hermetic e2e);
anything that runs after a merge (`deploy/`).

## Requirements

1. `ci.yml` MUST keep a single `pull_request` trigger with no workflow-level `paths` or `paths-ignore`. A skipped workflow leaves a required check pending forever; a job skipped by `if:` reports success.
2. A first job `changes` MUST run `dorny/paths-filter` v4.0.3, pinned to commit `ceb8a2b8f2d89434be7ff52d3de7ec3738c5cc9d` (core 030 req 8), with exactly these filters: `go` = `cmd/**`, `internal/**`, `go.mod`, `go.sum`, `.golangci.yml`, `deploy/docker/ahorro-api.Dockerfile`; `flutter` = `flutter-ui/**`, `deploy/docker/ahorro-web.Dockerfile`, `deploy/docker/ahorro-web.nginx.conf`, `deploy/docker/ahorro-web.Dockerfile.dockerignore`; `helm` = `deploy/helm/**`; `gitops` = `gitops/**`; `workflows` = `.github/**`. Every other job carries `needs: changes` and an `if:` on one or more outputs:

   | Job | Runs when |
   |---|---|
   | `go` | `go` |
   | `image-api` | `go` |
   | `image-web` | `flutter` |
   | `ui` | `flutter` |
   | `helm` | `helm` |
   | `gitops` (`make gitops-lint gitops-check`, core 060 req 7) | `gitops` |
   | `repo` | always |
   | `workflows` (`actionlint`) | `workflows` |
   | `ci-ok` | always |

   Two corrections from reading the Dockerfiles. The `flutter` filter above gains the nginx config and the dockerignore, which `deploy/docker/ahorro-web.Dockerfile` consumes — without them an nginx-only change skips `image-web`. And the `workflows` filter was defined with no job reading it, so the new `workflows` job consumes it: a workflow edit is checked and a docs-only change is not.

3. `repo` MUST run `make specs-check` and `make domain-check`; it is the only job that needs the OIDC token, so it stays the job that fails on a fork (CLAUDE.md, CI rules). `actionlint` is **new to this repository** — an earlier draft of this requirement said it "moves out of `repo`", which was wrong: it ran nowhere. It arrives as its own job on the `workflows` filter, per the table above. It MUST be installed as a released binary verified against a pinned `SHA256`, the shape the `helm` job already uses for kubeconform, rather than as a third-party action (CLAUDE.md: prefer no new tool dependency in CI).
4. `ci-ok` MUST declare `needs:` on every other job, run with `if: always()`, and exit non-zero when any `needs.*.result` is `failure` or `cancelled`. A `skipped` result passes. It MUST be the **only** required status check on `main`; the four contexts required today (`go`, `image`, `repo`, `helm`) are removed from the list, and a job rename never touches protection again.
5. Branch protection on `main` MUST require `ci-ok`, keep `enforce_admins`, linear history, no force-push and no deletion, and require zero approvals: the repository has one or two developers. Squash is already the only merge method and the branch is deleted on merge; the spec records both as required.
6. Protection, labels — including `preview`, which `deploy/070` needs and without which the preview workflow has no trigger — and the `release` Environment (`deploy/020`) MUST be applied by `make repo-settings`, a one-line target calling `scripts/repo-settings.sh`, which uses `gh api` and is idempotent. A setting clicked in the web UI is not reproducible.
7. Each job keeps its own `concurrency` group keyed on the pull request number with `cancel-in-progress: true` (030 shipped this).

## Implementation hints

- `dorny/paths-filter` on a `pull_request` event reads the diff through the API, so `changes` needs `pull-requests: read` and no checkout.
- The aggregate pattern: `if: always()` on the job, then a single step guarded by `if: contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled')` whose body is `exit 1`. Keep the expression on the step-level `if:`; inside a `run: |` block scalar it has to survive a line break.
- Write protection through the **sub-resource** `PUT repos/{owner}/{repo}/branches/main/protection/required_status_checks`, never `PUT .../protection`. The parent endpoint replaces the whole object, so a body that mentions only the contexts silently clears `enforce_admins`, linear history and the force-push ban. Linear history and the force-push ban have no sub-resource of their own: read them back and fail loudly on a mismatch rather than writing the parent.
- Collapsing the required list and renaming `image` cannot happen in either order alone: a branch renaming the job cannot merge while a context named `image` is required, and `enforce_admins` applies to the operator too. Open the pull request, let `ci-ok` report once, run `make repo-settings`, then merge. Any other open pull request is blocked until rebased, and the same call restores the old contexts if it goes wrong.

## Testing / acceptance criteria

- A pull request touching only `docs/` runs `changes`, `repo` and `ci-ok`; the run finishes in under 2 minutes.
- A pull request touching only `internal/` runs `go` and `image-api` and skips `ui`, `image-web`, `helm`, `gitops`; `ci-ok` is green.
- A pull request with a failing Go test makes `ci-ok` red and the merge button disabled.
- `gh api repos/savak1990/vk-ahorro/branches/main/protection --jq .required_status_checks.contexts` prints `["ci-ok"]`.
- `make repo-settings` twice in a row: the second run changes nothing.
