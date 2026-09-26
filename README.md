# vk-ahorro

Ahorro: a personal spending application. A Flutter client for Android,
iOS, and web, plus Go services, in one repository, deployed on
[vk-lab-platform](https://github.com/savak1990/vk-lab-platform).

See [`docs/architecture.md`](docs/architecture.md) for the target
architecture, [`docs/adr/`](docs/adr/) for decisions, and
[`specs/`](specs/) for the requirements.

## Status

Milestone 1 is `specs/core/`, implemented in numeric order. The `hello`
image and chart are on GHCR, the Cognito pool lives in the platform, and the
Flutter shell runs locally. The GitOps link (060) is in progress.

| Spec | Delivers | State |
|---|---|---|
| 000 | Constitution | done |
| 010 | Repository bootstrap, GitHub publication | done |
| 020 | Go `hello` service with Cognito JWT verification | done |
| 030 | The `hello` image on GHCR, CI | done |
| 040 | Helm chart for `hello` on GHCR | done |
| 050 | Cognito: the platform's pool, one client, the test user | done |
| 055 | Cognito identifiers from SSM, `make token` | done |
| 060 | GitOps chart and the platform pointer | planned |
| 070 | Flutter trimmed to the shell | planned |
| 080 | Flutter runtime config and the "+" → hello call | planned |
| 090 | Local toolchain | planned |
| 100 | Android, iOS, web | planned |
| 105 | Web delivery: image, chart, Argo Application | planned |
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
gitops/           app-of-apps chart for Argo    (planned)
flutter-ui/       Flutter client
specs/core/       milestone specs
docs/             architecture, ADRs
```

## Make targets

`make help` prints every target that exists. A planned target has no
repository folder yet.

| Group | Targets | State |
|---|---|---|
| Go | `go-build` `go-test` `go-lint` `go-run` | exists |
| Flutter | `ui-run-web` `ui-run-android` `ui-run-ios` | exists |
| Devices | `emulator-android` `emulator-ios` `emulator-stop` | exists |
| Images | `image-build SVC=` `image-push SVC=` `images-push` | exists |
| Helm | `helm-lint` `helm-template CHART=` `helm-package CHART=` `helm-push CHART=` | exists |
| Checks | `specs-check` `domain-check` `help` | exists |
| Cognito | `cognito-config` `token` | exists |
| GitOps | `gitops-lint` `gitops-template` `gitops-check` | planned |
| Flutter config | `ui-config ENV=` `ui-build-web` `web-serve-local` | planned |

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

`flutter-ui/` declares `.env` as an asset. The file is not in Git, and the
build fails without it. The `ui-config` target that generates it is planned.

Hostnames are `ahorro.<fqdn>` and `api-ahorro.<fqdn>`; the domain itself
is never written in this repository.
