---
id: "CORE-055"
status: "DONE"
updated: "2026-09-26"
---
# 055 — Cognito consumption and the ad-hoc token

**Status note:** Done on 2026-09-26, verified against `vk-hetzner-lab` before
its teardown. `make cognito-config | jq` printed the three identifiers and
nothing else; `make token` printed a JWT whose payload decoded to
`"token_use": "id"` with `aud` equal to the client id; the deployed API
answered 401 without the header and 200 with it, with a body containing
`e2e@vk-ahorro.invalid` rather than a UUID; `initiate-auth --auth-flow
USER_PASSWORD_AUTH` against the client id was rejected; and the Terraform grep
finds nothing. The pool itself is 050.

**Complexity:** Small
**Risk:** Low — two read-only targets; this repository creates no AWS resource.
**Estimated cost:** ~0.5 day · AWS runtime cost: none. The pool is the platform's.
**Recommended model:** Sonnet.
**Depends on:** 000-constitution, 020-go-hello-service; the platform's `vk-lab-platform/specs/aws/035-A-ahorro-cognito`, which creates the pool.
**Lifecycle class(es) touched:** None. This repository owns no AWS resource.

## Scope

How this repository reads the Cognito identifiers the platform publishes, and
how an operator mints a token to exercise the protected API by hand with
`curl`.

Excludes: creating the pool, the client or the test user (the platform's spec
035); carrying the identifiers into a running cluster (060); the Flutter
runtime config (080); the end-to-end smoke test (110).

## Requirements

1. This repository MUST hold no Terraform and no Terragrunt. It creates no AWS resource, owns no state bucket, and has no State lifecycle class (constitution §1, §3, ADR 0004).
2. Every Cognito value MUST be read from SSM under `/$(PROJECT_NAME)/persistent/ahorro-cognito/`, never from a committed literal. The pool is per platform project, so a committed id is correct for exactly one project and wrong for every other.
3. `PROJECT_NAME` MUST be a Make variable defaulting to `vk-hetzner-lab`, the usual target, and overridable for any other platform project. It is the only platform concept this repository names.
4. `make cognito-config` MUST print JSON on stdout and nothing else, so it can be piped into `jq`. It reports the public identifiers only: `user_pool_id`, `client_id` and `issuer` (constitution §4).
5. `make token` MUST print one id token on stdout and nothing else. It reads the client id, the test user's name and the test user's password from SSM and calls `aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH`.
6. `make token` MUST emit the **id token**, not the access token. A Cognito access token carries no `email` claim, and the pool uses email as the username attribute, so `username` holds a UUID: an access token would greet the user by UUID. `internal/platform/auth/jwt.go` accepts an id token because `aud` contains the configured client id.
7. No credential MUST reach a tracked file, a process listing, or Make's command echo. Both recipes are `@`-prefixed. The password MUST travel to `aws` in a `mktemp` file removed by a `trap`, not on the command line: an argument is visible to any local `ps`, and a file created by `mktemp` is `-rw-------` and gone when the script exits.
8. No secret MUST be committed here. The test user's password lives in the platform as KMS ciphertext and reaches this repository only as a `SecureString` SSM parameter read at call time (constitution §4).
9. Each target carries a `##` doc comment immediately above it and joins `.PHONY` (constitution §8). A recipe longer than one line goes into `scripts/`.

## Implementation hints

- `aws ssm get-parameters-by-path --path <prefix>` returns every value in one call; `--with-decryption` is needed only for the password, so `cognito-config` MUST NOT ask for it and stays usable without `kms:Decrypt`.
- Build the auth payload with `jq -n --arg`, never `printf` into a JSON template: a password containing a quote or a backslash would corrupt it.
- The issuer already contains the region and the pool id, so the service needs neither separately: `internal/api/config.go` reads `COGNITO_ISSUER` and `COGNITO_CLIENT_ID` and nothing else.
- `make go-run` already exports `AUTH_DISABLED` with a default of `true`, so `AUTH_DISABLED=false make go-run` is enough to exercise the protected route locally.

## Testing / acceptance criteria

- `make cognito-config | jq -r .issuer` prints the issuer URL and no other output.
- `make token` prints a JWT whose payload decodes to `"token_use": "id"` and whose `aud` equals `make cognito-config | jq -r .client_id`.
- Against a locally running service with auth enabled: `curl` without a bearer token returns 401; with the token from `make token` it returns 200 and a body containing the test user's email address, not a UUID.
- `aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH` against the same client id is rejected, proving the public password flow is off.
- `grep -rn 'terraform\|terragrunt' Makefile scripts/` finds nothing.
