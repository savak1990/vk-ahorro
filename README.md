# vk-ahorro

Ahorro: a personal spending application. A Flutter client for Android,
iOS, and web, plus Go services, in one repository, deployed on
[vk-lab-platform](https://github.com/savak1990/vk-lab-platform).

See [`docs/architecture.md`](docs/architecture.md) for the target
architecture, [`docs/adr/`](docs/adr/) for decisions, and
[`specs/`](specs/) for the requirements.

## Status

Milestone 1 is `specs/core/`, implemented in numeric order. The Go `hello`
service runs locally; nothing is containerized or deployed yet.

| Spec | Delivers | State |
|---|---|---|
| 000 | Constitution | done |
| 010 | Repository bootstrap, GitHub publication | done |
| 020 | Go `hello` service with Cognito JWT verification | done |
| 030 | Multi-arch images on GHCR, CI | in progress (`hello` only) |
| 040 | Helm charts on GHCR | planned |
| 050 | Terraform: state bucket, Cognito | planned |
| 060 | GitOps chart and the platform pointer | planned |
| 070 | Flutter trimmed to the shell | planned |
| 080 | Flutter runtime config and the "+" → hello call | planned |
| 090 | Local toolchain | planned |
| 100 | Android, iOS, web | planned |
| 110 | End-to-end verification | planned |

## Relationship to vk-lab-platform

The platform owns the cluster, the gateway, DNS, TLS, and Argo CD. This
repository plugs in through one pointer `Application` in the platform
(`gitops/templates/apps/vk-ahorro/`) that renders this repository's
`gitops/` chart. Platform `make full-up` starts the app.

## Layout

```text
cmd/hello         the hello service entry point
internal/         service and shared Go code
deploy/docker     Dockerfiles                    hello only
deploy/helm       one chart per service         (planned)
deploy/terraform  Terragrunt: state, Cognito    (planned)
gitops/           app-of-apps chart for Argo    (planned)
flutter-ui/       Flutter client
specs/core/       milestone specs
docs/             architecture, ADRs
```

## Make targets

Targets without a repository folder yet are planned; `make help` lists the
ones that exist.

| Group | Targets |
|---|---|
| Go | `go-build` `go-test` `go-lint` `go-run` |
| Images | `image-build SVC=` `image-push SVC=` `images-push` |
| Helm | `helm-lint` `helm-template` `helm-package` `helm-push` |
| Terraform | `tf-state-up` `tf-plan` `tf-apply` `tf-outputs` `tf-destroy` |
| GitOps | `gitops-lint` `gitops-template` `gitops-check` |
| Flutter | `ui-config ENV=` `ui-run-web` `ui-run-android ENV=` `ui-run-ios ENV=` `ui-build-web` `web-serve-local` |
| Tooling | `tools-install` `tools-check` `specs-check` `help` |

Hostnames are `ahorro.<fqdn>` and `api-ahorro.<fqdn>`; the domain itself
is never written in this repository.
