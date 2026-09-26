---
id: "CORE-050"
status: "DONE"
updated: "2026-09-26"
---
# 050 — Cognito: the user pool

**Status note:** Done on 2026-09-26. This spec first planned a Terragrunt tree
and a state bucket in this repository; that text is in git history before this
commit. The pool now lives in the platform, and this spec records what was
decided and verified. The pool, its client and the test user were checked live
against `vk-hetzner-lab` on 2026-09-26: five SSM parameters with exactly one
`SecureString`, `DeletionProtection: INACTIVE`, `MfaConfiguration: OFF`, one
client, the test user `CONFIRMED`, and a `full-down` that left no pool behind.
The consumer side, `make cognito-config` and `make token`, is 055.

**Complexity:** Small
**Risk:** Low — the platform's `full-down` deletes the pool and every user in it; acceptable while the only user is a test account its Terraform recreates.
**Estimated cost:** ~0.5 day, spent in `vk-lab-platform` · AWS runtime cost: Cognito Essentials, free below 10,000 monthly active users.
**Recommended model:** Sonnet.
**Depends on:** 000-constitution; the platform's `vk-lab-platform/specs/aws/035-A-ahorro-cognito`, which creates the pool.
**Lifecycle class(es) touched:** None here. The pool is Persistent in the platform.

## Scope

Where the Cognito user pool lives, what it looks like, and how its identifiers
leave it. The resource itself is the platform's; this spec is the decision
record this repository builds on.

Excludes: the Terraform (the platform's spec 035); reading the identifiers and
minting a token (055); carrying them into the cluster (060); the Flutter
sign-in (080).

## Requirements

1. The pool MUST be created by `vk-lab-platform/terraform/live/persistent/ahorro-cognito/`, one pool per platform project, named `<project>-ahorro`. This repository MUST hold no Terraform and no state bucket (ADR 0004).
2. There MUST be exactly one app client, `vk-ahorro-app`, with `ALLOW_USER_SRP_AUTH`, `ALLOW_ADMIN_USER_PASSWORD_AUTH` and `ALLOW_REFRESH_TOKEN_AUTH`, and no client secret. `internal/platform/auth/jwt.go` pins one client id, so a second client would mint tokens the service refuses (ADR 0005).
3. `ALLOW_USER_PASSWORD_AUTH` MUST stay off: anyone holding the public client id could call it.
4. `deletion_protection` MUST be `INACTIVE`. The AWS API refuses `DeleteUserPool` on a protected pool, so the platform's `full-down` would fail and its lifecycle CI would leak one pool per run. Protection for real users is a later decision.
5. MFA MUST stay off. With it on, `AdminInitiateAuth` returns a challenge instead of tokens, and the scripted token path stops working (ADR 0005).
6. Email is the username attribute, `email` and `name` are required, and the password policy is minimum 8 with lowercase, uppercase and a digit.
7. One test user MUST be created by the platform's Terraform from KMS ciphertext the platform holds, at a fixed non-deliverable address (`e2e@vk-ahorro.invalid`), with no invitation sent and a permanent password so it lands `CONFIRMED`. No credential for it exists in this repository.
8. The platform MUST publish `user_pool_id`, `client_id`, `issuer` and `test_user_email` as `String` and `test_user_password` as `SecureString` under `/<project>/persistent/ahorro-cognito/`. The first three are public (constitution §4) but per project, so they are never committed here; every consumer reads SSM.
9. The identifiers reach the cluster the way `fqdn` does: read from SSM by the platform's `argo-up.sh` and passed as Helm parameters (060). They MUST NOT travel through an `ExternalSecret`, which would store public data as secret data.
10. Any token used to prove the email greeting MUST be the id token. An access token carries no `email` claim, and `username` holds a UUID (055).

## Implementation hints

- The platform's module is `terraform/modules/ahorro-cognito`; its `lab-role` carries the `cognito-idp` grants, with `CreateUserPool` alone on `Resource: "*"` because no pool ARN exists before the pool does.
- The issuer is `https://cognito-idp.eu-west-1.amazonaws.com/<pool id>`; the service derives the JWKS URL from it and needs no region of its own.

## Testing / acceptance criteria

Verified on 2026-09-26 against `vk-hetzner-lab`:

- `aws ssm get-parameters-by-path --path /<project>/persistent/ahorro-cognito` returns five parameters, exactly one `SecureString`.
- `aws cognito-idp describe-user-pool` shows `DeletionProtection: INACTIVE`, `MfaConfiguration: OFF` and one client, `vk-ahorro-app`.
- `aws cognito-idp list-users` shows the test user with `UserStatus: CONFIRMED`.
- `aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH` against the client id is rejected with `USER_PASSWORD_AUTH flow not enabled for this client`.
- The platform's `ci:lifecycle-aws` run completes `full-up` → `test` → `full-down` with no pool left behind.
- `git ls-files '*.tf' '*.hcl'` in this repository prints nothing.
