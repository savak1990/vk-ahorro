---
id: "DEPLOY-060"
status: "DRAFT"
updated: "2026-10-06"
---
# 060 — Versioned delivery: the channels, `ahorro-dev`, and the release

**Status note:** Draft, and nearly closed. Everything except the merge path
itself is implemented and verified live on the hetzner lab (2026-10-07): the
version scheme, the release channel, the credential chain, and `ahorro-dev`
serving both components over public TLS with the real user pool. What remains
unrun is criteria 4, 5 and 9, which need a merge and a cluster rebuild. The
status flips in the commit that records those, not before. Replaces [`deploy/010`](../010-Z-deploy-branch-and-release/spec.md),
which is superseded. Implements
[ADR 0009](../../../docs/adr/0009-three-environments-and-one-version-track.md)
and [ADR 0010](../../../docs/adr/0010-the-pipeline-deploys-to-the-cluster.md);
the rules it enforces are written in
[`docs/delivery.md`](../../../docs/delivery.md).

Amends core 030 requirements 3 and 6, core 040 requirements 7a and 9, core 060
requirements 5, 6 and 8, core 105 requirements 2 and 8, and constitution §5.

**Complexity:** Large
**Risk:** Medium — a wrong version pin leaves Argo reporting `Synced` over an old build, and a wrong RBAC grant lets the pipeline reach the released environment.
**Estimated cost:** ~3 days, plus a pull request against `vk-lab-platform`.
**Recommended model:** Opus.
**Depends on:** `ci/010-P-change-aware-checks` (the `changes` job and `make repo-settings`), `core/060-A-gitops-and-platform-link`, and the platform spec that creates the `ahorro-deploy` ServiceAccount.
**Lifecycle class(es) touched:** Disposable (the two pipeline-owned namespaces). The SSM parameters the pipeline reads are the platform's persistent and cluster classes.

## Scope

The version scheme and the two environments the pipeline owns at merge time:
how a build is named on each channel, which components build, what a merge
deploys to `ahorro-dev`, and how a release becomes the version the platform
pins.

**Excludes:** pull-request previews and their teardown, which are
[`deploy/070`](../070-P-preview-environments/spec.md). Android and iOS, which
are `deploy/030` and `deploy/040` and which need their own ruling on
`flutter-ui/pubspec.yaml`, one version shared by three platforms. The
platform-side ServiceAccount, RBAC and SSM publication, which are a spec in
`vk-lab-platform`.

## Requirements

1. **One version number names the whole repository**, carried by a git tag. `Chart.yaml`'s `version:` MUST be overridden at package time and MUST NOT be hand-edited. `scripts/chart-version-check.sh` MUST be **deleted**: it exists only to catch a forgotten hand bump, and there is no longer one to forget.
1a. The base of a prerelease MUST be the **next** patch version, from `git describe --tags`, never the last release. A prerelease sorts below its release, so a build made after `0.5.0` named `0.5.0-main.<sha>` would claim to predate the release it followed. The correct name is `0.5.1-main.<sha>`.
2. `helm-package` MUST accept a `--version` override (core 040 req 7a) and publish on three channels from one chart source: `<version>-pr-<n>`, `<version>-main.<short-sha>`, and the clean `<version>`. The image tag MUST equal the chart version. A version MUST NOT carry `+build` metadata.
2a. **Every component MUST be published on every channel**, whether or not it changed, so one number names everything an environment runs. A component whose inputs did not change MUST NOT be rebuilt: its manifest is copied with `docker buildx imagetools create`, which uploads no layer. Change detection decides what is *built*, never what is *published*.
3. `gitops/values.yaml` MUST pin an exact version for every chart and every image, and MUST NOT use a range or a moving tag. `gitops/templates/validate.yaml` MUST `fail` when any of them is empty, so an unpinned render is impossible rather than merely discouraged.
4. `.github/workflows/release.yml` MUST be renamed `deploy.yml`. It MUST gain the `changes` job of `ci/010` req 2, which decides what is rebuilt.
5. On a push to `main`, `deploy.yml` MUST publish `<version>-main.<short-sha>` for **every** component, then `helm upgrade --install` both releases into namespace `ahorro-dev`. It MUST NOT touch namespace `ahorro`. Both releases carry the same version, so the namespace names one build of `main` rather than a mixture.
6. The pipeline MUST obtain cluster access by assuming `ahorro-ci-role` through OIDC and reading `/<project>/cluster/ahorro-deploy/{token,ca,endpoint}` from SSM, building a kubeconfig under `$RUNNER_TEMP` and **never the workspace**, where an upload step could sweep it up. No kubeconfig and no token is persisted between runs, and none is stored as a GitHub secret: the cluster is disposable, so a stored credential dies at the next `make up` (ADR 0010).
6a. The kubeconfig builder MUST preflight the cluster with a ten-second timeout and MUST exit with a **distinct status** when it is unreachable, so the caller can tell *the lab is down* from *the deploy is broken*. A missing parameter MUST report the same way: the platform deletes the credential on teardown, so absent means destroyed.
6b. An unreachable cluster MUST be reported loudly and leave the job **green**; any other failure MUST fail it. The lab is deliberately torn down when unused, so unreachable is the normal state, and a red run on every merge trains everyone to ignore the colour.
6c. CI MUST invoke `scripts/deploy-dev.sh` directly, **never** `make deploy-dev`. GNU make collapses every recipe failure to exit 2, which is the very status 6a reserves for *unreachable* - going through make would report a broken deploy as a skip and leave the job green.
6d. The workflow step MUST capture the status with `|| status=$?`, never a bare call. GitHub's default shell is `bash -eo pipefail`, so a bare call aborts the step on any non-zero exit and the branches of 6b never run - the skip is dead code and every failure is red. Proven against that exact shell.
6e. A failure to **read** the credential MUST be distinguished from a failure to **reach** the cluster. `AccessDenied` means a missing grant and MUST be red; only an absent parameter or an unanswered endpoint may be the green skip of 6b. One message for both would send the operator to rebuild a healthy cluster.
7. The pipeline MUST read the lab domain from `/<project>/cluster/ahorro-deploy/fqdn` and build `host`, `config.apiBaseUrl` and `corsAllowedOrigins` from it. *(Amended: an earlier draft said `/account/root_domain`. That parameter holds the account root, and the project's domain carries one more label; `ahorro-ci-role` can read neither the project fqdn parameter nor the subdomain it is composed from, so there is nothing to compose. The platform publishes a copy beside the deploy credential, which the role's existing wildcard already covers - vk-lab-platform spec `shared/049` req 4a.)* It MUST read the Cognito identifiers from `/<project>/persistent/ahorro-cognito/` and pass them, so `ahorro-dev` signs in against the real user pool. No hostname and no domain is committed (constitution §4).
8. A release MUST be a `workflow_dispatch` on `deploy.yml` that tags the repository and publishes the clean `<version>` for **every** component. It MUST take only the bump level — patch, minor or major — never a version string, so the number is always derivable from the tag history.
9. Promotion into `ahorro` MUST be a pull request against `vk-lab-platform` that bumps `ahorro.targetRevision`. It MUST be **one line**, because every component is at the same version. Nothing automatic MUST move it.
10. Both child Applications and the platform pointer MUST set `selfHeal: true` (core 060 req 6, as amended). `prune: true` stays.
11. Make targets MUST cover every pipeline action, so each runs from a laptop with the operator's own credentials: `deploy-dev`, `kubeconfig` and the `deploy/070` preview pair. Each recipe is one line and the logic goes to `scripts/`, which is also what lets CI call the script directly per 6c.

## Implementation hints

`git rev-parse --short HEAD` gives the suffix; `github.sha` is the full value
and must be shortened for readability, not for correctness.

`helm upgrade --install` is idempotent, so the merge path needs no branch for
the first run.

`aws ssm get-parameters` caps at ten names per call. The platform's resolver
already slices for this; copy that loop rather than writing a second one.

A kubeconfig built in the job needs the CA as base64 in
`clusters[0].cluster.certificate-authority-data` and the token in
`users[0].user.token`. Write it under `$RUNNER_TEMP`, never the workspace,
so it cannot be picked up by an upload step.

`git describe --tags --abbrev=0` gives the last release; the patch bump of it
is the prerelease base. On a repository with no tag at all the scheme has no
base, and `scripts/version.sh` MUST fail saying so rather than guess. Seeding
is a one-off human act: this repository was seeded at `v0.2.0`, matching the
highest chart version already on GHCR, because a lower base would publish
*behind* artifacts that already exist. `0.0.1` is correct only for a
repository that has published nothing.

`docker buildx imagetools create -t <repo>:<new> <repo>:<old>` is the copy for
an unchanged component. It needs the old tag to exist, so the very first
release has nothing to copy from and builds everything.

## Testing / acceptance criteria

1. `make helm-package CHART=ahorro-api VERSION=0.5.1-main.abc1234` produces `ahorro-api-0.5.1-main.abc1234.tgz`, and `helm template` of it names the image at the same tag.
2. `helm template gitops` fails with a clear message when a chart version or an image tag is empty, and renders when both are pinned.
3. `make gitops-check` passes for both targets and reports no range and no moving tag.
4. A merge touching only `internal/` **rebuilds** `ahorro-api` and does not rebuild `ahorro-web`, visible as a skipped job. Both are nonetheless **published** at the same `-main.<sha>`, and the web image's digest is unchanged from the previous version.
5. After that merge, `helm -n ahorro-dev list` shows **both** releases at that one version, and `helm -n ahorro list` is empty of pipeline releases. *(The second half is already true: Argo renders manifests and creates no Helm release, so `helm -n ahorro list` is empty by construction. Verified 2026-10-07.)*
6. `https://ahorro-dev.<fqdn>` serves `config.json` whose `apiBaseUrl` names `api-ahorro-dev.<fqdn>`, and signing in with a real pool user succeeds. *(Verified 2026-10-07 by `make deploy-dev VERSION=0.2.1`: both releases deployed, both pods Running, both HTTPRoutes `Accepted`, external-dns created a record for each, HTTPS answered 200 with a valid chain on the web host and on `/healthz` of the api host, and `config.json` carried a non-empty `apiBaseUrl` labelled `api-ahorro-dev` plus all three Cognito identifiers. The interactive sign-in is the one half still to be done by hand.)*
7. `argocd app get vk-ahorro` reports the pinned version, unchanged by the merge.
8. A `workflow_dispatch` release with bump level `patch` after `0.5.0` tags `v0.5.1`, publishes both components at `0.5.1`, and the resulting platform pull request changes exactly one line. *(Verified 2026-10-07: a `patch` dispatch after `v0.2.0` tagged `v0.2.1`, published both images and both charts at `0.2.1`, and rebuilt neither image - both manifests were copied. `helm pull` of each chart at `0.2.1` succeeded anonymously.)*
8a. A build published after release `0.5.0` is named `0.5.1-main.<sha>`, and `helm show chart` confirms it sorts **above** `0.5.0`.
9. `make down` then `make up` returns `ahorro` to the pinned version, and the next merge still deploys — proving the SSM token was republished.
10. `make domain-check` passes with `ROOT_DOMAIN` supplied, and no file in the diff carries a hostname.
