# The builder runs native and cross-compiles, so no emulator is needed for
# the arm64 image on an amd64 runner.
FROM --platform=$BUILDPLATFORM golang:1.26 AS build
WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY cmd ./cmd
COPY internal ./internal

ARG TARGETARCH
RUN CGO_ENABLED=0 GOOS=linux GOARCH=$TARGETARCH \
    go build -trimpath -ldflags="-s -w" -o /hello ./cmd/hello

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /hello /hello
EXPOSE 8080
ENTRYPOINT ["/hello"]
