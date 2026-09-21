---
id: "CORE-030"
status: "IN_PROGRESS"
updated: "2026-09-21"
---
# 030 — Container images, registry, and CI

**Status note:** The `hello` half is done. Requirements 1, 3, 4, 5 (for
`hello`) and the root-domain guard of 6 ship in `deploy/docker/hello.Dockerfile`,
`scripts/domain-guard.sh`, the `image-*` Make targets, `.github/workflows/ci.yml`
and `.github/workflows/release.yml`. The guard reads a `ROOT_DOMAIN` repository
secret: `vk-lab-platform` reads the same value from KMS through an OIDC role,
which this repository cannot do before 050 creates one, and requirement 7 forbids
AWS credentials in the release workflow. Deferred, with the spec that unblocks
each: requirement 2 and the `web` parts of 3, 4, 5 and 8 (070, and 090 for the
Flutter toolchain); the `helm lint` step of 6 (040); the `terraform fmt -check`
step of 6 (050); the `flutter analyze` and `flutter test` steps of 6 (070, 090);
the chart push of 7 (040); the `gitops/values.yaml` commit of 7 (060).

**Complexity:** Medium
**Risk:** Medium — a CI loop (the SHA commit retriggers the build) or a `latest` tag breaks Argo's diff.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [020-go-hello-service](../020-D-go-hello-service/spec.md), 070-flutter-shell-trim (for the web image)
**Lifecycle class(es) touched:** None in AWS. GHCR packages are persistent by nature: they survive a platform `make down`.

## Scope

Multi-arch images for `hello` and `web`, pushed to GHCR, built locally by
Make and in CI by GitHub Actions. The CD handoff is a Git commit of the new
SHA into `gitops/values.yaml` (platform ADR 0015).

Excludes: Helm chart packaging and push (040), the runtime `config.json`
content for web (080).

## Requirements

1. `deploy/docker/hello.Dockerfile`: builder `golang:1.26` with `--platform=$BUILDPLATFORM`, `CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH`, final stage `gcr.io/distroless/static-debian12:nonroot`, `EXPOSE 8080`, `ENTRYPOINT ["/hello"]`.
2. `deploy/docker/web.Dockerfile`: build stage `ghcr.io/cirruslabs/flutter:<pinned>` with `--platform=$BUILDPLATFORM` running `flutter build web --release`; final stage `nginxinc/nginx-unprivileged:<pinned>` serving `/usr/share/nginx/html` on port 8080 with SPA fallback (`try_files $uri /index.html`) and `Cache-Control: no-store` for `config.json` and `index.html`. `config.json` MUST be replaceable at runtime by a mounted file.
3. Both images MUST be built for `linux/amd64,linux/arm64` with `docker buildx` (the platform runs arm64 Karpenter nodes on AWS and amd64 on Civo).
4. Tags MUST be the full commit SHA: `ghcr.io/savak1990/vk-ahorro/hello:<sha>`, `.../web:<sha>`. `latest` MUST NOT be pushed (constitution §5).
5. Make targets: `image-build SVC=<hello|web>` (single arch, `--load`, for local runs), `image-push SVC=<hello|web>` (multi-arch, push), `images-push` (both). Variables `REGISTRY ?= ghcr.io/savak1990/vk-ahorro`, `IMAGE_TAG ?= $(shell git rev-parse HEAD)`.
6. `.github/workflows/ci.yml` runs on pull requests: `go test`, `golangci-lint`, `helm lint`, `flutter analyze`, `flutter test`, `terraform fmt -check`, and the root-domain grep from 000.
7. `.github/workflows/release.yml` runs on push to `main` with `paths-ignore: [gitops/**, docs/**, specs/**]`: builds and pushes both images, packages and pushes both charts (040), then commits the new SHA into `gitops/values.yaml` with a `[skip ci]` message. Permissions: `contents: write`, `packages: write`. No AWS credentials in this workflow.
8. GHCR packages `hello`, `web`, `charts/hello`, `charts/web` MUST be public so the cluster pulls without a secret.

## Implementation hints

- Copy the login and `docker/build-push-action@v6` steps from `vk-lab-platform/.github/workflows/sidecar-image.yml`; add `platforms: linux/amd64,linux/arm64`.
- Buildx needs a `docker-container` driver for multi-arch: `docker buildx create --use --name vk` once, wrapped in a `buildx-init` target.
- The Flutter build stage is slow (5–8 min). Cache `~/.pub-cache` with `actions/cache` keyed on `pubspec.lock`.
- Package visibility is set once in GitHub UI (Packages → package → settings → Change visibility) or via `gh api -X PATCH /user/packages/container/<name>` when the API supports it.

## Testing / acceptance criteria

- `make image-build SVC=hello && docker run --rm -p 8080:8080 -e AUTH_DISABLED=true ghcr.io/savak1990/vk-ahorro/hello:<sha>` answers `curl localhost:8080/healthz` on an arm64 Mac.
- `make images-push` then `docker buildx imagetools inspect ghcr.io/savak1990/vk-ahorro/hello:<sha>` lists `linux/amd64` and `linux/arm64`; same for `web`.
- `docker run --rm -p 8081:8080 -v $PWD/flutter-ui/web/config.json:/usr/share/nginx/html/config.json:ro .../web:<sha>` serves the Flutter app and the mounted `config.json`.
- A merged pull request to `main` produces exactly one `release` run, one image push per service, and one `[skip ci]` commit; that commit does not start a second run.
- `docker pull` of each image works from a machine with no GitHub login.
- CI fails when a committed file contains the root domain (constitution §4). The
  check reads the domain from a secret, never from Git. It reads the whole
  history, not only the working tree: a public repository publishes every
  commit. It reports file names and commit ids only, never a matched line.
- Every GitHub action in every workflow is pinned to a full commit SHA with the
  version in a trailing comment. A tag can be moved; a commit cannot.
