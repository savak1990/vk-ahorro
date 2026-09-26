.PHONY: help go-build go-test go-lint go-run specs-check domain-check cognito-config token buildx-init image-build image-push images-push require-svc require-chart helm-lint helm-template helm-package helm-push emulator-android emulator-ios emulator-stop ui-get ui-fix ui-format ui-analyze ui-test ui-build-web ui-build-android ui-run-web ui-run-android ui-run-ios

.DEFAULT_GOAL := help

UI_DIR := $(CURDIR)/flutter-ui

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

# Chart coordinates. CHART names a directory under deploy/helm.
CHART ?=
CHART_DIR = deploy/helm/$(CHART)
CHART_VERSION = $(shell sed -n 's/^version: *//p' $(CHART_DIR)/Chart.yaml)
CHARTS_REGISTRY ?= oci://$(REGISTRY)/charts
DIST_DIR := $(CURDIR)/dist

# A documented placeholder. The real hostname exists only at install time.
TEMPLATE_HOST := api-ahorro.lab.example.com

# Flutter UI. AVD and IOS_DEVICE name the simulators a developer boots locally;
# override either on the command line to use a different one.
UI_DIR := $(CURDIR)/flutter-ui
AVD ?= pixel_phone
IOS_DEVICE ?= iPhone 18 Pro

# The platform project whose persistent layer owns the Cognito pool. The pool
# is per project, so nothing about it can be committed here. Exported because
# the scripts read it from the environment.
export PROJECT_NAME ?= vk-hetzner-lab

## Print this help
help:
	@awk 'BEGIN { FS = ":" } \
	     /^## / { doc = substr($$0, 4); next } \
	     /^[a-z][a-z0-9-]*:/ { if (doc != "") { printf "  %-18s %s\n", $$1, doc; doc = "" } } \
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

## Print the Cognito pool's public identifiers as JSON
cognito-config:
	@./scripts/cognito.sh config

## Print a one-hour Cognito id token for the test user
token:
	@./scripts/cognito.sh token

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

## Fail unless CHART names an existing chart
require-chart:
	@test -n "$(CHART)" || { echo "set CHART=<chart>, for example: make helm-template CHART=hello" >&2; exit 1; }
	@test -f "$(CHART_DIR)/Chart.yaml" || { echo "no $(CHART_DIR)/Chart.yaml" >&2; exit 1; }

# lint renders the templates, so the required values must be present or every
# chart fails on its own guard rather than on a real defect.
## Lint every chart
helm-lint:
	@for c in deploy/helm/*/; do \
	  helm lint "$$c" --set host=$(TEMPLATE_HOST) --set image.tag=$(IMAGE_TAG); \
	done

## Render one chart to stdout with a placeholder host. Usage: make helm-template CHART=hello
helm-template: require-chart
	@helm template $(CHART) $(CHART_DIR) \
	  --set host=$(TEMPLATE_HOST) --set image.tag=$(IMAGE_TAG)

## Package one chart into dist/. Usage: make helm-package CHART=hello
helm-package: require-chart
	@mkdir -p $(DIST_DIR)
	helm package $(CHART_DIR) --app-version $(IMAGE_TAG) --destination $(DIST_DIR)

## Push one packaged chart to GHCR. Usage: make helm-push CHART=hello
helm-push: helm-package
	helm push $(DIST_DIR)/$(CHART)-$(CHART_VERSION).tgz $(CHARTS_REGISTRY)

## Fetch the Flutter package dependencies
ui-get:
	cd $(UI_DIR) && flutter pub get

## Apply the automatic lint fixes in place
ui-fix:
	cd $(UI_DIR) && dart fix --apply

## Format the Flutter code in place
ui-format:
	cd $(UI_DIR) && dart format lib test

## Analyze the Flutter code
ui-analyze:
	cd $(UI_DIR) && flutter analyze

## Run the Flutter widget tests
ui-test:
	cd $(UI_DIR) && flutter test

## Build the web bundle into flutter-ui/build/web
ui-build-web:
	cd $(UI_DIR) && flutter build web

## Build a debug APK
ui-build-android:
	cd $(UI_DIR) && flutter build apk --debug

## Boot the Android emulator $AVD and print its adb serial
emulator-android:
	@$(CURDIR)/scripts/android-emulator.sh $(AVD)

# Xcode 27 replaced Simulator.app with DeviceHub.app, which is the only way
# to see the booted device; simctl alone boots it headless.
## Boot the iOS simulator $IOS_DEVICE and show its window
emulator-ios:
	@xcrun simctl boot "$(IOS_DEVICE)" 2>/dev/null || true
	@xcrun simctl bootstatus "$(IOS_DEVICE)" >/dev/null
	@open -a "$(shell xcode-select -p)/../Applications/DeviceHub.app"
	@echo "$(IOS_DEVICE) ready"

## Run the Flutter app on the Android emulator $AVD
ui-run-android:
	@serial=$$($(CURDIR)/scripts/android-emulator.sh $(AVD)) && \
	  cd $(UI_DIR) && flutter run -d $$serial

## Run the Flutter app on the iOS simulator $IOS_DEVICE
ui-run-ios: emulator-ios
	cd $(UI_DIR) && flutter run -d "$(IOS_DEVICE)"

# Port 3000 is the origin `make go-run` allows through CORS.
## Run the Flutter app in Chrome on :3000
ui-run-web:
	cd $(UI_DIR) && flutter run -d chrome --web-port 3000

## Shut down every running Android emulator and iOS simulator
emulator-stop:
	@for s in $$(adb devices | awk '/^emulator-/ {print $$1}'); do adb -s $$s emu kill; done
	@xcrun simctl shutdown all
