---
id: "CI-040"
status: "DRAFT"
updated: "2026-09-26"
---
# 040 — Hermetic end-to-end test on every pull request

**Status note:** Draft. The pull-request half of what core 110 asked for.
The other half, against the real cluster and the real Cognito pool, is
`deploy/050`.

**Complexity:** Medium
**Risk:** Medium — `flutter drive` on a headless browser is the flakiest job in the workflow; a retry budget of one is allowed, more hides a real defect.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** [030-flutter-gates](../030-P-flutter-gates/spec.md), [080-flutter-config-and-hello](../../core/080-P-flutter-config-and-hello/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

One integration test that starts the Go service and the Flutter web app on
the runner, taps "+" and reads the hello answer. It proves the wiring: config
load, the HTTP call, the request id, the message on screen. It needs no
cluster, no AWS and no secret.

Excludes: authentication. The app runs with `SKIP_AUTH` and the service with
`AUTH_DISABLED`, which core 110 forbade for the real test and this spec
allows for the hermetic one, because the two tests prove different things.
The real token path is `deploy/050`.

## Requirements

1. `flutter-ui/integration_test/hello_test.dart` MUST start the app, tap the "+" action, and assert the text `Hello, anonymous` appears. `flutter-ui/test_driver/integration_test.dart` holds the standard driver.
2. `make e2e-local` MUST run `scripts/e2e-local.sh`: start `go run ./cmd/hello` with `AUTH_DISABLED=true` on `:8080`, start `chromedriver --port=4444`, run `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/hello_test.dart -d web-server --dart-define=SKIP_AUTH=true`, and stop both processes on exit through a `trap`. It exits non-zero when the test fails.
3. The web app under test MUST read `web/config.json` as shipped (`apiBaseUrl: http://localhost:8080`); no test-only config file.
4. CI job `e2e-local` on `ubuntu-latest` MUST run when the `go` **or** the `flutter` filter matched, call `make e2e-local`, and join `ci-ok`. `ubuntu-latest` ships Chrome and a matching ChromeDriver, so no browser setup action is added.
5. The test MUST run under `kDebugMode` builds only, which is what `flutter drive` produces; `SKIP_AUTH` is compiled out of release builds (core 110 req 6, kept).

## Implementation hints

- `web-server` device is headless and needs no display; `-d chrome` would need a windowed Chrome.
- The Go service prints its port on start; wait for `curl -fsS localhost:8080/healthz` in a loop with a 30 s cap before starting the driver.
- Keep the test to one file and one flow. A second flow is a second file.

## Testing / acceptance criteria

- `make e2e-local` on a laptop exits 0 and prints the driver's `All tests passed`.
- Stopping the Go service before the tap makes the test fail with the error message shown in the app, and the script exits non-zero.
- A pull request touching only `internal/hello/handler.go` runs `e2e-local`.
- The job finishes in under 8 minutes with warm caches.
