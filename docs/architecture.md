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
  deploy/docker/                 ahorro-api.Dockerfile, ahorro-web.Dockerfile (multi-arch)
  deploy/helm/ahorro-api/, ahorro-web/  one chart per service, pushed to GHCR as OCI
  gitops/                        app-of-apps chart Argo renders (one Application per service)
  flutter-ui/                    Flutter client, trimmed to the shell by spec 070
  scripts/                                 specs-check.sh, domain-guard.sh, cognito.sh; later e2e-smoke.sh
  specs/core/                    milestone specs
  docs/architecture.md           this document
  docs/delivery.md               how a commit becomes a running application
  docs/adr/                      decisions
  .github/workflows/             ci.yml (pull requests), deploy.yml (main), preview.yml (the label); actions pinned by commit SHA
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

`AUTH_DISABLED=true` exists for local development and for the `local`
platform target, which creates no pool. It logs a warning at startup and
makes every request anonymous. `AUTH_ANONYMOUS_EMAIL` and
`AUTH_ANONYMOUS_SUB` name the user those requests are answered as, so the
client and the API agree; unset, the service says `anonymous`.

The client skips the Authenticator only when its configuration asks for it,
through `authDisabled` in `config.json`. It is never inferred from the
Cognito identifiers being empty: that state means a project whose values were
not threaded, and it must stay an error (ADR 0007).

# 5. Configuration

Three layers. Values flow downward; nothing flows back into Git except
image tags and chart versions.

| Layer | Holds | Written by | Read by |
|---|---|---|---|
| SSM `/<project>/persistent/ahorro-cognito/*` | pool id, client id, issuer, region, the test user and its password | the platform's `make persistent-up` | `make cognito-config`, `make token`, `make ui-config`, the platform's `argo-up.sh` |
| `gitops/values.yaml` (Git) | image tags (SHA), chart versions, namespace; Cognito keys present but empty | CI (tags), operator (the rest) | Argo through the pointer Application |
| `flutter-ui/web/config.json` (untracked) | API base URL, Cognito ids and region | `make ui-config`, from SSM for `$PROJECT_NAME` | the Chrome dev server at `make ui-run-web` |
| `flutter-ui/config/<env>.json` (untracked) | API base URL, Cognito ids | `make ui-config ENV=lab FQDN=...` | mobile builds via `--dart-define-from-file` |
| Runtime | env vars (hello), `/config.json` ConfigMap (web) | Helm charts from Argo parameters | the processes |

Public and committable: Cognito user pool id, client id, region. Never in
Git: the root domain, `<fqdn>`, any password or token. `<fqdn>` arrives as
the helm parameter `fqdn` on the pointer Application and is templated into
hostnames, the CORS origin, and `config.json`'s `apiBaseUrl`.

Web reads `config.json` at startup, so one `web` image serves every
environment. Mobile builds bake the same keys in with `--dart-define`.

# 6. Build and delivery

**The rules live in [`docs/delivery.md`](delivery.md).** This section is the
shape only.

```text
  pull request ──▶ -pr-<n>    ──▶ ahorro-pr    (on the `preview` label)
  merge        ──▶ -main.<sha>──▶ ahorro-dev   (every merge)
  release      ──▶ 0.3.0      ──▶ ahorro       (Argo, when the platform pin moves)
```

Each component carries its own semver, bumped by hand in the pull request
that changes its chart. The image tag and the chart version are the same
string, so one version identifies everything a deployment runs. Every image
also carries its full commit SHA, and `latest` is never built.

GHCR replaces the ECR that platform ADR 0015 proposed: the packages are
public, so the cluster needs no pull secret and CI needs no AWS role for them
(ADR 0001).

GitOps pins an exact version, never a range. Argo resolves chart versions with
`Masterminds/semver`, where a constraint carrying no prerelease never matches
a version that has one, so a range would stop seeing new builds while still
reporting `Synced`.

Local builds use the same Make targets (`image-build`, `image-push`,
`helm-push`) with `IMAGE_TAG` defaulting to `git rev-parse HEAD`.

See ADR 0009 for the environments and the versions, and ADR 0010 for how the
pipeline reaches the cluster.

# 7. GitOps topology

Two-level app-of-apps, split by ownership (platform ADR 0015):

```text
  vk-lab-platform/gitops (chart "platform", rendered by Application "root")
    └── templates/apps/vk-ahorro/
          ├── appproject.yaml     AppProject vk-ahorro  (namespaces ahorro + argocd, sources: this repo + GHCR charts)
          └── application.yaml    Application vk-ahorro (pointer)
                 source: https://github.com/savak1990/vk-ahorro  path: gitops
                 targetRevision: <platform's ahorro.targetRevision>
                 helm parameters: fqdn = <platform's envoyGateway.fqdn>, target, cognito.*
                 automated: prune=true, selfHeal=true
                        │
                        ▼
  vk-ahorro/gitops (chart "ahorro")
    ├── templates/validate.yaml   fails when fqdn is empty, except on local
    ├── templates/services.yaml   one Application per backend service, from a
    │                             range over .Values.services; today
    │                             ahorro-api → chart ahorro-api, wave 1
    └── templates/web.yaml        Application ahorro-web → chart ahorro-web, wave 2
```

Backend Applications render from a loop because every Go service takes the
same parameter shape, so adding one is four lines of values and no new
template. The client keeps its own template: its parameters are the four keys
the browser reads, not the backend's shape.

`selfHeal: true` on the pointer and on both child Applications. It was `false`
while the operator installed those charts by hand; that work now happens in
`ahorro-dev` and `ahorro-pr`, which Argo does not watch, so drift in `ahorro`
is always a mistake and is reverted within about three minutes (ADR 0009).

Argo owns the `ahorro` namespace and nothing else. The pipeline owns
`ahorro-dev` and `ahorro-pr` and is granted nothing in `ahorro`
(`docs/delivery.md` §1).

The two child waves order the backend before the client. They are scoped to
the pointer's own sync and never interact with the platform's waves, which
order the pointer itself.

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
- A kind cluster: `PROVIDER=local make full-up` in the platform runs both services; `make forward-up` here puts the client on `:8090` and the API on `:8091`. That target has no gateway route, no public hostname and no user pool, so sign-in is skipped and both halves report the stand-in user `e2e@vk-ahorro.invalid` (ADR 0007). Argo still fetches this repository from GitHub `main` there, so a local bring-up runs merged code.

# 10. Invariants

1. No secret, root domain, or `<fqdn>` value in Git. CI greps for the domain.
2. Images tagged by full commit SHA and by their chart's semver; `latest` never pushed. GitOps pins an exact version, never a range (ADR 0009).
3. One AWS region, `eu-west-1`, as a constant.
4. Terraform never manages a Kubernetes object; Argo never manages an AWS resource. This repository holds no Terraform at all (ADR 0004).
5. Platform changes for this app are limited to `vk-lab-platform/gitops/templates/apps/vk-ahorro/`, `terraform/live/account/ahorro-ci-role/`, `terraform/live/persistent/ahorro-cognito/`, the RBAC that grants the pipeline its two namespaces, the SSM publication of that ServiceAccount's token in `scripts/argo-up.sh`, their golden files, and ADRs. This line listed only the first of those until ADR 0004; `ahorro-ci-role` had been in the platform since ADR 0003 and was never recorded here. The last two arrived with ADR 0010.
6. `make` targets are the only supported entry points; every target has a doc comment.
7. Every service verifies tokens itself with the shared `internal/platform/auth` package; no gateway-level auth exists on the platform today.
8. Argo owns the `ahorro` namespace. The pipeline owns `ahorro-dev` and `ahorro-pr` and is granted nothing in `ahorro` (ADR 0009, ADR 0010).

# 11. Later

Not in the first milestone, listed so the layout leaves room:

- More services under `cmd/` and `internal/`, each with its own chart and `gitops/templates/<svc>.yaml`.
- Postgres access through the platform's CNPG cluster: an `ExternalSecret` against the platform's `aws-parameter-store` ClusterSecretStore and a `PreSync` hook that waits on the Secret (platform ADR 0015 consequences).
- A `prod` environment: a second platform project, which already means a second Cognito pool, plus a second `gitops` values file.
- Argo CD Image Updater is deliberately not used (platform ADR 0015).
