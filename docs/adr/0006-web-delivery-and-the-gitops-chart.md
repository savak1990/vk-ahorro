# ADR 0006: Web delivery, the GitOps chart, and the names they ship under

## Status

Accepted

Implements specs 060 and 105. Deviates from four of their written
requirements; each deviation is recorded below.

## Context

Nothing in this repository reached a cluster. The Go service had an image and
a chart on GHCR, the Flutter client had neither, and no Argo CD wiring existed
on either side of the platform boundary. The goal is that `make full-up` in
`vk-lab-platform` ends with both applications running and reachable, with no
manual step.

Spec 060 defines the app-of-apps chart and the platform pointer; spec 105
defines the web image, its chart and its Argo `Application`. Platform ADR 0015
fixes the two-level topology, and platform ADR 0042 puts the Cognito pool in
the platform's persistent layer.

## Decision

### 1. The names are `ahorro-api` and `ahorro-web`

`hello` described the one endpoint the service had, not the service. It is
renamed end to end: `cmd/ahorro-api`, `internal/api`, the Dockerfile, the
chart, and the GHCR packages. The Flutter web artifacts are `ahorro-web`.

The endpoint `/api/v1/hello` and the greeting it returns are unchanged — they
are the API, not the deployable. The spec folder `020-D-go-hello-service`
keeps its name, because renaming a finished spec's folder rewrites every link
to it for no gain.

`internal/platform/auth` and `internal/platform/httpx` keep their names: they
are shared, not service-specific. `ghcr.io/savak1990/vk-ahorro/hello` and
`charts/hello` become orphans; published artifacts are never deleted.

The cost is churn across three finished specs, two draft specs and two
documents. It was paid now because every later spec would have repeated the
wrong name.

### 2. The web image serves one build to every environment

`deploy/docker/ahorro-web.Dockerfile` builds with the pinned Cirrus Flutter
image and serves from `nginx-unprivileged` on 8080. The Flutter client reads
`config.json` at startup, and the chart mounts that file from a ConfigMap, so
one image serves every environment. `AppConfig.load()` fetches
`Uri.base.resolve('config.json')` on web and keeps `String.fromEnvironment` on
mobile, which has no server to fetch from.

`config.json` is mounted with `subPath`. Without it the volume shadows the
whole html directory and the application disappears. A `subPath` mount never
receives ConfigMap updates from kubelet, so the pod-template checksum
annotation is what applies a changed value.

Hashed assets are served `immutable` with a one-year expiry and a `=404`
fallback rather than the SPA rewrite: a cached shell asking for a deleted hash
would otherwise receive HTML with `Content-Type: text/html` for a JavaScript
module, which is the classic post-deploy white screen. `index.html` and
`config.json` are `no-store`, or a deploy leaves browsers pointing at old
asset hashes and an old API URL.

### 3. Backend Applications render from a loop

`gitops/templates/services.yaml` ranges over `.Values.services` rather than
declaring one template per service. Every Go service takes the same parameter
shape, so the loop is about the size of one static template and handles any
number of them. Adding a service becomes four lines of values. The web chart
keeps its own template, because its parameters are the four `config.*` keys.

This is the shape platform ADR 0015 endorses over ApplicationSet.

### 4. Nothing is pinned, for now

`image.tag` is the moving `main` tag and `chartVersion` is the wildcard `"*"`.
A fresh bring-up therefore always runs the newest build with no edit anywhere,
which is what a disposable lab wants.

**This contradicts constitution §5**, which requires GitOps to reference a
commit SHA so an Argo diff is meaningful. The consequences are real and
accepted: there is no reproducibility, no one-line rollback, and a *running*
cluster does not pick up a new image, because a moving tag leaves the rendered
manifest unchanged and Argo creates no new pod. The refresh is
`kubectl -n ahorro rollout restart deploy`.

The chart already derives `imagePullPolicy: Always` for any tag that is not a
40-character SHA, so a new pod does pull the newest image.

Two guards remain. `chart-version-check.sh` still fails a pull request that
changes a chart without bumping its version, which is what guarantees a newer
version exists for the wildcard to resolve. And no chart version may carry
build metadata: Helm rewrites `+` to `_` in the registry tag and Argo then
rejects it as invalid semver, breaking wildcard resolution entirely.

Revisit when the cluster stops being disposable, or the first time a rollback
is needed.

### 5. Both child Applications set `selfHeal: false`

The operator runs `helm install` by hand against this namespace and does not
want it reverted. `selfHeal: false` means Argo reacts only to a change in the
desired state, not to drift in the live state.

Stated plainly, because it surprises people: a change to `gitops/values.yaml`
in Git is a desired-state change and still triggers an automatic sync that
replaces a manual release.

### 6. No CDN, and no caching at Envoy

Compression, immutable caching on hashed assets and Flutter's own service
worker cover a single-operator lab. The service worker is the largest win: a
repeat visit loads from local disk with no network round trip.

CloudFront is rejected for now. It needs an ACM certificate in `us-east-1`
against a region this project fixes at `eu-west-1`; a distribution adds five
to fifteen minutes to both `full-up` and `full-down`; and a CDN terminating
the public hostname takes over DNS and TLS, which the architecture assigns to
the platform — so it would be a platform spec, not one of ours. Revisit on a
measured cold load above roughly five seconds from where the application is
actually used.

Caching at Envoy was evaluated and rejected. Envoy's HTTP cache filter is
work-in-progress with an in-memory per-worker store, and Envoy Gateway exposes
it through no policy CRD; reaching it would need an `EnvoyPatchPolicy` against
the platform's shared gateway. `BackendTrafficPolicy` covers circuit breaking,
connections, rate limiting, failover, fault injection, load balancing and
response compression — not caching. Compression and `Cache-Control` are both
available at that layer and both are done better in our own nginx, per
`location`, with no CRD and no platform coordination.

The real caches are the browser and the service worker.

## Consequences

- Four written requirements are not implemented as stated. Spec 060
  requirement 1 lists `cognito.clientId` and `cognito.issuer` only; the web
  chart also needs `cognitoUserPoolId`, so a third identifier is threaded and
  the platform's AWS resolver carries nine SSM names rather than the eight
  that requirement predicts. Spec 060 requirement 3 sets `selfHeal: true`.
  Spec 060 requirement 5 names a platform ADR number that is already taken.
  Spec 060 requirement 8 asks CI to commit the image SHA into
  `gitops/values.yaml`; with nothing pinned there is nothing to commit, so
  `release.yml` keeps `contents: read` and gains no `[skip ci]` commit.
- `cognito.region` stays a committed constant. The platform publishes no
  region parameter, and the value is fixed by constitution §7.
- The OCI chart source uses the bare registry form, `ghcr.io/...`, not the
  `oci://` form ADR 0001 writes. The bare form is the one already proven to
  sync on this platform.
- Both new GHCR packages must be public, or the cluster cannot pull them
  without a secret.
- A second pull request against `vk-lab-platform` carries the pointer, the
  `AppProject` and the SSM threading. It is the only cross-repository change.
