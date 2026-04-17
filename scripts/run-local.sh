#!/usr/bin/env bash
#
# run-local.sh
#
# Helper to build and run local dev environment (docker-compose.dev.yml)
# and execute the Nakama -> combat smoke test.
#
# Usage:
#   ./scripts/run-local.sh up      # build images and start services
#   ./scripts/run-local.sh smoke   # run the smoke test (assumes services are up)
#   ./scripts/run-local.sh run     # shortcut: up then smoke
#   ./scripts/run-local.sh down    # stop and remove containers
#   ./scripts/run-local.sh logs    # tail logs for nakama and combat
#
# Notes:
#  - This script expects to be run from the repository (it resolves the repo root
#    relative to this script's location).
#  - The compose file used is docker-compose.dev.yml at the repo root.
#  - The smoke test is scripts/smoke-nakama-combat.sh and requires SERVER_KEY and NAKAMA_HTTP.
#  - The script attempts to auto-detect SERVER_KEY from nakama/data/config.yml if possible,
#    but you can also export SERVER_KEY before invoking the smoke target:
#       export SERVER_KEY="your-server-key"
#       ./scripts/run-local.sh smoke
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
COMPOSE_FILE="$REPO_ROOT/docker-compose.dev.yml"
SMOKE_SCRIPT="$REPO_ROOT/scripts/smoke-nakama-combat.sh"
NAKAMA_CONFIG="$REPO_ROOT/nakama/data/config.yml"

# Defaults
NAKAMA_HTTP_DEFAULT="http://localhost:7350"
SMOKE_TIMEOUT_SECONDS=120

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

info() {
  echo "[INFO] $*"
}

check_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

# Try to read a server key from nakama/data/config.yml
detect_server_key() {
  local cfg="$NAKAMA_CONFIG"
  if [[ ! -f "$cfg" ]]; then
    return 1
  fi

  # Try a few patterns that commonly hold a token/key:
  # - server_key: <value>
  # - session:
  #     token_key: <value>
  # - session.token_key: <value>
  # The sed expressions below try to capture those.
  local key

  key="$(sed -n -e 's/^[[:space:]]*server_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then
    echo "$key"
    return 0
  fi

  key="$(sed -n -e '/^[[:space:]]*session:/, /^[[:space:]]*[a-zA-Z0-9_]*:/ { s/^[[:space:]]*token_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p }' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then
    echo "$key"
    return 0
  fi

  key="$(sed -n -e 's/^[[:space:]]*session\.token_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then
    echo "$key"
    return 0
  fi

  return 1
}

# Wait until an HTTP endpoint returns any HTTP code (i.e. responds).
# Returns 0 if succeeded before timeout, non-zero otherwise.
wait_for_http() {
  local url="$1"
  local timeout="${2:-$SMOKE_TIMEOUT_SECONDS}"
  local sleeptime=2
  local elapsed=0

  info "Waiting for HTTP endpoint to respond: $url (timeout ${timeout}s)..."
  while true; do
    # Capture HTTP status code; if curl fails entirely we get "000"
    local status
    status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "$url" || echo "000")"
    if [[ "$status" != "000" ]]; then
      info "Endpoint responded (http code: $status)"
      return 0
    fi
    elapsed=$((elapsed + sleeptime))
    if (( elapsed >= timeout )); then
      echo "[WARN] Timeout waiting for $url" >&2
      return 1
    fi
    sleep $sleeptime
  done
}

cmd_up() {
  check_command docker
  check_command docker-compose || true
  check_command docker-compose || true

  if [[ ! -f "$COMPOSE_FILE" ]]; then
    die "Compose file not found: $COMPOSE_FILE"
  fi

  info "Building images (docker compose build)..."
  # Use docker compose where available; fall back to docker-compose
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" build
  else
    docker-compose -f "$COMPOSE_FILE" build
  fi

  info "Bringing up services (detached)..."
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" up -d
  else
    docker-compose -f "$COMPOSE_FILE" up -d
  fi

  # Wait for combat and nakama endpoints to respond
  local nakama_url="${NAKAMA_HTTP:-$NAKAMA_HTTP_DEFAULT}"
  local combat_health="http://localhost:8082/api/v1/combat/health"

  if ! wait_for_http "$combat_health" 60; then
    echo "[WARN] combat health endpoint did not respond in time. Check 'docker compose logs combat'." >&2
  fi

  # Nakama may not expose a stable /health but waiting for any response on base path is OK
  if ! wait_for_http "$nakama_url" 60; then
    echo "[WARN] Nakama did not respond in time at $nakama_url. Check 'docker compose logs nakama'." >&2
  fi

  info "Services started (or at least responding)."
  info "You can run: ./scripts/run-local.sh smoke"
}

cmd_down() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    die "Compose file not found: $COMPOSE_FILE"
  fi

  info "Stopping services..."
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" down --volumes
  else
    docker-compose -f "$COMPOSE_FILE" down --volumes
  fi
  info "Stopped and removed containers."
}

cmd_logs() {
  if docker compose version >/dev/null 2>&1; then
    docker compose -f "$COMPOSE_FILE" logs -f nakama combat
  else
    docker-compose -f "$COMPOSE_FILE" logs -f nakama combat
  fi
}

cmd_smoke() {
  if [[ ! -x "$SMOKE_SCRIPT" ]]; then
    if [[ -f "$SMOKE_SCRIPT" ]]; then
      info "Making smoke script executable: $SMOKE_SCRIPT"
      chmod +x "$SMOKE_SCRIPT"
    else
      die "Smoke script not found: $SMOKE_SCRIPT"
    fi
  fi

  # Determine NAKAMA_HTTP and SERVER_KEY
  NAKAMA_HTTP="${NAKAMA_HTTP:-$NAKAMA_HTTP_DEFAULT}"
  export NAKAMA_HTTP

  if [[ -z "${SERVER_KEY:-}" ]]; then
    info "SERVER_KEY env not set, trying to detect from $NAKAMA_CONFIG..."
    if key="$(detect_server_key)"; then
      export SERVER_KEY="$key"
      info "Detected SERVER_KEY from config file."
    else
      echo
      echo "----------------------------------------------------------------"
      echo "[WARN] SERVER_KEY not set and could not be detected automatically."
      echo "Please set SERVER_KEY to the server key used by Nakama before running the smoke test."
      echo "Example:"
      echo "  export SERVER_KEY=\"$(head -c 24 /dev/urandom | od -An -t x1 | tr -d ' \\n')\""
      echo "  ./scripts/run-local.sh smoke"
      echo "Or examine $NAKAMA_CONFIG and set SERVER_KEY accordingly."
      echo "----------------------------------------------------------------"
      echo
      return 1
    fi
  fi

  info "Running smoke test against Nakama at $NAKAMA_HTTP"
  if ! "$SMOKE_SCRIPT"; then
    echo "[ERROR] Smoke test failed. Check logs and service status." >&2
    return 1
  fi
  info "Smoke test completed successfully."
}

cmd_run() {
  cmd_up
  cmd_smoke
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  up       Build images and start local dev compose (docker-compose.dev.yml)
  smoke    Run the Nakama -> combat smoke test (scripts/smoke-nakama-combat.sh)
  run      Shortcut: up, then smoke
  down     Stop and remove containers/volumes
  logs     Tail logs for nakama and combat
  help     Show this message

Examples:
  ./scripts/run-local.sh up
  ./scripts/run-local.sh smoke
  ./scripts/run-local.sh run
  ./scripts/run-local.sh down
EOF
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 0
  fi

  case "$1" in
    up) cmd_up ;;
    smoke) cmd_smoke ;;
    run) cmd_run ;;
    down) cmd_down ;;
    logs) cmd_logs ;;
    help|-h|--help) usage ;;
    *) echo "[ERROR] Unknown command: $1" >&2; usage; exit 2 ;;
  esac
}

main "$@"
