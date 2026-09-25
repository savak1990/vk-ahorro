---
id: "CORE-020"
status: "DONE"
updated: "2026-09-21"
---
# 020 — Go hello service

**Status note:** Done on 2026-09-21. `make go-test` passes 4 packages,
`make go-lint` reports 0 issues, and a local run answers `/healthz` 200 with an
echoed `X-Request-Id`, `/api/v1/hello` 200 `Hello, anonymous` with
`AUTH_DISABLED=true`, and 401 without a token when auth is on. SIGTERM shut the
process down in under a second. The check against a real Cognito token moves to
the platform's spec AWS-035, which creates the pool (055, ADR 0004). This spec also added the repository's first
`Makefile`, `.golangci.yml` (schema v2) and `scripts/specs-check.sh`.

**Complexity:** Small
**Risk:** Low — the JWT middleware is the only part with a security consequence.
**Estimated cost:** ~1 day
**Recommended model:** Sonnet.
**Depends on:** 000-constitution, [010-repo-bootstrap](../010-D-repo-bootstrap/spec.md)
**Lifecycle class(es) touched:** None (source code only).

## Scope

One Go module, one service `hello`, and the shared packages every later
service reuses: JWT verification against Cognito, JSON helpers, request id,
CORS.

Excludes: the Dockerfile (030), the chart (040), the Cognito pool itself (the platform's spec AWS-035).

## Requirements

1. `go.mod` MUST declare `module github.com/savak1990/vk-ahorro` and Go `1.26`. One module for the whole repository (constitution §1).
2. Layout MUST be `cmd/hello/main.go`, `internal/hello/` (server wiring, handlers, tests), `internal/platform/auth/` (JWT), `internal/platform/httpx/` (JSON responses, request id, CORS, logging middleware).
3. Configuration comes from environment variables only: `PORT` (default `8080`), `COGNITO_ISSUER`, `COGNITO_CLIENT_ID`, `CORS_ALLOWED_ORIGINS` (comma list), `AUTH_DISABLED` (`true` only for local development; the service MUST log a warning at startup when set).
4. Routes:
   - `GET /healthz` → `200 {"status":"ok"}`, no auth.
   - `GET /api/v1/hello` → `401` without a valid bearer token; `200 {"message":"Hello, <email>","sub":"<sub>"}` with one. With `AUTH_DISABLED=true` it returns `Hello, anonymous`.
5. Token verification MUST use the issuer's JWKS (`<issuer>/.well-known/jwks.json`), check `iss`, `exp`, and either `aud` (id token) or `client_id` (access token) against `COGNITO_CLIENT_ID`, and accept `token_use` `id` or `access`. Keys are cached and refreshed on unknown `kid`.
6. Every response MUST carry `X-Request-Id`: echoed from the request when present, generated otherwise. Logs are JSON lines (`log/slog`) with the request id, method, path, status, duration.
7. The server MUST shut down gracefully on `SIGTERM` within 10 s (Kubernetes rolling updates).
8. Make targets: `go-build`, `go-test`, `go-lint` (golangci-lint), `go-run` (local, `AUTH_DISABLED=true`).

## Implementation hints

- Standard library `net/http` with Go 1.22+ method patterns (`mux.HandleFunc("GET /healthz", ...)`). No web framework.
- `github.com/coreos/go-oidc/v3/oidc` gives a JWKS-backed verifier in a few lines; `oidc.NewRemoteKeySet` plus `oidc.NewVerifier` with `SkipClientIDCheck: true` and a manual `client_id` claim check covers both token types.
- Test the middleware with a local RSA key and a fake JWKS endpoint (`httptest.Server`); never call Cognito in unit tests.

## Testing / acceptance criteria

- `make go-test` passes; coverage includes: healthz 200, hello 401 (no token, bad signature, expired, wrong audience), hello 200 (id token, access token), `AUTH_DISABLED` path, request id echo.
- `make go-lint` reports zero issues.
- `make go-run` then `curl -i localhost:8080/healthz` → 200 with `X-Request-Id`; `curl -i localhost:8080/api/v1/hello` → 200 `Hello, anonymous`.
- With `AUTH_DISABLED` unset and the lab pool values: `curl` without a token → 401; with `aws cognito-idp initiate-auth` id token → 200 with the user's email. The token half needs the pool, so it runs under spec 055 with `make token`.
