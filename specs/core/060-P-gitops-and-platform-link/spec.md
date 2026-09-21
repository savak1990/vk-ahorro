---
id: "CORE-060"
status: "DRAFT"
updated: "2026-09-21"
---
# 060 — GitOps chart and the platform pointer

**Status note:** Draft. Covers the `hello` Application only. 105 adds the
`web` Application and its values keys, and the release commit of the web
image tag.

**Complexity:** Medium
**Risk:** Medium — the only cross-repository change; a broken pointer wedges the platform's `root` Application until its retry budget runs out.
**Estimated cost:** ~1.5 days
**Recommended model:** Opus for the platform pull request, Sonnet for the chart.
**Depends on:** 040-helm-charts, 050-terraform-cognito; platform ADR 0015.
**Lifecycle class(es) touched:** Disposable (every object Argo creates from this chart).

## Scope

Two things. In this repository: the app-of-apps chart `gitops/` that Argo
renders into one `Application` per service. In `vk-lab-platform`: the
pointer `Application` and `AppProject` that make the platform's `root`
pick this repository up, so `make full-up` in the platform starts the app.

Excludes: the service charts themselves (040), CI's SHA commit (030), any
platform change outside `gitops/templates/apps/vk-ahorro/`, its golden
files, and one ADR.

## Requirements

1. `gitops/Chart.yaml` name `ahorro`. `gitops/values.yaml` MUST hold: `fqdn: ""`, `namespace: ahorro`, `repo: https://github.com/savak1990/vk-ahorro`, `charts.registry: ghcr.io/savak1990/vk-ahorro/charts`, `charts.hello.version`, `images.hello.tag`, `cognito.userPoolId`, `cognito.clientId`, `cognito.region`. Image tags are commit SHAs written by CI (030).
2. `gitops/templates/validate.yaml` MUST `fail` when `fqdn` is empty (constitution §4). No template may contain a literal hostname.
3. `gitops/templates/hello.yaml` renders one Argo `Application` in namespace `argocd`, `project: vk-ahorro`, source `repoURL: {{ .Values.charts.registry }}`, `chart: hello`, `targetRevision: {{ chart version }}`, destination namespace `ahorro`, `syncPolicy.automated {prune: true, selfHeal: true}`, `syncOptions [CreateNamespace=true, ServerSideApply=true]`, the `resources-finalizer.argocd.argoproj.io` finalizer, and helm `parameters`: `image.tag`, `host` (`api-ahorro.{{ .Values.fqdn }}` / `ahorro.{{ .Values.fqdn }}`), `cognito.issuer`, `cognito.clientId`, `corsAllowedOrigins` (`https://ahorro.{{ .Values.fqdn }}`). Every parameter MUST be a scalar: Argo's `helm.parameters` carries scalar overrides only.
4. Platform side, exactly these files in `vk-lab-platform`:
   - `gitops/templates/apps/vk-ahorro/appproject.yaml`: `AppProject vk-ahorro`, `sourceRepos: [https://github.com/savak1990/vk-ahorro, ghcr.io/savak1990/vk-ahorro/charts]`, `destinations: [{server: https://kubernetes.default.svc, namespace: ahorro}, {..., namespace: argocd}]`, `clusterResourceWhitelist: [{group: "", kind: Namespace}]`, sync-wave `4`.
   - `gitops/templates/apps/vk-ahorro/application.yaml`: `Application vk-ahorro`, `project: vk-ahorro`, source `repoURL: https://github.com/savak1990/vk-ahorro`, `path: gitops`, `targetRevision: main`, helm parameter `fqdn: {{ .Values.envoyGateway.fqdn }}`, destination namespace `argocd`, `automated {prune: true, selfHeal: false}`, `syncOptions [ServerSideApply=true]`, finalizer, sync-wave `5`, gated `{{- if ne .Values.target "local" }}`.
   - `tests/golden/gitops-aws/platform/` regenerated; `docs/adr/0038-first-business-app-pointer.md`.
5. The pointer's `selfHeal: false` is deliberate: the operator syncs the app when they choose. `prune: true` stays so a removed service disappears.
6. Make targets in this repository: `gitops-lint`, `gitops-template` (with `--set fqdn=example.invalid`), `gitops-check` (renders and runs kubeconform with the Argo CD schema).
7. `.github/workflows/release.yml` MUST commit the new image tag into `gitops/values.yaml` with a `[skip ci]` message, and its permissions rise to `contents: write`. 030 created the workflow with `contents: read`; the commit is what needs the raise. `paths-ignore` already excludes `gitops/**`, so the commit MUST NOT start a second run.

## Implementation hints

- Argo CD 3.x (platform chart 10.4.0) reads OCI Helm sources with `repoURL: ghcr.io/...` and `chart:`; no repository credential is needed for a public package. Verify once with `argocd app get`; the fallback is a Git source (`repoURL` this repo, `path: deploy/helm/hello`).
- The `fqdn` value is sensitive on the platform (never echoed). Pass it only through the helm parameter; do not print it in `NOTES.txt` or logs.
- Regenerate golden files with the platform's `scripts/gitops-render-check.sh update` (check the script's mode argument first).

## Testing / acceptance criteria

- `make gitops-template` renders exactly one `Application` object; `helm template gitops` without `fqdn` fails.
- In `vk-lab-platform`: `make gitops-check`, `helm lint gitops`, and kubeconform pass with the two new files; the pull request's `pr-gate` check is green.
- After the platform's `make full-up` (or `make up` on an existing bootstrap): `argocd app get vk-ahorro` is `Synced`/`Healthy`; `argocd app list` shows `hello` in project `vk-ahorro`; `kubectl -n ahorro get pods` shows one Running pod.
- `curl https://api-ahorro.<fqdn>/healthz` → 200. The `web` hostname is verified by 105.
- A merged pull request produces exactly one `release` run and one `[skip ci]` commit; that commit does not start a second run.
- `make down` then `make up` in the platform recreates the app with no manual step.
