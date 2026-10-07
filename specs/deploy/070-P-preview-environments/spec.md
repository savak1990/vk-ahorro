---
id: "DEPLOY-070"
status: "DRAFT"
updated: "2026-10-06"
---
# 070 — A deployed preview per labeled pull request

**Status note:** Draft. Implements the preview half of
[ADR 0009](../../../docs/adr/0009-three-environments-and-one-version-track.md)
and [ADR 0010](../../../docs/adr/0010-the-pipeline-deploys-to-the-cluster.md);
the rules are written in [`docs/delivery.md`](../../../docs/delivery.md) §3.1.

**Complexity:** Medium
**Risk:** Medium — a teardown that silently fails leaves a release and its DNS record behind, and nothing else notices.
**Estimated cost:** ~1.5 days.
**Recommended model:** Opus.
**Depends on:** `deploy/060` (the version channels and the credential chain), `ci/010` requirement 6 (`make repo-settings`, which creates the label).
**Lifecycle class(es) touched:** Disposable.

## Scope

Deploying a pull request on demand, into one shared namespace, and removing
every trace of it when the label goes away or the pull request closes.

**Excludes:** the version scheme and the merge path, which are `deploy/060`.
Argo-managed previews through an ApplicationSet pull-request generator, which
would need a GitHub token living in the cluster. Mobile builds.

## Requirements

1. A **labeled** pull request MUST publish an image and a chart as `<version>-pr-<n>.<short-sha>` for **every** component, from `preview.yml`, with an unchanged one copied rather than rebuilt (`deploy/060` req 2a). One version names the whole preview, and the commit is part of it (`deploy/060` req 2b) so a second push actually rolls the pods.
1a. `ci.yml` MUST NOT publish anything and MUST NOT hold `packages: write`. *(Amended: requirement 1 originally published from `ci.yml` on every pull request. Three reasons it cannot. A fork's `GITHUB_TOKEN` is read-only, so the push would fail there, and today only the `repo` job fails on a fork, deliberately. Both image jobs and the `helm` job are gated on the `changes` filter, so a Go-only pull request packages no chart at all - "every component" would need all three gates reworked. And every pull request that nobody previews would leave four artifacts behind that cannot be deleted; see req 8.)*
2. Deployment MUST live in a **new** workflow file, `.github/workflows/preview.yml`, and MUST NOT be a job in `ci.yml`. `ci.yml` relies on the default `pull_request` types, so a label event does not re-run it today; its required status checks are maintained by hand, and a context that never reports blocks every merge.
3. `preview.yml` MUST trigger on `pull_request` types `[opened, labeled, unlabeled, synchronize, closed]` and act only as follows:

   | Event | Condition | Action |
   |---|---|---|
   | `labeled` | `github.event.label.name == 'ci:preview-web'` | install |
   | `opened` | the pull request carries `ci:preview-web` | install |
   | `synchronize` | the pull request carries `ci:preview-web` | upgrade |
   | `unlabeled` | `github.event.label.name == 'ci:preview-web'` | uninstall |
   | `closed` | always | uninstall |

   Any other label MUST do nothing at all.
3a. `opened` is in the list because a pull request created with the label already on it - through the API, or from a template that applies labels - emits no `labeled` event, so it would otherwise need the label removed and re-added before it deployed. *(Amended: the original list omitted `opened`.)*
3b. The action MUST be decided from the event payload **before** any checkout, and the checkout MUST be conditional on there being work to do. Most events this workflow sees are a push to a pull request nobody labeled, and those must not pay for a full-history clone to conclude "do nothing" - the same principle as the `changes` job in `ci/010`.
4. The label MUST be `ci:preview-web`, created by `make repo-settings` (`ci/010` req 6). A comment trigger MUST NOT be used: `issue_comment` fires on every issue in the repository, runs the workflow file from the default branch rather than the pull request head, and carries no state, so a release nobody cleaned up becomes invisible.
5. Releases MUST share one namespace, `ahorro-pr`, and MUST be named `pr-<n>-api` and `pr-<n>-web`. `svc.fullname` is `{{- if eq .Release.Name (include "svc.name" .) }}` - **exact equality**, not `contains` - so these render as `pr-42-api-ahorro-api`. The helper MUST NOT be changed to `contains`: it would rename every live object in `ahorro`. *(Amended: the original text said "named per pull request" and cited `<release>-<chart>`, which does not survive two components sharing one number - both would have been `pr-42`.)*
6. Hostnames MUST be `ahorro-pr-<n>.<fqdn>` — exactly one label below the domain. The platform's wildcard certificate and the external-dns domain filter are both single-label, so `pr-42.ahorro.<fqdn>` would have neither TLS nor DNS.
7. A preview MUST use the real Cognito user pool, read from SSM as `deploy/060` req 7 describes. There is one pool and one app client per platform project by design, so a preview needs no new identity and no terraform change.
8. Teardown MUST remove both Helm releases with `--ignore-not-found`, and MUST succeed when there is nothing to remove. The DNS records go with the routes, because external-dns runs with `--policy=sync`.
8a. The namespace MUST NOT be deleted. `ahorro-pr` carries `argocd.argoproj.io/tracking-id` and is created by the platform at sync wave 1; the deploy credential is **denied** namespace deletion, and Argo would recreate it anyway. *(Amended: requirement 8 required the delete.)*
8b. GHCR versions MUST NOT be deleted automatically, and the `-pr-<n>` artifacts are left in place. The packages are owned by a **User**, not an Organization, so the only delete endpoint is the user-level one, which needs a PAT carrying `delete:packages` - a scope `GITHUB_TOKEN` does not have. This repository holds **no** secrets, and that is worth more than a tidy package list: storage is free and unlimited for a public package, so the cost is clutter, not money. Prune by hand from the GitHub UI when it becomes a nuisance. *(Amended: requirement 8 required the delete.)*
9. **Dropped.** A scheduled prune of untagged manifests needs the same PAT as 8b. A multi-arch build does leave untagged manifests behind, and nothing removes them; that is accepted for a public package where storage is free. Revisit only if the package list becomes unusable, and then with a fine-grained token scoped to this repository alone.
10. `-main.<sha>` versions MUST NOT be pruned. One per merge is the record of what ran.
11. Make targets `preview-up PR=<n> VERSION=<v>` and `preview-down PR=<n>` MUST run the same script the workflow runs, so a preview can be driven from a laptop. The workflow MUST call `scripts/preview.sh` **directly**, never through make, for the reason in `deploy/060` req 6c: make collapses every recipe failure to exit 2, which is the status reserved for an unreachable cluster.

## Implementation hints

Tearing down on `closed` is safe here, although ADR 0007 rejected a
`pull_request: closed` trigger. Its reason was a race with a second merge for
a shared branch; removing one pull request's own release races nothing.

`closed` fires for both a merge and an abandon, and needs no branch between
them — the preview goes either way.

A teardown MUST succeed when there is nothing to remove, because `unlabeled`
can arrive for a pull request that was never deployed. `helm uninstall
--ignore-not-found` and a guarded namespace delete cover it.

`scripts/preview.sh` reuses `scripts/kubeconfig.sh` unchanged: it already
takes the target path as its first argument, masks the token, preflights in
ten seconds, and exits 2 for unreachable and 1 for a missing grant. Pass the
path in; never read it back from stdout (`deploy/060` req 6f).

`github.event.number` is the pull request number on every one of the four
event types, which `github.event.pull_request.number` is not.

## Testing / acceptance criteria

1. Opening a pull request that changes `flutter-ui/` **rebuilds** `ahorro-web` and skips the `ahorro-api` build, while publishing both at the same `-pr-<n>`. No namespace is created.
2. Adding the `ci:preview-web` label creates `ahorro-pr`, installs the release, and `https://ahorro-pr-<n>.<fqdn>` returns the client with a `config.json` naming its own API host.
3. Signing in on that hostname with a real pool user succeeds.
4. Adding any other label does nothing: no workflow run beyond `ci.yml`, and no change in the cluster.
5. Pushing a commit upgrades the existing release; `helm -n ahorro-pr list` shows one release for that pull request, not two.
6. A second labeled pull request coexists in the same namespace, on its own hostname, with both reachable. *(Verified 2026-10-07 with two previews at once: four releases in `ahorro-pr`, four pods Running, four HTTPRoutes Accepted, both web hosts answering HTTPS 200 with a valid chain, and each `config.json` naming its own API host.)*
7. Removing the label uninstalls both releases and the DNS records disappear. The `-pr-<n>` GHCR versions remain, per req 8b. *(The script half verified 2026-10-07: `make preview-down PR=99` removed both releases, left `pr-98` running, left the namespace in place, and Route53 held no `pr-99` record afterwards. A `dig` still answered for a while - that was a resolver cache, not a record.)*
8. Closing a labeled pull request without removing the label does the same.
9. Removing the label from a pull request that was never deployed succeeds and changes nothing. *(Verified 2026-10-07: `make preview-down PR=12345` exited 0.)*
10. **Dropped with req 9.**
