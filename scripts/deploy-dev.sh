#!/usr/bin/env bash
# Usage: deploy-dev.sh <version>
#
# Upgrades both releases in namespace ahorro-dev to one version. Every merge
# to main runs this, so the namespace always names one coherent build of main
# rather than a mixture.
#
# It never touches namespace ahorro. That one is Argo's, pinned to a released
# version, and the credential this uses is refused there by cluster RBAC.
set -euo pipefail

REGION=eu-west-1
: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"

NAMESPACE=ahorro-dev
API_HOST_LABEL=api-ahorro-dev
WEB_HOST_LABEL=ahorro-dev
# `make ui-run-web ENV=dev` serves the client from here, so the API must name
# it or the browser throws the answer away. The port matches --web-port in the
# Makefile. Safe because this API reads a bearer token and sets no
# Access-Control-Allow-Credentials, so no credential travels on its own.
LOCAL_WEB_ORIGIN=http://localhost:3000
CHARTS="oci://ghcr.io/savak1990/vk-ahorro/charts"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "DEPLOY-DEV: usage: deploy-dev.sh <version>, for example 0.2.2-main.abc1234" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The path is passed in rather than read back from stdout. kubeconfig.sh also
# writes `::add-mask::` there, and a command substitution would capture that
# directive into the path instead of letting the runner act on it.
KUBECONFIG="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ahorro-deploy.kubeconfig"
export KUBECONFIG

# Exit 2 means the cluster is not reachable, which is a normal state for a lab
# that is torn down when unused. The caller decides whether that is a skip or
# a failure; this script just passes it through.
set +e
"$REPO_ROOT/scripts/kubeconfig.sh" "$KUBECONFIG"
status=$?
set -e
[ "$status" -eq 0 ] || exit "$status"

ssm() {
  local name="$1"
  local value
  if ! value="$(aws ssm get-parameter --region "$REGION" \
    --name "$name" --query Parameter.Value --output text 2>/dev/null)"; then
    echo "DEPLOY-DEV: no SSM parameter $name." >&2
    echo "DEPLOY-DEV: PROJECT_NAME=$PROJECT_NAME. Has that project's persistent layer been applied?" >&2
    exit 1
  fi
  printf '%s' "$value"
}

# The domain is published beside the deploy credential: this role cannot read
# the bootstrap parameter it comes from. Never echoed.
fqdn="$(ssm "/$PROJECT_NAME/cluster/ahorro-deploy/fqdn")"
cognito="/$PROJECT_NAME/persistent/ahorro-cognito"
issuer="$(ssm "$cognito/issuer")"
client_id="$(ssm "$cognito/client_id")"
user_pool_id="$(ssm "$cognito/user_pool_id")"
cognito_region="$(ssm "$cognito/region")"

api_host="$API_HOST_LABEL.$fqdn"
web_host="$WEB_HOST_LABEL.$fqdn"

echo "DEPLOY-DEV: upgrading $NAMESPACE to $VERSION."

# --rollback-on-failure (--atomic before Helm 4.3) restores the previous
# release rather than leaving the namespace half updated.
helm upgrade --install ahorro-api "$CHARTS/ahorro-api" \
  --version "$VERSION" \
  --namespace "$NAMESPACE" \
  --rollback-on-failure --timeout 5m \
  --set image.tag="$VERSION" \
  --set host="$api_host" \
  --set corsAllowedOrigins="https://$web_host,$LOCAL_WEB_ORIGIN" \
  --set cognito.issuer="$issuer" \
  --set cognito.clientId="$client_id"

helm upgrade --install ahorro-web "$CHARTS/ahorro-web" \
  --version "$VERSION" \
  --namespace "$NAMESPACE" \
  --rollback-on-failure --timeout 5m \
  --set image.tag="$VERSION" \
  --set host="$web_host" \
  --set config.apiBaseUrl="https://$api_host" \
  --set config.cognitoUserPoolId="$user_pool_id" \
  --set config.cognitoClientId="$client_id" \
  --set config.cognitoRegion="$cognito_region"

# Short names only. A full hostname embeds the lab domain, which is never
# written to a log.
echo "DEPLOY-DEV: $NAMESPACE is at $VERSION, on $WEB_HOST_LABEL and $API_HOST_LABEL."
