# CLAUDE.md

## Code comments

Comments are allowed only in very complex parts of code, and must be at most 3 lines. Prefer a single line where a comment is necessary at all. Do not comment straightforward code.

Never reference specific documents (specs, ADRs, tickets) in code comments, e.g. do not write "the guard baseline - ADR 0002". Explain the WHY directly in the comment instead; document links belong in commit messages or PR descriptions, not in code.

---

## Project purpose

Ahorro is a personal-finance application: a Flutter UI for Android, iOS and web, plus Go services, in one repository. It is deployed onto the separate platform repository `vk-lab-platform`.

This repository holds the application only. It MUST NOT hold platform code. Platform changes go to `vk-lab-platform` as a pull request.

The authority is `specs/core/000-D-constitution/spec.md`. Read it before non-trivial work; this file does not restate it.

---

## Ownership and the platform boundary

Identity and trust live in the platform. The application's own resources live here.

`ahorro-ci-role` is defined in `vk-lab-platform`, not here, because an application that can apply its own IAM role can widen that role to `Action: "*"`. Every new AWS permission this repository needs is a pull request against the other repository. See `docs/adr/0003-identity-lives-in-the-platform.md`.

The application enters the cluster through exactly one pointer `Application` in the platform, whose path is this repository's `gitops/` folder. That folder is this repository's own app-of-apps and renders one child `Application` per service. The platform never renders a chart from here.

Terraform owns AWS resources. Argo CD owns every Kubernetes object. Neither crosses into the other.

---

## Nothing sensitive in Git

No secret, no root domain, and no `fqdn` value is ever committed — not in code, not in a chart value, not in a spec, a commit message, a pull request body, or a CI log.

Hostnames are always templated from a value the platform passes in. A chart's `host` has no default and fails the render when empty. Use `<root-domain>` or a documented placeholder such as `lab.example.com` in anything that must show a shape.

Cognito user pool id and client id are public identifiers and MAY be committed.

`make domain-check` enforces this over the working tree and over every commit after the baseline. It fails closed: no value, no history to walk, no green. The history before the baseline is the imported, pre-constitution past; see `docs/adr/0002-domain-guard-and-the-imported-history.md`. Moving the baseline forward hides commits from the check, so it belongs in a commit of its own with a reason.

---

## Images and charts

Every image carries the full commit SHA as a tag. `latest` is never built or pushed.

A release also publishes the branch or release-tag name beside the SHA. That moving tag is a convenience for a local run. GitOps references the SHA only, because Argo diffs manifest text: a moving tag leaves the rendered manifest unchanged, so Argo reports `Synced` while the cluster serves an older build.

A chart derives `imagePullPolicy` from the tag — `IfNotPresent` for a 40-character SHA, `Always` for anything else — because a node that cached a moving tag never pulls it again.

Images and charts both live on GHCR under `ghcr.io/savak1990/vk-ahorro/`. A chart carries a semver `version`; its `appVersion` carries the image SHA. A published chart version is immutable in practice, because Argo pins a `targetRevision` — bump the version whenever a chart changes.

One region, `eu-west-1`, declared as a constant and never read from an environment variable.

---

## Spec-driven development workflow

For non-trivial work:

1. Read `docs/architecture.md`.
2. Read `specs/core/000-D-constitution/spec.md`.
3. Read the relevant numbered spec.
4. Inspect the existing implementation.
5. Produce an implementation plan.
6. Implement incrementally.
7. Run validation.
8. Fix failures before declaring completion.
9. Record material decisions as ADRs in `docs/adr/`.

A spec's folder letter must match its front-matter `status:`; changing the status renames the folder in the same commit. `make specs-check` enforces it.

Do not silently change a requirement to make implementation easier. A spec that cannot close because it owns clauses another spec will deliver is a spec to split, not a spec to fudge.

If requirements are ambiguous, prefer the interpretation most consistent with:

1. architecture invariants,
2. security,
3. low cost,
4. simplicity.

---

## Exploration and planning tools

When exploring the codebase to understand existing patterns before planning or implementing, prefer dispatching read-only subagents in parallel over ad hoc reading, so each area gets focused context.

When designing an implementation approach for non-trivial work, prefer consulting the advisor tool before committing to a plan, and again before declaring the work complete.

---

## Validation

`make` targets are the only supported entry points, and every target carries a `##` doc comment that `make help` prints. A `##` line must sit immediately above its target or it disappears from the help output.

Before opening a pull request:

- `make go-build go-test go-lint`
- `make specs-check`
- `make helm-lint` and `make helm-template CHART=<chart>`
- `make domain-check` (needs `ROOT_DOMAIN`; CI reads it from the platform's SSM parameter)

Never claim a check passes without running it in the same session. A previous run is not evidence.

---

## CI rules

Every pull request runs `go`, `image`, `helm` and `repo`. `main` requires them; a new job must be added to the required list by hand or it is advisory.

Every GitHub action is pinned to a full commit SHA with the version in a trailing comment. A tag can be moved; a commit cannot.

A pull request from a fork gets no secrets, no variables and no OIDC token, so the `repo` job fails there. That is correct: a run that cannot verify the domain must not report green.

No long-lived AWS credentials. GitHub Actions authenticates to AWS through OIDC and temporary credentials only.

Prefer no new tool dependency in CI when a shell builtin will do.

---

## Cost rules

This is an educational project on a personal account.

Prefer inexpensive designs. Do not introduce without explicit justification: oversized replicas, production-grade HA, expensive managed services where a smaller alternative works, or anything that keeps compute running when storage would do.

Resource requests set cpu and memory; limits set memory only, never cpu. This matches the platform's own charts.

---

## Working rules for Claude

Before changing anything that reaches the cluster or AWS:

- determine which repository owns the resource;
- determine its lifecycle class (state, persistent, disposable);
- consider destroy and recreate behavior;
- consider CI behavior;
- consider cost.

Do not use broad AWS IAM permissions when narrower permissions are practical.

Do not touch `vk-lab-platform` unless the task says to. A change there is a separate pull request in a separate repository.
