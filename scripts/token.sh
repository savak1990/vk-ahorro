#!/usr/bin/env bash
# Prints one Cognito id token for the end-to-end test user, and nothing else.
#
# The id token, not the access token: a Cognito access token carries no email
# claim, and this pool uses email as the username attribute, so username holds
# a UUID and the service would greet the user by it.
set -euo pipefail

# One region, a constant (constitution 7).
REGION=eu-west-1
PROJECT_NAME="${PROJECT_NAME:-vk-lab-platform}"
PREFIX="/$PROJECT_NAME/persistent/ahorro-cognito"

param() {
  if ! aws ssm get-parameter --region "$REGION" --with-decryption \
    --name "$PREFIX/$1" --query Parameter.Value --output text 2>/dev/null; then
    echo "TOKEN: no SSM parameter $PREFIX/$1." >&2
    echo "TOKEN: has vk-lab-platform's persistent layer been applied for PROJECT_NAME=$PROJECT_NAME?" >&2
    exit 1
  fi
}

pool_id="$(param user_pool_id)"
client_id="$(param client_id)"
email="$(param test_user_email)"
password="$(param test_user_password)"

# The password travels in a parameters file, never on the command line, so it
# never appears in a process listing.
auth="$(mktemp)"
trap 'rm -f "$auth"' EXIT
printf '{"USERNAME":"%s","PASSWORD":"%s"}' "$email" "$password" > "$auth"

aws cognito-idp admin-initiate-auth --region "$REGION" \
  --user-pool-id "$pool_id" --client-id "$client_id" \
  --auth-flow ADMIN_USER_PASSWORD_AUTH \
  --auth-parameters "file://$auth" \
  --query AuthenticationResult.IdToken --output text
