# The Flutter web build is architecture-independent output, so the build stage
# runs natively on the builder and only the nginx stage is cross-built.
FROM --platform=$BUILDPLATFORM ghcr.io/cirruslabs/flutter:3.44.0@sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8 AS build

WORKDIR /app

# pubspec first: the dependency layer is cached until the manifest changes,
# which is what keeps a source-only edit off the five-minute path.
COPY flutter-ui/pubspec.yaml flutter-ui/pubspec.lock ./
RUN flutter pub get

COPY flutter-ui/ ./

# --no-web-resources-cdn self-hosts CanvasKit rather than loading it from
# gstatic.com: no third-party runtime dependency, and a deterministic build.
RUN flutter build web --release --no-web-resources-cdn

FROM nginxinc/nginx-unprivileged:1.29-alpine@sha256:0c79d56aee561a1d81c63f00eee5fb5fe29279560cdc55e91425133104c7fbe6

LABEL org.opencontainers.image.source="https://github.com/savak1990/vk-ahorro"

COPY deploy/docker/ahorro-web.nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

# Already the image's own user; stated so a base change cannot silently
# promote this to root.
USER 101

EXPOSE 8080
