.PHONY: help go-build go-test go-lint go-run specs-check domain-check buildx-init image-build image-push images-push require-svc

.DEFAULT_GOAL := help

# Where `go build` puts binaries; ignored by Git.
BIN_DIR := $(CURDIR)/bin

# Local run defaults, set on go-run only so they never leak into go test.
# AUTH_DISABLED is for development only: it makes every request anonymous,
# and the service warns about it at startup.
PORT ?= 8080
AUTH_DISABLED ?= true

# Image coordinates. The tag is always the full commit SHA; `latest` is never
# built or pushed.
REGISTRY ?= ghcr.io/savak1990/vk-ahorro
IMAGE_TAG ?= $(shell git rev-parse HEAD)

# Multi-arch needs the docker-container driver; the default builder cannot do it.
BUILDER := vk
DOCKERFILE = deploy/docker/$(SVC).Dockerfile
IMAGE = $(REGISTRY)/$(SVC):$(IMAGE_TAG)
PLATFORMS := linux/amd64,linux/arm64

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

## Check no file and no new commit contains the root domain
domain-check:
	@./scripts/domain-guard.sh

## Create the multi-arch buildx builder if it is missing
buildx-init:
	@docker buildx inspect $(BUILDER) >/dev/null 2>&1 || docker buildx create --name $(BUILDER) --driver docker-container

## Fail unless SVC names an existing Dockerfile
require-svc:
	@test -n "$(SVC)" || { echo "set SVC=<service>, for example: make image-build SVC=hello" >&2; exit 1; }
	@test -f "$(DOCKERFILE)" || { echo "no $(DOCKERFILE)" >&2; exit 1; }

## Build one image for this machine only. Usage: make image-build SVC=hello
image-build: require-svc
	docker buildx build --load -f $(DOCKERFILE) -t $(IMAGE) .

## Build and push one multi-arch image. Usage: make image-push SVC=hello
image-push: require-svc buildx-init
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --provenance=false \
	  --push -f $(DOCKERFILE) -t $(IMAGE) .

## Build and push every image
images-push:
	@$(MAKE) image-push SVC=hello
