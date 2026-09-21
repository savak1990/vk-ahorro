.PHONY: help go-build go-test go-lint go-run specs-check

.DEFAULT_GOAL := help

# Where `go build` puts binaries; ignored by Git.
BIN_DIR := $(CURDIR)/bin

# Local run defaults, set on go-run only so they never leak into go test.
# AUTH_DISABLED is for development only: it makes every request anonymous,
# and the service warns about it at startup.
PORT ?= 8080
AUTH_DISABLED ?= true

## Print this help
help:
	@awk 'BEGIN { FS = ":" } \
	     /^## / { doc = substr($$0, 4); next } \
	     /^[a-z][a-z0-9-]*:/ { if (doc != "") { printf "  %-14s %s\n", $$1, doc; doc = "" } } \
	     { doc = "" }' $(MAKEFILE_LIST)

## Build every Go binary into bin/
go-build:
	@mkdir -p $(BIN_DIR)
	go build -o $(BIN_DIR)/ ./cmd/...

## Run the Go unit tests
go-test:
	go test ./... -count=1

## Run golangci-lint over the Go code
go-lint:
	golangci-lint run ./...

## Run the hello service locally on $PORT with auth disabled
go-run: export PORT := $(PORT)
go-run: export AUTH_DISABLED := $(AUTH_DISABLED)
go-run:
	go run ./cmd/hello

## Check the specs/ layout, front matter and links
specs-check:
	@./scripts/specs-check.sh
