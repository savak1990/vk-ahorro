#!/usr/bin/env bash
# Applies the repository settings this project depends on: branch protection,
# the labels two workflows trigger on, and the release Environment. A setting
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
echo '{"strict":false,"checks":[{"context":"ci-ok"}]}' |
  gh api -X PUT "repos/$REPO/branches/$BRANCH/protection/required_status_checks" \
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

# preview drives the pull-request preview workflow; the two release labels
# decide which mobile build a dispatch produces.
add_label() {
  gh label create "$1" --repo "$REPO" --color "$2" --description "$3" --force >/dev/null
  echo "REPO-SETTINGS: label $1"
}
add_label preview 0e8a16 "Deploy this pull request to the ahorro-pr namespace"
add_label release:android 5319e7 "Publish an Android build from the release dispatch"
add_label release:ios 5319e7 "Publish an iOS build from the release dispatch"

# The Environment holds the mobile signing secrets, which are added by hand
# once and named in the deploy specs. Creating it here is what makes
# `environment: release` in a workflow resolve at all.
gh api -X PUT "repos/$REPO/environments/release" --silent
echo "REPO-SETTINGS: release environment"

echo "REPO-SETTINGS: done."
