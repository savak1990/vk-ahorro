---
id: "CORE-040"
status: "DRAFT"
updated: "2026-09-21"
---
# 040 — Helm charts for hello and web

**Status note:** Draft.

**Complexity:** Small–Medium
**Risk:** Low — a wrong `parentRef` or missing `SkipDryRunOnMissingResource` makes Argo fail the dry run before the Gateway CRDs exist.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** 030-images-and-registry
**Lifecycle class(es) touched:** Disposable (every object the charts render).

## Scope

One chart per service under `deploy/helm/`, each rendering a Deployment,
a Service, an HTTPRoute on the platform gateway, and its configuration
object. Charts are packaged and pushed to GHCR as OCI artifacts.

Excludes: the Argo `Application` objects that install these charts (060),
the values that Argo passes in (060).

## Requirements

1. `deploy/helm/hello` and `deploy/helm/web` MUST each contain `Chart.yaml` (semver `version`, `appVersion` = image tag at package time), `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`, `templates/httproute.yaml`, and a config object (`configmap.yaml`), plus `templates/_helpers.tpl` and `NOTES.txt`.
2. Deployment: `replicas: 1`, `image: {{ .Values.image.repository }}:{{ .Values.image.tag }}`, `imagePullPolicy: IfNotPresent`, readiness and liveness probes (`/healthz` for hello, `/` for web), resource requests and limits (hello `10m/32Mi` → `128Mi`; web `10m/16Mi` → `64Mi`), `securityContext` non-root, read-only root filesystem where the image allows, `automountServiceAccountToken: false`.
3. Service: `ClusterIP`, port 80 → container 8080.
4. HTTPRoute: `parentRefs: [{name: platform-gateway, namespace: envoy, sectionName: https}]`, `hostnames: [{{ .Values.host }}]`, one rule to the Service, annotations `argocd.argoproj.io/sync-wave: "2"` and `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` (copy `vk-lab-platform/gitops/templates/platform/shared/envoy-gateway/httproutes.yaml`).
5. `host` MUST have no default; `helm template` MUST fail with a clear message when it is empty (constitution §4: the hostname only ever arrives as a value).
6. hello ConfigMap → env: `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`, `CORS_ALLOWED_ORIGINS`. web ConfigMap → file `config.json` mounted at `/usr/share/nginx/html/config.json` with keys `apiBaseUrl`, `cognitoUserPoolId`, `cognitoClientId`, `cognitoRegion` (080). A checksum annotation on the pod template restarts pods on config change.
7. Make targets: `helm-lint`, `helm-template` (renders both with a dummy host), `helm-package` (to `dist/`), `helm-push` (`helm push dist/*.tgz oci://ghcr.io/savak1990/vk-ahorro/charts`). `CHART_VERSION` is read from `Chart.yaml`; CI fails when a chart changed but its version did not.
8. Rendered manifests MUST pass `kubeconform -strict` with the Gateway API schemas.

## Implementation hints

- Start from `helm create`, then delete Ingress, HPA, ServiceAccount, and tests. Keep `_helpers.tpl` naming.
- Gateway API schemas for kubeconform: `-schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'`.
- `required "host is required" .Values.host` in the HTTPRoute template implements Requirement 5.

## Testing / acceptance criteria

- `make helm-lint` clean for both charts.
- `make helm-template` output passes `kubeconform -strict -summary`; the output contains one `HTTPRoute` per chart with `parentRefs[0].name == platform-gateway`.
- `helm template deploy/helm/hello` without `--set host=...` fails with "host is required".
- `make helm-push` then `helm pull oci://ghcr.io/savak1990/vk-ahorro/charts/hello --version <v>` succeeds from a machine with no GitHub login.
- `helm install` of each chart into a kind cluster with Gateway API CRDs installed (no controller) results in Ready pods; `kubectl port-forward` to hello answers `/healthz`.
