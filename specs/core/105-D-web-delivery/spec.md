---
id: "CORE-105"
status: "DONE"
updated: "2026-09-26"
---
# 105 — Web delivery: the image, the chart, and the Argo Application

**Status note:** Done. The `ahorro-web` image, its chart and its Argo
`Application` ship, and the Flutter client reads `config.json` at startup.

The last criterion was closed on 2026-10-07, after a full cluster rebuild: the web
pod is Running in namespace `ahorro` and the application answers over its
public hostname with HTTPS 200 and a valid certificate chain. A deep link to
`/settings` returns the application rather than a 404, and `index.html` and
`config.json` both carry `Cache-Control: no-store`. The published image is a
multi-architecture index listing `amd64` and `arm64`.
Both are on GHCR and both packages are public: release `0.2.1` published the
image and the chart, and `helm pull` of the chart succeeds from a machine with
no GitHub login (verified 2026-10-07). The one criterion still unrun is the
web pod in namespace `ahorro` reached over its public hostname; the equivalent
is recorded for `ahorro-dev` in `deploy/060` criterion 6.

Named `ahorro-web`, not `web`; see
[ADR 0006](../../../docs/adr/0006-web-delivery-and-the-gitops-chart.md).
Requirement 3's `.dockerignore` blocker is solved with a per-Dockerfile ignore
file rather than by editing the root one, so the Go build context does not
gain the mobile asset tree. Requirement 1's read-only root filesystem is on,
with `emptyDir` on `/tmp` and `/var/cache/nginx`: both were confirmed
necessary, because with neither the container does not start.

**Complexity:** Medium
**Risk:** Medium — the Flutter build stage is slow and the runtime `config.json` must stay replaceable, or the image has to be rebuilt per environment.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [040-helm-charts](../040-D-helm-charts/spec.md), [080-flutter-config-and-hello](../080-A-flutter-config-and-hello/spec.md), [090-local-toolchain](../090-P-local-toolchain/spec.md), [100-flutter-platforms](../100-P-flutter-platforms/spec.md)
**Lifecycle class(es) touched:** Disposable (every Kubernetes object the chart renders). GHCR packages are persistent by nature.

## Scope

Everything that puts the Flutter web build in front of a browser: the `web`
image, the `web` Helm chart, its Argo `Application`, and the CI steps for
each.

Excludes: the Flutter source itself (070, 080, 100), the `config.json` key
meanings (080), the `ahorro-api` chart and the chart tooling it introduces (040),
the app-of-apps chart the Application lives in (060).

## Requirements

1. `deploy/docker/web.Dockerfile`: build stage `ghcr.io/cirruslabs/flutter:<pinned>` with `--platform=$BUILDPLATFORM` running `flutter build web --release`; final stage `nginxinc/nginx-unprivileged:<pinned>` serving `/usr/share/nginx/html` on port 8080 with SPA fallback (`try_files $uri /index.html`) and `Cache-Control: no-store` for `config.json` and `index.html`. `config.json` MUST be replaceable at runtime by a mounted file.
2. The image MUST be multi-arch (`linux/amd64,linux/arm64`), tagged by the full commit SHA as `ghcr.io/savak1990/vk-ahorro/web:<sha>` and by its chart's semver, never `latest` (constitution §5, as amended by ADR 0009). It MUST build through the existing `image-push SVC=web` target with no change to that target (030 requirement 4), and `images-push` MUST gain a `web` line.
3. `.dockerignore` currently excludes `flutter-ui`, so the build context MUST be corrected before this image can build.
4. `deploy/helm/web` MUST follow the chart layout 040 establishes: `Chart.yaml`, `values.yaml`, `templates/` with `_helpers.tpl`, `deployment.yaml`, `service.yaml`, `httproute.yaml`, `configmap.yaml` and `NOTES.txt`. Resources: requests `10m/16Mi`, memory limit `64Mi`. Probe path `/`.
5. The ConfigMap MUST render `config.json` with the keys `apiBaseUrl`, `cognitoUserPoolId`, `cognitoClientId` and `cognitoRegion` (080), mounted at `/usr/share/nginx/html/config.json`, with a checksum annotation on the pod template so a value change restarts the pods.
6. `host` MUST have no default and `helm template` MUST fail with a clear message when it is empty (constitution §4). `NOTES.txt` MUST NOT print the host.
7. `gitops/templates/web.yaml` MUST render the second Argo `Application`, and `gitops/values.yaml` MUST gain `charts.web.version`, `images.web.tag` and the four `config.*` keys, with the parameters 060 requirement 3 describes.
8. `.github/workflows/ci.yml` MUST build the `web` image without pushing it, and `deploy.yml` MUST push the image and the chart. *(Renamed from `release.yml` by ADR 0009. A pull request also publishes a `-pr-<n>` build; see `deploy/070`.)*
9. GHCR packages `web` and `charts/web` MUST be public so the cluster pulls without a secret.

## Implementation hints

- The Flutter build stage is slow (5–8 min). Cache `~/.pub-cache` with `actions/cache` keyed on `pubspec.lock`.
- `nginx-unprivileged` already runs as a non-root user and listens on 8080, so the chart's `securityContext` can match the `ahorro-api` chart's.
- A read-only root filesystem needs `emptyDir` mounts for nginx's cache and run directories. Confirm before setting it.

## Testing / acceptance criteria

- `make image-push SVC=web` then `docker buildx imagetools inspect ghcr.io/savak1990/vk-ahorro/web:<sha>` lists `linux/amd64` and `linux/arm64`.
- `docker run --rm -p 8081:8080 -v $PWD/flutter-ui/web/config.json:/usr/share/nginx/html/config.json:ro .../web:<sha>` serves the Flutter app and the mounted `config.json`; a deep link such as `/settings` returns the app, not a 404.
- `curl -I` on `config.json` and `index.html` shows `Cache-Control: no-store`.
- `make helm-lint` and `make helm-template CHART=web` pass, and the rendered output passes `kubeconform -strict`.
- `helm template deploy/helm/web` without `--set host=...` fails with "host is required".
- `docker pull` and `helm pull` of the web artifacts work from a machine with no GitHub login.
- After the platform syncs: `kubectl -n ahorro get pods` shows the `ahorro-web` pod Running, and the app answers over its public hostname. *(Verified 2026-10-07 after a `make down` / `make up` cycle: HTTPS 200 with `ssl_verify_result 0`, `/settings` returns the application, and both `index.html` and `config.json` answer `Cache-Control: no-store`.)*
