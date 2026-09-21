---
id: "CORE-030"
status: "DONE"
updated: "2026-09-21"
---
# 030 — The hello image, the registry, and CI

**Status note:** Done. `deploy/docker/hello.Dockerfile`, the `image-*` Make
targets, `.github/workflows/ci.yml`, `.github/workflows/release.yml`,
`scripts/domain-guard.sh` and `.github/dependabot.yml` ship the whole scope.
The guard reads the root domain from the platform's SSM parameter
`/account/root_domain` over the `ahorro-ci-role` OIDC role that
`vk-lab-platform` defines; see [ADR 0003](../../../docs/adr/0003-identity-lives-in-the-platform.md).
The image is public at `ghcr.io/savak1990/vk-ahorro/hello:<sha>` for
`linux/amd64` and `linux/arm64`.

This spec once carried every step any later spec would add to the workflows,
which made it impossible to close. Each of those clauses now belongs to the
spec that adds the step: the `helm` job and the chart push to 040, the
`terraform fmt -check` step to 050, the `gitops/values.yaml` commit and the
`contents: write` permission to 060, `flutter analyze` and `flutter test` to
070, and everything `web` to 105.

**Complexity:** Medium
**Risk:** Medium — a CI loop (the SHA commit retriggers the build) or a `latest` tag breaks Argo's diff.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [020-go-hello-service](../020-D-go-hello-service/spec.md)
**Lifecycle class(es) touched:** None in AWS. GHCR packages are persistent by nature: they survive a platform `make down`.

## Scope

The multi-arch `hello` image on GHCR, built locally by Make and in CI by
GitHub Actions, and the pull-request gate those later specs extend.

Excludes: the `web` image and everything that serves the Flutter build (105),
Helm chart packaging and push (040), the CD commit into `gitops/values.yaml`
(060).

## Requirements

1. `deploy/docker/hello.Dockerfile`: builder `golang:1.26` with `--platform=$BUILDPLATFORM`, `CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH`, final stage `gcr.io/distroless/static-debian12:nonroot`, `EXPOSE 8080`, `ENTRYPOINT ["/hello"]`.
2. The image MUST be built for `linux/amd64,linux/arm64` with `docker buildx` (the platform runs arm64 Karpenter nodes on AWS and amd64 on Civo).
3. Every push MUST publish the full commit SHA tag `ghcr.io/savak1990/vk-ahorro/hello:<sha>` (constitution §5). It MAY publish additional moving tags for the branch or release tag being built, as a convenience for local runs. `latest` MUST NOT be pushed. GitOps MUST pin the SHA and never a moving tag: Argo diffs manifest text, so a moving tag leaves the rendered manifest unchanged and the old image running.
4. Make targets: `image-build SVC=<svc>` (single arch, `--load`, for local runs), `image-push SVC=<svc>` (multi-arch, push), `images-push` (every image). Variables `REGISTRY ?= ghcr.io/savak1990/vk-ahorro`, `IMAGE_TAG ?= $(shell git rev-parse HEAD)`. The `SVC` argument MUST work for any service, so 105 adds `web` without changing a target.
5. `.github/workflows/ci.yml` runs on pull requests: `go test`, `golangci-lint`, a multi-arch image build that is not pushed, `make specs-check`, and the root-domain check from 000. Later specs add their own jobs and steps here.
6. `.github/workflows/release.yml` runs on push to `main` with `paths-ignore: [gitops/**, docs/**, specs/**]` and builds and pushes the image. Permissions: `contents: read`, `packages: write`. No AWS credentials in this workflow. 060 raises `contents` to `write` when it adds the CD commit.
7. GHCR package `hello` MUST be public so the cluster pulls without a secret.
8. Every GitHub action MUST be pinned to a full commit SHA with the version in a trailing comment, and Dependabot MUST watch the `github-actions`, `docker` and `gomod` ecosystems.

## Implementation hints

- Copy the login and `docker/build-push-action` steps from `vk-lab-platform/.github/workflows/sidecar-image.yml`; add `platforms: linux/amd64,linux/arm64`.
- Buildx needs a `docker-container` driver for multi-arch: `docker buildx create --use --name vk` once, wrapped in a `buildx-init` target.
- Package visibility is set once in the GitHub UI (Packages → package → settings → Change visibility). There is no API for a user-owned package.

## Testing / acceptance criteria

- `make image-build SVC=hello && docker run --rm -p 8080:8080 -e AUTH_DISABLED=true ghcr.io/savak1990/vk-ahorro/hello:<sha>` answers `curl localhost:8080/healthz` on an arm64 Mac.
- `make images-push` then `docker buildx imagetools inspect ghcr.io/savak1990/vk-ahorro/hello:<sha>` lists `linux/amd64` and `linux/arm64`.
- After a merge to `main`, `docker pull ghcr.io/savak1990/vk-ahorro/hello:main` resolves to the same digest as that run's SHA tag.
- `docker pull` of that tag works from a machine with no GitHub login.
- A merged pull request to `main` produces exactly one `release` run and one image push.
- CI fails when a committed file contains the root domain (constitution §4). The
  check reads the domain from the platform's SSM parameter
  `/account/root_domain`, never from Git, over a GitHub OIDC role scoped to
  this repository. It reads the whole
  history, not only the working tree: a public repository publishes every
  commit. It reports file names and commit ids only, never a matched line.
- The check fails closed. No role, no parameter, or a history it cannot walk
  all exit non-zero rather than reporting clean.
