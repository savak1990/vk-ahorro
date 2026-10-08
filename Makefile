.PHONY: help go-build go-test go-lint go-run specs-check domain-check repo-settings version print-project deploy-dev preview-up preview-down preview-url kubeconfig gitops-lint gitops-template gitops-check cognito-config token buildx-init image-build image-push images-push require-svc require-chart helm-lint helm-template helm-package helm-push emulator-android emulator-ios emulator-stop ui-get ui-fix ui-format ui-analyze ui-test ui-build-web ui-build-android ui-run-web ui-run-android ui-run-ios forward-up forward-down ui-config

.DEFAULT_GOAL := help

UI_DIR := $(CURDIR)/flutter-ui

# Where `go build` puts binaries; ignored by Git.
BIN_DIR := $(CURDIR)/bin

# Local run defaults, set on go-run only so they never leak into go test.
# AUTH_DISABLED is for development only: it makes every request anonymous,
# and the service warns about it at startup.
PORT ?= 8080
AUTH_DISABLED ?= true

# Which backend the Flutter client talks to: local is this machine, and dev,
# prod and pr-<n> are deployed namespaces whose host names come from the
# platform's domain. These four are expanded in order, and SKIP_AUTH reads ENV.
ENV ?= local
SKIP_AUTH ?= $(if $(filter local,$(ENV)),true,false)
# info prints one line per API call carrying the request id, which is what
# correlates a tap on the device with a line in the service log. debug and
# verbose add bodies and headers.
LOG_LEVEL ?= info
UI_DEFINES := --dart-define=SKIP_AUTH=$(SKIP_AUTH) --dart-define=LOG_LEVEL=$(LOG_LEVEL)
MOBILE_DEFINES := $(UI_DEFINES) --dart-define-from-file=config/$(ENV).json
# A --dart-define beats the same key in the define file whichever order they
# arrive in, so this machine's address must be absent for a deployed backend.
ANDROID_API := $(if $(filter local,$(ENV)),--dart-define=API_BASE_URL=http://10.0.2.2:$(PORT))
IOS_API := $(if $(filter local,$(ENV)),--dart-define=API_BASE_URL=http://localhost:$(PORT))

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
CHARTS_REGISTRY ?= oci://$(REGISTRY)/charts
DIST_DIR := $(CURDIR)/dist

# One version names the whole repository, derived from the git tag. The
# Chart.yaml value is a placeholder that keeps `helm lint` quiet; the pipeline
# always overrides it, so nothing has to remember a hand bump.
VERSION ?= $(shell ./scripts/version.sh base)
CHART_VERSION = $(VERSION)

# A documented placeholder. The real hostname exists only at install time.
TEMPLATE_HOST := api-ahorro.lab.example.com

# Which platform target the app-of-apps chart renders for. local has no public
# hostname at all, so it is the one target that passes no fqdn.
TARGET ?= aws
GITOPS_FQDN = $(if $(filter local,$(TARGET)),,--set fqdn=example.invalid)

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

## Run the ahorro-api service locally on $PORT with auth disabled
go-run: export PORT := $(PORT)
go-run: export AUTH_DISABLED := $(AUTH_DISABLED)
go-run: export CORS_ALLOWED_ORIGINS := http://localhost:3000
go-run:
	go run ./cmd/ahorro-api

## Check the specs/ layout, front matter and links
specs-check:
	@./scripts/specs-check.sh

## Check no file and no new commit contains the root domain
domain-check:
	@./scripts/domain-guard.sh

## Apply branch protection, the labels and the release environment on GitHub
repo-settings:
	@./scripts/repo-settings.sh

## Print the version the next build publishes under
version:
	@echo $(VERSION)

## Print the platform project this repository targets
print-project:
	@echo $(PROJECT_NAME)

## Upgrade both releases in ahorro-dev. Usage: make deploy-dev VERSION=0.2.2-main.abc1234
deploy-dev:
	@./scripts/deploy-dev.sh $(VERSION)

## Deploy one pull request to ahorro-pr. Usage: make preview-up PR=42 VERSION=0.2.3-pr-42
preview-up:
	@./scripts/preview.sh up $(PR) $(VERSION)

## Remove one pull request from ahorro-pr. Usage: make preview-down PR=42
preview-down:
	@./scripts/preview.sh down $(PR)

## Print a preview's clickable URL, which CI never logs. Usage: make preview-url PR=42
preview-url:
	@./scripts/preview.sh url $(PR)

## Write a kubeconfig for the ahorro-dev deploy credential and print its path
kubeconfig:
	@./scripts/kubeconfig.sh

## Print the Cognito pool's public identifiers as JSON
cognito-config:
	@./scripts/cognito.sh config

## Print a one-hour Cognito id token for the test user
token:
	@./scripts/cognito.sh token

## Write both Flutter config files for $ENV from $PROJECT_NAME's Cognito pool
ui-config:
	@./scripts/ui-config.sh $(ENV)

## Create the multi-arch buildx builder if it is missing
buildx-init:
	@docker buildx inspect $(BUILDER) >/dev/null 2>&1 || docker buildx create --name $(BUILDER) --driver docker-container

## Fail unless SVC names an existing Dockerfile
require-svc:
	@test -n "$(SVC)" || { echo "set SVC=<service>, for example: make image-build SVC=ahorro-api" >&2; exit 1; }
	@test -f "$(DOCKERFILE)" || { echo "no $(DOCKERFILE)" >&2; exit 1; }

## Build one image for this machine only. Usage: make image-build SVC=ahorro-api
image-build: require-svc
	docker buildx build --load -f $(DOCKERFILE) -t $(IMAGE) .

## Build and push one multi-arch image. Usage: make image-push SVC=ahorro-api
image-push: require-svc buildx-init
	docker buildx build --builder $(BUILDER) --platform $(PLATFORMS) --provenance=false \
	  --push -f $(DOCKERFILE) -t $(IMAGE) .

## Build and push every image
images-push:
	@$(MAKE) image-push SVC=ahorro-api
	@$(MAKE) image-push SVC=ahorro-web

## Fail unless CHART names an existing chart
require-chart:
	@test -n "$(CHART)" || { echo "set CHART=<chart>, for example: make helm-template CHART=ahorro-api" >&2; exit 1; }
	@test -f "$(CHART_DIR)/Chart.yaml" || { echo "no $(CHART_DIR)/Chart.yaml" >&2; exit 1; }

# lint renders the templates, so the required values must be present or every
# chart fails on its own guard rather than on a real defect.
## Lint every chart
helm-lint:
	@for c in deploy/helm/*/; do \
	  helm lint "$$c" --set host=$(TEMPLATE_HOST) --set image.tag=$(IMAGE_TAG); \
	done

## Render one chart to stdout with a placeholder host. Usage: make helm-template CHART=ahorro-api
helm-template: require-chart
	@helm template $(CHART) $(CHART_DIR) \
	  --set host=$(TEMPLATE_HOST) --set image.tag=$(IMAGE_TAG)

## Package one chart into dist/. Usage: make helm-package CHART=ahorro-api VERSION=0.2.1-pr-42
helm-package: require-chart
	@mkdir -p $(DIST_DIR)
	helm package $(CHART_DIR) --version $(VERSION) --app-version $(IMAGE_TAG) --destination $(DIST_DIR)

## Push one packaged chart to GHCR. Usage: make helm-push CHART=ahorro-api
helm-push: helm-package
	helm push $(DIST_DIR)/$(CHART)-$(CHART_VERSION).tgz $(CHARTS_REGISTRY)

# A documented placeholder; the real fqdn exists only at install time.
## Lint the app-of-apps chart
gitops-lint:
	@helm lint gitops --set target=$(TARGET) $(GITOPS_FQDN)

## Render the app-of-apps chart to stdout. Usage: make gitops-template TARGET=local
gitops-template:
	@helm template ahorro gitops --set target=$(TARGET) $(GITOPS_FQDN)

## Render the app-of-apps chart and validate it with kubeconform
gitops-check:
	@./scripts/gitops-check.sh

## Forward both services to localhost. Only the local target needs it.
forward-up:
	@./scripts/forward.sh up

## Stop the forwards make forward-up started. Safe when nothing is up.
forward-down:
	@./scripts/forward.sh down

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

## Build a debug APK against $ENV
ui-build-android: ui-config
	cd $(UI_DIR) && flutter build apk --debug $(MOBILE_DEFINES) $(ANDROID_API)

## Start the Android emulator $AVD without waiting for it to boot
emulator-android:
	@$(CURDIR)/scripts/android-emulator.sh $(AVD) nowait

## Start the iOS simulator $IOS_DEVICE without waiting for it to boot
emulator-ios:
	@$(CURDIR)/scripts/ios-simulator.sh "$(IOS_DEVICE)" nowait

## Run the Flutter app on the Android emulator $AVD against $ENV
ui-run-android: ui-config
	@serial=$$($(CURDIR)/scripts/android-emulator.sh $(AVD)) && \
	  cd $(UI_DIR) && flutter run -d $$serial $(MOBILE_DEFINES) $(ANDROID_API)

## Run the Flutter app on the iOS simulator $IOS_DEVICE against $ENV
ui-run-ios: ui-config
	@$(CURDIR)/scripts/ios-simulator.sh "$(IOS_DEVICE)" && cd $(UI_DIR) && flutter run -d "$(IOS_DEVICE)" $(MOBILE_DEFINES) $(IOS_API)

# Port 3000 is the origin `make go-run` allows through CORS.
## Run in Chrome on :3000. SKIP_AUTH=false signs in against $PROJECT_NAME's pool
ui-run-web: ui-config
	cd $(UI_DIR) && flutter run -d chrome --web-port 3000 $(UI_DEFINES)

## Shut down every running Android emulator and iOS simulator
emulator-stop:
	@for s in $$(adb devices | awk '/^emulator-/ {print $$1}'); do adb -s $$s emu kill; done
	@xcrun simctl shutdown all
