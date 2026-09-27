#!/usr/bin/env bash
# Usage: forward.sh up|down
#
# Reaches both services on a cluster that publishes no hostname. The ports are
# not a free choice: they are rendered into config.json as the API base URL
# and into the API's allowed CORS origin, so changing one here without
# changing gitops/values.yaml breaks the browser call.
set -euo pipefail

NAMESPACE="${NAMESPACE:-ahorro}"
WEB_PORT="${WEB_PORT:-8090}"
API_PORT="${API_PORT:-8091}"
RUN_DIR="${TMPDIR:-/tmp}/vk-ahorro-forward"

forward() {
  # Declared separately: bash 3.2, which macOS ships, creates every name in a
  # single `local` before assigning any of them, so a later initialiser
  # reading an earlier one fails under set -u.
  local name="$1"
  local port="$2"
  local pidfile="$RUN_DIR/$name.pid"
  if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
    echo "FORWARD: $name already on $port"
    return
  fi
  # A held port is a real conflict, not something to work around silently:
  # the platform's own gateway forward takes 8080 the same way.
  if lsof -ti "tcp:$port" >/dev/null 2>&1; then
    echo "FORWARD: port $port is already in use. Free it, or set WEB_PORT/API_PORT." >&2
    exit 1
  fi
  kubectl -n "$NAMESPACE" port-forward "svc/$name" "$port:80" \
    >"$RUN_DIR/$name.log" 2>&1 &
  echo $! > "$pidfile"
  echo "FORWARD: $name on http://localhost:$port"
}

stop() {
  local name="$1"
  local pidfile="$RUN_DIR/$name.pid"
  [ -f "$pidfile" ] || { echo "FORWARD: $name was not running"; return; }
  kill "$(cat "$pidfile")" 2>/dev/null || true
  rm -f "$pidfile"
  echo "FORWARD: $name stopped"
}

case "${1:-}" in
  up)
    mkdir -p "$RUN_DIR"
    forward ahorro-web "$WEB_PORT"
    forward ahorro-api "$API_PORT"
    echo "FORWARD: the client reads http://localhost:$API_PORT as its API."
    ;;
  down)
    stop ahorro-web
    stop ahorro-api
    ;;
  *)
    echo "Usage: $0 up|down" >&2
    exit 1
    ;;
esac
