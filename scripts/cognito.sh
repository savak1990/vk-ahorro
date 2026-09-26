#!/usr/bin/env bash
# Usage: cognito.sh config|token
#
# token emits the id token: an access token carries no email claim, and this
# pool holds a UUID in username, so the service would greet the user by it.
set -euo pipefail

# One region, a constant, never read from the environment.
REGION=eu-west-1
# Set by the Makefile, which owns the default.
: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"
PREFIX="/$PROJECT_NAME/persistent/ahorro-cognito"

# Only the token path reads the SecureString, so only it asks for decryption:
# the three public identifiers stay readable without kms:Decrypt.
DECRYPT=

param() {
  local value
  # A missing parameter must fail here, not surface later as a null in a config
  # file the Flutter build reads.
  if ! value="$(aws ssm get-parameter --region "$REGION" $DECRYPT \
    --name "$PREFIX/$1" --query Parameter.Value --output text 2>/dev/null)"; then
    echo "COGNITO: no SSM parameter $PREFIX/$1." >&2
    echo "COGNITO: PROJECT_NAME=$PROJECT_NAME. Has that project's persistent layer been applied?" >&2
    echo "COGNITO: for another project, run: PROJECT_NAME=<project> make $2" >&2
    exit 1
  fi
  printf '%s' "$value"
}

case "${1:-}" in
  config)
    # Assigned one at a time so set -e stops at the first missing parameter:
    # param's exit inside a command substitution would only end the subshell.
    pool_id="$(param user_pool_id cognito-config)"
    client_id="$(param client_id cognito-config)"
    issuer="$(param issuer cognito-config)"
    printf '{\n  "user_pool_id": "%s",\n  "client_id": "%s",\n  "issuer": "%s"\n}\n' \
      "$pool_id" "$client_id" "$issuer"
    ;;
  token)
    DECRYPT=--with-decryption
    pool_id="$(param user_pool_id token)"
    client_id="$(param client_id token)"
    email="$(param test_user_email token)"
    password="$(param test_user_password token)"

    # The password travels in a parameters file, never on the command line, so
    # it never appears in a process listing.
    auth="$(mktemp)"
    trap 'rm -f "$auth"' EXIT
    jq -n --arg u "$email" --arg p "$password" '{USERNAME:$u,PASSWORD:$p}' > "$auth"

    aws cognito-idp admin-initiate-auth --region "$REGION" \
      --user-pool-id "$pool_id" --client-id "$client_id" \
      --auth-flow ADMIN_USER_PASSWORD_AUTH \
      --auth-parameters "file://$auth" \
      --query AuthenticationResult.IdToken --output text
    ;;
  *)
    echo "Usage: $0 config|token" >&2
    exit 1
    ;;
esac
