---
id: "CI-020"
status: "DRAFT"
updated: "2026-09-26"
---
# 020 — Go quality, architecture and correctness gates

**Status note:** Draft.

**Complexity:** Small
**Risk:** Low — every gate is a Make target that runs on a laptop first; a noisy linter is turned off in the same file that turned it on.
**Estimated cost:** ~0.5 day
**Recommended model:** Sonnet.
**Depends on:** [010-change-aware-checks](../010-P-change-aware-checks/spec.md), [020-go-hello-service](../../core/020-D-go-hello-service/spec.md)
**Lifecycle class(es) touched:** None.

## Scope

What the `go` job proves, expressed as Make targets so CI and a laptop run
the same commands (constitution §8).

Excludes: image build and push (`deploy/010`); API contract tests against a
running cluster (`deploy/050`).

## Requirements

1. `.golangci.yml` (already `version: "2"`) MUST enable, on top of the standard set: `errorlint`, `gosec`, `bodyclose`, `noctx`, `revive`, `gocognit`, `exhaustive`. `make go-lint` stays the entry point; CI MUST call it rather than the lint action's own runner, so both run one pinned version.
2. `make go-test` MUST run `go test ./... -race -shuffle=on -count=1 -coverprofile=cover.out`. `make go-cover` MUST fail when total coverage is below 70%, read from `cover.out` with `go tool cover -func` and `awk`; no new tool.
3. `make go-vet` runs `go vet ./...`; `go test` runs only a subset of vet analyzers.
4. `make go-tidy-check` runs `go mod tidy -diff` and fails on any output.
5. `make go-vuln` runs `govulncheck ./...` through `go run golang.org/x/vuln/cmd/govulncheck@<version>` with the version pinned in the Makefile.
6. `make go-arch` runs `go-arch-lint check` (pinned the same way) against `.go-arch-lint.yml` with three components: `cmd` (`cmd/**`), `hello` (`internal/hello`), `platform` (`internal/platform/**`). `cmd` may depend on `hello` and `platform`; `hello` may depend on `platform`; `platform` depends on nothing inside the module. A new service becomes a fourth component with the same rule.
7. The `go` job MUST run, in order: `go-build`, `go-vet`, `go-lint`, `go-test`, `go-cover`, `go-tidy-check`, `go-arch`, `go-vuln`. Each target carries a `##` doc line.
8. Fuzz targets and OpenAPI contract tests are not added: the service has two routes and no parser. Recorded so the omission is deliberate.

## Implementation hints

- `revive` needs a `rules:` list or it enables its defaults; start with `exported`, `package-comments`, `unused-parameter`, `early-return`.
- `go-arch-lint` config is `version: 3`, `components:` with `in:` globs, `deps:` with `mayDependOn:`; `allow.depOnAnyVendor: true` keeps third-party imports out of the rules.
- Tool pins in the Makefile: `GOVULNCHECK_VERSION := vX.Y.Z`, `GOARCHLINT_VERSION := vX.Y.Z`; Dependabot does not bump these, so note them in `docs/toolchain.md` (core 090).

## Testing / acceptance criteria

- Every target in requirement 7 exits 0 on `main`.
- Adding `import "vk-ahorro/internal/hello"` to a file under `internal/platform/` makes `make go-arch` fail and name the component.
- Deleting a test until coverage drops below 70% makes `make go-cover` fail with the measured number.
- Adding an unused module to `go.mod` makes `make go-tidy-check` fail.
- The `go` job on a pull request finishes in under 6 minutes with warm caches.
