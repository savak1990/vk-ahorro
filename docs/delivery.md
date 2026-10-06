# vk-ahorro — Delivery

How a commit becomes a running application. Sections are numbered so specs
and ADRs can cite them. This document is the single place the delivery
decisions are pinned; `docs/architecture.md` §6 and §7 describe the shape and
link here for the rules.

The decisions below are recorded in ADR 0009 (the environments and the
versions) and ADR 0010 (the pipeline reaching the cluster).

# 1. Three environments

| Namespace | Owner | Runs | Hostnames | Changes when |
|---|---|---|---|---|
| `ahorro` | Argo CD | a released version, pinned | `ahorro.<fqdn>`, `api-ahorro.<fqdn>` | the platform's pin is bumped by hand |
| `ahorro-dev` | the pipeline | the newest `main` build | `ahorro-dev.<fqdn>`, `api-ahorro-dev.<fqdn>` | every merge |
| `ahorro-pr` | the pipeline | one release per labeled pull request | `ahorro-pr-<n>.<fqdn>` | a label is added or removed |

Each stage makes a stronger claim about the code than the one before it. A
preview proves the change builds and runs. `ahorro-dev` proves it runs beside
everything else that merged. `ahorro` is what survives a cluster rebuild.

Argo owns `ahorro` and nothing else. The pipeline owns the other two and never
reaches into `ahorro`. The separation is not a preference: Helm refuses to
adopt an object another tool created, and Argo applies rendered manifests
without creating a Helm release, so a `helm upgrade` over Argo's objects fails
with `invalid ownership metadata`. Distinct namespaces mean the two owners
never meet.

`make down` followed by `make up` restores `ahorro` to its pinned version and
leaves the other two empty until the pipeline runs again. That is the point of
`ahorro`: a known version to return to.

## 1.1 Hostnames are one label deep

The platform issues one wildcard certificate, `*.<fqdn>`, and external-dns
filters on the same single label. `ahorro-pr-42.<fqdn>` is covered.
`pr-42.ahorro.<fqdn>` is covered by neither the certificate nor DNS.

No hostname and no root domain is ever committed. The pipeline reads the
domain at run time from the SSM parameter `/account/root_domain` and builds
every hostname from it.

# 2. Versions

Each component carries its own semver in its own `Chart.yaml`, bumped by hand
in the pull request that changes the chart. `scripts/chart-version-check.sh`
fails a pull request that changes a chart without bumping it.

| Event | Version | Published |
|---|---|---|
| pull request | `0.3.0-pr-42` | image and chart |
| merge to `main` | `0.3.0-main.a1b2c3d` | image and chart |
| release | `0.3.0` | image and chart |

The image tag and the chart version are the same string. A chart installed at
`0.3.0-pr-42` therefore pulls the image of the same name with no second flag,
and one version identifies everything a deployment runs.

Every image also carries its full commit SHA as a tag. The SHA is the audit
trail; the semver is what a human promotes.

## 2.1 A prerelease is not matched by a range

Argo resolves a chart version with `Masterminds/semver`, and a constraint
without a prerelease never matches a version with one. The constraint `*`
matches `0.3.0` and does not match `0.3.0-pr-42`.

This is why GitOps pins an exact version and never a range. A range would
silently stop seeing new builds while Argo continued to report `Synced`.

## 2.2 No build metadata

A version may not carry `+build` metadata. Helm rewrites `+` to `_` because
`+` is illegal in an OCI tag, and the rewritten string is no longer valid
semver. The prerelease suffix carries the commit instead.

# 3. The pipeline

Only a component whose inputs changed is built, versioned and published. A
change under `internal/` never rebuilds the Flutter image.

## 3.1 Pull request

`ci.yml` runs the checks. Each changed component publishes an image and a
chart as `-pr-<n>`.

A deployment happens only when the pull request carries the `preview` label.
That lives in its own workflow file, `preview.yml`, so a label event never
restarts `ci.yml` — whose required status checks are maintained by hand, and
one of which failing to report blocks every merge.

| Event | Condition | Action |
|---|---|---|
| `labeled` | the label is `preview` | install into `ahorro-pr` |
| `synchronize` | the pull request carries `preview` | upgrade that release |
| `unlabeled` | the label is `preview` | uninstall, and delete the published versions |
| `closed` | always | the same |

The label is state, not an event: it answers "is this pull request deployed
right now" by looking at the pull request, so a release nobody cleaned up is
visible. `make repo-settings` creates the label.

Tearing down on `closed` is safe here. ADR 0007 rejected a `pull_request:
closed` trigger because it would race a second merge for a shared branch;
removing one pull request's own release races nothing.

## 3.2 Merge to `main`

`deploy.yml` publishes `-main.<sha>` for each changed component and upgrades
the releases in `ahorro-dev`. Nothing reaches `ahorro`.

## 3.3 Release

A normal pull request bumps the chart versions and pins them in
`gitops/values.yaml`. After it merges, the release action publishes the clean
version. A pull request in `vk-lab-platform` then bumps the pinned versions,
and Argo moves `ahorro` on its next sync.

The promotion is deliberate at both ends. Nothing automatic moves `ahorro`.

# 4. How the pipeline reaches the cluster

```text
  GitHub OIDC
       │
       ▼
  ahorro-ci-role            (vk-lab-platform owns it; see ADR 0003)
       │  ssm:GetParameter
       ├── /account/root_domain
       ├── /<project>/persistent/ahorro-cognito/*
       └── /<project>/cluster/ahorro-deploy/{token,ca,endpoint}
       │
       ▼
  kubeconfig, built in the job and never persisted
       │
       ▼
  helm, limited by RBAC to ahorro-dev and ahorro-pr
```

The cluster is disposable, so every `make up` creates a new certificate
authority and new tokens. A kubeconfig stored in a GitHub secret would break
on the first rebuild and stay broken until a deployment failed. The platform
therefore mints the ServiceAccount token during bring-up and republishes it to
SSM each time, and the pipeline reads it fresh on every run.

The ServiceAccount is granted nothing in `ahorro`. A pipeline that cannot
reach the released environment cannot damage it.

## 4.1 Configuration the pipeline supplies itself

`gitops/templates/services.yaml` and `web.yaml` build hostnames from
`hostPrefix` and CORS from the web prefix and the domain. Argo renders them
for `ahorro` only. A pipeline install bypasses those templates, so it passes
`host`, `config.apiBaseUrl` and `corsAllowedOrigins` itself, built from the
domain it read from SSM.

All three environments use the same Cognito user pool and the same app client.
There is one of each per platform project by deliberate design: the API
verifier pins a single client id, so a second client would mint tokens the
service refuses. `ahorro-dev` therefore signs in for real, which is what makes
it useful before a release.

# 5. Artifacts

Images and charts are published to GHCR under `ghcr.io/savak1990/vk-ahorro/`.
The packages are public, so Argo and a laptop both pull with no credential.
Public packages have no storage or bandwidth charge, so retention is about
keeping the package list readable, not about cost.

| Version | Removed by |
|---|---|
| `-pr-<n>` | the teardown step, beside the `helm uninstall` |
| untagged manifests | a scheduled prune; a multi-arch build leaves two per image and nothing else removes them |
| `-main.<sha>` | nothing. One per merge is a useful record |

# 6. Invariants

1. Argo owns `ahorro`. The pipeline owns `ahorro-dev` and `ahorro-pr`. Neither
   crosses.
2. GitOps pins an exact chart version, never a range and never a moving tag.
3. One component, one semver, bumped by hand in the pull request that earns it.
4. The image tag and the chart version are the same string.
5. No hostname, no root domain and no secret is ever committed.
6. Nothing automatic changes what `ahorro` runs.
