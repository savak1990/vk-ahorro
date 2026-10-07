#!/usr/bin/env bash
# Usage: kubeconfig.sh [path]
#
# Builds a kubeconfig from the deploy credential the platform republishes on
# every bring-up, and prints the path it wrote. The cluster is disposable: a
# new one mints a new CA and new tokens, so a kubeconfig stored anywhere
# durable is wrong by the next `make up`. SSM is the one place both sides
# already reach.
#
# Exit 2 means the cluster is not reachable, which is a normal state for a lab
# that is torn down when unused. Any other non-zero exit is a real failure.
set -euo pipefail

REGION=eu-west-1
: "${PROJECT_NAME:?run this through make, which exports PROJECT_NAME}"
PREFIX="/$PROJECT_NAME/cluster/ahorro-deploy"

UNREACHABLE=2

# Never the workspace: a file there can be swept up by an upload step. The
# runner's temp directory is wiped with the job.
TARGET="${1:-${RUNNER_TEMP:-${TMPDIR:-/tmp}}/ahorro-deploy.kubeconfig}"

# Absent and forbidden are different failures and must not share a message.
# The platform deletes this credential on teardown, so absent really does mean
# the cluster is gone; forbidden means a grant is missing and rebuilding the
# cluster would change nothing.
param() {
  local value err
  if value="$(aws ssm get-parameter --region "$REGION" --with-decryption \
    --name "$PREFIX/$1" --query Parameter.Value --output text 2>/dev/null)"; then
    printf '%s' "$value"
    return 0
  fi

  err="$(aws ssm get-parameter --region "$REGION" --with-decryption \
    --name "$PREFIX/$1" --query Parameter.Value --output text 2>&1 >/dev/null || true)"

  case "$err" in
    *AccessDenied*|*not\ authorized*)
      echo "KUBECONFIG: not allowed to read $PREFIX/$1." >&2
      echo "KUBECONFIG: the parameter exists; the role is missing a grant. The token is a" >&2
      echo "KUBECONFIG: SecureString, so reading it needs kms:Decrypt on alias/lab-secrets as" >&2
      echo "KUBECONFIG: well as ssm:GetParameter. Fix ahorro-ci-role in vk-lab-platform and run" >&2
      echo "KUBECONFIG: 'make account-up'. Rebuilding the cluster will not help." >&2
      exit 1
      ;;
    *)
      echo "KUBECONFIG: no SSM parameter $PREFIX/$1." >&2
      echo "KUBECONFIG: PROJECT_NAME=$PROJECT_NAME. The platform publishes this on every" >&2
      echo "KUBECONFIG: bring-up and removes it on teardown, so a missing one means the" >&2
      echo "KUBECONFIG: cluster is gone. Run 'make up' in vk-lab-platform, then retry." >&2
      exit "$UNREACHABLE"
      ;;
  esac
}

# One at a time: param's exit inside $( ) would only kill the subshell, and
# set -e then stops at the first failure.
endpoint="$(param endpoint)"
ca="$(param ca)"
token="$(param token)"

# An SSM value is not masked the way a GitHub secret is, so register the mask
# before anything can print it.
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo "::add-mask::$token"
fi

mkdir -p "$(dirname "$TARGET")"
umask 077
cat > "$TARGET" <<YAML
apiVersion: v1
kind: Config
clusters:
  - name: lab
    cluster:
      server: ${endpoint}
      certificate-authority-data: ${ca}
users:
  - name: ahorro-deploy
    user:
      token: ${token}
contexts:
  - name: ahorro-deploy
    context:
      cluster: lab
      user: ahorro-deploy
current-context: ahorro-deploy
YAML

# The preflight. Stale parameters are the common failure on a disposable lab:
# they describe a cluster that was destroyed without a teardown, so the config
# looks valid and a plain helm call would wait out a multi-minute TCP timeout
# instead of saying what is wrong.
if ! KUBECONFIG="$TARGET" kubectl version --request-timeout=10s >/dev/null 2>&1; then
  echo "KUBECONFIG: the cluster is not reachable within 10s." >&2
  echo "KUBECONFIG: the credential names an endpoint that does not answer, so the cluster was" >&2
  echo "KUBECONFIG: most likely destroyed. Run 'make up' in vk-lab-platform, then retry." >&2
  rm -f "$TARGET"
  exit "$UNREACHABLE"
fi

printf '%s\n' "$TARGET"
