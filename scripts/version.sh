#!/usr/bin/env bash
# Prints the version this build publishes under. One number names the whole
# repository on every channel, and the image tag equals the chart version.
#
#   version.sh main <sha>      0.2.1-main.a1b2c3d
#   version.sh pr <number> <sha>  0.2.1-pr-42.a1b2c3d
#   version.sh release <level> 0.2.1 | 0.3.0 | 1.0.0   (patch|minor|major)
#   version.sh base            0.2.1
#
# No channel ever emits `+build` metadata: Helm rewrites `+` to `_` because
# `+` is illegal in an OCI tag, and the result is no longer valid semver.
set -euo pipefail

channel="${1:-}"
arg="${2:-}"
sha="${3:-}"

last="$(git describe --tags --abbrev=0 2>/dev/null || true)"
last="${last#v}"
if [ -z "$last" ]; then
  echo "VERSION: no git tag found. Seed one with 'git tag v0.2.0' - the" >&2
  echo "VERSION: published charts already reach 0.2.0, so a lower base would" >&2
  echo "VERSION: publish behind them." >&2
  exit 1
fi

case "$last" in
  [0-9]*.[0-9]*.[0-9]*) ;;
  *) echo "VERSION: latest tag '$last' is not a semver triple." >&2; exit 1 ;;
esac

major="${last%%.*}"
rest="${last#*.}"
minor="${rest%%.*}"
patch="${rest#*.}"
patch="${patch%%-*}"

bump() {
  case "$1" in
    patch) echo "$major.$minor.$((patch + 1))" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    major) echo "$((major + 1)).0.0" ;;
    *) echo "VERSION: bump level must be patch, minor or major, not '$1'." >&2; exit 1 ;;
  esac
}

# A prerelease sorts below its release, so a build made after 0.2.0 must not be
# called 0.2.0-main.<sha> - it would claim to predate the release it followed.
base="$(bump patch)"

case "$channel" in
  base)
    echo "$base"
    ;;
  main)
    [ -n "$arg" ] || { echo "VERSION: main needs a commit sha." >&2; exit 1; }
    echo "$base-main.${arg:0:7}"
    ;;
  pr)
    [ -n "$arg" ] || { echo "VERSION: pr needs a pull request number." >&2; exit 1; }
    # The commit is part of the version, not decoration. Without it a second
    # push to the same pull request republishes the same tag, the rendered
    # Deployment is byte-identical, no new ReplicaSet is created, and the
    # preview keeps serving the previous build while the run reports success.
    [ -n "$sha" ] || { echo "VERSION: pr needs a commit sha." >&2; exit 1; }
    echo "$base-pr-$arg.${sha:0:7}"
    ;;
  release)
    bump "${arg:-patch}"
    ;;
  *)
    echo "VERSION: usage: version.sh {base|main <sha>|pr <n> <sha>|release <level>}" >&2
    exit 1
    ;;
esac
