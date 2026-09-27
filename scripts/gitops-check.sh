#!/usr/bin/env bash
# Renders the app-of-apps chart for every target and validates every Argo
# object it produces. The placeholder fqdn is documented and never a real
# domain.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The .yaml suffix is load-bearing: kubeconform skips a file it cannot
# recognise and then reports "0 resource found", which reads as a pass.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The same two schema locations the helm CI job uses, so an Application that
# validates here validates there. Argo's CRDs live in the catalogue, not in
# kubeconform's defaults.
validate() {
  kubeconform -summary -strict \
    -schema-location default \
    -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
    "$1"
}

cloud="$work/gitops-cloud.yaml"
helm template ahorro "$REPO_ROOT/gitops" --set fqdn=example.invalid > "$cloud"
validate "$cloud"

# The local target renders a different shape, not a different value, so a
# check that only ever saw the cloud render would miss a broken one.
local_render="$work/gitops-local.yaml"
helm template ahorro "$REPO_ROOT/gitops" --set target=local > "$local_render"
validate "$local_render"

if grep -q 'value: "ahorro\."' "$local_render"; then
  echo "GITOPS-CHECK: the local render carries a hostname built from an empty fqdn." >&2
  exit 1
fi

if ! grep -q 'name: httpRoute.enabled' "$local_render"; then
  echo "GITOPS-CHECK: the local render does not turn the gateway routes off." >&2
  exit 1
fi

# `value` is optional in the Application CRD, so the API server drops
# `value: ""` on write. Argo then compares a stored object without the field
# against a manifest that has it and reports OutOfSync for ever, which
# selfHeal: false never corrects. Omit the parameter instead.
for rendered in "$cloud" "$local_render"; do
  if grep -q '^ *value: ""$' "$rendered"; then
    echo "GITOPS-CHECK: $rendered passes an empty helm parameter:" >&2
    grep -B1 '^ *value: ""$' "$rendered" >&2
    echo "GITOPS-CHECK: omit the parameter instead - an empty value never round-trips." >&2
    exit 1
  fi
done

echo "GITOPS-CHECK: the app-of-apps renders are valid for every target."
