# ADR 0003: Identity lives in the platform, not in the app

## Status

Accepted

## Context

Spec 030 needed the root domain in CI without committing it. The value already
had one delivery path: `vk-lab-platform` decrypts `secrets/root-domain.enc`
with KMS and writes the SSM parameter `/account/root_domain`. Reading it from
`vk-ahorro` needed an AWS identity, so a role had to be defined somewhere.

`lab-role` was not that role. It carries the whole platform permission set, and
its trust policy names a single repository. Widening either would have traded a
scoped grant for a broad one.

So a new role was needed, and the question was which repository defines it.

## Decision

Identity and trust live in `vk-lab-platform`. The app's own resources live in
`vk-ahorro/deploy/terraform/`, applied by a role the platform granted.

`ahorro-ci-role` is therefore a platform unit
(`terraform/live/account/ahorro-ci-role`). Its trust names `savak1990/vk-ahorro`
through the GitHub OIDC provider the platform owns. Its only statement today is
`ssm:GetParameter` on the root domain parameter.

The reasons, strongest first:

1. **An app must not grant itself IAM.** Creating the role needs
   `iam:CreateRole` and `iam:PutRolePolicy`. A pipeline that applies its own
   role definition can change that definition to `Action: "*"`, and the scope of
   the grant stops being a control.
2. **Bootstrap.** `vk-ahorro` CI has no AWS credentials until a role exists. A
   role defined there could never create itself.
3. **State placement.** The role is account-global. It belongs in the platform's
   `savak1990-account-state` bucket, not the per-project state bucket that spec
   050 creates.

No constitution is bent: `vk-ahorro` requirement 1 says platform changes go to
`vk-lab-platform` as a pull request, and platform requirement 5 already allows a
role for each consumer.

## Consequences

- Every new AWS permission `vk-ahorro` needs is a pull request against the other
  repository. Spec 050 needs S3, `cognito-idp` and SSM grants, so it pays this
  cost three times.
- The name says `ci`, not `app`. A workload identity for the running service is
  a separate role with its own trust, added when a service needs one.
- `vk-ahorro` still owns its Cognito pool, its state bucket and its own SSM
  parameters. This ADR moves identity, not resources.
