#!/usr/bin/env bash
# Renders the app-of-apps chart and validates every Argo object it produces.
# The placeholder fqdn is documented and never a real domain.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# The .yaml suffix is load-bearing: kubeconform skips a file it cannot
# recognise and then reports "0 resource found", which reads as a pass.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
rendered="$work/gitops.yaml"

helm template ahorro "$REPO_ROOT/gitops" --set fqdn=example.invalid > "$rendered"

# The same two schema locations the helm CI job uses, so an Application that
# validates here validates there. Argo's CRDs live in the catalogue, not in
# kubeconform's defaults.
kubeconform -summary -strict \
  -schema-location default \
  -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
  "$rendered"

echo "GITOPS-CHECK: the app-of-apps render is valid."
