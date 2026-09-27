#!/usr/bin/env bash
# Writes flutter-ui/web/config.json, which the Chrome dev server reads at
# startup. Generated, never committed: there is one Cognito pool per platform
# project, so the values are resolved from SSM for $PROJECT_NAME every time.
#
# Without AWS access it writes blank Cognito keys instead of failing, so the
# shell still runs offline - the app then reports that no pool is configured.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"

TARGET=flutter-ui/web/config.json
# The API a local `make go-run` serves, not the cluster's: this file is read
# only by the dev server.
API_BASE_URL="${API_BASE_URL:-http://localhost:8080}"

pool=""
client=""
# Only meaningful beside a pool, so it follows the same source rather than
# being a constant here; cognito.sh falls back when the parameter is absent.
region=""
if config="$(./scripts/cognito.sh config 2>/dev/null)"; then
  pool="$(jq -r .user_pool_id <<<"$config")"
  client="$(jq -r .client_id <<<"$config")"
  region="$(jq -r '.region // ""' <<<"$config")"
  echo "UI-CONFIG: using the $PROJECT_NAME pool in ${region:-an unpublished region}."
else
  echo "UI-CONFIG: no Cognito parameters for $PROJECT_NAME - writing blank keys." >&2
  echo "UI-CONFIG: sign-in will report that no pool is configured." >&2
fi

jq -n \
  --arg api "$API_BASE_URL" \
  --arg pool "$pool" \
  --arg client "$client" \
  --arg region "${region:-eu-west-1}" \
  '{
     apiBaseUrl: $api,
     cognitoUserPoolId: $pool,
     cognitoClientId: $client,
     cognitoRegion: $region,
     authDisabled: false,
     devUserEmail: "",
     devUserSub: ""
   }' > "$TARGET"

echo "UI-CONFIG: wrote $TARGET"
