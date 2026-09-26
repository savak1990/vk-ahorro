---
id: "CORE-110"
status: "SUPERSEDED"
updated: "2026-09-26"
---
# 110 — End-to-end verification

**Status note:** Superseded on 2026-09-26. The core milestone ends at a web
app that deploys when the cluster boots and mobile apps that build from
`make`; a machine-run smoke test reaches past that. The test is split in two:
`specs/ci/040-P-hermetic-e2e` runs on every pull request with no cluster, and
`specs/deploy/050-P-post-deploy-e2e` runs after a deploy against the real
hostnames and the real pool, and carries this spec's results table. The text
below is kept as the record of what was planned.

**Complexity:** Small
**Risk:** Low — verification only; it consumes platform runtime cost while the cluster is up.
**Estimated cost:** ~0.5 day · AWS runtime: the platform's `make up` cost for the duration of the run.
**Recommended model:** Sonnet.
**Depends on:** every other `core/` spec, 105 included.
**Lifecycle class(es) touched:** None (reads only).

## Scope

One script and one runbook that prove the whole chain from a clean clone:
build, push, apply, deploy through the platform, reach the API and the web
app over the public hostnames, and sign in plus tap "+" on Android, iOS,
and web.

Excludes: load tests, security scans, release automation.

## Requirements

1. `scripts/e2e-smoke.sh` MUST run, in order, and stop at the first failure: `make tools-check`, `make go-test go-lint helm-lint gitops-lint`, `make images-push helm-push`, wait for `argocd app get vk-ahorro` to be `Synced` and `Healthy` (timeout 10 min), `curl -fsS https://api-ahorro.$FQDN/healthz`, `curl -fsSI https://ahorro.$FQDN/` (200, `text/html`), `curl -s -o /dev/null -w '%{http_code}' https://api-ahorro.$FQDN/api/v1/hello` = 401, `make token` for an id token (SRP is not scriptable), then the same URL with the bearer token = 200 and a body containing the test user's email. There is no `make tf-apply` step: the pool is the platform's, created by its `make persistent-up` (055, ADR 0004).
2. `FQDN` MUST come from the environment, never from a file in Git. The test user and its password are created by the platform's Terraform from KMS ciphertext it holds; `make token` reads them from SSM, so no credential is committed here and none is typed by the operator.
3. Running this script in CI needs `ahorro-ci-role` widened — `ssm:GetParameter` on `/*/persistent/ahorro-cognito/*`, `kms:Decrypt` on `alias/lab-secrets` for the `SecureString`, and `cognito-idp:AdminInitiateAuth`. That is a pull request against `vk-lab-platform` and it belongs to this spec (ADR 0003). Run from an operator's laptop, it needs nothing new.
4. The manual half is a checklist in this spec: on Android emulator, iOS simulator, and Chrome — start the app with the lab config, sign in, tap "+", read "Hello, <email>", sign out.
5. On success the operator MUST fill the results table below with the date, commit SHA, platform target (`aws`), and one line per check, then flip every `core/` spec to `DONE` (rename folders, update links, run `make specs-check`).
6. `SKIP_AUTH` MUST NOT appear anywhere in this spec's checks. The flag exists for local UI work and renders the shell with no sign-in, so a run that sets it exercises a different app than the one shipped: it cannot catch a wrong issuer, a stale JWKS, an expired token, or CORS failing on the authenticated call, which are the failures e2e exists to find. `kDebugMode` already keeps the flag out of release builds.
7. The script MUST be runnable against an already-running platform (skips nothing, but is idempotent: re-running pushes the same SHA and re-applies a no-op plan).

## Implementation hints

- Use `argocd --core` with the platform's kubeconfig (`KUBECONFIG=../vk-lab-platform/.kube/vk-lab-platform.config`); it needs no Argo password.
- `make token` wraps `aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH` and prints `AuthenticationResult.IdToken`; do not duplicate it here.
- Keep the script under 100 lines; it orchestrates Make targets, it does not duplicate them.

## Testing / acceptance criteria

- `scripts/e2e-smoke.sh` exits 0 against a running platform and prints one `OK` line per step.
- Removing the bearer token makes the hello step fail with 401, and the script exits non-zero (negative test of the script itself).
- The manual checklist is ticked for all three platforms.
- Results table filled:

| Date | Commit | Target | Check | Result |
|---|---|---|---|---|
| — | — | — | — | — |
