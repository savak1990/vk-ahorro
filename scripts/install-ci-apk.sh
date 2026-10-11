#!/usr/bin/env bash
# Usage: install-ci-apk.sh <env> <device>
#
# Downloads the newest APK that CI built for <env> and installs it on <device>.
# Nothing is compiled here: this is the artifact a merge or a release already
# produced, signed with the upload key and pointed at a real backend.
set -euo pipefail

env="${1:-}"
device="${2:-}"
[ -n "$env" ] || { echo "INSTALL-CI: usage: install-ci-apk.sh <env> <device>" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! gh auth status >/dev/null 2>&1; then
  echo "INSTALL-CI: gh is not logged in. Run gh auth login." >&2
  exit 1
fi

serial="$("$REPO_ROOT/scripts/android-emulator.sh" "$device")"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# No run id: gh takes the newest artifact matching the pattern, which is the
# newest build for this backend across every channel.
echo "INSTALL-CI: looking for the newest ahorro-android-$env-* artifact."
if ! gh run download --pattern "ahorro-android-$env-*" --dir "$tmp" 2>/dev/null; then
  echo "INSTALL-CI: no artifact for $env. A dev build comes from a merge that" >&2
  echo "INSTALL-CI: touched the flutter filter; a prod build comes from a release." >&2
  echo "INSTALL-CI: artifacts also expire - 30 days for dev, 90 for prod." >&2
  exit 1
fi

apk="$(find "$tmp" -name app-release.apk -print -quit)"
[ -n "$apk" ] || { echo "INSTALL-CI: the artifact holds no app-release.apk." >&2; exit 1; }

# The top-level directory is named after the version, and it is the only place
# the build's identity survives the download. Not the APK's own parent: the
# artifact keeps the build tree, so that one is flutter-apk.
dir="$(find "$tmp" -maxdepth 1 -type d -name "ahorro-android-$env-*" -print -quit)"
version="$(basename "$dir" | sed "s/^ahorro-android-$env-//")"
echo "INSTALL-CI: installing $version on $serial."

if ! adb -s "$serial" install -r "$apk"; then
  echo "INSTALL-CI: if this says the signatures do not match, the app on the" >&2
  echo "INSTALL-CI: device was signed with a different key. Run:" >&2
  echo "INSTALL-CI:   make ui-uninstall-android DEVICE=$serial" >&2
  exit 1
fi

echo "INSTALL-CI: $version is on $serial, built against $env."
