#!/usr/bin/env bash
# Fails when a chart changed but its version did not. A pushed chart version is
# immutable in practice: Argo pins a targetRevision, so reusing a version makes
# two different charts answer to one reference.
set -uo pipefail
cd "$(dirname "$0")/.."

base="${1:-}"
if [ -z "$base" ]; then
  echo "CHART-VERSION: usage: $0 <base-ref>" >&2
  exit 1
fi

if ! git rev-parse --verify "$base^{commit}" >/dev/null 2>&1; then
  echo "CHART-VERSION: base ref $base is missing. Fetch the whole history." >&2
  exit 1
fi

fail=0
checked=0

for dir in deploy/helm/*/; do
  chart="${dir%/}"
  name=$(basename "$chart")

  if ! git diff --quiet "$base" -- "$chart"; then
    checked=$((checked + 1))
    head_version=$(sed -n 's/^version: *//p' "$chart/Chart.yaml")
    base_version=$(git show "$base:$chart/Chart.yaml" 2>/dev/null | sed -n 's/^version: *//p')

    if [ -z "$base_version" ]; then
      echo "CHART-VERSION: $name is new at $head_version."
      continue
    fi

    if [ "$head_version" = "$base_version" ]; then
      echo "CHART-VERSION: $name changed but version is still $head_version. Bump it." >&2
      fail=1
    else
      echo "CHART-VERSION: $name $base_version -> $head_version."
    fi
  fi
done

if [ "$fail" -ne 0 ]; then
  exit 1
fi

if [ "$checked" -eq 0 ]; then
  echo "CHART-VERSION: no chart changed."
else
  echo "CHART-VERSION: every changed chart has a new version."
fi
