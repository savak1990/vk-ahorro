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

1. Every pull request MUST publish an image and a chart as `<version>-pr-<n>` for **every** component, from `ci.yml`, with an unchanged one copied rather than rebuilt (`deploy/060` req 2a). This happens with or without the label: an artifact that exists is what makes the deployment a single `helm install`, and one version names the whole preview.
2. Deployment MUST live in a **new** workflow file, `.github/workflows/preview.yml`, and MUST NOT be a job in `ci.yml`. `ci.yml` relies on the default `pull_request` types, so a label event does not re-run it today; its required status checks are maintained by hand, and a context that never reports blocks every merge.
3. `preview.yml` MUST trigger on `pull_request` types `[labeled, unlabeled, synchronize, closed]` and act only as follows:

   | Event | Condition | Action |
   |---|---|---|
   | `labeled` | `github.event.label.name == 'preview'` | install |
   | `synchronize` | the pull request carries `preview` | upgrade |
   | `unlabeled` | `github.event.label.name == 'preview'` | uninstall and delete artifacts |
   | `closed` | always | the same |

   Any other label MUST do nothing at all.
4. The label MUST be `preview`, created by `make repo-settings` (`ci/010` req 6). A comment trigger MUST NOT be used: `issue_comment` fires on every issue in the repository, runs the workflow file from the default branch rather than the pull request head, and carries no state, so a release nobody cleaned up becomes invisible.
5. Releases MUST share one namespace, `ahorro-pr`, named per pull request so they coexist. The chart's `svc.fullname` is `<release>-<chart>`, so `pr-42` and `pr-43` collide on nothing.
6. Hostnames MUST be `ahorro-pr-<n>.<fqdn>` — exactly one label below the domain. The platform's wildcard certificate and the external-dns domain filter are both single-label, so `pr-42.ahorro.<fqdn>` would have neither TLS nor DNS.
7. A preview MUST use the real Cognito user pool, read from SSM as `deploy/060` req 7 describes. There is one pool and one app client per platform project by design, so a preview needs no new identity and no terraform change.
8. Teardown MUST remove the Helm release and MUST also delete the `-pr-<n>` image tags and chart versions from GHCR. The namespace MUST be deleted when its last release goes.
9. A scheduled workflow MUST prune untagged GHCR manifests with `delete-only-untagged-versions: true`. A multi-arch build leaves two per image and nothing else removes them; this is the only artifact class that grows without bound.
10. `-main.<sha>` versions MUST NOT be pruned. One per merge is the record of what ran.
11. Make targets `preview-up PR=<n>` and `preview-down PR=<n>` MUST run the same scripts the workflow runs, so a preview can be driven from a laptop.

## Implementation hints

Tearing down on `closed` is safe here, although ADR 0007 rejected a
`pull_request: closed` trigger. Its reason was a race with a second merge for
a shared branch; removing one pull request's own release races nothing.

`closed` fires for both a merge and an abandon, and needs no branch between
them — the preview goes either way.

A teardown MUST succeed when there is nothing to remove, because `unlabeled`
can arrive for a pull request that was never deployed. `helm uninstall
--ignore-not-found` and a guarded namespace delete cover it.

`actions/delete-package-versions` needs `packages: write` and the version id,
not the tag; list the versions and filter by name.

`github.event.number` is the pull request number on every one of the four
event types, which `github.event.pull_request.number` is not.

## Testing / acceptance criteria

1. Opening a pull request that changes `flutter-ui/` **rebuilds** `ahorro-web` and skips the `ahorro-api` build, while publishing both at the same `-pr-<n>`. No namespace is created.
2. Adding the `preview` label creates `ahorro-pr`, installs the release, and `https://ahorro-pr-<n>.<fqdn>` returns the client with a `config.json` naming its own API host.
3. Signing in on that hostname with a real pool user succeeds.
4. Adding any other label does nothing: no workflow run beyond `ci.yml`, and no change in the cluster.
5. Pushing a commit upgrades the existing release; `helm -n ahorro-pr list` shows one release for that pull request, not two.
6. A second labeled pull request coexists in the same namespace, on its own hostname, with both reachable.
7. Removing the label uninstalls the release, deletes the DNS record, and removes the `-pr-<n>` versions from GHCR.
8. Closing a labeled pull request without removing the label does the same.
9. Removing the label from a pull request that was never deployed succeeds and changes nothing.
10. The scheduled prune removes untagged manifests and leaves every tagged version in place.
