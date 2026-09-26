---
id: "CORE-107"
status: "DRAFT"
updated: "2026-09-26"
---
# 107 — The local target runs both applications in kind

**Status note:** Draft. Split out of 060 and 105, which both gate the
application off the `local` target. The work is its own spec because local
differs structurally, not by a value.

**Complexity:** Small–Medium
**Risk:** Low — a target that nothing depends on; a broken render there cannot reach a cloud cluster.
**Estimated cost:** ~0.5 day · Runtime cost: none. kind runs on the operator's machine.
**Recommended model:** Sonnet.
**Depends on:** [060-gitops-and-platform-link](../060-A-gitops-and-platform-link/spec.md), [105-web-delivery](../105-A-web-delivery/spec.md)
**Lifecycle class(es) touched:** Disposable (every Kubernetes object the charts render).

## Scope

`PROVIDER=local make full-up` in `vk-lab-platform` brings both applications up
in kind, so the delivery chain can be exercised end to end with no cloud
account and no cost.

Excludes: the charts themselves (040, 105), the app-of-apps chart (060), the
Cognito pool, which is an AWS resource the local target never creates.

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
| The pointer | rendered | gated off by `ne .Values.target "local"` |

## Requirements

1. `gitops/templates/validate.yaml` MUST NOT fail on an empty `fqdn` when the
   target is local. That requires the platform's pointer to pass `target` down
   as a Helm parameter, which nothing does today: this chart has no other way
   to know which target it is rendering for.
2. The platform's `gitops/templates/apps/vk-ahorro/application.yaml` gate MUST
   widen to include local, and MUST supply `target` and empty Cognito values
   there. `local_resolve_inputs` reads no SSM, so the values cannot come from
   the resolver.
3. Neither service MUST render an HTTPRoute on the local target. Two reasons,
   and the second is the binding one:
   - Argo CD already claims the root path prefix `/` on that target, and
     Gateway API matches the longer prefix first.
   - Serving the Flutter build under a sub-path such as `/ahorro` needs
     `--base-href` at **build** time, which would break the
     one-image-many-environments property that 105 requirement 1 exists to
     protect. The platform's own Argo CD route documents this exact failure:
     the UI keeps `<base href="/">` and every relative asset then resolves to
     the root and 404s.

   Port-forward the two Services instead.
4. An HTTPRoute naming a listener that does not exist is never Accepted, and
   that stalls the whole root sync behind its health check. So requirement 3
   is not only a convenience: a route hard-coding `sectionName: https` would
   wedge the local bring-up.
5. `config.apiBaseUrl` MUST be `http://localhost:<api port>` on local, and the
   API's `corsAllowedOrigins` MUST be `http://localhost:<web port>`, so the
   browser can call across the two port-forwards.
6. The empty Cognito values MUST be tolerated, not worked around.
   `AppConfig.fromJson` throws on a **missing** key, never on an empty one, so
   an empty pool id already renders and already loads. State it here so nobody
   later "fixes" it with a default.
7. A Make target in this repository MUST wrap the two forwards, one line each,
   with the complex part in `scripts/` if it grows:
   `kubectl -n ahorro port-forward svc/ahorro-web 8080:80` and
   `svc/ahorro-api 8081:80`.
8. `scripts/gitops-render-check.sh` in the platform MUST name the two new
   Applications in the local target's lists. A new Application is today
   neither required nor forbidden there, so the check passes silently either
   way — which is the trap this requirement closes.

## Implementation hints

- `local_wait_for_children` already waits for every Application in `argocd` to
  report Synced and Healthy, so both applications gate `full-up` on this
  target with no change.
- On local, Argo still fetches this repository from GitHub `main`.
  `argocd app sync root --local` applies to the platform chart only. So a local
  bring-up tests what is merged, not what is uncommitted — which is worth
  saying out loud, because it is the opposite of what "local" suggests.
- Do not add a new `case "$PROVIDER"` block to `argo-up.sh`. Its dispatch test
  requires every block to name all four providers.
- `FORBIDDEN_KINDS_LOCAL` in the render check includes `ExternalSecret`, so
  nothing on this target may deliver a value that way.

## Testing / acceptance criteria

- `PROVIDER=local make full-up` in `vk-lab-platform` completes, and
  `kubectl -n ahorro get pods` shows both pods Running.
- `make gitops-template` in this repository renders no HTTPRoute when the
  target is local, and both HTTPRoutes when it is not.
- `helm template gitops --set target=local` succeeds with no `fqdn`, and
  `helm template gitops` with neither still fails.
- The two port-forwards serve the client on 8080 and the API on 8081;
  `curl localhost:8081/healthz` returns 200 and the browser console prints
  `http://localhost:8081` as the resolved base URL.
- `make gitops-check` in the platform passes with the two new Applications
  named in the local target's object lists.
- `make scripts-check` and `make argo-up-dispatch-check` in the platform pass.
