#!/usr/bin/env bash
# run-wsl-local.sh
#
# Helper to start minimal local environment on WSL for Nakama -> combat validation.
# - Starts Postgres, Redis, Nakama containers (if not already running)
# - Runs backend binaries locally via `cargo run` (player-state and combat)
# - Provides commands: run, smoke, stop, status, logs
#
# Usage:
#   ./scripts/run-wsl-local.sh run     # start containers + backend processes (in background)
#   ./scripts/run-wsl-local.sh smoke   # run smoke test (assumes services are up)
#   ./scripts/run-wsl-local.sh stop    # stop containers and kill backend processes
#   ./scripts/run-wsl-local.sh status  # show status of containers and backend processes
#   ./scripts/run-wsl-local.sh logs    # tail nakama, combat and player-state logs
#
# Notes:
#  - Requires Docker (Docker Desktop recommended with WSL integration) and Rust/Cargo for backend.
#  - Run from repository root (where this script lives in ./scripts).
#  - PID files and logs are saved under ./scripts/.run-wsl-local/
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="$REPO_ROOT"
DATA_DIR="$WORK_DIR/nakama/data"
PID_DIR="$WORK_DIR/scripts/.run-wsl-local/pids"
LOG_DIR="$WORK_DIR/scripts/.run-wsl-local/logs"
SMOKE_SCRIPT="$WORK_DIR/scripts/smoke-nakama-combat.sh"

POSTGRES_NAME="cf-postgres"
REDIS_NAME="cf-redis"
NAKAMA_NAME="cf-nakama"

POSTGRES_IMAGE="postgres:13"
REDIS_IMAGE="redis:6"
NAKAMA_IMAGE="heroiclabs/nakama:3.22.0"

NAKAMA_HTTP="http://localhost:7350"
COMBAT_HOST_URL="http://host.docker.internal:8082"  # Docker Desktop/WSL2 mapping

# Backend run settings
PLAYER_STATE_PORT=8081
COMBAT_PORT=8082

mkdir -p "$PID_DIR" "$LOG_DIR"

info() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERROR]\033[0m %s\n" "$*"; }
die() { err "$*"; exit 1; }

check_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

docker_running() {
  docker info >/dev/null 2>&1
}

container_exists() {
  local name="$1"
  docker ps -a --format '{{.Names}}' | grep -wq "$name"
}

container_running() {
  local name="$1"
  docker ps --format '{{.Names}}' | grep -wq "$name"
}

start_postgres() {
  if container_running "$POSTGRES_NAME"; then
    info "Postgres container '$POSTGRES_NAME' already running."
    return
  fi
  if container_exists "$POSTGRES_NAME"; then
    info "Starting existing Postgres container '$POSTGRES_NAME'..."
    docker start "$POSTGRES_NAME"
    return
  fi
  info "Creating and starting Postgres container '$POSTGRES_NAME'..."
  docker run -d --name "$POSTGRES_NAME" \
    -e POSTGRES_USER=nakama -e POSTGRES_PASSWORD=local -e POSTGRES_DB=nakama \
    -p 5432:5432 \
    "$POSTGRES_IMAGE"
}

start_redis() {
  if container_running "$REDIS_NAME"; then
    info "Redis container '$REDIS_NAME' already running."
    return
  fi
  if container_exists "$REDIS_NAME"; then
    info "Starting existing Redis container '$REDIS_NAME'..."
    docker start "$REDIS_NAME"
    return
  fi
  info "Creating and starting Redis container '$REDIS_NAME'..."
  docker run -d --name "$REDIS_NAME" -p 6379:6379 "$REDIS_IMAGE"
}

start_nakama() {
  if [[ ! -d "$DATA_DIR" ]]; then
    warn "Nakama data directory not found at $DATA_DIR. Nakama requires nakama/data with config.yml and modules."
    warn "Please ensure nakama/data exists in the repo. Continuing will still attempt to start Nakama but may fail."
  fi

  if container_running "$NAKAMA_NAME"; then
    info "Nakama container '$NAKAMA_NAME' already running."
    return
  fi
  if container_exists "$NAKAMA_NAME"; then
    info "Starting existing Nakama container '$NAKAMA_NAME'..."
    docker start "$NAKAMA_NAME"
    return
  fi

  info "Creating and starting Nakama container '$NAKAMA_NAME'..."
  # Use host.docker.internal so Nakama can reach the host-local combat service (running in WSL)
  docker run -d --name "$NAKAMA_NAME" \
    --link "$POSTGRES_NAME":postgres --link "$REDIS_NAME":redis \
    -p 7350:7350 -p 7349:7349 \
    -v "$DATA_DIR":/nakama/data:ro \
    -e DATABASE_ADDRESS=postgres:5432 \
    -e REDIS_ADDRESS=redis:6379 \
    -e COMBAT_API_BASE_URL="$COMBAT_HOST_URL" \
    "$NAKAMA_IMAGE" \
    /bin/sh -ecx "/nakama/nakama migrate up --database.address postgres:5432 && /nakama/nakama --config /nakama/data/config.yml --database.address postgres:5432"
}

wait_for_http() {
  local url="${1:-}"
  local timeout="${2:-60}"
  local interval=2
  local elapsed=0
  if [[ -z "$url" ]]; then
    die "wait_for_http requires a URL"
  fi
  info "Waiting for HTTP $url (timeout ${timeout}s)..."
  while true; do
    if curl -sSf --max-time 3 "$url" >/dev/null 2>&1; then
      info "$url responded"
      return 0
    fi
    elapsed=$((elapsed + interval))
    if (( elapsed >= timeout )); then
      warn "Timeout waiting for $url"
      return 1
    fi
    sleep "$interval"
  done
}

detect_server_key() {
  local cfg="$DATA_DIR/config.yml"
  if [[ ! -f "$cfg" ]]; then
    return 1
  fi
  # Try common keys: server_key, session.token_key, session: token_key
  local key
  key="$(sed -n -e 's/^[[:space:]]*server_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then echo "$key"; return 0; fi
  key="$(sed -n -e '/^[[:space:]]*session:/, /^[[:space:]]*[a-zA-Z]/ { s/^[[:space:]]*token_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p }' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then echo "$key"; return 0; fi
  key="$(sed -n -e 's/^[[:space:]]*session\.token_key:[[:space:]]*"\?\([^"]\+\)"\?[[:space:]]*$/\1/p' "$cfg" | head -n1 || true)"
  if [[ -n "$key" ]]; then echo "$key"; return 0; fi
  return 1
}

start_player_state() {
  check_command cargo
  local logfile="$LOG_DIR/player-state.log"
  local pidfile="$PID_DIR/player-state.pid"

  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" >/dev/null 2>&1; then
    info "player-state already running (pid $(cat "$pidfile"))"
    return
  fi

  info "Starting player-state locally (cargo run --package player-state)..."
  # Run in background, redirect logs
  nohup bash -lc "cd '$WORK_DIR' && PORT=$PLAYER_STATE_PORT cargo run --package player-state 2>&1" >"$logfile" &
  local pid=$!
  echo "$pid" >"$pidfile"
  info "player-state started (pid $pid), logs: $logfile"
}

start_combat() {
  check_command cargo
  local logfile="$LOG_DIR/combat.log"
  local pidfile="$PID_DIR/combat.pid"

  if [[ -f "$pidfile" ]] && kill -0 "$(cat "$pidfile")" >/dev/null 2>&1; then
    info "combat already running (pid $(cat "$pidfile"))"
    return
  fi

  info "Starting combat locally (cargo run --package combat)..."
  nohup bash -lc "cd '$WORK_DIR' && PLAYER_STATE_API=http://localhost:$PLAYER_STATE_PORT/api/v1/players PORT=$COMBAT_PORT cargo run --package combat 2>&1" >"$logfile" &
  local pid=$!
  echo "$pid" >"$pidfile"
  info "combat started (pid $pid), logs: $logfile"
}

stop_backend_processes() {
  for svc in player-state combat; do
    local pidfile="$PID_DIR/$svc.pid"
    if [[ -f "$pidfile" ]]; then
      local pid
      pid="$(cat "$pidfile")"
      if kill -0 "$pid" >/dev/null 2>&1; then
        info "Killing $svc (pid $pid)..."
        kill "$pid" || true
        sleep 1
        if kill -0 "$pid" >/dev/null 2>&1; then
          warn "$svc did not exit, sending SIGKILL..."
          kill -9 "$pid" || true
        fi
      fi
      rm -f "$pidfile"
    else
      info "No pidfile for $svc; assuming not running."
    fi
  done
}

stop_containers() {
  for name in "$NAKAMA_NAME" "$POSTGRES_NAME" "$REDIS_NAME"; do
    if container_exists "$name"; then
      if container_running "$name"; then
        info "Stopping container $name..."
        docker stop "$name" >/dev/null || true
      else
        info "Container $name exists but is not running."
      fi
    else
      info "Container $name not present."
    fi
  done
}

status() {
  info "Docker status:"
  if docker_running; then
    docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
  else
    warn "Docker daemon not reachable."
  fi

  info ""
  info "Backend processes (pid files in $PID_DIR):"
  for svc in player-state combat; do
    local pidfile="$PID_DIR/$svc.pid"
    if [[ -f "$pidfile" ]]; then
      local pid
      pid="$(cat "$pidfile")"
      if kill -0 "$pid" >/dev/null 2>&1; then
        info "$svc running (pid $pid)"
      else
        warn "$svc pidfile exists but process $pid not found"
      fi
    else
      info "$svc not running"
    fi
  done
}

tail_logs() {
  local nakama_logs="docker logs -f $NAKAMA_NAME"
  local combat_logfile="$LOG_DIR/combat.log"
  local player_logfile="$LOG_DIR/player-state.log"

  info "Tailing logs. Press Ctrl+C to exit."
  echo "---- Nakama (docker) ----"
  docker logs --tail 200 "$NAKAMA_NAME" || true
  echo "---- combat (local) ----"
  [[ -f "$combat_logfile" ]] && tail -n 200 "$combat_logfile" || echo "(no combat logs yet)"
  echo "---- player-state (local) ----"
  [[ -f "$player_logfile" ]] && tail -n 200 "$player_logfile" || echo "(no player-state logs yet)"

  echo
  info "Now following live logs (docker + local files). Use Ctrl+C to stop."
  # Follow in background; user can Ctrl+C to stop the script.
  docker logs -f "$NAKAMA_NAME" &
  tail -f "$combat_logfile" &
  tail -f "$player_logfile" &
  wait
}

run_smoke_test() {
  if [[ ! -x "$SMOKE_SCRIPT" ]]; then
    if [[ -f "$SMOKE_SCRIPT" ]]; then
      chmod +x "$SMOKE_SCRIPT"
    else
      die "Smoke script not found: $SMOKE_SCRIPT"
    fi
  fi

  # Try auto-detect SERVER_KEY from nakama/data/config.yml
  local sk
  if sk="$(detect_server_key)"; then
    export SERVER_KEY="$sk"
    info "Detected SERVER_KEY from nakama/data/config.yml"
  else
    warn "SERVER_KEY not auto-detected. Please set SERVER_KEY env var before running smoke test."
    warn "You can export SERVER_KEY manually or check $DATA_DIR/config.yml for the key."
    return 1
  fi

  export NAKAMA_HTTP="$NAKAMA_HTTP"
  info "Running smoke test against $NAKAMA_HTTP ..."
  (cd "$WORK_DIR" && "$SMOKE_SCRIPT")
}

cmd_run() {
  check_command docker
  if ! docker_running; then
    die "Docker daemon not reachable. If using Docker Desktop, ensure it is running and WSL integration is enabled."
  fi

  info "Starting Postgres, Redis, Nakama containers..."
  start_postgres
  start_redis
  start_nakama

  # Wait for services
  wait_for_http "http://localhost:5432" 10 || info "Postgres may not expose HTTP; relying on container status."
  wait_for_http "http://localhost:6379" 5 >/dev/null 2>&1 || true
  # Wait for nakama HTTP
  if ! wait_for_http "$NAKAMA_HTTP" 60; then
    warn "Nakama did not respond in time. Check 'docker logs $NAKAMA_NAME'."
  fi

  # Start backend binaries
  check_command cargo
  start_player_state
  # Wait for player-state
  if ! wait_for_http "http://localhost:$PLAYER_STATE_PORT" 30; then
    warn "player-state did not respond in time. Check logs at $LOG_DIR/player-state.log"
  fi

  start_combat
  if ! wait_for_http "http://localhost:$COMBAT_PORT/api/v1/combat/health" 30; then
    warn "combat did not respond in time. Check logs at $LOG_DIR/combat.log"
  fi

  info "Local environment should be up. Run './scripts/run-wsl-local.sh smoke' to run the smoke test."
}

cmd_stop() {
  info "Stopping local backend processes..."
  stop_backend_processes
  info "Stopping containers..."
  stop_containers
  info "Done."
}

usage() {
  cat <<EOF
Usage: $(basename "$0") <command>

Commands:
  run     Start Postgres, Redis, Nakama (docker) and run backend binaries locally (player-state, combat)
  smoke   Run the Nakama -> combat smoke test (requires SERVER_KEY or auto-detect from nakama/data/config.yml)
  stop    Stop backend processes and stop containers
  status  Show status of containers and backend processes
  logs    Tail logs for Nakama (docker) and local backend logs
  help    Show this message
EOF
}

main() {
  if [[ $# -lt 1 ]]; then
    usage
    exit 0
  fi
  case "$1" in
    run) cmd_run ;;
    smoke) run_smoke_test ;;
    stop) cmd_stop ;;
    status) status ;;
    logs) tail_logs ;;
    help|-h|--help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
