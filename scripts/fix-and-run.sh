#!/usr/bin/env bash
# fix-and-run.sh
#
# Apply fixes and run a local Nakama + backend dev environment:
# 1) Normalize LF line endings for helper scripts
# 2) Remove & recreate the Nakama container with correct DB DSN and COMBAT_API_BASE_URL
# 3) Start local backend binaries (player-state, combat) via `cargo run` from the backend dir
# 4) Wait for services to be healthy
# 5) Run the smoke test
#
# Usage:
#   ./scripts/fix-and-run.sh
#
# Notes:
# - Run this from WSL/Ubuntu where docker (Docker Desktop + WSL integration) and cargo are available.
# - The script assumes the repo root is one level up from this script's directory.
# - It uses a conservative default Postgres DSN: postgres://nakama:local@postgres:5432/nakama
#   adjust the DSN below (POSTGRES_DSN) if your Postgres credentials differ.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
BACKEND_DIR="$REPO_ROOT/backend"
NAKAMA_DATA="$REPO_ROOT/nakama/data"
PIDS_DIR="$SCRIPTS_DIR/.run-wsl-local/pids"
LOGS_DIR="$SCRIPTS_DIR/.run-wsl-local/logs"

mkdir -p "$PIDS_DIR" "$LOGS_DIR"

info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; }

# 1) Normalize helper scripts to LF and make executable
normalize_scripts() {
  info "Normalizing line endings for helper scripts..."
  cd "$REPO_ROOT"
  local files=( \
    "$SCRIPTS_DIR/run-wsl-local.sh" \
    "$SCRIPTS_DIR/debug-local.sh" \
    "$SCRIPTS_DIR/smoke-nakama-combat.sh" \
    "$SCRIPTS_DIR/extract-debug.sh" \
    "$SCRIPTS_DIR/run-local.sh" \
    "$SCRIPTS_DIR/fix-and-run.sh" \
  )

  if command -v dos2unix >/dev/null 2>&1; then
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      dos2unix "$f" >/dev/null 2>&1 || true
    done
  else
    # fallback to sed to strip CR (\r) at line ends
    for f in "${files[@]}"; do
      [[ -f "$f" ]] || continue
      sed -i 's/\r$//' "$f" || true
    done
  fi

  chmod +x "$SCRIPTS_DIR"/*.sh || true
  info "Normalization complete."
}

# 2) Remove existing Nakama container if present
remove_existing_nakama() {
  if docker ps -a --format '{{.Names}}' | grep -wq cf-nakama; then
    info "Stopping and removing existing cf-nakama container..."
    docker rm -f cf-nakama || true
  else
    info "No existing cf-nakama container found."
  fi
}

# choose combat host that Nakama container will use to reach host-local combat
choose_combat_api_url() {
  # prefer host.docker.internal if resolvable
  if getent hosts host.docker.internal >/dev/null 2>&1; then
    echo "http://host.docker.internal:8082"
    return 0
  fi

  # fallback to nameserver IP from /etc/resolv.conf (typical WSL mapping)
  if grep -q nameserver /etc/resolv.conf 2>/dev/null; then
    local ns
    ns="$(awk '/nameserver/ {print $2; exit}' /etc/resolv.conf)"
    if [[ -n "$ns" ]]; then
      echo "http://$ns:8082"
      return 0
    fi
  fi

  # final fallback to localhost (may not work from container)
  echo "http://localhost:8082"
  return 0
}

# 3) Recreate Nakama with correct args
recreate_nakama() {
  info "Recreating cf-nakama container with correct DB DSN and COMBAT_API_BASE_URL..."

  # Default DSN: update if your DB credentials differ
  local POSTGRES_DSN="postgres://nakama:local@postgres:5432/nakama"
  local COMBAT_API_BASE_URL
  COMBAT_API_BASE_URL="$(choose_combat_api_url)"

  # Ensure nakama data dir exists
  if [[ ! -d "$NAKAMA_DATA" ]]; then
    warn "nakama/data not found at $NAKAMA_DATA. Nakama will likely fail to start without config/modules."
  fi

  # Run Nakama: let image entrypoint run /nakama/nakama and pass flags
  docker run -d --name cf-nakama \
    --link cf-postgres:postgres --link cf-redis:redis \
    -p 7350:7350 -p 7349:7349 -p 7351:7351 \
    -v "$NAKAMA_DATA":/nakama/data:ro \
    -e COMBAT_API_BASE_URL="$COMBAT_API_BASE_URL" \
    -e REDIS_ADDRESS=redis:6379 \
    heroiclabs/nakama:3.22.0 \
    --config /nakama/data/config.yml \
    --database.address "$POSTGRES_DSN" >/dev/null

  info "Created cf-nakama (image heroiclabs/nakama:3.22.0)."
  info "COMBAT_API_BASE_URL set to: $COMBAT_API_BASE_URL"
  info "Waiting for Nakama to be ready (http://localhost:7350)..."
  # wait for Nakama http endpoint
  local i=0
  local max=60
  while ! curl -sSf --max-time 2 http://localhost:7350/ >/dev/null 2>&1; do
    i=$((i+1))
    if (( i >= max )); then
      err "Nakama did not become ready within timeout. Check docker logs: docker logs --tail 200 cf-nakama"
      return 1
    fi
    sleep 1
  done
  info "Nakama is responding on http://localhost:7350"
  return 0
}

# 4) Start backend binaries (player-state and combat) from backend/ dir
start_backends() {
  if ! command -v cargo >/dev/null 2>&1; then
    err "cargo not found. Install Rust toolchain (rustup) before running backends."
    return 1
  fi

  # player-state
  if [[ -f "$PIDS_DIR/player-state.pid" ]]; then
    local pid
    pid="$(cat "$PIDS_DIR/player-state.pid")"
    if kill -0 "$pid" >/dev/null 2>&1; then
      info "player-state already running (pid $pid)."
    else
      rm -f "$PIDS_DIR/player-state.pid"
    fi
  fi

  info "Starting player-state in background (logs -> $LOGS_DIR/player-state.log)..."
  nohup bash -lc "cd '$BACKEND_DIR' && PORT=8081 cargo run --package player-state" >"$LOGS_DIR/player-state.log" 2>&1 &
  echo $! > "$PIDS_DIR/player-state.pid"
  sleep 1

  # wait for player-state
  local try=0
  while ! curl -sS --max-time 2 http://localhost:8081/ >/dev/null 2>&1; do
    try=$((try+1))
    if (( try >= 30 )); then
      warn "player-state did not respond in time. Check $LOGS_DIR/player-state.log"
      break
    fi
    sleep 1
  done
  info "player-state process started (pid $(cat "$PIDS_DIR/player-state.pid" 2>/dev/null || echo unknown))."

  # combat
  if [[ -f "$PIDS_DIR/combat.pid" ]]; then
    local pid2
    pid2="$(cat "$PIDS_DIR/combat.pid")"
    if kill -0 "$pid2" >/dev/null 2>&1; then
      info "combat already running (pid $pid2)."
    else
      rm -f "$PIDS_DIR/combat.pid"
    fi
  fi

  info "Starting combat in background (logs -> $LOGS_DIR/combat.log)..."
  nohup bash -lc "cd '$BACKEND_DIR' && PLAYER_STATE_API=http://localhost:8081/api/v1/players PORT=8082 cargo run --package combat" >"$LOGS_DIR/combat.log" 2>&1 &
  echo $! > "$PIDS_DIR/combat.pid"
  sleep 1

  # wait for combat health endpoint
  try=0
  while ! curl -sS --max-time 2 http://localhost:8082/api/v1/combat/health >/dev/null 2>&1; do
    try=$((try+1))
    if (( try >= 30 )); then
      warn "combat did not respond in time. Check $LOGS_DIR/combat.log"
      break
    fi
    sleep 1
  done
  info "combat process started (pid $(cat "$PIDS_DIR/combat.pid" 2>/dev/null || echo unknown))."
  return 0
}

# 5) Try to detect SERVER_KEY from nakama config
detect_server_key() {
  local cfg="$NAKAMA_DATA/config.yml"
  if [[ -f "$cfg" ]]; then
    # try common keys
    local key
    key="$(sed -n -e 's/^[[:space:]]*socket\\.server_key:[[:space:]]*\"\\?\\([^\" ]\\+\\)\"\\?[[:space:]]*$/\\1/p' "$cfg" | head -n1 || true)"
    if [[ -n "$key" ]]; then
      echo "$key"
      return 0
    fi
    key="$(sed -n -e 's/^[[:space:]]*server_key:[[:space:]]*\"\\?\\([^\" ]\\+\\)\"\\?[[:space:]]*$/\\1/p' "$cfg" | head -n1 || true)"
    if [[ -n "$key" ]]; then
      echo "$key"
      return 0
    fi
    # session.token_key
    key="$(sed -n -e 's/^[[:space:]]*session\\.token_key:[[:space:]]*\"\\?\\([^\" ]\\+\\)\"\\?[[:space:]]*$/\\1/p' "$cfg" | head -n1 || true)"
    if [[ -n "$key" ]]; then
      echo "$key"
      return 0
    fi
  fi
  return 1
}

# 6) Run smoke test
run_smoke() {
  if [[ ! -f "$SCRIPTS_DIR/smoke-nakama-combat.sh" ]]; then
    err "Smoke script not found: $SCRIPTS_DIR/smoke-nakama-combat.sh"
    return 1
  fi

  export NAKAMA_HTTP="http://localhost:7350"
  if [[ -z "${SERVER_KEY:-}" ]]; then
    if sk="$(detect_server_key)"; then
      export SERVER_KEY="$sk"
      info "Detected SERVER_KEY from config.yml: $SERVER_KEY"
    else
      warn "SERVER_KEY not found in config.yml. Using default 'constellation_dev_key' if present."
      export SERVER_KEY="constellation_dev_key"
    fi
  fi

  info "Running smoke test script..."
  (cd "$REPO_ROOT" && bash "$SCRIPTS_DIR/smoke-nakama-combat.sh")
}

# main flow
main() {
  info "Starting fix-and-run flow..."

  normalize_scripts

  # remove bad nakama if present
  remove_existing_nakama

  # attempt to recreate Nakama with correct settings
  if ! recreate_nakama; then
    err "Failed to create Nakama container correctly. Inspect 'docker logs cf-nakama' for details."
    docker logs --tail 200 cf-nakama || true
    return 1
  fi

  # start player-state and combat (local cargo)
  if ! start_backends; then
    err "Failed to start backend processes."
    return 2
  fi

  # run smoke test
  if ! run_smoke; then
    warn "Smoke test failed. Inspect logs:"
    warn " - Nakama: docker logs --tail 200 cf-nakama"
    warn " - Combat logs: $LOGS_DIR/combat.log"
    warn " - Player-state logs: $LOGS_DIR/player-state.log"
    return 3
  fi

  info "All steps completed. If smoke test succeeded, integration is validated."
  info "Hints: to tail logs run: docker logs -f cf-nakama  OR tail -f $LOGS_DIR/combat.log"
  return 0
}

main "$@"
