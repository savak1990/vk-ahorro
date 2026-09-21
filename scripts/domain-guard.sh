#!/usr/bin/env bash
# Fails when the root domain appears in the working tree or in any commit
# made after the baseline (constitution 4). This repository is public, so the
# check reports file names and commit ids only: a matched line would publish
# the string the check exists to protect.
#
# The baseline is the last commit that still carried the value, from before
# this constitution was enforced. See ADR 0002.
set -uo pipefail
cd "$(dirname "$0")/.."

BASELINE_FILE=scripts/domain-guard-baseline

if [ -z "${ROOT_DOMAIN:-}" ]; then
  echo "DOMAIN-GUARD: ROOT_DOMAIN is not set. In CI, the repo job reads it from SSM." >&2
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

baseline="$(tr -d '[:space:]' < "$BASELINE_FILE")"
if ! git cat-file -e "$baseline^{commit}" 2>/dev/null; then
  echo "DOMAIN-GUARD: baseline commit $baseline is missing. Fetch the whole history." >&2
  exit 1
fi

# A walk that fails prints nothing, which would read as clean. Check it first.
if ! revs="$(git rev-list --all --not "$baseline")"; then
  echo "DOMAIN-GUARD: could not walk the history. Fetch the whole history." >&2
  exit 1
fi

history_hits="$(printf '%s\n' "$revs" | xargs -n 50 -r git grep -lIi -f "$pat" 2>/dev/null | sort -u)"
if [ -n "$history_hits" ]; then
  echo "DOMAIN-GUARD: the root domain is in a commit after the baseline, as <commit>:<path>:" >&2
  echo "$history_hits" | head -20 >&2
  echo "DOMAIN-GUARD: $(echo "$history_hits" | wc -l | tr -d ' ') match(es). Rewriting the branch is the only fix." >&2
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  exit 1
fi

echo "DOMAIN-GUARD: the root domain is in no tracked file and in no commit after the baseline."
