#!/usr/bin/env bash
# debug-local.sh
# Collect diagnostics for local Nakama <-> combat environment (WSL-friendly).
#
# Usage:
#   ./scripts/debug-local.sh
#   ./scripts/debug-local.sh /path/to/output.tar.gz   # specify archive path
#
# The script gathers:
#  - docker info, docker ps, container inspect and logs for cf-nakama, cf-postgres, cf-redis
#  - nakama config and module file contents (from repo)
#  - resolution of host.docker.internal, /etc/resolv.conf and network listeners
#  - local backend logs (scripts/.run-wsl-local/logs)
#  - quick curl checks for local endpoints
#  - saves results under scripts/debug-output/<timestamp>/ and creates a tar.gz
#
# Copy or paste the generated archive or the key text files when asking for help.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_ROOT="$REPO_ROOT/scripts/debug-output"
TS="$(date +%Y%m%dT%H%M%S)"
OUT_DIR="$OUT_ROOT/$TS"
ARCHIVE_DEFAULT="$OUT_ROOT/constellation-debug-$TS.tar.gz"
ARCHIVE_PATH="${1:-$ARCHIVE_DEFAULT}"

NAKAMA_DATA_DIR="$REPO_ROOT/nakama/data"
LOCAL_LOG_DIR="$REPO_ROOT/scripts/.run-wsl-local/logs"
PID_DIR="$REPO_ROOT/scripts/.run-wsl-local/pids"

mkdir -p "$OUT_DIR"

info() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*"; }
err() { printf '%s\n' "[ERROR] $*"; }

run_and_capture() {
  # Usage: run_and_capture <outfile-prefix> <command...>
  local prefix="$1"; shift
  local outfile="$OUT_DIR/${prefix}.txt"
  {
    printf '=== %s ===\n' "$prefix"
    printf 'Command: %s\n\n' "$*"
    "$@" 2>&1 || echo "[WARN] Command failed with non-zero exit"
  } > "$outfile"
}

# 1. Basic environment
run_and_capture "env_pwd" pwd
run_and_capture "date" date -u
run_and_capture "uname" uname -a || true

# 2. Versions
if command -v docker >/dev/null 2>&1; then
  run_and_capture "docker_version" docker --version
  run_and_capture "docker_info" docker info
else
  echo "[WARN] docker not found" > "$OUT_DIR/docker_version.txt"
fi

# Compose plugin or docker-compose
if docker compose version >/dev/null 2>&1 2>/dev/null; then
  run_and_capture "docker_compose_version" docker compose version
elif command -v docker-compose >/dev/null 2>&1; then
  run_and_capture "docker_compose_version" docker-compose --version
else
  echo "docker compose/docker-compose not found" > "$OUT_DIR/docker_compose_version.txt"
fi

if command -v cargo >/dev/null 2>&1; then
  run_and_capture "cargo_version" cargo --version
else
  echo "cargo not found" > "$OUT_DIR/cargo_version.txt"
fi

run_and_capture "python_version" python3 --version || true
run_and_capture "bash_version" bash --version | head -n1 || true

# 3. Docker containers status (filter by cf- prefix)
if command -v docker >/dev/null 2>&1; then
  run_and_capture "docker_ps" docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
else
  echo "docker not available" > "$OUT_DIR/docker_ps.txt"
fi

# 4. Container-specific diagnostics
for cname in cf-nakama cf-postgres cf-redis; do
  if command -v docker >/dev/null 2>&1 && docker ps -a --format '{{.Names}}' | grep -wq "$cname"; then
    run_and_capture "docker_inspect_${cname}" docker inspect "$cname" || true
    run_and_capture "docker_logs_${cname}_tail500" docker logs --tail 500 "$cname" || true
  else
    echo "container $cname not present" > "$OUT_DIR/docker_${cname}_missing.txt"
  fi
done

# 5. Nakama repo files (if present)
if [[ -d "$NAKAMA_DATA_DIR" ]]; then
  run_and_capture "nakama_data_ls" ls -la "$NAKAMA_DATA_DIR"
  if [[ -f "$NAKAMA_DATA_DIR/config.yml" ]]; then
    run_and_capture "nakama_config_head" sed -n '1,200p' "$NAKAMA_DATA_DIR/config.yml"
  fi
  if [[ -d "$NAKAMA_DATA_DIR/modules" ]]; then
    run_and_capture "nakama_modules_ls" ls -la "$NAKAMA_DATA_DIR/modules"
    if [[ -f "$NAKAMA_DATA_DIR/modules/constellation.lua" ]]; then
      run_and_capture "nakama_module_constellation" sed -n '1,400p' "$NAKAMA_DATA_DIR/modules/constellation.lua"
    fi
  fi
else
  echo "nakama/data directory not found in repo" > "$OUT_DIR/nakama_data_missing.txt"
fi

# 6. Network and DNS checks
run_and_capture "resolv_conf" sed -n '1,120p' /etc/resolv.conf || true
run_and_capture "hosts_check" getent hosts host.docker.internal || echo "host.docker.internal not resolvable" || true

# Attempt python DNS resolution (some environments may lack getent resolution)
if command -v python3 >/dev/null 2>&1; then
  run_and_capture "resolve_host_docker_internal" python3 - <<'PY'
import socket, sys
try:
    print('host.docker.internal ->', socket.gethostbyname('host.docker.internal'))
except Exception as e:
    print('resolve failed:', e)
PY
fi

# Show listening ports
if command -v ss >/dev/null 2>&1; then
  run_and_capture "ss_listen" ss -tuln || true
elif command -v netstat >/dev/null 2>&1; then
  run_and_capture "netstat_listen" netstat -tuln || true
fi

# 7. Local backend logs (if present)
mkdir -p "$OUT_DIR/local_logs"
if [[ -d "$LOCAL_LOG_DIR" ]]; then
  run_and_capture "local_logs_ls" ls -la "$LOCAL_LOG_DIR"
  for f in "$LOCAL_LOG_DIR"/*; do
    [[ -f "$f" ]] || continue
    base="$(basename "$f")"
    # capture last 1000 lines but keep file size reasonable
    tail -n 1000 "$f" > "$OUT_DIR/local_$base.tail" 2>/dev/null || cp "$f" "$OUT_DIR/local_$base.tail" || true
  done
else
  echo "No local backend logs directory: $LOCAL_LOG_DIR" > "$OUT_DIR/local_logs_missing.txt"
fi

# 8. PID files and running processes (if any)
if [[ -d "$PID_DIR" ]]; then
  run_and_capture "pid_dir_ls" ls -la "$PID_DIR"
  for pf in "$PID_DIR"/*.pid; do
    [[ -f "$pf" ]] || continue
    name="$(basename "$pf" .pid)"
    run_and_capture "pidfile_${name}" cat "$pf"
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
      run_and_capture "ps_pid_${pid}" ps -fp "$pid" || true
      if command -v lsof >/dev/null 2>&1; then
        run_and_capture "lsof_pid_${pid}" lsof -p "$pid" || true
      fi
    fi
  done
else
  echo "PID dir not found: $PID_DIR" > "$OUT_DIR/pid_dir_missing.txt"
fi

# 9. Quick curl checks for local endpoints
if command -v curl >/dev/null 2>&1; then
  run_and_capture "curl_nakama_base" curl -sS --max-time 5 http://localhost:7350/ || echo "no-response"
  run_and_capture "curl_combat_health" curl -sS --max-time 5 http://localhost:8082/api/v1/combat/health || echo "no-response"
  run_and_capture "curl_player_state" curl -sS --max-time 5 http://localhost:8081/ || echo "no-response"
else
  echo "curl not installed" > "$OUT_DIR/curl_missing.txt"
fi

# 10. Quick cargo checks (if cargo present)
if command -v cargo >/dev/null 2>&1; then
  run_and_capture "cargo_check_player_state" bash -lc "cd '$REPO_ROOT' && cargo check --package player-state" || true
  run_and_capture "cargo_check_combat" bash -lc "cd '$REPO_ROOT' && cargo check --package combat" || true
else
  echo "cargo not available" > "$OUT_DIR/cargo_missing.txt"
fi

# 11. Git state
if command -v git >/dev/null 2>&1; then
  run_and_capture "git_status" git -C "$REPO_ROOT" status --short || true
  run_and_capture "git_branch" git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD || true
fi

# 12. Summaries
{
  echo "Debug bundle generated at: $OUT_DIR"
  echo "Timestamp: $TS"
  echo
  echo "Quick summary of docker containers (if docker available):"
  if command -v docker >/dev/null 2>&1; then
    docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' || true
  else
    echo "(docker not available)"
  fi
  echo
  echo "host.docker.internal resolution:"
  getent hosts host.docker.internal || echo "host.docker.internal not resolvable"
  echo
  echo "/etc/resolv.conf (head):"
  sed -n '1,40p' /etc/resolv.conf || true
} > "$OUT_DIR/quick_summary.txt" 2>&1

# 13. Create archive
CUR_PWD="$(pwd)"
cd "$OUT_ROOT" || true
if tar -czf "$ARCHIVE_PATH" "$(basename "$OUT_DIR")" >/dev/null 2>&1; then
  cd "$CUR_PWD" || true
  printf '%s\n' "[OK] Debug bundle created: $ARCHIVE_PATH"
  printf '%s\n' "Please upload or paste $ARCHIVE_PATH (or the contents of quick_summary.txt and the Nakama logs) for analysis."
else
  cd "$CUR_PWD" || true
  warn "Failed to create archive at $ARCHIVE_PATH; debug output remains in $OUT_DIR"
  printf '%s\n' "Debug directory: $OUT_DIR"
fi

exit 0
