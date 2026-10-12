#!/usr/bin/env bash
# Applies the repository settings this project depends on: branch protection,
# the Environments the workflows name, and no ci labels. A setting
# clicked in the web UI is not reproducible; this is.
#
# Idempotent. Run it as often as you like.
set -euo pipefail

REPO="${REPO:-savak1990/vk-ahorro}"
BRANCH="${BRANCH:-main}"

command -v gh >/dev/null || { echo "REPO-SETTINGS: gh is not installed." >&2; exit 1; }

echo "REPO-SETTINGS: applying to $REPO"

# One required check, not a list of job names. A renamed job used to leave
# branch protection waiting on a context that never reported again.
#
# The sub-resource, never PUT .../protection: the parent endpoint replaces the
# whole object, so a partial body silently drops enforce_admins, linear
# history and the force-push ban.
#
# strict stays false: with one developer, forcing every branch up to date
# before merge only re-runs CI for no new information.
# PATCH, not PUT: PUT exists only on the parent .../protection and answers 404
# here, which reads like a missing branch rather than a wrong method.
echo '{"strict":false,"checks":[{"context":"ci-ok"}]}' |
  gh api -X PATCH "repos/$REPO/branches/$BRANCH/protection/required_status_checks" \
    --input - --silent
echo "REPO-SETTINGS: required status check is ci-ok"

gh api -X POST "repos/$REPO/branches/$BRANCH/protection/enforce_admins" --silent
echo "REPO-SETTINGS: enforce_admins on"

# Linear history, no force push and no deletion have no sub-resource of their
# own, so they are read back rather than written. Failing loudly beats a PUT
# that would clear what it does not mention.
protection="$(gh api "repos/$REPO/branches/$BRANCH/protection")"
for field in required_linear_history:true allow_force_pushes:false allow_deletions:false; do
  key="${field%%:*}"
  want="${field##*:}"
  got="$(printf '%s' "$protection" | jq -r ".${key}.enabled")"
  if [ "$got" != "$want" ]; then
    echo "REPO-SETTINGS: $key is $got, expected $want - fix it in the branch protection UI." >&2
    exit 1
  fi
done
echo "REPO-SETTINGS: linear history on, force push and deletion off"

# Squash is the only merge method and the branch goes on merge, so the history
# stays linear without anyone remembering to make it so.
gh api -X PATCH "repos/$REPO" \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F delete_branch_on_merge=true \
  --silent
echo "REPO-SETTINGS: squash-only, branch deleted on merge"

for label in ci:preview-web ci:release-android ci:release-ios; do
  gh label delete "$label" --repo "$REPO" --yes >/dev/null 2>&1 || true
done
echo "REPO-SETTINGS: no ci labels; nothing triggers on one"

# No secret and no gate: the preview workflow names it so a pull request page
# shows its branch as deployed.
gh api -X PUT "repos/$REPO/environments/preview" --silent
echo "REPO-SETTINGS: preview environment"

# Both Environments hold the same four signing secrets, published by
# `make android-keystore`. Creating them here is what makes `environment:` in
# a workflow resolve at all.
#
# They are separate because `release` publishes to a store and is where a
# reviewer gate belongs, while `mobile-dev` runs on every merge - a gate there
# would stall main. The key is the same, so a phone never needs an uninstall
# between a merge build and a release build.
for env in release mobile-dev; do
  gh api -X PUT "repos/$REPO/environments/$env" --silent
  echo "REPO-SETTINGS: $env environment"
done

echo "REPO-SETTINGS: done."
