#!/usr/bin/env bash
# Validates specs/ layout: group folders, NNN-X-name letters vs front-matter
# status, the id prefix and number, relative Markdown links, and referenced
# spec paths that a status rename left behind.
set -uo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "SPECS-CHECK: $*" >&2; fail=1; }

letter_for() {
  case "$1" in
    DONE) echo D ;;
    IN_PROGRESS|IN_REVIEW) echo A ;;
    DRAFT|READY|BLOCKED) echo P ;;
    DEFERRED|SUPERSEDED|CANCELLED) echo Z ;;
    *) echo "?" ;;
  esac
}

prefix_for() {
  case "$1" in
    core) echo CORE ;;
    product) echo PROD ;;
    *) echo "?" ;;
  esac
}

for entry in specs/*; do
  name=$(basename "$entry")
  if [[ -d "$entry" ]]; then
    case "$name" in core|product) ;; *) err "unexpected folder $entry" ;; esac
  elif [[ "$name" != "README.md" ]]; then
    err "unexpected file $entry"
  fi
done

for d in specs/*/[0-9]*; do
  [[ -d "$d" ]] || continue
  group=$(basename "$(dirname "$d")")
  name=$(basename "$d")
  if [[ ! "$name" =~ ^([0-9]{3})(-[0-9]+)?-([DAPZ])-[a-z0-9-]+$ ]]; then
    err "$d: name is not NNN-X-name"
    continue
  fi
  number=${BASH_REMATCH[1]}
  letter=${BASH_REMATCH[3]}
  f="$d/spec.md"
  if [[ ! -f "$f" ]]; then err "$d: no spec.md"; continue; fi
  if [[ "$(head -1 "$f")" != "---" ]]; then err "$f: no front matter"; continue; fi
  fm=$(awk 'NR==1{next} /^---$/{exit} {print}' "$f")
  id=$(printf '%s\n' "$fm" | sed -n 's/^id: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p')
  status=$(printf '%s\n' "$fm" | sed -n 's/^status: *"\{0,1\}\([A-Z_]*\)"\{0,1\} *$/\1/p')
  want_id="$(prefix_for "$group")-$number"
  [[ "$id" == "$want_id" ]] || err "$f: id is '$id', want '$want_id'"
  want=$(letter_for "$status")
  [[ "$want" == "$letter" ]] || err "$d: letter $letter does not match status '${status}'"
done

while IFS= read -r f; do
  dir=$(dirname "$f")
  while IFS= read -r target; do
    case "$target" in ''|http://*|https://*|mailto:*) continue ;; esac
    [[ -e "$dir/$target" ]] || err "$f: broken link ($target)"
  done < <(sed 's/`[^`]*`//g' "$f" | grep -o '\]([^)#[:space:]]*' | sed 's/^](//')
done < <(find specs docs -name '*.md')

# A status change renames the folder, so every lettered path must still exist.
while IFS= read -r p; do
  [[ -e "$p" ]] || err "path to a missing spec folder: $p"
done < <(grep -rIohE '(vk-lab-platform/)?specs/[a-z]+/[0-9]{3}(-[0-9]+)?-[DAPZ]-[a-z0-9-]+' . \
  --exclude-dir=.git --exclude-dir=flutter-ui --exclude-dir=node_modules \
  --exclude-dir=.claude --exclude-dir=.cursor | grep -v '^vk-lab-platform/' | sort -u)

if [[ $fail -eq 0 ]]; then echo "SPECS-CHECK: specs/ layout is valid."; fi
exit $fail
