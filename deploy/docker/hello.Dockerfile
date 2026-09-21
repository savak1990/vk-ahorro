# Both bases are pinned by digest as well as tag: a tag moves, a digest does
# not, and Dependabot raises a pull request when a new digest appears.

# The builder runs native and cross-compiles, so no emulator is needed for
# the arm64 image on an amd64 runner.
FROM --platform=$BUILDPLATFORM golang:1.26@sha256:6c2a5538f964f1c82f97ad14988bf05de100d922d159d0e398b54c7b0ca0c6c9 AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /hello ./cmd/hello

FROM gcr.io/distroless/static-debian12:nonroot@sha256:afa5c872c891853ca7fcf1f12c3edb23f7eeef36189728842dd51042ff57f7ab

# GHCR uses this label to link the package to the repository.
LABEL org.opencontainers.image.source="https://github.com/savak1990/vk-ahorro"

COPY --from=build /hello /hello
# Numeric, so a Kubernetes runAsNonRoot check can verify it without a lookup.
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/hello"]
