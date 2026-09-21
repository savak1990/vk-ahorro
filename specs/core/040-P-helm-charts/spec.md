---
id: "CORE-040"
status: "DRAFT"
updated: "2026-09-21"
---
# 040 — Helm chart for hello

**Status note:** Draft. Covers the `hello` chart and the chart tooling every
later chart reuses. The `web` chart moved to 105, which cannot start before
the Flutter web build exists.

**Complexity:** Small–Medium
**Risk:** Low — a wrong `parentRef` or missing `SkipDryRunOnMissingResource` makes Argo fail the dry run before the Gateway CRDs exist.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [030-images-and-registry](../030-D-images-and-registry/spec.md)
**Lifecycle class(es) touched:** Disposable (every object the chart renders).

## Scope

One chart under `deploy/helm/hello`, rendering a Deployment, a Service, an
HTTPRoute on the platform gateway, and its ConfigMap. The chart is packaged
and pushed to GHCR as an OCI artifact. The Make targets and the CI job this
spec adds MUST work for any chart, so 105 adds `web` without changing them.

Excludes: the `web` chart (105), the Argo `Application` objects that install
these charts and the values Argo passes in (060).

## Requirements

1. `deploy/helm/hello` MUST contain `Chart.yaml` (semver `version`, `appVersion` = image tag at package time), `values.yaml`, `templates/deployment.yaml`, `templates/service.yaml`, `templates/httproute.yaml`, `templates/configmap.yaml`, `templates/_helpers.tpl` and `templates/NOTES.txt`.
2. Deployment: `replicas: 1`, `image: {{ .Values.image.repository }}:{{ .Values.image.tag }}`, `imagePullPolicy: IfNotPresent`, readiness and liveness probes on `/healthz`, requests `10m/32Mi` and a memory limit of `128Mi` with no cpu limit (the platform's own convention), `securityContext` non-root with a read-only root filesystem, `automountServiceAccountToken: false`.
3. Service: `ClusterIP`, port 80 → container 8080.
4. HTTPRoute: `parentRefs: [{name: platform-gateway, namespace: envoy, sectionName: https}]`, `hostnames: [{{ .Values.host }}]`, one rule to the Service, annotations `argocd.argoproj.io/sync-wave: "2"` and `argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true` (copy `vk-lab-platform/gitops/templates/platform/shared/envoy-gateway/httproutes.yaml`).
5. `host` and `image.tag` MUST have no default; `helm template` MUST fail with a clear message when either is empty (constitution §4: the hostname only ever arrives as a value). `NOTES.txt` MUST NOT print the host.
5a. `image.tag` MUST accept any tag, not only a SHA. `imagePullPolicy` MUST be derived from the tag — `IfNotPresent` for a 40-character commit SHA, `Always` otherwise — because a node that cached a moving tag never re-pulls it. `image.pullPolicy` MAY override the derived value.
6. The ConfigMap MUST carry the env values `COGNITO_ISSUER`, `COGNITO_CLIENT_ID` and `CORS_ALLOWED_ORIGINS`, with a checksum annotation on the pod template so a config change restarts the pods. Every value key MUST be a scalar: Argo's `helm.parameters` carries scalar overrides only.
7. Make targets: `helm-lint`, `helm-template` (renders with a placeholder host), `helm-package` (to `dist/`), `helm-push` (`helm push dist/*.tgz oci://ghcr.io/savak1990/vk-ahorro/charts`). `CHART_VERSION` is read from `Chart.yaml`.
8. `.github/workflows/ci.yml` MUST gain a job that runs `helm lint`, renders the chart, validates the output with `kubeconform -strict` against the Gateway API schemas, and fails when a chart changed but its `version` did not.
9. `.github/workflows/release.yml` MUST package and push the chart on a merge to `main`, keeping `contents: read` and `packages: write`.
10. GHCR package `charts/hello` MUST be public so Argo pulls the chart without a secret.

## Implementation hints

- Start from `helm create`, then delete Ingress, HPA, ServiceAccount, and tests. Keep `_helpers.tpl` naming.
- Gateway API schemas for kubeconform: `-schema-location default -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'`. Do not add `-ignore-missing-schemas`: the only custom resource here is `HTTPRoute`, which the catalog carries, so a missing schema is a real failure.
- `required "host is required" .Values.host` in the HTTPRoute template implements requirement 5.
- The placeholder host used for rendering is a documented dummy, never a real hostname. The platform's own CI does the same.

## Testing / acceptance criteria

- `make helm-lint` clean.
- `make helm-template` output passes `kubeconform -strict -summary`; the output contains one `HTTPRoute` with `parentRefs[0].name == platform-gateway`.
- `helm template deploy/helm/hello` without `--set host=...` fails with "host is required".
- The placeholder host appears in no packaged chart and in no committed file.
- `make helm-push` then `helm pull oci://ghcr.io/savak1990/vk-ahorro/charts/hello --version <v>` succeeds from a machine with no GitHub login.
- `helm install` into a kind cluster with the Gateway API CRDs installed (no controller) results in a Ready pod; `kubectl port-forward` answers `/healthz` with `200 {"status":"ok"}`.
- A pull request that edits the chart without bumping `version` fails CI.
