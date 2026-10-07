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
CHARTS="oci://ghcr.io/savak1990/vk-ahorro/charts"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "DEPLOY-DEV: usage: deploy-dev.sh <version>, for example 0.2.2-main.abc1234" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Exit 2 from kubeconfig.sh means the cluster is not reachable, which is a
# normal state for a lab that is torn down when unused. The caller decides
# whether that is a skip or a failure; this script just passes it through.
set +e
KUBECONFIG_PATH="$("$REPO_ROOT/scripts/kubeconfig.sh")"
status=$?
set -e
[ "$status" -eq 0 ] || exit "$status"
export KUBECONFIG="$KUBECONFIG_PATH"

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

# --atomic rolls back a failed upgrade rather than leaving the namespace half
# updated; --wait alone would leave the broken release in place.
helm upgrade --install ahorro-api "$CHARTS/ahorro-api" \
  --version "$VERSION" \
  --namespace "$NAMESPACE" \
  --atomic --timeout 5m \
  --set image.tag="$VERSION" \
  --set host="$api_host" \
  --set corsAllowedOrigins="https://$web_host" \
  --set cognito.issuer="$issuer" \
  --set cognito.clientId="$client_id"

helm upgrade --install ahorro-web "$CHARTS/ahorro-web" \
  --version "$VERSION" \
  --namespace "$NAMESPACE" \
  --atomic --timeout 5m \
  --set image.tag="$VERSION" \
  --set host="$web_host" \
  --set config.apiBaseUrl="https://$api_host" \
  --set config.cognitoUserPoolId="$user_pool_id" \
  --set config.cognitoClientId="$client_id" \
  --set config.cognitoRegion="$cognito_region"

# Short names only. A full hostname embeds the lab domain, which is never
# written to a log.
echo "DEPLOY-DEV: $NAMESPACE is at $VERSION, on $WEB_HOST_LABEL and $API_HOST_LABEL."
