---
id: "DEPLOY-060"
status: "DRAFT"
updated: "2026-10-06"
---
# 060 — Versioned delivery: the channels, `ahorro-dev`, and the release

**Status note:** Draft. Replaces [`deploy/010`](../010-Z-deploy-branch-and-release/spec.md),
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
6. The pipeline MUST obtain cluster access by assuming `ahorro-ci-role` through OIDC and reading `/<project>/cluster/ahorro-deploy/{token,ca,endpoint}` from SSM, building a kubeconfig in the workspace. No kubeconfig and no token is persisted between runs, and none is stored as a GitHub secret: the cluster is disposable, so a stored credential dies at the next `make up` (ADR 0010).
7. The pipeline MUST read the root domain from `/account/root_domain` and build `host`, `config.apiBaseUrl` and `corsAllowedOrigins` from it. It MUST read the Cognito identifiers from `/<project>/persistent/ahorro-cognito/` and pass them, so `ahorro-dev` signs in against the real user pool. No hostname and no domain is committed (constitution §4).
8. A release MUST be a `workflow_dispatch` on `deploy.yml` that tags the repository and publishes the clean `<version>` for **every** component. It MUST take only the bump level — patch, minor or major — never a version string, so the number is always derivable from the tag history.
9. Promotion into `ahorro` MUST be a pull request against `vk-lab-platform` that bumps `ahorro.targetRevision`. It MUST be **one line**, because every component is at the same version. Nothing automatic MUST move it.
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
5. After that merge, `helm -n ahorro-dev list` shows **both** releases at that one version, and `helm -n ahorro list` is empty of pipeline releases.
6. `https://ahorro-dev.<fqdn>` serves `config.json` whose `apiBaseUrl` names `api-ahorro-dev.<fqdn>`, and signing in with a real pool user succeeds.
7. `argocd app get vk-ahorro` reports the pinned version, unchanged by the merge.
8. A `workflow_dispatch` release with bump level `patch` after `0.5.0` tags `v0.5.1`, publishes both components at `0.5.1`, and the resulting platform pull request changes exactly one line.
8a. A build published after release `0.5.0` is named `0.5.1-main.<sha>`, and `helm show chart` confirms it sorts **above** `0.5.0`.
9. `make down` then `make up` returns `ahorro` to the pinned version, and the next merge still deploys — proving the SSM token was republished.
10. `make domain-check` passes with `ROOT_DOMAIN` supplied, and no file in the diff carries a hostname.
