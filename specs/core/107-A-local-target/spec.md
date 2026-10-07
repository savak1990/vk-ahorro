---
id: "CORE-107"
status: "IN_PROGRESS"
updated: "2026-09-27"
---
# 107 — The local target runs both applications in kind

**Status note:** In progress. This repository's half ships: the `target`
parameter, the route gate, the stand-in identity, the `AUTH_DISABLED` chart
key and the two forwards. The platform half — lifting the pointer's gate,
the e2e RBAC and the render check's local lists — is a separate pull request
against `vk-lab-platform`, and it must merge **after** this one.

Four requirements below were added after the draft, because the draft could
not have passed its own acceptance test without them: requirements 9 to 12.
Two are not implemented as written; see
[ADR 0008](../../../docs/adr/0008-the-local-target-and-the-stand-in-identity.md).
Requirement 7 names ports 8080 and 8081, which collide with the platform's own
gateway forward; 8090 and 8091 ship. Requirement 6 says the empty Cognito
values are merely tolerated; tolerating them renders an error page, so an
explicit skip flag ships instead.

**Complexity:** Small–Medium
**Risk:** Low — a target that nothing depends on; a broken render there cannot reach a cloud cluster.
**Estimated cost:** ~0.5 day · Runtime cost: none. kind runs on the operator's machine.
**Recommended model:** Sonnet.
**Depends on:** [060-gitops-and-platform-link](../060-D-gitops-and-platform-link/spec.md), [105-web-delivery](../105-D-web-delivery/spec.md)
**Lifecycle class(es) touched:** Disposable (every Kubernetes object the charts render).

## Scope

`PROVIDER=local make full-up` in `vk-lab-platform` brings both applications up
in kind, so the delivery chain can be exercised end to end with no cloud
account and no cost. Sign-in is skipped there, because the target creates no
user pool, and a stand-in identity takes the place of a Cognito user.

Excludes: the charts themselves (040, 105), the app-of-apps chart (060), the
Cognito pool, which is an AWS resource the local target never creates, and
the authenticated end-to-end run, which is
`specs/deploy/050-P-post-deploy-e2e` since core 110 was superseded.

## What differs on the local target

Every row is a structural difference, not a value. Each was read from
`vk-lab-platform` on `main`.

| | aws / civo / hetzner | local |
|---|---|---|
| `fqdn` | read from SSM | never set; stays `""` |
| Gateway listener | `https` | one `http` on port 80 |
| Gateway Service | `LoadBalancer` | `ClusterIP`; kind has no load balancer |
| Route matching | by hostname | by path prefix, with no `hostnames` key |
| Reached by | public DNS and TLS | `kubectl port-forward` |
| Cognito | a pool in AWS | none; the resolver reaches no cloud API |
| Sign-in | the Authenticator | skipped, with a stand-in identity |
| The pointer | rendered | gated off by `ne .Values.target "local"` |

## Requirements

1. `gitops/templates/validate.yaml` MUST NOT fail on an empty `fqdn` when the
   target is local. That requires the platform's pointer to pass `target` down
   as a Helm parameter, which nothing does today: this chart has no other way
   to know which target it is rendering for. It MUST keep failing on every
   other target. An empty `fqdn` does not fail on its own — `printf "%s.%s"
   "ahorro" ""` yields `"ahorro."`, which `required` accepts.
2. The platform's `gitops/templates/apps/vk-ahorro/application.yaml` gate MUST
   widen to include local, and MUST supply `target` there. The Cognito values
   already default to `""` in the platform's `gitops/values.yaml`, and
   `envoyGateway.fqdn` already defaults to `""`, so `scripts/argo-up.sh` needs
   no change at all.
3. Neither service MUST render an HTTPRoute on the local target. Two reasons,
   and the second is the binding one:
   - Argo CD already claims the root path prefix `/` on that target, and
     Gateway API matches the longer prefix first.
   - Serving the Flutter build under a sub-path such as `/ahorro` needs
     `--base-href` at **build** time, which would break the
     one-image-many-environments property that 105 requirement 1 exists to
     protect.

   Port-forward the two Services instead.
4. An HTTPRoute naming a listener that does not exist is never Accepted, and
   that stalls the whole root sync behind its health check. So requirement 3
   is not only a convenience: a route hard-coding `sectionName: https` would
   wedge the local bring-up. The gate MUST compare its value as text: Argo may
   deliver it as a string, and a non-empty `"false"` is truthy to a Go
   template, which would render the very route this requirement forbids.
5. `config.apiBaseUrl` MUST be `http://localhost:<api port>` on local, and the
   API's `corsAllowedOrigins` MUST be `http://localhost:<web port>`, so the
   browser can call across the two port-forwards. Both ports MUST live in
   `gitops/values.yaml`: they are rendered into delivered configuration, not
   chosen at forward time.
6. The empty Cognito values MUST NOT throw. `AppConfig.fromJson` throws on a
   **missing** key, never on an empty one, so an empty pool id already renders
   and already loads. State it here so nobody later "fixes" it with a default.
   Tolerating them is not sufficient on its own; see requirement 9.
7. A Make target in this repository MUST wrap the two forwards. The ports MUST
   NOT be 8080: `scripts/forward-up-local.sh` in the platform puts the gateway
   there and refuses to start when the port is held, so the platform's forward
   and this one could never run together. 8090 and 8091 ship.
8. `scripts/gitops-render-check.sh` in the platform MUST name the two new
   Applications in the local target's lists. A new Application is today
   neither required nor forbidden there, so the check passes silently either
   way — which is the trap this requirement closes.
9. The client MUST render the shell with no sign-in when, and only when, the
   chart asks for it through an explicit flag. The flag MUST NOT be inferred
   from the Cognito identifiers being empty: empty identifiers already mean a
   project whose values were not threaded, and inferring the skip would turn
   that mistake into an application that quietly serves itself
   unauthenticated in place of the error page that catches it.
10. The flag MUST reach the web client through `config.json`, not through
    `--dart-define`. The deployed client is a release build, so the existing
    `SKIP_AUTH` define is inert there (`kDebugMode` is false), and
    `AppConfig.load()` reads `String.fromEnvironment` only on the `!kIsWeb`
    branch. Mobile keeps the defines, where they work. The new keys MUST be
    optional, read outside `AppConfig._keys`: a key in that list is mandatory
    in four places at once and would cost the "a missing key fails loudly"
    property that protects the four real ones.
11. `ahorro-api` MUST be able to start on this target. Its chart carries no
    `AUTH_DISABLED` key today, and `internal/api/config.go` rejects an empty
    issuer while `cmd/ahorro-api/main.go` exits 1, so the pod would enter
    CrashLoopBackOff and this spec could not pass its own acceptance test.
12. Both halves MUST name the same user. With auth off the API answers
    `Hello, anonymous`; it MUST instead answer with the stand-in identity the
    chart supplies, defaulting to `anonymous` when none is given. The address
    is `e2e@vk-ahorro.invalid`, the same one the pool's test user carries on
    every other target.
13. The Account tab MUST NOT offer Sign out while sign-in is skipped.
    `AmplifyProvider.signOut()` throws against an Amplify that was never
    configured.

## Implementation hints

- `local_wait_for_children` already waits for every Application in `argocd` to
  report Synced and Healthy, so both applications gate `full-up` on this
  target with no change.
- On local, Argo still fetches this repository from GitHub `main`.
  `argocd app sync root --local` applies to the platform chart only. So a local
  bring-up tests what is merged, not what is uncommitted — which is worth
  saying out loud, because it is the opposite of what "local" suggests. It is
  also why the platform's pull request must merge second.
- Do not add a new `case "$PROVIDER"` block to `argo-up.sh`. Its dispatch test
  requires every block to name all four providers. Nothing in that script
  needs to change for this spec.
- `FORBIDDEN_KINDS_LOCAL` in the render check includes `ExternalSecret`, so
  nothing on this target may deliver a value that way.
- `svc.host` is referenced only from `httproute.yaml`, so gating the route off
  is what makes an empty `host` legal. Leave the `required` guard alone.

## Testing / acceptance criteria

- `PROVIDER=local make full-up` in `vk-lab-platform` completes, and
  `kubectl -n ahorro get pods` shows both pods Running — which is the check
  that requirement 11 landed.
- `make gitops-template TARGET=local` renders no HTTPRoute and
  `apiBaseUrl: http://localhost:8091`; `make gitops-template` renders both
  hostnames as before.
- `helm template gitops --set target=local` succeeds with no `fqdn`, and
  `helm template gitops` with neither still fails.
- `make gitops-check` validates both renders.
- `helm template deploy/helm/ahorro-web --set httpRoute.enabled=false` with no
  `host` succeeds; with the route on and no host it still fails. The same
  holds with `--set-string`, which is the case requirement 4 names.
- The two forwards serve the client on 8090 and the API on 8091 while the
  platform's own forward holds 8080; `curl localhost:8091/healthz` returns
  200, `curl localhost:8091/api/v1/hello` returns
  `Hello, e2e@vk-ahorro.invalid`, and the browser console prints
  `http://localhost:8091` as the resolved base URL.
- The client shows the three tabs with no Authenticator, and the Account tab
  names the stand-in user and offers no Sign out.
- `make gitops-check` in the platform passes with the two new Applications
  named in the local target's object lists.
- `make scripts-check` and `make argo-up-dispatch-check` in the platform pass.
