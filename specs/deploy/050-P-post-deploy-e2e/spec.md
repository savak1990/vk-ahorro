---
id: "DEPLOY-050"
status: "DRAFT"
updated: "2026-09-26"
---
# 050 — End-to-end verification after a deploy

**Status note:** Draft. The cluster half of what core 110 asked for; the
hermetic half is `ci/040`. Becomes DONE only with a dated results line
below.

**Complexity:** Medium
**Risk:** Low — read-only against the cluster; the only write is the platform PR that widens the CI role.
**Estimated cost:** ~1 day, half of it the platform pull request · AWS runtime: none beyond the running lab.
**Recommended model:** Sonnet.
**Depends on:** [010-deploy-branch-and-release](../010-P-deploy-branch-and-release/spec.md), [055-cognito-and-token](../../core/055-D-cognito-and-token/spec.md), [050-cognito](../../core/050-D-cognito/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

After `deploy-branch` pushes, prove the chain over the public hostnames: the
new build is the one serving, the API refuses an anonymous call, accepts the
test user's id token, and greets by email; the web app answers. The same
script runs from a laptop against any platform project.

Excludes: the mobile apps (their proof is the tester's phone); load, security
scans.

## Requirements

1. The `ahorro-api` service MUST report its build: `GET /healthz` returns `{"status":"ok","version":"<sha>"}`, with the SHA injected at build time (`-ldflags -X` from a Docker build argument that `image-push` sets to `IMAGE_TAG`). Locally the version is `dev`.
2. `scripts/e2e-smoke.sh` MUST, in order, stopping at the first failure: poll `https://api-ahorro.$FQDN/healthz` until `version` equals `$EXPECTED_SHA` (cap 10 minutes); `curl -fsSI https://ahorro.$FQDN/` is 200 `text/html`; `GET /api/v1/hello` without a token is 401; `make -s token`; the same call with the bearer token is 200 and the body contains the test user's email. One `OK` line per step, under 100 lines, orchestrating Make targets rather than duplicating them.
3. `FQDN` MUST come from the environment. In CI it is read from SSM `/$PROJECT_NAME/bootstrap/route53/fqdn` and masked with `::add-mask::` before use, never printed, never written to a file (constitution §4). `PROJECT_NAME` comes from a repository variable `PLATFORM_PROJECT`, default `vk-hetzner-lab`.
4. The CI role MUST be widened in a `vk-lab-platform` pull request (core ADR 0003): `ssm:GetParameter` on `parameter/*/persistent/ahorro-cognito/*` and `parameter/*/bootstrap/route53/fqdn`; `kms:Decrypt` on `alias/lab-secrets` for the `SecureString`; `cognito-idp:AdminInitiateAuth` on `userpool/*`. Nothing else, and no cluster access.
5. Job `e2e-lab` in `deploy.yml` MUST run after `deploy-branch` on both the merge and the `web` dispatch paths, with `id-token: write`. When the first health poll gets no HTTP answer at all within 60 seconds, the job MUST end green with a `::notice::` saying the lab is down, and skip the rest. A wrong answer is a failure.
6. `SKIP_AUTH` and `AUTH_DISABLED` MUST NOT appear in this script or job (core 110 req 6, kept for this half).
7. On the first green run the operator MUST fill the results line below.

## Implementation hints

- The health poll distinguishes "no connection" (`curl` exit 6/7/28) from "wrong version" (HTTP 200, other SHA); only the first is a lab-down notice.
- `make token` already reads SSM under `/$PROJECT_NAME/persistent/ahorro-cognito/`; the job exports `PROJECT_NAME` from the variable.
- Argo reconciliation plus a rollout takes one to three minutes on the lab; the 10-minute cap covers a cold pull on a new node.

## Testing / acceptance criteria

- `FQDN=<fqdn> EXPECTED_SHA=<sha> make e2e-smoke` from a laptop exits 0 with five `OK` lines.
- Removing the bearer header from the last call makes the script exit non-zero (negative test of the script itself).
- With the lab down, the CI job is green and shows the notice; with the lab up and an old build serving, it is red at the version step.
- Results:

| Date | Commit | Project | Result |
|---|---|---|---|
| — | — | — | — |
