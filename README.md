# vk-ahorro

Ahorro: a personal spending application. A Flutter client for Android,
iOS, and web, plus Go services, in one repository, deployed on
[vk-lab-platform](https://github.com/savak1990/vk-lab-platform).

See [`docs/architecture.md`](docs/architecture.md) for the target
architecture, [`docs/adr/`](docs/adr/) for decisions, and
[`specs/`](specs/) for the requirements.

## Status

Milestone 1 is `specs/core/`, implemented in numeric order. The Cognito pool
lives in the platform and the Flutter shell runs locally. Both services now
have an image and a chart, and the Argo CD wiring is in review; the first
release run on `main` publishes the renamed artifacts to GHCR.

| Spec | Delivers | State |
|---|---|---|
| 000 | Constitution | done |
| 010 | Repository bootstrap, GitHub publication | done |
| 020 | Go `ahorro-api` service with Cognito JWT verification | done |
| 030 | The `ahorro-api` image on GHCR, CI | done |
| 040 | Helm chart for `ahorro-api` on GHCR | done |
| 050 | Cognito: the platform's pool, one client, the test user | done |
| 055 | Cognito identifiers from SSM, `make token` | done |
| 060 | GitOps chart and the platform pointer | in progress |
| 070 | Flutter trimmed to the shell | done |
| 080 | Flutter runtime config and the "+" → hello call | config done, call planned |
| 090 | Local toolchain | planned |
| 100 | Android, iOS, web | mostly done |
| 105 | Web delivery: image, chart, Argo Application | in progress |
| 107 | The local target runs both apps in kind | planned |
| 110 | End-to-end verification | superseded by `ci/040` and `deploy/050` |

The pipeline has its own groups: `specs/ci/` is what a pull request must
prove, `specs/deploy/` is what a merge or the deploy button does.

## Relationship to vk-lab-platform

The platform owns the cluster, the gateway, DNS, TLS, and Argo CD. This
repository plugs in through one pointer `Application` in the platform
(`gitops/templates/apps/vk-ahorro/`) that renders this repository's
`gitops/` chart. Platform `make full-up` starts the app.

A merge to `main` publishes four artifacts to GHCR, all public:

```text
ghcr.io/savak1990/vk-ahorro/ahorro-api:<sha>  and :main
ghcr.io/savak1990/vk-ahorro/ahorro-web:<sha>  and :main
oci://ghcr.io/savak1990/vk-ahorro/charts/ahorro-api:<chart version>
oci://ghcr.io/savak1990/vk-ahorro/charts/ahorro-web:<chart version>
```

`gitops/values.yaml` names the moving `main` tag and the `"*"` chart version,
so a fresh bring-up always runs the newest build and nothing has to be edited
per release. A cluster that is already running needs
`kubectl -n ahorro rollout restart deploy` to pick up a new image, because a
moving tag leaves the manifest unchanged. See
[ADR 0006](docs/adr/0006-web-delivery-and-the-gitops-chart.md).

## Layout

```text
cmd/ahorro-api    the Go API entry point
internal/         service and shared Go code
deploy/docker     Dockerfiles                   ahorro-api, ahorro-web
deploy/helm       one chart per service         ahorro-api, ahorro-web
gitops/           app-of-apps chart for Argo
flutter-ui/       Flutter client
specs/core/       milestone specs
docs/             architecture, ADRs
```

## Make targets

`make help` prints every target that exists. A planned target is one a later
spec adds.

| Group | Targets | State |
|---|---|---|
| Go | `go-build` `go-test` `go-lint` `go-run` | exists |
| Flutter run | `ui-run-web` `ui-run-android` `ui-run-ios` | exists |
| Devices | `emulator-android` `emulator-ios` `emulator-stop` | exists |
| Images | `image-build SVC=` `image-push SVC=` `images-push` | exists |
| Helm | `helm-lint` `helm-template CHART=` `helm-package CHART=` `helm-push CHART=` | exists |
| Checks | `specs-check` `domain-check` `help` | exists |
| Cognito | `cognito-config` `token` | exists |
| GitOps | `gitops-lint` `gitops-template` `gitops-check` | exists |
| Flutter build | `ui-get` `ui-analyze` `ui-test` `ui-build-web` `ui-build-android` | exists |
| Flutter config | `ui-config ENV=` `web-serve-local` | planned |

### Run the Flutter client on a local device

1. Run the client in Chrome: `make ui-run-web`
2. Run the client on the Android emulator: `make ui-run-android`
3. Run the client on the iOS simulator: `make ui-run-ios`
4. Stop every emulator and simulator: `make emulator-stop`

`ui-run-android` and `ui-run-ios` start the device first. To start a device
without the Flutter client, use `make emulator-android` or `make emulator-ios`.

Two variables name the device. Set a different value on the command line:

| Variable | Default | Example |
|---|---|---|
| `AVD` | `pixel_phone` | `make ui-run-android AVD=pixel_tablet` |
| `IOS_DEVICE` | `iPhone 18 Pro` | `make ui-run-ios IOS_DEVICE="iPhone 17"` |

On web the client reads `flutter-ui/web/config.json` at startup, which is
committed with local defaults. In the cluster the `ahorro-web` chart renders
the same file from a ConfigMap, so one image serves every environment.

Hostnames are `ahorro.<fqdn>` and `api-ahorro.<fqdn>`; the domain itself
is never written in this repository.
