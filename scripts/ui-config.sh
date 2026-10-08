#!/usr/bin/env bash
# Usage: ui-config.sh [local|dev|prod|pr-<n>]
#
# Writes the two configuration files the Flutter client reads. They carry the
# same values under different key names, because the platforms read them
# differently:
#
#   flutter-ui/web/config.json    fetched over HTTP at startup, camelCase
#   flutter-ui/config/<env>.json  --dart-define-from-file, define names
#
# Neither is committed: there is one Cognito pool per platform project, so a
# committed copy is right for one project and wrong for every other.
#
# Without AWS access it writes blank Cognito keys instead of failing, so the
# shell still runs offline - the app then reports that no pool is configured.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"

REGION=eu-west-1
ENV="${1:-local}"

WEB_TARGET=flutter-ui/web/config.json
DEFINES_TARGET="flutter-ui/config/$ENV.json"

ssm() {
  aws ssm get-parameter --region "$REGION" \
    --name "$1" --query Parameter.Value --output text 2>/dev/null
}

# The host label, and nothing else, comes from ENV, and it steers both files:
# the browser and the device talk to the same backend. local is the one target
# with no public hostname: the dev server and the emulators reach a local
# `make go-run`, and the Makefile names the host per platform.
case "$ENV" in
  local) api_label="" ;;
  dev)   api_label="api-ahorro-dev" ;;
  prod)  api_label="api-ahorro" ;;
  pr-*)  api_label="api-ahorro-$ENV" ;;
  *)
    echo "UI-CONFIG: ENV=$ENV is not a backend." >&2
    echo "UI-CONFIG: use local, dev, prod or pr-<number>." >&2
    exit 1
    ;;
esac

if [ -z "$api_label" ]; then
  api_base="http://localhost:8080"
else
  # The domain is published beside the disposable deploy credential, so `make
  # down` takes it away. FQDN= regenerates a config with the lab off. The
  # assignment is its own statement so set -e sees a failed read; inside a
  # command substitution an exit would only end the subshell. Never echoed.
  fqdn="${FQDN:-}"
  if [ -z "$fqdn" ] && ! fqdn="$(ssm "/$PROJECT_NAME/cluster/ahorro-deploy/fqdn")"; then
    echo "UI-CONFIG: no domain published for $PROJECT_NAME." >&2
    echo "UI-CONFIG: run make up in vk-lab-platform, or pass FQDN=<fqdn>." >&2
    exit 1
  fi
  api_base="https://$api_label.$fqdn"
fi

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
  --arg api "$api_base" \
  --arg pool "$pool" \
  --arg client "$client" \
  --arg region "${region:-$REGION}" \
  '{
     apiBaseUrl: $api,
     cognitoUserPoolId: $pool,
     cognitoClientId: $client,
     cognitoRegion: $region,
     authDisabled: false,
     devUserEmail: "",
     devUserSub: ""
   }' > "$WEB_TARGET"

mkdir -p flutter-ui/config
jq -n \
  --arg api "$api_base" \
  --arg pool "$pool" \
  --arg client "$client" \
  --arg region "${region:-$REGION}" \
  '{
     API_BASE_URL: $api,
     COGNITO_USER_POOL_ID: $pool,
     COGNITO_CLIENT_ID: $client,
     COGNITO_REGION: $region
   }' > "$DEFINES_TARGET"

# The two files carry the same values under different names. A key missing
# here becomes an empty define inside an APK, which the app reports as an
# unconfigured pool hours later.
jq -e 'has("API_BASE_URL") and has("COGNITO_USER_POOL_ID")
       and has("COGNITO_CLIENT_ID") and has("COGNITO_REGION")' \
  "$DEFINES_TARGET" > /dev/null

echo "UI-CONFIG: wrote $WEB_TARGET and $DEFINES_TARGET for ENV=$ENV."
