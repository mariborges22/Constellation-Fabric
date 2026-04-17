#!/usr/bin/env bash
# extract-debug.sh
# Extract a debug tarball produced by scripts/debug-local.sh and create a single
# concatenated text file with key logs/configs for quick sharing.
#
# Usage:
#   ./scripts/extract-debug.sh /path/to/constellation-debug-2026...tar.gz
#   ./scripts/extract-debug.sh              # find the newest under scripts/debug-output/
#
# Output:
#   - Creates a combined file like ./debug-share-<ts>.txt in the current working dir
#   - Prints the path to the combined file
#
# Notes:
#   - This script is defensive: it will handle tarballs that contain a single
#     top-level directory or files at the top level.
#   - It will look for likely filenames produced by the debug collector and
#     append them if present.
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") [path-to-debug-tar.gz]

If no path is provided, the script will try to pick the most recent
\"scripts/debug-output/*.tar.gz\" file.

Example:
  ./scripts/extract-debug.sh scripts/debug-output/constellation-debug-20260402T172157.tar.gz
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

# Resolve target tar.gz
TARGET_TAR="${1:-}"
if [[ -z "$TARGET_TAR" ]]; then
  # find the newest tar.gz under scripts/debug-output
  if compgen -G "scripts/debug-output/*.tar.gz" >/dev/null 2>&1; then
    TARGET_TAR="$(ls -1t scripts/debug-output/*.tar.gz | head -n1)"
  else
    echo "[ERROR] No tarball provided and no files found under scripts/debug-output/" >&2
    exit 2
  fi
fi

if [[ ! -f "$TARGET_TAR" ]]; then
  echo "[ERROR] Specified tarball not found: $TARGET_TAR" >&2
  exit 2
fi

# Create temp dir and ensure cleanup
TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

echo "[INFO] Extracting '$TARGET_TAR' to temporary dir..."
tar -xzf "$TARGET_TAR" -C "$TMPDIR"

# Determine the extraction root. Many tarballs include a single top-level dir.
EXTRACT_ROOT="$TMPDIR"
# If there is exactly one directory in TMPDIR, use it
shopt -s nullglob
dirs=("$TMPDIR"/*)
if [[ ${#dirs[@]} -eq 1 && -d "${dirs[0]}" ]]; then
  EXTRACT_ROOT="${dirs[0]}"
fi
shopt -u nullglob

echo "[INFO] Using extracted root: $EXTRACT_ROOT"

TS="$(date -u +%Y%m%dT%H%M%SZ)"
OUTFILE="$(pwd)/debug-share-${TS}.txt"
: > "$OUTFILE"

# Helper: append file with a header if it exists
append_if_exists() {
  local label="$1"
  local file="$2"
  if [[ -f "$file" ]]; then
    printf "\n\n===== %s: %s =====\n\n" "$label" "$file" >> "$OUTFILE"
    cat "$file" >> "$OUTFILE"
  fi
}

# Helper: find candidate files (glob under extract root) and append them
append_glob() {
  local label="$1"
  shift
  local pattern
  for pattern in "$@"; do
    # shellcheck disable=SC2010
    while IFS= read -r -d '' f; do
      append_if_exists "$label" "$f"
    done < <(find "$EXTRACT_ROOT" -type f -iname "$pattern" -print0 2>/dev/null)
  done
}

# 1) Quick summary (explicit filename quick_summary.txt or quick_summary*.txt)
append_glob "Quick summary" "quick_summary.txt" "quick_summary*.txt" "quick_summary_*.txt"

# 2) Nakama logs and inspections
append_glob "Nakama docker logs (tail)" "docker_logs_cf-nakama_tail500.txt" "docker_logs_cf-nakama*.txt" "docker_logs_*nakama*.txt"
append_glob "Nakama inspect" "docker_inspect_cf-nakama.txt" "docker_inspect_*nakama*.txt"

# 3) Nakama config & module files from repo (if present in bundle)
append_glob "Nakama config" "nakama_config_head.txt" "nakama_config*.txt" "nakama/data/config.yml"
append_glob "Nakama module (constellation.lua)" "nakama_module_constellation.txt" "constellation.lua" "nakama/data/modules/constellation.lua"

# 4) Local backend logs produced by helper
append_glob "Local combat log" "local_combat.log.tail" "local_combat.log*" "*combat*.log*" "*combat*.tail*"
append_glob "Local player-state log" "local_player-state.log.tail" "local_player-state.log*" "*player-state*.log*" "*player_state*.log*"

# 5) Any captured docker logs for postgres/redis
append_glob "Postgres docker logs" "docker_logs_cf-postgres_tail*.txt" "docker_logs_*postgres*.txt" "docker_logs_cf-postgres*.txt"
append_glob "Redis docker logs" "docker_logs_cf-redis_tail*.txt" "docker_logs_*redis*.txt" "docker_logs_cf-redis*.txt"

# 6) Any other useful files produced by the debug collector (patterns)
append_glob "Quick files (other)" "*quick_summary*" "*summary.txt" "quick_summary.txt" "summary.txt" "*inspect*.*" "*docker_logs*"

# 7) If nothing matched above, include a directory tree and list remaining files
echo -e "\n\n===== Extracted files tree =====\n" >> "$OUTFILE"
( cd "$EXTRACT_ROOT" && find . -maxdepth 3 -print ) >> "$OUTFILE" 2>/dev/null || true

# 8) Also include the first ~200 lines of any large log files we couldn't match (defensive)
# Look for large .log files and append head
while IFS= read -r -d '' bigf; do
  # Skip if already appended (best-effort)
  if ! grep -Fq "$bigf" "$OUTFILE" 2>/dev/null; then
    printf "\n\n===== Head of %s =====\n\n" "$bigf" >> "$OUTFILE"
    head -n 500 "$bigf" >> "$OUTFILE" 2>/dev/null || true
  fi
done < <(find "$EXTRACT_ROOT" -type f -iname "*.log" -size +1k -print0 2>/dev/null || true)

# Final message
echo "[INFO] Combined debug output written to: $OUTFILE"
echo "[INFO] You can now share that single file (it contains headers and selected logs/configs)."
echo "[INFO] Temporary extraction dir was: $TMPDIR (removed on exit)"

# Exit success
exit 0
