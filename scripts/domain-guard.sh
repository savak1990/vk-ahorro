#!/usr/bin/env bash
# Fails when the root domain appears in the working tree or anywhere in the
# history (constitution 4). This repository is public, so the check reports
# file names and commit ids only: a matched line would publish the string the
# check exists to protect.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ -z "${ROOT_DOMAIN:-}" ]; then
  echo "DOMAIN-GUARD: ROOT_DOMAIN is not set. In CI, add the repository secret." >&2
  echo "DOMAIN-GUARD: locally, run: ROOT_DOMAIN=<domain> make domain-check" >&2
  exit 1
fi

# The pattern travels in a file, never on a command line, so it never shows up
# in a process listing.
pat="$(mktemp)"
trap 'rm -f "$pat"' EXIT
printf '%s\n' "$ROOT_DOMAIN" > "$pat"

fail=0

tree_hits="$(git grep -lIi -f "$pat" -- 2>/dev/null | sort -u)"
if [ -n "$tree_hits" ]; then
  echo "DOMAIN-GUARD: the root domain is in the working tree:" >&2
  echo "$tree_hits" >&2
  fail=1
fi

history_hits="$(git rev-list --all | xargs -n 50 git grep -lIi -f "$pat" 2>/dev/null | sort -u)"
if [ -n "$history_hits" ]; then
  echo "DOMAIN-GUARD: the root domain is in the history, as <commit>:<path>:" >&2
  echo "$history_hits" | head -20 >&2
  echo "DOMAIN-GUARD: $(echo "$history_hits" | wc -l | tr -d ' ') match(es). Rewriting history is the only fix." >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "DOMAIN-GUARD: the root domain appears in no tracked file and in no commit."
