---
id: "CORE-000"
status: "DONE"
updated: "2026-09-21"
---
# 000 — Constitution

**Status note:** Done on 2026-09-21: `make specs-check` and `make help` ship with
spec 020. The CI guard against the root domain moved to spec 030, which creates
the workflows. Requirement 4 still binds every spec; only its enforcing job
lives elsewhere.

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

1. **Scope.** This repository holds the Ahorro application only: the Flutter UI (`flutter-ui/`), Go services (`cmd/`, `internal/`), their images and charts (`deploy/`), and their GitOps chart (`gitops/`). It MUST NOT hold platform code, and it MUST NOT hold Terraform: the platform creates this application's AWS resources (ADR 0004). Platform changes go to `vk-lab-platform` as a pull request.
2. **Ownership.** Terraform owns AWS resources; Argo CD owns every Kubernetes object. Terraform MUST NOT create Kubernetes objects; Argo MUST NOT create AWS resources. The Terraform is the platform's: this application's Cognito pool and SSM parameters are a unit in `vk-lab-platform/terraform/live/persistent/ahorro-cognito/` (ADR 0004).
3. **Lifecycle classes.** Every resource belongs to exactly one class:
   - Persistent: the Cognito user pool, its app client and its SSM parameters, all owned by the platform's persistent layer; plus the GHCR packages. They survive a platform `make down` and are destroyed only by `make persistent-down`.
   - Disposable: every Kubernetes object in namespace `ahorro`. Recreated by the platform's `make up` from Git alone.

   There is no State class here. This repository owns no Terraform state, so
   the bucket `vk-ahorro-tf-state` is never created (ADR 0004).
4. **Nothing sensitive in Git.** No secret, no root domain, no `fqdn` value MUST ever be committed. Hostnames are always templated from a value the platform passes in (`fqdn`). Cognito user pool id and client id are public identifiers and MAY be committed — but there is one pool per platform project, so a committed id is right for exactly one project and wrong for every other. They travel from SSM as the platform passes them down, the same way `fqdn` does.
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
- Every `make` target prints a one-line description under `make help`.
