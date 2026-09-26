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
2. A first job `changes` MUST run `dorny/paths-filter` (SHA-pinned, core 030 req 8) with exactly these filters: `go` = `cmd/**`, `internal/**`, `go.mod`, `go.sum`, `.golangci.yml`, `deploy/docker/hello.Dockerfile`; `flutter` = `flutter-ui/**`, `deploy/docker/web.Dockerfile`; `helm` = `deploy/helm/**`; `gitops` = `gitops/**`; `workflows` = `.github/**`. Every other job carries `needs: changes` and an `if:` on one or more outputs:

   | Job | Runs when |
   |---|---|
   | `go` | `go` |
   | `image-hello` | `go` |
   | `image-web` | `flutter` |
   | `ui` | `flutter` |
   | `helm` | `helm` |
   | `gitops` (`make gitops-lint gitops-check`, core 060 req 7) | `gitops` |
   | `repo` | always |
   | `ci-ok` | always |

3. `repo` MUST run `make specs-check`, `make domain-check` and `actionlint` over `.github/workflows/`; it is the only job that needs the OIDC token, so it stays the job that fails on a fork (CLAUDE.md, CI rules).
4. `ci-ok` MUST declare `needs:` on every other job, run with `if: always()`, and exit non-zero when any `needs.*.result` is `failure` or `cancelled`. A `skipped` result passes. It MUST be the **only** required status check on `main`; the four contexts required today (`go`, `image`, `repo`, `helm`) are removed from the list, and a job rename never touches protection again.
5. Branch protection on `main` MUST require `ci-ok`, keep `enforce_admins`, linear history, no force-push and no deletion, and require zero approvals: the repository has one or two developers. Squash is already the only merge method and the branch is deleted on merge; the spec records both as required.
6. Protection, labels and the `release` Environment (020, `deploy/020`) MUST be applied by `make repo-settings`, a one-line target calling `scripts/repo-settings.sh`, which uses `gh api` and is idempotent. A setting clicked in the web UI is not reproducible.
7. Each job keeps its own `concurrency` group keyed on the pull request number with `cancel-in-progress: true` (030 shipped this).

## Implementation hints

- `dorny/paths-filter` on a `pull_request` event reads the diff through the API, so `changes` needs `pull-requests: read` and no checkout.
- The aggregate pattern: `if: always()` then `if [ "${{ contains(needs.*.result, 'failure') || contains(needs.*.result, 'cancelled') }}" = true ]; then exit 1; fi`.
- `gh api -X PUT repos/{owner}/{repo}/branches/main/protection` takes the whole object; send every field each run so the script converges.

## Testing / acceptance criteria

- A pull request touching only `docs/` runs `changes`, `repo` and `ci-ok`; the run finishes in under 2 minutes.
- A pull request touching only `internal/` runs `go` and `image-hello` and skips `ui`, `image-web`, `helm`, `gitops`; `ci-ok` is green.
- A pull request with a failing Go test makes `ci-ok` red and the merge button disabled.
- `gh api repos/savak1990/vk-ahorro/branches/main/protection --jq .required_status_checks.contexts` prints `["ci-ok"]`.
- `make repo-settings` twice in a row: the second run changes nothing.
