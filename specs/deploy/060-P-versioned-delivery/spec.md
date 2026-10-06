---
id: "DEPLOY-060"
status: "DRAFT"
updated: "2026-10-06"
---
# 060 — Versioned delivery: the channels, `ahorro-dev`, and the release

**Status note:** Draft. Replaces [`deploy/010`](../010-Z-deploy-branch-and-release/spec.md),
which is superseded. Implements
[ADR 0009](../../../docs/adr/0009-three-environments-and-per-component-versions.md)
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

1. Each component MUST carry its own semver in its own `Chart.yaml`, bumped by hand in the pull request that changes the chart. `scripts/chart-version-check.sh` keeps enforcing that; it MUST additionally fail when `gitops/values.yaml` pins a version no chart declares, so the two cannot drift.
2. `helm-package` MUST accept a `--version` override (core 040 req 7a) and publish on three channels from one chart source: `<version>-pr-<n>`, `<version>-main.<short-sha>`, and the clean `<version>`. The image tag MUST equal the chart version. A version MUST NOT carry `+build` metadata.
3. `gitops/values.yaml` MUST pin an exact version for every chart and every image, and MUST NOT use a range or a moving tag. `gitops/templates/validate.yaml` MUST `fail` when any of them is empty, so an unpinned render is impossible rather than merely discouraged.
4. `.github/workflows/release.yml` MUST be renamed `deploy.yml`. It MUST gain the `changes` job of `ci/010` req 2 so only a component whose inputs changed is built, versioned and published.
5. On a push to `main`, `deploy.yml` MUST publish `<version>-main.<short-sha>` for each changed component, then `helm upgrade --install` those releases into namespace `ahorro-dev`. It MUST NOT touch namespace `ahorro`.
6. The pipeline MUST obtain cluster access by assuming `ahorro-ci-role` through OIDC and reading `/<project>/cluster/ahorro-deploy/{token,ca,endpoint}` from SSM, building a kubeconfig in the workspace. No kubeconfig and no token is persisted between runs, and none is stored as a GitHub secret: the cluster is disposable, so a stored credential dies at the next `make up` (ADR 0010).
7. The pipeline MUST read the root domain from `/account/root_domain` and build `host`, `config.apiBaseUrl` and `corsAllowedOrigins` from it. It MUST read the Cognito identifiers from `/<project>/persistent/ahorro-cognito/` and pass them, so `ahorro-dev` signs in against the real user pool. No hostname and no domain is committed (constitution §4).
8. A release MUST be a `workflow_dispatch` on `deploy.yml` that publishes the clean `<version>` for each component whose current `Chart.yaml` version has not yet been published. It MUST NOT take a version as an input: the version is whatever Git says, written in a reviewed pull request.
9. Promotion into `ahorro` MUST be a pull request against `vk-lab-platform` that bumps `ahorro.targetRevision`. Nothing automatic MUST move it.
10. Both child Applications and the platform pointer MUST set `selfHeal: true` (core 060 req 6, as amended). `prune: true` stays.
11. Make targets MUST cover every pipeline action, so each runs from a laptop with the operator's own credentials: `deploy-dev` and the `deploy/070` preview pair. The Makefile keeps one line per recipe; the logic goes to `scripts/`.

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

Requirement 1's cross-check is a `grep` of `gitops/values.yaml` against each
`Chart.yaml`; it needs no new tool.

## Testing / acceptance criteria

1. `make helm-package CHART=ahorro-api VERSION=0.3.0-main.abc1234` produces `ahorro-api-0.3.0-main.abc1234.tgz`, and `helm template` of it names the image at the same tag.
2. `helm template gitops` fails with a clear message when a chart version or an image tag is empty, and renders when both are pinned.
3. `make gitops-check` passes for both targets and reports no range and no moving tag.
4. A merge touching only `internal/` publishes `ahorro-api` and does not publish `ahorro-web`, and `gitops/values.yaml` still names the web chart's current version.
5. After that merge, `helm -n ahorro-dev list` shows the new `ahorro-api` version and the unchanged `ahorro-web` one, and `helm -n ahorro list` is empty of pipeline releases.
6. `https://ahorro-dev.<fqdn>` serves `config.json` whose `apiBaseUrl` names `api-ahorro-dev.<fqdn>`, and signing in with a real pool user succeeds.
7. `argocd app get vk-ahorro` reports the pinned version, unchanged by the merge.
8. A `workflow_dispatch` release publishes the clean version; a second dispatch with no chart bump publishes nothing and says so.
9. `make down` then `make up` returns `ahorro` to the pinned version, and the next merge still deploys — proving the SSM token was republished.
10. `make domain-check` passes with `ROOT_DOMAIN` supplied, and no file in the diff carries a hostname.
