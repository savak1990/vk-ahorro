# vk-ahorro — Architecture

Target architecture for the Ahorro application. Sections are numbered so
specs and ADRs can cite them. `docs/adr/` records the decisions; `specs/`
holds the requirements.

# 1. Purpose

Ahorro is a personal spending application: a Flutter client for Android,
iOS, and web, and a set of Go services behind one API hostname. This
repository is the application monorepo. It runs on
[`vk-lab-platform`](https://github.com/savak1990/vk-lab-platform), a
disposable EKS platform that provides the cluster, the public edge (NLB +
Envoy Gateway), DNS, TLS, and Argo CD.

The first milestone (`specs/core/`) delivers one service (`ahorro-api`), the
Flutter shell, Cognito sign-in, and the full delivery chain from a commit
to a running app on all three client platforms.

# 2. Repository structure

Planned layout. Items marked `(planned)` do not exist yet; the rest is
as-built.

```text
vk-ahorro/
  go.mod                                   module github.com/savak1990/vk-ahorro
  cmd/ahorro-api/main.go                        one entry point per service
  internal/api/                          service code: server, handlers, tests
  internal/platform/auth/                  Cognito JWT verification, shared by every service
  internal/platform/httpx/                 JSON helpers, request id, CORS, logging
  deploy/docker/                 ahorro-api.Dockerfile; web.Dockerfile planned (multi-arch)
  deploy/helm/ahorro-api/, web/       (planned) one chart per service, pushed to GHCR as OCI
  gitops/                        (planned) app-of-apps chart Argo renders (one Application per service)
  flutter-ui/                    Flutter client (as-built, to be trimmed by spec 070)
  scripts/                                 specs-check.sh, domain-guard.sh, cognito.sh; later e2e-smoke.sh
  specs/core/                    milestone specs
  docs/architecture.md           this document
  docs/adr/                      decisions
  .github/workflows/             ci.yml (pull requests), release.yml (main); actions pinned by commit SHA
  Makefile                                 the only supported entry points
```

Rule: platform code never lives here. A platform change is a pull request
to `vk-lab-platform` (spec 000 §1).

# 3. Runtime topology

```text
  Browser / Android / iOS
          │  https
          ▼
  Route 53 (lab.<root-domain>, external-dns publishes both records)
          │
          ▼
  NLB (TLS terminated with the platform's ACM certificate)
          │  plaintext, PROXY protocol
          ▼
  Envoy Gateway  ── Gateway platform-gateway (namespace envoy, listener https)
          │
          ├── HTTPRoute ahorro.<fqdn>      → Service web   → nginx serving the Flutter web build
          │                                                   + /config.json from a ConfigMap
          └── HTTPRoute api-ahorro.<fqdn>  → Service hello → Go, /healthz and /api/v1/*
                                                              (namespace ahorro)
```

`<fqdn>` is `lab.<root-domain>` on the AWS target. Its value is a platform
secret: it reaches this repository's charts only as a Helm parameter and
never appears in Git (§10).

Two hostnames, not one with a path split, so the web build can move to a
static host later without touching the API. The cost is CORS: `ahorro-api`
allows the origin `https://ahorro.<fqdn>`.

# 4. Authentication

Identity provider: one Cognito user pool per platform project, in the same
AWS account and region (`eu-west-1`), with a single public app client (no
client secret). The client allows SRP for real sign-in and the admin password
flow for scripted tokens; the non-admin password flow is off (ADR 0005). The
alternatives compared were Firebase Auth and Supabase Auth; Cognito won on
reuse (the Flutter code already uses Amplify) and one cloud account.

The pool is created by `vk-lab-platform`, not here — this repository holds no
Terraform (ADR 0004).

```text
  Flutter (amplify_authenticator)          Cognito                 hello (Go)
      │  sign in, SRP                          │                        │
      │ ─────────────────────────────────────► │                        │
      │  id token + access token + refresh     │                        │
      │ ◄───────────────────────────────────── │                        │
      │  GET /api/v1/hello                                              │
      │  Authorization: Bearer <id token>, X-Request-Id                 │
      │ ───────────────────────────────────────────────────────────────►│
      │                                        │   JWKS (cached)        │
      │                                        │ ◄──────────────────────│
      │  200 {"message":"Hello, <email>"}                               │
      │ ◄───────────────────────────────────────────────────────────────│
```

The Go middleware verifies signature (JWKS at
`https://cognito-idp.eu-west-1.amazonaws.com/<pool id>/.well-known/jwks.json`),
`iss`, `exp`, and the client id (`aud` on id tokens, `client_id` on access
tokens). It accepts both token types. No service calls Cognito on the
request path.

`AUTH_DISABLED=true` exists for local development only and logs a warning
at startup.

# 5. Configuration

Three layers. Values flow downward; nothing flows back into Git except
image tags and chart versions.

| Layer | Holds | Written by | Read by |
|---|---|---|---|
| SSM `/<project>/persistent/ahorro-cognito/*` | pool id, client id, issuer, the test user and its password | the platform's `make persistent-up` | `make cognito-config`, `make token`, `make ui-config`, the platform's `argo-up.sh` |
| `gitops/values.yaml` (Git) | image tags (SHA), chart versions, namespace; Cognito keys present but empty | CI (tags), operator (the rest) | Argo through the pointer Application |
| `flutter-ui/config/<env>.json` (untracked) | API base URL, Cognito ids | `make ui-config ENV=lab FQDN=...` | mobile builds via `--dart-define-from-file` |
| Runtime | env vars (hello), `/config.json` ConfigMap (web) | Helm charts from Argo parameters | the processes |

Public and committable: Cognito user pool id, client id, region. Never in
Git: the root domain, `<fqdn>`, any password or token. `<fqdn>` arrives as
the helm parameter `fqdn` on the pointer Application and is templated into
hostnames, the CORS origin, and `config.json`'s `apiBaseUrl`.

Web reads `config.json` at startup, so one `web` image serves every
environment. Mobile builds bake the same keys in with `--dart-define`.

# 6. Build and delivery

```text
  commit on main
       │
       ▼
  release.yml (GitHub Actions, no AWS credentials)
       ├── docker buildx  linux/amd64 + linux/arm64
       │      ghcr.io/savak1990/vk-ahorro/ahorro-api:<sha>
       │      ghcr.io/savak1990/vk-ahorro/web:<sha>
       ├── helm package + push
       │      oci://ghcr.io/savak1990/vk-ahorro/charts/{hello,web}:<chart version>
       └── git commit gitops/values.yaml  images.*.tag = <sha>   [skip ci]
                                  │
                                  ▼
                       Argo CD reconciles on its next sync (or on operator sync)
```

Images are tagged by full commit SHA, never `latest`, so an Argo diff is
always meaningful (platform ADR 0015). GHCR replaces the ECR that ADR 0015
proposed: the images are public, so the cluster needs no pull secret and CI
needs no AWS role (ADR 0001). The CD handoff is a Git commit, which works
while the cluster is destroyed; Argo catches up on `make up`.

Local builds use the same Make targets (`image-build`, `image-push`,
`helm-push`) with `IMAGE_TAG` defaulting to `git rev-parse HEAD`.

# 7. GitOps topology

Two-level app-of-apps, split by ownership (platform ADR 0015):

```text
  vk-lab-platform/gitops (chart "platform", rendered by Application "root")
    └── templates/apps/vk-ahorro/
          ├── appproject.yaml     AppProject vk-ahorro  (namespaces ahorro + argocd, sources: this repo + GHCR charts)
          └── application.yaml    Application vk-ahorro (pointer)
                 source: https://github.com/savak1990/vk-ahorro  path: gitops  targetRevision: main
                 helm parameter: fqdn = <platform's envoyGateway.fqdn>
                 automated: prune=true, selfHeal=false
                        │
                        ▼
  vk-ahorro/gitops (chart "ahorro")
    ├── templates/validate.yaml   fails when fqdn is empty
    ├── templates/ahorro-api.yaml      Application ahorro-api → oci chart hello, namespace ahorro
    └── templates/web.yaml        Application web   → oci chart web,   namespace ahorro
```

`selfHeal: false` on the pointer is deliberate: the platform's `make
full-up` creates the app, and after that the operator decides when a new
`gitops/values.yaml` goes live. The two child Applications keep
`selfHeal: true` so drift inside the namespace is corrected.

Adding a service is a change in this repository only: a chart, a
`templates/<svc>.yaml`, and values. The platform side never changes for
that.

# 8. Infrastructure lifecycle

| Class | Resources | Created by | Destroyed by |
|---|---|---|---|
| Persistent | Cognito user pool + client + test user, its SSM parameters, GHCR packages | the platform's `make persistent-up`; CI for packages | the platform's `CONFIRM_DESTROY=<project> make persistent-down` |
| Disposable | everything in namespace `ahorro`, the two child Applications | platform `make up` through the pointer | platform `make down` |

The platform's `make full-up` (bootstrap → persistent → cluster → Argo)
ends with `root` synced, which creates the pointer, which creates the app.
No step in this repository has to run for the app to come back after a
platform `make down` / `make up`, provided the images and charts referenced
in `gitops/values.yaml` exist on GHCR.

# 9. Local development

- Go: `make go-run` starts `ahorro-api` on `:8080` with `AUTH_DISABLED=true` and CORS for `http://localhost:3000`.
- Web: `make ui-run-web` runs Flutter in Chrome on `:3000` against the committed `flutter-ui/web/config.json` (localhost API, empty Cognito → the Authenticator is skipped only when auth is disabled server-side; otherwise the app shows a config error).
- Mobile: `make ui-config ENV=lab FQDN=<fqdn>` writes `flutter-ui/config/lab.json` from the platform's SSM parameters; `make ui-run-android ENV=lab` and `make ui-run-ios ENV=lab` pass it as `--dart-define-from-file`.
- Images: `make image-build SVC=web && make web-serve-local` serves the production web image on `:8081`.

# 10. Invariants

1. No secret, root domain, or `<fqdn>` value in Git. CI greps for the domain.
2. Images tagged by full commit SHA; `latest` never pushed.
3. One AWS region, `eu-west-1`, as a constant.
4. Terraform never manages a Kubernetes object; Argo never manages an AWS resource. This repository holds no Terraform at all (ADR 0004).
5. Platform changes for this app are limited to `vk-lab-platform/gitops/templates/apps/vk-ahorro/`, `terraform/live/account/ahorro-ci-role/`, `terraform/live/persistent/ahorro-cognito/`, their golden files, and ADRs. This line listed only the first of those until ADR 0004; `ahorro-ci-role` had been in the platform since ADR 0003 and was never recorded here.
6. `make` targets are the only supported entry points; every target has a doc comment.
7. Every service verifies tokens itself with the shared `internal/platform/auth` package; no gateway-level auth exists on the platform today.

# 11. Later

Not in the first milestone, listed so the layout leaves room:

- More services under `cmd/` and `internal/`, each with its own chart and `gitops/templates/<svc>.yaml`.
- Postgres access through the platform's CNPG cluster: an `ExternalSecret` against the platform's `aws-parameter-store` ClusterSecretStore and a `PreSync` hook that waits on the Secret (platform ADR 0015 consequences).
- A `prod` environment: a second platform project, which already means a second Cognito pool, plus a second `gitops` values file.
- Argo CD Image Updater is deliberately not used (platform ADR 0015).
