#!/usr/bin/env bash
# Fails when a tracked file contains the root domain (constitution 4).
# It reports file names only: this repository is public, so printing a
# matched line would publish the string the check exists to protect.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ -z "${ROOT_DOMAIN:-}" ]; then
  echo "DOMAIN-GUARD: ROOT_DOMAIN is not set. In CI, add the repository secret." >&2
  echo "DOMAIN-GUARD: locally, run: ROOT_DOMAIN=<domain> make domain-check" >&2
  exit 1
fi

hits="$(git ls-files -z | xargs -0 grep -lIiF -- "$ROOT_DOMAIN" 2>/dev/null)"

if [ -n "$hits" ]; then
  echo "DOMAIN-GUARD: the root domain appears in these files:" >&2
  echo "$hits" >&2
  exit 1
fi

echo "DOMAIN-GUARD: the root domain appears in no tracked file."
