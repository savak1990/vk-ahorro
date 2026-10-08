# Both bases are pinned by digest as well as tag: a tag moves, a digest does
# not, and Dependabot raises a pull request when a new digest appears.

# The builder runs native and cross-compiles, so no emulator is needed for
# the arm64 image on an amd64 runner.
FROM --platform=$BUILDPLATFORM golang:1.27@sha256:3680233e3204827fbdc66088528ae6d4b3d034f51d03a99d454f6de034888244 AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /ahorro-api ./cmd/ahorro-api

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

# GHCR uses this label to link the package to the repository.
LABEL org.opencontainers.image.source="https://github.com/savak1990/vk-ahorro"

COPY --from=build /ahorro-api /ahorro-api
# Numeric, so a Kubernetes runAsNonRoot check can verify it without a lookup.
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/ahorro-api"]
