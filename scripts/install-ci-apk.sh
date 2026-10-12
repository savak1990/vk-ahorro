#!/usr/bin/env bash
# Usage: install-ci-apk.sh list [env]
#        install-ci-apk.sh install <env> <device> [version]
#
# Installs an APK that CI already built. Nothing is compiled here: the artifact
# comes from a merge (dev) or a release (prod), signed with the upload key and
# pointed at a real backend.
#
# With no version, the newest artifact for that backend wins. With one, that
# exact build is installed, which is how an older or a specific release is
# reached.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! gh auth status >/dev/null 2>&1; then
  echo "INSTALL-CI: gh is not logged in. Run gh auth login." >&2
  exit 1
fi

repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"

# Every page, because one page is the newest 100 artifacts of any kind and the
# pull-request builds push the mobile ones off it. Expired ones are still
# listed by the API, so the filter keeps this to what can be downloaded.
artifacts() {
  gh api --paginate "repos/$repo/actions/artifacts?per_page=100" \
    --jq ".artifacts[]
          | select(.name | startswith(\"ahorro-android-${1:+$1-}\"))
          | select(.expired == false)
          | \"\(.created_at) \(.name)\"" |
    sort -r | awk '!seen[$2]++'
}

list_artifacts() {
  artifacts "${1:-}" | awk 'NR <= 20 { printf "  %s   built %s\n", $2, substr($1, 1, 10) }'
}

case "${1:-}" in
  list)
    echo "INSTALL-CI: the newest ${2:+$2 }artifacts you can install today, 20 at most:"
    list_artifacts "${2:-}"
    echo
    echo "INSTALL-CI: make ui-install-ci ENV=<dev|prod> [VERSION=<the part after the env>]"
    exit 0
    ;;
  install) ;;
  *) echo "INSTALL-CI: usage: install-ci-apk.sh list [env] | install <env> <device> [version]" >&2; exit 1 ;;
esac

env="${2:-}"
device="${3:-}"
version="${4:-}"
[ -n "$env" ] || { echo "INSTALL-CI: install needs an env." >&2; exit 1; }

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Resolve a single artifact name first, then download that one.
#
# Not `gh run download --pattern`: it keeps the newest run *per name*, and
# every version is its own name, so a pattern pulls down every build that has
# not expired and leaves the choice to whatever `find` happens to hit. Asking
# the API which is newest is the only way to mean "newest".
if [ -n "$version" ]; then
  name="ahorro-android-$env-$version"
else
  echo "INSTALL-CI: finding the newest $env build."
  name="$(artifacts "$env" | awk 'NR == 1 { print $2 }')"
fi

if [ -n "$name" ]; then
  echo "INSTALL-CI: downloading $name."
  gh run download --name "$name" --dir "$tmp" >/dev/null 2>&1 || name=""
fi

if [ -z "$name" ]; then
  echo "INSTALL-CI: no such artifact. A dev build comes from a merge; a prod" >&2
  echo "INSTALL-CI: build comes from a release. They expire after 30 and 90 days." >&2
  echo >&2
  echo "INSTALL-CI: available now for $env:" >&2
  list_artifacts "$env" >&2
  exit 1
fi

# A glob rather than a literal, so this reads both layouts: artifacts built
# before the files were named carry app-release.apk in a build tree, newer
# ones carry ahorro-<env>-<version>.apk at the top. The older shape stops
# appearing once every artifact predating the rename has expired.
apk="$(find "$tmp" -name '*.apk' -print -quit)"
[ -n "$apk" ] || { echo "INSTALL-CI: the artifact holds no APK." >&2; exit 1; }

# A single --name extracts into the root with no artifact directory, so the
# name resolved above is the only record of which build this is.
got="${name#"ahorro-android-$env-"}"

serial="$("$REPO_ROOT/scripts/android-emulator.sh" "$device")"
echo "INSTALL-CI: installing $got on $serial, built against $env."

if ! adb -s "$serial" install --user 0 -r "$apk"; then
  echo >&2
  echo "INSTALL-CI: signatures do not match -> the app on the device was signed" >&2
  echo "INSTALL-CI: with a different key:  make ui-uninstall-android DEVICE=$serial" >&2
  echo "INSTALL-CI: version downgrade     -> the device holds a build from a later" >&2
  echo "INSTALL-CI: commit. Uninstall, or install the newer one instead." >&2
  exit 1
fi

echo "INSTALL-CI: $got is on $serial, built against $env."
