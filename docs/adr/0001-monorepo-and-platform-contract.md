# ADR 0001: Monorepo, GHCR delivery, and app-owned Cognito

## Status

Accepted

## Context

The previous version of Ahorro lived in several repositories: `ahorro-ui`
(Flutter), separate service repositories, and an `ahorro-shared` Terraform
module repository. The UI's Terraform pointed at a sibling checkout that
is no longer present, the pipeline built without configuration, and the
Cognito pool id lived in source.

The new home is `vk-lab-platform`, whose ADR 0015 already fixes the
integration shape for business applications: the platform owns one pointer
`Application` and one `AppProject` per app; the app repository owns its own
app-of-apps; images are tagged by commit SHA and committed into the app's
values by its CI. ADR 0015 also proposes ECR repositories and a per-repo
OIDC push role, both created by platform Terraform.

Three questions remained for this repository: one repo or many; where
images and charts live; who creates Cognito.

## Decision

1. **One monorepo.** Flutter UI, every Go service, their Dockerfiles,
   charts, Terraform, and the GitOps chart live in `vk-ahorro`. One Go
   module with `cmd/<svc>` and `internal/<svc>`; shared code in
   `internal/platform/`.
2. **GHCR for images and charts, not ECR.** `ghcr.io/savak1990/vk-ahorro/*`
   for images, `oci://ghcr.io/savak1990/vk-ahorro/charts/*` for charts, all
   public. This deviates from ADR 0015's ECR proposal on purpose: public
   packages need no pull secret in the cluster and no AWS role in CI, which
   removes two pieces of platform Terraform. The SHA-tag and
   commit-the-tag rules of ADR 0015 stay.
3. **Cognito is application infrastructure.** A Terragrunt tree in
   `deploy/terraform/` with its own state bucket `vk-ahorro-tf-state`
   creates the user pool and clients in the same AWS account and region
   the platform uses. The platform repository stays platform-only.
4. **Two public hostnames.** `ahorro.<fqdn>` for the web build,
   `api-ahorro.<fqdn>` for the API, both as HTTPRoutes in this
   repository's charts on the platform's `platform-gateway`.
5. **Runtime configuration, not build-time.** The web image reads
   `/config.json`; mobile builds read a `--dart-define-from-file` that Make
   generates from Terraform outputs. The root domain never enters Git.

## Consequences

- Adding a service touches only this repository.
- Anyone can pull the images and charts; nothing private may ever be baked
  into them.
- The platform pull request for this app is two files plus regenerated
  golden files and one ADR (spec 060).
- The pointer runs with `selfHeal: false`, so a values change in this
  repository waits for an operator sync; the child Applications self-heal.
- If GHCR rate limits or visibility rules ever become a problem, ECR is the
  documented fallback, and ADR 0015 already describes it.
