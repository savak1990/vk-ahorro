#!/usr/bin/env bash
# Usage: preview.sh up <pr> <version>
#        preview.sh down <pr>
#
# Deploys one pull request into the shared ahorro-pr namespace, on its own
# hostname, against the real user pool. Many previews coexist there: the
# release names carry the pull request number, and the chart derives every
# object name from the release.
#
# It never touches namespace ahorro or ahorro-dev. The credential it uses is
# refused in ahorro by cluster RBAC.
set -euo pipefail

REGION=eu-west-1
: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"

NAMESPACE=ahorro-pr
CHARTS="oci://ghcr.io/savak1990/vk-ahorro/charts"

ACTION="${1:-}"
PR="${2:-}"

case "$ACTION" in
  up|down) ;;
  *) echo "PREVIEW: usage: preview.sh up <pr> <version> | preview.sh down <pr>" >&2; exit 1 ;;
esac

# A pull request number, not a branch name: it is the only identifier that is
# short, unique and legal in both a DNS label and a Helm release name.
case "$PR" in
  ''|*[!0-9]*) echo "PREVIEW: <pr> must be a pull request number, not '$PR'." >&2; exit 1 ;;
esac

# svc.fullname is "<release>-<chart>" unless the release equals the chart name,
# so these render as pr-42-api-ahorro-api. Keeping the number first means every
# object for one pull request sorts together.
API_RELEASE="pr-$PR-api"
WEB_RELEASE="pr-$PR-web"
# One DNS label below the domain. The wildcard certificate and the external-dns
# domain filter are both a single label deep, so ahorro-pr-42.<fqdn> gets TLS
# and a record while pr-42.ahorro.<fqdn> would get neither.
API_HOST_LABEL="api-ahorro-pr-$PR"
WEB_HOST_LABEL="ahorro-pr-$PR"

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

if [ "$ACTION" = down ]; then
  # --ignore-not-found, because unlabelling can arrive for a pull request that
  # was never deployed, and that must succeed rather than fail the workflow.
  #
  # The namespace is deliberately left in place: Argo owns it at sync wave 1,
  # this credential is denied namespace deletion, and Argo would recreate it.
  # external-dns runs with policy=sync, so the DNS records go with the routes.
  helm uninstall "$API_RELEASE" --namespace "$NAMESPACE" --ignore-not-found --wait
  helm uninstall "$WEB_RELEASE" --namespace "$NAMESPACE" --ignore-not-found --wait
  echo "PREVIEW: pull request $PR is removed from $NAMESPACE."
  exit 0
fi

VERSION="${3:-}"
if [ -z "$VERSION" ]; then
  echo "PREVIEW: usage: preview.sh up <pr> <version>, for example: preview.sh up 42 0.2.3-pr-42" >&2
  exit 1
fi

ssm() {
  local name="$1"
  local value
  if ! value="$(aws ssm get-parameter --region "$REGION" \
    --name "$name" --query Parameter.Value --output text 2>/dev/null)"; then
    echo "PREVIEW: no SSM parameter $name." >&2
    echo "PREVIEW: PROJECT_NAME=$PROJECT_NAME. Has that project's persistent layer been applied?" >&2
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

echo "PREVIEW: deploying pull request $PR to $NAMESPACE at $VERSION."

# --rollback-on-failure (--atomic before Helm 4.3) restores the previous
# release rather than leaving the namespace half updated.
helm upgrade --install "$API_RELEASE" "$CHARTS/ahorro-api" \
  --version "$VERSION" \
  --namespace "$NAMESPACE" \
  --rollback-on-failure --timeout 5m \
  --set image.tag="$VERSION" \
  --set host="$api_host" \
  --set corsAllowedOrigins="https://$web_host" \
  --set cognito.issuer="$issuer" \
  --set cognito.clientId="$client_id"

helm upgrade --install "$WEB_RELEASE" "$CHARTS/ahorro-web" \
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
echo "PREVIEW: pull request $PR is at $VERSION, on $WEB_HOST_LABEL and $API_HOST_LABEL."
