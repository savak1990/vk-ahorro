# vk-ahorro

Ahorro: a personal spending application. A Flutter client for Android,
iOS, and web, plus Go services, in one repository, deployed on
[vk-lab-platform](https://github.com/savak1990/vk-lab-platform).

See [`docs/architecture.md`](docs/architecture.md) for the target
architecture, [`docs/adr/`](docs/adr/) for decisions, and
[`specs/`](specs/) for the requirements.

## Status

Milestone 1 is `specs/core/`, implemented in numeric order. The whole web
delivery path works end to end: a commit reaches a public URL with TLS and a
real sign-in, unattended, and survives the cluster being destroyed and
rebuilt.

| Spec | Delivers | State |
|---|---|---|
| 000 | Constitution | done |
| 010 | Repository bootstrap, GitHub publication | done |
| 020 | Go `ahorro-api` service with Cognito JWT verification | done |
| 030 | The `ahorro-api` image on GHCR, CI | done |
| 040 | Helm chart for `ahorro-api` on GHCR | done |
| 050 | Cognito: the platform's pool, one client, the test user | done |
| 055 | Cognito identifiers from SSM, `make token` | done |
| 060 | GitOps chart and the platform pointer | done |
| 070 | Flutter trimmed to the shell | done |
| 080 | Flutter runtime config and the "+" → hello call | built; waiting on a sign-in on three devices |
| 090 | Local toolchain | planned |
| 100 | Android, iOS, web | mostly done |
| 120 | Imported app cleanup | done |
| 105 | Web delivery: image, chart, Argo Application | done |
| 107 | The local target runs both apps in kind | in progress |
| 110 | End-to-end verification | superseded by `ci/040` and `deploy/050` |

The pipeline has its own groups: `specs/ci/` is what a pull request must
prove, `specs/deploy/` is what a merge or the deploy button does. All three
delivery specs are done: `ci/010` for the change-aware checks, `deploy/060`
for the version scheme and `ahorro-dev`, and `deploy/070` for the previews.

## Relationship to vk-lab-platform

The platform owns the cluster, the gateway, DNS, TLS, and Argo CD. This
repository plugs in through one pointer `Application` in the platform
(`gitops/templates/apps/vk-ahorro/`) that renders this repository's
`gitops/` chart. Platform `make full-up` starts the app.

A merge to `main` publishes four artifacts to GHCR, all public:

```text
ghcr.io/savak1990/vk-ahorro/ahorro-api:<version>  and :<sha>
ghcr.io/savak1990/vk-ahorro/ahorro-web:<version>  and :<sha>
oci://ghcr.io/savak1990/vk-ahorro/charts/ahorro-api:<version>
oci://ghcr.io/savak1990/vk-ahorro/charts/ahorro-web:<version>
```

One version names the whole repository and comes from a git tag, so the image
tag and the chart version are the same string. A pull request publishes
`<version>-pr-<n>.<sha>`, a merge publishes `<version>-main.<sha>`, and a
release publishes the clean `<version>`. Both prerelease channels carry the
commit, so no tag is ever republished with different content - without it a
second push would leave the pods untouched.

`gitops/values.yaml` pins one exact released version, never a range and never
a moving tag, so a cluster recreate always returns to a known-good baseline.
Promoting a new release into `ahorro` is a deliberate edit here followed by a
one-line pull request in `vk-lab-platform`. See
[`docs/delivery.md`](docs/delivery.md).

## Three environments

| Namespace | Holds | Moves when | Survives `make down`/`up` |
|---|---|---|---|
| `ahorro` | the released version | **you promote it, by hand** | yes, Argo restores it |
| `ahorro-dev` | the last merge to `main` | every merge | no, comes back empty |
| `ahorro-pr` | a labeled pull request | you add or remove the label | no |

`ahorro` is Argo's. The other two belong to the pipeline, which installs them
with Helm. The credential the pipeline uses is **refused** in `ahorro` by
cluster RBAC, so a bug in CI cannot reach the released environment.

## What happens when you change something

Start here. Find the row that matches your change.

| You changed | CI builds | A merge publishes | A merge deploys |
|---|---|---|---|
| `internal/`, `cmd/`, `go.mod` | `ahorro-api` | both components | `ahorro-dev` |
| `flutter-ui/` | `ahorro-web`, runs the Flutter tests | both components | `ahorro-dev` |
| both of the above | both | both | `ahorro-dev` |
| `deploy/helm/` | nothing; renders and validates the charts | both components | `ahorro-dev` |
| `gitops/` | nothing; renders the app-of-apps | **nothing** | **Argo does it** |
| `scripts/`, `docs/`, `specs/`, `README.md` | nothing | **nothing** | nothing |
| `.github/workflows/` | nothing; runs `actionlint` | depends on the rest | depends |

Two rules explain every row.

**A build is change-aware; publication is not.** Only a component whose code
changed is rebuilt. Both are still published at the same version, because the
unchanged one is **copied** inside the registry - no build, no upload, about
two seconds. One version number therefore names everything an environment
runs.

**`gitops/` is the pin, not the code.** A change there does not publish
anything. It tells Argo which already-published version `ahorro` should run.

### Use case: you changed Go code

```sh
make go-build go-test go-lint
```

Open the pull request. Five checks run - `changes`, `go`, `image-api`, `repo`
and `ci-ok` - and five skip. The image is built but **not** pushed, so a
broken Dockerfile fails the pull request instead of a release.

Merge it. `ahorro-api` is rebuilt, `ahorro-web` is copied, both are published
at `0.2.2-main.<sha>`, and both are deployed to `ahorro-dev`. `ahorro` does
not move.

### Use case: you changed Go code and the chart

The same, plus the `helm` job: it lints every chart, renders them, and
validates the output against the Gateway API schemas.

You do **not** bump `Chart.yaml`. Its `version:` is a placeholder that the
pipeline overrides at package time, so there is no hand bump to forget.

```sh
make helm-lint
make helm-template CHART=ahorro-api
```

### Use case: you changed the Flutter client

```sh
make ui-get ui-analyze ui-test
```

CI runs the same three plus the `ahorro-web` image build. The Go jobs skip.

Check it on a device **before** you push - the client is the part a screenshot
cannot verify:

```sh
make ui-run-web          # Chrome on :3000, against this machine
make ui-run-android      # the emulator, against this machine
make ui-run-ios          # the simulator, against this machine
```

To check it against a **deployed** backend instead, name one with `ENV`:

```sh
make ui-run-android ENV=dev      # ahorro-dev, real sign-in
make ui-run-android ENV=pr-33    # the preview for pull request 33
make ui-run-ios ENV=dev          # the same on the simulator
```

`ENV` changes mobile only. See [Pick a backend with `ENV`](#pick-a-backend-with-env).

### Use case: you changed only scripts, docs or specs

Nothing builds and nothing deploys. `changes`, `repo` and `ci-ok` run, and the
pull request finishes in well under a minute.

Run the two checks the `repo` job runs:

```sh
make specs-check
make domain-check        # needs ROOT_DOMAIN; CI reads it from SSM
```

A merge starts no `deploy` run at all, because `deploy.yml` ignores `docs/`,
`specs/` and `gitops/`.

### Use case: you want to see it running before you merge

Add the label **`ci:preview-web`** to the pull request.

It publishes `<version>-pr-<n>.<sha>` for both components and installs them
into `ahorro-pr` on their own hostname, against the **real** user pool. The
run then comments on the pull request with the version and the hostname
labels.

```sh
make preview-url PR=42   # prints the clickable URL
```

The URL is printed locally and never in a comment or a log, because it embeds
the lab domain (constitution section 4).

| What you do | What happens |
|---|---|
| add the label | publish, then install |
| push another commit | the release is upgraded and the pods roll |
| remove the label | both releases are uninstalled |
| **merge or close** | **the same, automatically** |

You never have to remove the label to clean up. A merge does it.

Nothing is published without the label, so a pull request nobody previews
leaves nothing behind.

### Use case: you want to cut a release

Run the `deploy` workflow by hand, choosing `patch`, `minor` or `major`. You
never type a version: it is derived from the tag history.

The release publishes the clean `<version>` for every component - copying both
images rather than rebuilding them, because the code is already built - and
tags the repository. It does **not** touch any environment.

### Use case: you want the release running in `ahorro`

Two deliberate steps, and nothing automatic does either.

1. In this repository, pin the new version in `gitops/values.yaml`. It is
   **one** number per component, and both are the same.
2. In `vk-lab-platform`, bump `ahorro.targetRevision` - **one line**, because
   every component is at the same version.

Argo moves `ahorro` on its next sync.

### Use case: the lab is torn down

Everything still works, and nothing lies to you.

A merge publishes its artifacts and then **skips** the deploy in about ten
seconds, with a loud notice naming `make up`. The job stays **green**, because
a cluster that is deliberately off is not a failure.

```sh
cd ../vk-lab-platform && make up
```

Then re-run the failed job. `make up` republishes the deploy credential with a
new certificate authority and a new token, so the pipeline needs no change.

After a rebuild, `ahorro` returns to its pinned version on its own.
`ahorro-dev` comes back **empty** and fills on the next merge, because nothing
declares its state.

## Every job, and when it does not run

Three workflows. A job that skips reports **success**, which is what lets
`ci-ok` be the only check `main` requires.

### `ci.yml` - runs on every pull request

| Job | Does | Does not run when |
|---|---|---|
| `changes` | reads the diff, sets five outputs | never skips |
| `go` | `go-build`, `go-test`, `golangci-lint` | no Go change |
| `image-api` | builds `ahorro-api` for both architectures, pushes **nothing** | no Go change |
| `image-web` | builds `ahorro-web`, pushes **nothing** | no Flutter change |
| `ui` | `flutter analyze`, `flutter test` | no Flutter change |
| `helm` | lints and renders every chart, validates with kubeconform, packages at the pull request version | no `deploy/helm/` change |
| `gitops` | renders the app-of-apps for every target, rejects a range or a moving tag | no `gitops/` change |
| `workflows` | `actionlint` | no `.github/` change |
| `repo` | `specs-check` and `domain-check` | never skips |
| `ci-ok` | the **one** required check; fails if any job above failed or was cancelled | never skips |

The whole workflow has no `paths` filter and must never gain one: a skipped
*workflow* reports nothing at all, and a required check that never reports
blocks every merge for ever.

`repo` is the only job that assumes an AWS role, so it is the only one that
fails on a pull request from a fork. That is deliberate - a run that cannot
verify the domain must not report green.

### `deploy.yml` - runs on a merge to `main`, and by hand for a release

| Job | Does | Does not run when |
|---|---|---|
| `version` | derives the version from the tag history, reads the diff | never skips |
| `images` | **builds** a changed component, **copies** an unchanged one | never skips; it branches inside |
| `charts` | packages and pushes both charts at the one version | never skips |
| `deploy-dev` | installs both releases into `ahorro-dev` | a **release** dispatch - a release publishes, it does not deploy |
| `tag` | tags the repository `v<version>` | a **merge** - only a release tags |

**The whole workflow does not run** when a merge touches only `gitops/`,
`docs/` or `specs/`. Nothing is published, because nothing that ships
changed.

`deploy-dev` ends **green with a notice** when the cluster is unreachable, and
**red** when it is reachable and the deploy fails. The lab is off most of the
time, so a red run on every merge would train you to ignore the colour.

### `preview.yml` - runs on a pull request event

| Job | Does | Does not run when |
|---|---|---|
| `decide` | maps the event to `up`, `down` or `none` | never skips |
| `images` | publishes both components at `<version>-pr-<n>.<sha>` | the action is not `up` |
| `charts` | pushes both charts at that version | the action is not `up` |
| `install` | installs into `ahorro-pr`, then comments on the pull request | the action is not `up` |
| `teardown` | uninstalls both releases | the action is not `down` |

How `decide` reads an event:

| Event | Action |
|---|---|
| the `ci:preview-web` label is added | `up` |
| opened with that label already on it | `up` |
| a commit is pushed and the label is on | `up` |
| that label is removed | `down` |
| closed, merged or not | `down`, **always** |
| **any other label**, added or removed | `none` - nothing runs |

`teardown` depends only on `decide`, never on the publish jobs. Those skip on
a `down` event, and a job whose dependency skipped would skip too - which
would silently leave the preview running for ever.

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
| Flutter run | `ui-run-web` `ui-run-android ENV=` `ui-run-ios ENV=` | exists |
| Devices | `emulator-android` `emulator-ios` `emulator-stop` | exists |
| Images | `image-build SVC=` `image-push SVC=` `images-push` | exists |
| Helm | `helm-lint` `helm-template CHART=` `helm-package CHART=` `helm-push CHART=` | exists |
| Checks | `specs-check` `domain-check` `help` | exists |
| Versions | `version` `print-project` | exists |
| Deploy | `deploy-dev VERSION=` `kubeconfig` | exists |
| Previews | `preview-up PR= VERSION=` `preview-down PR=` `preview-url PR=` | exists |
| Repository | `repo-settings` | exists |
| Cognito | `cognito-config` `token` `ui-config ENV=` | exists |
| GitOps | `gitops-lint` `gitops-template TARGET=` `gitops-check` | exists |
| Local cluster | `forward-up` `forward-down` | exists |
| Flutter build | `ui-get` `ui-analyze` `ui-test` `ui-build-web` `ui-build-android ENV=` | exists |
| Flutter config | `web-serve-local` | planned |

### Run the Flutter client on a local device

1. Run the client in Chrome: `make ui-run-web`
2. Run the client on the Android emulator: `make ui-run-android`
3. Run the client on the iOS simulator: `make ui-run-ios`
4. Stop every emulator and simulator: `make emulator-stop`

`ui-run-android` and `ui-run-ios` start the device first. To start a device
without the Flutter client, use `make emulator-android` or `make emulator-ios`.

Three variables steer these targets. Set a different value on the command line:

| Variable | Default | Example |
|---|---|---|
| `AVD` | `pixel_phone` | `make ui-run-android AVD=pixel_tablet` |
| `IOS_DEVICE` | `iPhone 18 Pro` | `make ui-run-ios IOS_DEVICE="iPhone 17"` |
| `ENV` | `local` | `make ui-run-android ENV=dev` |

### Pick a backend with `ENV`

`ENV` names which API the client on the device talks to.

| `ENV` | The client talks to | Sign-in |
|---|---|---|
| `local` | `make go-run` on this machine | skipped |
| `dev` | `ahorro-dev`, every merge to `main` | real |
| `prod` | `ahorro`, the pinned release | real |
| `pr-<n>` | the preview for that pull request | real |

Two things follow from the table:

- **`SKIP_AUTH` follows `ENV`.** It is `true` for `local` and `false` for every
  deployed backend, so a device run against the lab shows the Authenticator
  without another flag. `SKIP_AUTH=true` on the command line still wins.
- **The targets generate the config first.** `ui-run-android`, `ui-run-ios`
  and `ui-build-android` run `make ui-config` for you, which writes
  `flutter-ui/config/$ENV.json` and passes it as `--dart-define-from-file`.
  The values are compiled in, so changing `ENV` rebuilds.

Every value but `local` needs the domain. It comes from the platform, which
publishes it beside the deploy credential, so **the lab must be up** — or pass
it yourself:

```text
make ui-run-android ENV=dev                   the lab is up
FQDN=<fqdn> make ui-run-android ENV=dev       the lab is down
```

With the lab down and no `FQDN=`, the run stops **before the emulator starts**,
on a `UI-CONFIG:` message naming both fixes. The emulator is not the problem.

### Correlate a tap with the service log

Every API call prints one line, with no extra flag:

```text
[ApiLogger]  GET https://api-ahorro-dev.<fqdn>/api/v1/hello -> 200 128ms request_id=7f3c...
```

The service logs JSON with the same id as a field, so one query joins the two:

```logql
{namespace="ahorro-dev", container="ahorro-api"} | json | request_id = "7f3c..."
```

The container label is `ahorro-api`, not `api`. Raise `LOG_LEVEL` to `debug`
for bodies or `verbose` for headers; `info` is the default and `kDebugMode`
gates all of it, so a release build prints nothing.

Two limits worth knowing:

- **`ENV` changes mobile only.** A deployed API allows exactly one CORS
  origin, its own web host, so a browser on `localhost:3000` cannot reach it.
  To use the deployed client in a browser, open its hostname — the cluster
  serves it already.
- **`ENV=prod` points a debug build at the released namespace.** That is
  ordinary read-only client traffic, but it is the namespace Argo owns, so
  reach for `dev` unless you mean `prod`.

### How the config files work

On web the client reads `flutter-ui/web/config.json` at startup. That file is
**generated, never committed**: the Cognito pool is one per platform project,
so `make ui-config` resolves it from SSM for `$PROJECT_NAME` every time, and
`make ui-run-web` does that first.

```text
make ui-run-web                              the default project, vk-hetzner-lab
make ui-run-web PROJECT_NAME=vk-other-lab    another project's pool
```

With no pool it writes blank Cognito keys and says so, and the client reports
that none is configured rather than skipping sign-in. In the cluster the
`ahorro-web` chart renders the same file from a ConfigMap, so one image serves
every environment.

On mobile there is no server to fetch from, so the same values are **compiled
in** instead. `make ui-config` writes a second file for that, and the two
carry the same values under **different key names**:

| File | Read by | Keys look like |
|---|---|---|
| `flutter-ui/web/config.json` | the browser, over HTTP at startup | `apiBaseUrl` |
| `flutter-ui/config/<env>.json` | `--dart-define-from-file`, at build time | `API_BASE_URL` |

A `--dart-define` on the command line beats the same key in the file, in
either order. That is why the local targets pass the host address explicitly —
Android reaches this machine at `10.0.2.2`, iOS at `localhost` — and why a
deployed `ENV` passes no address at all and lets the file win.

Both files are generated and both are gitignored, so neither can carry the
domain into Git. `make domain-check` greps tracked files only.

Hostnames are `ahorro.<fqdn>` and `api-ahorro.<fqdn>`; the domain itself
is never written in this repository.

### Run both services on a local kind cluster

`PROVIDER=local make full-up` in `vk-lab-platform` brings up kind and both
applications. That target has no public hostname and no Cognito pool, so:

```text
make forward-up          the client on :8090, the API on :8091
make forward-down        stop both
```

The platform's own `make forward-up` holds 8080 for the gateway, which is why
these two are 8090 and 8091. The ports are rendered into `config.apiBaseUrl`
and into the API's allowed CORS origin, so they live in `gitops/values.yaml`
rather than being chosen at forward time.

Sign-in is skipped there and both halves report the same stand-in user,
`e2e@vk-ahorro.invalid`. The client asks for this through `authDisabled` in
`config.json` and the API through `AUTH_DISABLED`; neither infers it from the
Cognito keys being empty, because empty keys mean a project whose values were
not threaded and must stay an error. See
[ADR 0008](docs/adr/0008-the-local-target-and-the-stand-in-identity.md).

Argo fetches this repository from GitHub `main` even on that target, so a
local bring-up runs **merged** code, not the working tree.
