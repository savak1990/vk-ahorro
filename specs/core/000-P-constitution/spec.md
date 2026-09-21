---
id: "CORE-000"
status: "DRAFT"
updated: "2026-09-21"
---
# 000 — Constitution

**Status note:** Draft. Becomes DONE when every rule below has one enforcing check (a Make target, a CI job, or a review checklist item).

**Complexity:** Small
**Risk:** Low — a document, but every other spec cites it.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** `vk-lab-platform/specs/shared/000-D-constitution` (the platform constitution) and `vk-lab-platform/docs/adr/0015-business-app-gitops-topology.md` (the app-to-platform contract).
**Lifecycle class(es) touched:** All (defines them for this repository).

## Scope

The rules every other `core/` spec obeys: what this repository holds, who
owns which resources, what never enters Git, how the app plugs into
`vk-lab-platform`.

Excludes: any platform rule that `vk-lab-platform` already owns (cluster,
gateway, DNS, TLS, Argo CD bootstrap). This repository consumes those; it
does not restate or override them.

## Requirements

1. **Scope.** This repository holds the Ahorro application only: the Flutter UI (`flutter-ui/`), Go services (`cmd/`, `internal/`), their images and charts (`deploy/`), their AWS resources (`deploy/terraform/`), and their GitOps chart (`gitops/`). It MUST NOT hold platform code. Platform changes go to `vk-lab-platform` as a pull request.
2. **Ownership.** Terraform/Terragrunt owns AWS resources (Cognito, SSM parameters, the state bucket). Argo CD owns every Kubernetes object. Terraform MUST NOT create Kubernetes objects; Argo MUST NOT create AWS resources.
3. **Lifecycle classes.** Every resource belongs to exactly one class:
   - State: the bucket `vk-ahorro-tf-state`. Essentially never destroyed.
   - Persistent: Cognito user pool and client, SSM parameters. Survive a platform `make down`.
   - Disposable: every Kubernetes object in namespace `ahorro`. Recreated by the platform's `make up` from Git alone.
4. **Nothing sensitive in Git.** No secret, no root domain, no `fqdn` value MUST ever be committed. Hostnames are always templated from a value the platform passes in (`fqdn`). Cognito user pool id and client id are public identifiers and MAY be committed.
5. **Images.** Every image is tagged by full commit SHA. `latest` MUST NOT be used anywhere. Images and charts live on GHCR under `ghcr.io/savak1990/vk-ahorro/`.
6. **Platform contract.** The app enters the cluster only through one pointer `Application` plus one `AppProject` in `vk-lab-platform/gitops/templates/apps/vk-ahorro/` (ADR 0015). The pointer has `selfHeal: false` so the operator decides when to sync. Everything below the pointer lives in this repository's `gitops/` chart.
7. **One region.** `eu-west-1`, declared as a constant, never from an environment variable (platform ADR 0024).
8. **Entry points.** `make` targets are the only supported way to build, test, push, apply, and run. Every target carries a `##` doc comment.
9. **Workflow.** For non-trivial work: read `docs/architecture.md`, read the spec, inspect the implementation, plan, implement in increments, run validation, then declare completion. Record material decisions in `docs/adr/`.
10. **Comments.** Code comments only where the WHY is not obvious, at most 3 lines. Never reference a spec or ticket number in code; put links in commit messages.

## Implementation hints

- Copy enforcing scripts from the platform where one exists (`specs-check.sh`, `gitops-render-check.sh`) rather than write new ones.
- A `grep` for the root domain in CI is the cheapest guard for Requirement 4.

## Testing / acceptance criteria

- `make specs-check` exists and passes: every `specs/core/*/spec.md` has front matter, an id, and a status that matches its folder letter.
- CI fails when a committed file contains the root domain (the check reads the domain from a secret, never from Git).
- Every `make` target prints a one-line description under `make help`.
