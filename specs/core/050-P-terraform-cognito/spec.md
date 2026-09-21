---
id: "CORE-050"
status: "DRAFT"
updated: "2026-09-21"
---
# 050 — Terraform: state bucket and Cognito

**Status note:** Draft.

**Complexity:** Medium
**Risk:** Medium — a user pool destroyed by accident loses every user; the state bucket destroy path must be guarded.
**Estimated cost:** ~1 day · AWS runtime cost: Cognito Essentials tier, free below 10,000 monthly active users; S3 state bucket, cents.
**Recommended model:** Sonnet.
**Depends on:** 000-constitution
**Lifecycle class(es) touched:** State (the bucket), Persistent (Cognito, SSM parameters).

## Scope

This repository's own Terragrunt tree under `deploy/terraform/`: a state
layer and a persistent layer with one Cognito user pool and one public app
client. Outputs feed the Flutter config (080) and the GitOps values (060).

Excludes: any Kubernetes object (constitution §2), any platform resource
(zone, cert, cluster), an identity pool, social identity providers, a
custom domain for managed login.

## Requirements

1. Layout MUST mirror the platform: `deploy/terraform/live/root.hcl`, `live/state/`, `live/persistent/cognito/`, `deploy/terraform/modules/terraform-state/`, `modules/cognito/`. Each module has `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, and a committed `.terraform.lock.hcl`.
2. `root.hcl` MUST set the region constant `eu-west-1`, provider `default_tags` `{Project = "vk-ahorro", Scope = "app", Lifecycle = <derived from path>, ManagedBy = "terraform"}`, and an S3 backend on bucket `vk-ahorro-tf-state` with `use_lockfile = true` and `encrypt = true` (copy `vk-lab-platform/terraform/live/root.hcl`, drop the Civo parts).
3. The state module MUST be a copy of the platform's `terraform-state` module (versioning, SSE-S3, public access block, deny-insecure-transport policy, `force_destroy = false`).
4. The Cognito module MUST create: one user pool `vk-ahorro-lab` (email as username, email auto-verified, required attributes `email` and `name`, password policy min 8 with lower, upper, number — the same policy the old app used), one app client `vk-ahorro-app` with `generate_secret = false`, `explicit_auth_flows = [ALLOW_USER_SRP_AUTH, ALLOW_REFRESH_TOKEN_AUTH]`, id and access token validity 1 h, refresh token 30 d, `prevent_user_existence_errors = ENABLED`; and a second app client `vk-ahorro-e2e` with `generate_secret = false` and `explicit_auth_flows = [ALLOW_ADMIN_USER_PASSWORD_AUTH, ALLOW_REFRESH_TOKEN_AUTH]`, used only by the smoke test (110). Deletion protection MUST be `ACTIVE`.
5. Outputs: `user_pool_id`, `client_id`, `e2e_client_id`, `region`, `issuer` (`https://cognito-idp.eu-west-1.amazonaws.com/<pool id>`). The same values MUST be written to SSM as `String` parameters `/vk-ahorro/persistent/cognito/{user_pool_id,client_id,issuer}` so a future in-cluster consumer can read them without Git.
6. Make targets: `tf-state-up` (idempotent first-run bootstrap, copy `vk-lab-platform/scripts/state-up.sh`), `tf-plan`, `tf-apply`, `tf-outputs` (JSON of every output), `tf-destroy` (refuses unless `CONFIRM_DESTROY=vk-ahorro`; never destroys the state bucket), `tf-fmt`, `tf-validate`.
7. Terraform MUST never read or write anything under the platform's state buckets.
8. `.github/workflows/ci.yml` MUST gain a `terraform fmt -check` step on pull requests. 030 created the workflow; the step belongs to the spec that adds the Terraform code.

## Implementation hints

- `aws_cognito_user_pool` with `username_attributes = ["email"]`, `auto_verified_attributes = ["email"]`, `schema` blocks for `email` and `name`, `deletion_protection = "ACTIVE"`.
- `aws_cognito_user_pool_client` with `supported_identity_providers = ["COGNITO"]`; no OAuth flows are needed for SRP sign-in through Amplify.
- Terragrunt 1.1.x: `terragrunt run --all --non-interactive -- apply -auto-approve` from `live/persistent`.

## Testing / acceptance criteria

- A real access token from this pool greets the user by email, not by a UUID.
  The pool uses email as the username attribute, so `username` holds a UUID;
  spec 020 reads the `email` claim first and falls back to `username`. The unit
  tests use a local fixture, so only this pool proves the claim shape.

- `make tf-fmt tf-validate` clean; `make tf-state-up` twice in a row is a no-op the second time.
- `make tf-apply` then `make tf-plan` shows no changes.
- `aws cognito-idp describe-user-pool --user-pool-id $(make -s tf-outputs | jq -r .user_pool_id)` returns the pool with `DeletionProtection: ACTIVE`.
- `aws cognito-idp admin-create-user` + `admin-set-user-password --permanent` creates a test user; `aws cognito-idp initiate-auth --auth-flow USER_PASSWORD_AUTH` against `client_id` is rejected (SRP only); `admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH` against `e2e_client_id` returns an id token.
- `aws ssm get-parameters-by-path --path /vk-ahorro/persistent/cognito` returns the three parameters.
- `CONFIRM_DESTROY=wrong make tf-destroy` exits non-zero without a plan; the state bucket still exists after a correct `tf-destroy`.
