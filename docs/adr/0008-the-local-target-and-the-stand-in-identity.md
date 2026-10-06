# ADR 0008: The local target, and the stand-in identity it signs in as

## Status

Accepted

Implements spec 107. Deviates from two of its written requirements and adds
four it does not carry; each is recorded below.

## Context

`PROVIDER=local make full-up` in `vk-lab-platform` brings up kind, Argo CD and
the whole platform, but not this application. Platform ADR 0043 gates the
pointer off that target and names spec 107 as the work that lifts the gate.

Two things stood in the way, and only one of them was written down.

The first is routing. The local gateway has one plain-HTTP listener named
`http`, matches by path rather than hostname, and Argo CD already claims the
root prefix. Both charts hard-code `sectionName: https` and a `hostnames`
entry, and a route naming a listener that does not exist is never Accepted,
which stalls the sync behind its own health check. Spec 107 says this.

The second is identity, and spec 107 does not mention it. The local target
creates no Cognito pool, because `make persistent-up` is an `echo` there and
no AWS API is ever called. So the client has no pool to sign in against and
the service has no issuer to verify against.

## Decision

### 1. The stand-in identity travels in `config.json`, not in a dart-define

The obvious lever looked like `--dart-define`. It cannot work on the deployed
client, for two independent reasons:

- `main.dart` gated `SKIP_AUTH` behind `kDebugMode`, and the image is built
  with `flutter build web --release`. The flag was inert in every image.
- `AppConfig.load()` reads `String.fromEnvironment` only on the `!kIsWeb`
  branch. Web ignores dart-defines by design.

A define would also bake the identity into the image, which is the property
spec 105 requirement 1 exists to protect: one image serves every environment.

So the web client reads three more keys from the `config.json` the chart
already mounts, and mobile keeps the defines, where they work and where there
is no server to fetch a file from.

### 2. The keys are optional, and the flag is explicit

`authDisabled`, `devUserEmail` and `devUserSub` are read **outside**
`AppConfig._keys`. A key inside that list is mandatory in four places at once
— the chart's values, its ConfigMap, `gitops/templates/web.yaml` and the
committed `web/config.json` — and the point of the list is that a chart which
forgets one of the four real keys fails loudly.

The flag is never inferred from the Cognito identifiers being empty, although
that would have needed no new key at all. Empty identifiers already mean
something: a platform project whose values were not threaded. Inferring the
skip from them would turn that mistake into an application that quietly serves
itself unauthenticated, in place of the error page that exists to catch it.

It is not called `SKIP_AUTH`. That name belongs to the debug define, which
`specs/ci/040-P-hermetic-e2e` uses for the driver run, and which
`specs/deploy/050-P-post-deploy-e2e` requirement 6 forbids outright in the
post-deploy checks. Both inherit the rule from the superseded core 110.

### 3. The API gets the same identity, and a reason to start at all

`ahorro-api` rejected an empty issuer and called `os.Exit(1)`, and its chart
had no `AUTH_DISABLED` key. On local it would have entered CrashLoopBackOff,
so spec 107's own acceptance criterion — both pods Running — could not have
passed. The chart now carries the key.

With auth off the service answered `Hello, anonymous`. It now answers with
`AUTH_ANONYMOUS_EMAIL` and `AUTH_ANONYMOUS_SUB`, defaulting to `anonymous` and
an empty subject. Both halves of the application therefore name the same user,
`e2e@vk-ahorro.invalid`, which is the address the pool's test user carries on
every other target.

### 4. Neither service renders an HTTPRoute on local

Both charts gain `httpRoute.enabled`, default `true`. The gate compares the
value as text rather than testing it directly, because Argo may deliver it as
a string and a non-empty `"false"` is truthy to a Go template — which would
render exactly the route that wedges the bring-up.

`svc.host` is referenced only from the route, so turning the route off is also
what makes an empty `host` legal. The `required` guard on it is untouched and
still fires everywhere else.

### 5. The ports are 8090 and 8091

Spec 107 requirement 7 names 8080 and 8081. The platform's own
`make forward-up` puts the gateway on 8080 and refuses to start when the port
is held, so the two could never run together.

These are not a local preference. They are rendered into `config.apiBaseUrl`
and into the API's allowed CORS origin, so they are part of the delivered
configuration and live in `gitops/values.yaml`.

### 6. The chart is told which target it renders for

`gitops/values.yaml` gains `target`, which the platform's pointer passes down.
Nothing else could carry it: with an empty `fqdn`,
`printf "%s.%s" "ahorro" ""` yields `"ahorro."`, which is not empty, so
`required` passes and a bogus hostname renders silently. An explicit
conditional is the only thing that fails honestly.

`validate.yaml` still fails on an empty `fqdn` for every other target.

## Consequences

- **A local bring-up tests merged code only.** The platform's pointer hardcodes
  `targetRevision: main`, and `argocd app sync root --local` applies to the
  platform chart. This is the opposite of what "local" suggests, and it means
  the platform change must merge after this one or the local target breaks.
- Both chart versions move to `0.2.0`. A published version is immutable in
  practice, and `chart-version-check.sh` fails a pull request without the bump.
- `make gitops-template` and `gitops-lint` take `TARGET`, and `gitops-check`
  now renders and validates both shapes. A check that only ever saw the cloud
  render would not notice a broken local one.
- The Account tab names the stand-in user and hides Sign out when sign-in is
  skipped: `AmplifyProvider.signOut()` throws against an Amplify that was
  never configured.
- This closes nothing in `specs/deploy/050-P-post-deploy-e2e`. A run with auth
  off cannot catch a wrong issuer, a stale JWKS, an expired token, or CORS
  failing on the authenticated call, which are the failures that spec exists
  to find. It runs against the real hostnames and the real pool, which the
  local target has neither of.
- `make images-push` pushed only `ahorro-api`, so it never built the client.
  Fixed here because the local target is the first thing that would have
  noticed.
