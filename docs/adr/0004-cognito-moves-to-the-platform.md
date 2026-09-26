# ADR 0004: Cognito moves to the platform; this repository holds no Terraform

## Status

Accepted

Supersedes decision 3 of
[ADR 0001](0001-monorepo-and-platform-contract.md). Every other decision in
ADR 0001 stands. Narrows
[ADR 0003](0003-identity-lives-in-the-platform.md)'s closing sentence, which
said this ADR moved identity but not resources.

## Context

ADR 0001 decision 3 put the Cognito user pool in a Terragrunt tree here, with
its own state bucket `vk-ahorro-tf-state`. It is four lines with no
alternatives section and one stated reason: "The platform repository stays
platform-only." The only trade-off argued anywhere in that ADR is GHCR against
ECR, which is about registries.

Nothing was ever built. `deploy/terraform/` does not exist, the Makefile has no
`tf-` target and the bucket was never created, so the cost of revisiting this
is entirely in prose.

What prompted the revisit is the platform's lifecycle button.
`vk-lab-platform/.github/workflows/lab.yml` is a `workflow_dispatch` whose
`target` choices include `full-up`, and it runs `make <target>` as the
platform's own deploy role. Nothing in that chain applies this repository's
Terraform. Under ADR 0001 the pool would have been created once, by hand, in a
second repository, behind a second backend and a second bootstrap script — and
pressing the button would still not have produced a working application.

Three things decided it:

1. **The platform already owns app resources, deliberately.** Platform ADR 0015
   creates each application's CI role and its registries in the platform,
   "since IAM and the OIDC provider are this repo's responsibility regardless
   of which repo the workload code lives in", and anticipates app-owned units
   landing in its persistent layer. `terraform/live/account/ahorro-ci-role` is
   the shipped precedent. The platform's own constitution forbids business
   application *source code*; a Terraform unit is not source code.
2. **ADR 0003's third reason generalizes and was never run on Cognito.** Its
   first two reasons are IAM-specific — an app must not grant itself IAM, and a
   role cannot bootstrap itself — and neither applies to a user pool. The third
   is a placement rule keyed on scope and lifecycle: a resource belongs in the
   state that matches its blast radius. Applied to Cognito, the pool is
   per platform project and belongs in that project's persistent state.
3. **The thing that runs the apply owns the resource.** There is no industry
   answer to who owns an application's identity provider. This is the rule that
   holds, and the button is the only apply path worth having.

## Decision

The user pool, its single app client and its end-to-end test user are created
by `vk-lab-platform/terraform/live/persistent/ahorro-cognito/`, recorded in
platform ADR 0042 and platform spec AWS-035.

This repository holds no Terraform and no Terragrunt. `vk-ahorro-tf-state` is
never created, and the State lifecycle class disappears from the constitution.
`make tf-state-up`, `tf-plan`, `tf-apply`, `tf-outputs` and `tf-destroy` are
never written.

Every consumer reads SSM under
`/<project>/persistent/ahorro-cognito/` instead of Terraform outputs.
`PROJECT_NAME` becomes a Make variable here, defaulting to `vk-hetzner-lab`,
the usual target.

The identifiers stay public (constitution §4), but they are now **per platform
project**, so they are no longer committed to `gitops/values.yaml`. They take
the route `fqdn` already takes: read from SSM by the platform's
`scripts/argo-up.sh`, passed down as Helm parameters. They are not delivered by
External Secrets, which would store public data as secret data.

## Consequences

- One functional break, and it is the only one: `make ui-config` (spec 080) read
  `make tf-outputs`. It reads SSM instead. Everything downstream of
  `gitops/values.yaml` was already decoupled from Terraform, and the running
  service needs no AWS access at all.
- Spec 050 is superseded by 055 and by the platform's AWS-035. Specs 000, 020,
  030, 060, 080, 090 and 110 are amended. Spec 010 and `.gitignore` are left
  alone: `git check-ignore` does not need a path to exist, so its acceptance
  line still passes and the dead Terraform patterns cost nothing.
- A new AWS permission for this application is still a pull request against the
  platform, exactly as ADR 0003 said. What changes is that two of the three
  grants ADR 0003 anticipated — S3 for the state bucket and `cognito-idp` for
  the pool — are no longer needed by this repository at all.
- The platform's `full-down` destroys the pool and every user in it. That is
  acceptable while the only user is a test account its Terraform recreates.
- This repository can no longer create its own identity provider, by design.
  Should that ever become wrong, the fallback is ADR 0001's original design,
  which this document describes in full.
