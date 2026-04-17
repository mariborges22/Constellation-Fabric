#!/usr/bin/env bash
set -euo pipefail

# Minimal smoke test for Nakama RPC -> Combat flow.
# Requirements:
# - Nakama HTTP endpoint reachable (default: http://localhost:7350)
# - SERVER_KEY environment variable set (Nakama server key)
# - RPCs registered in Nakama modules: cf_start_match, cf_submit_turn, cf_get_match_state, cf_end_match
#
# Usage:
#   SERVER_KEY=... NAKAMA_HTTP=http://localhost:7350 ./scripts/smoke-nakama-combat.sh
#
# Notes:
# - Uses curl and python3 (both required).
# - Intentionally prints short status messages prefixed with [INFO] / [ERRO].

NAKAMA_HTTP="${NAKAMA_HTTP:-http://localhost:7350}"
SERVER_KEY="${SERVER_KEY:-}"
DEVICE_ID="${DEVICE_ID:-smoke-device-001}"
USERNAME="${USERNAME:-smoke_tester}"

usage() {
  cat <<'EOF'
Usage:
  SERVER_KEY=... NAKAMA_HTTP=http://localhost:7350 ./scripts/smoke-nakama-combat.sh

Optional env:
  DEVICE_ID=smoke-device-001
  USERNAME=smoke_tester
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ -z "$SERVER_KEY" ]]; then
  echo "[ERRO] SERVER_KEY is required."
  usage
  exit 1
fi

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "[ERRO] Missing command: $1"; exit 1; }
}

require curl
require python3
require base64

uuid() {
  python3 - <<'PY'
import uuid
print(uuid.uuid4())
PY
}

MATCH_ID="$(uuid)"
ATTACKER_ID="$(uuid)"
DEFENDER_ID="$(uuid)"
IDEMPOTENCY_KEY="$(uuid)"

# Basic auth header for server key (server_key:)
AUTH_BASIC="$(printf '%s' "$SERVER_KEY:" | base64 | tr -d '\n\r')"

echo "[INFO] Authenticating device user..."
AUTH_RESP="$(curl -sS -X POST "$NAKAMA_HTTP/v2/account/authenticate/device?create=true&username=$USERNAME" \
  -H "Authorization: Basic $AUTH_BASIC" \
  -H "Content-Type: application/json" \
  --data "{\"id\":\"$DEVICE_ID\"}")"

TOKEN="$(python3 - <<PY
import json, sys
try:
    d = json.loads('''$AUTH_RESP''')
    print(d.get("token", ""))
except Exception:
    print("")
PY
)"

if [[ -z "$TOKEN" ]]; then
  echo "[ERRO] Failed to authenticate against Nakama."
  echo "$AUTH_RESP"
  exit 1
fi
echo "[OK] Nakama auth token acquired."

rpc_call() {
  local rpc_id="$1"
  local payload="$2"
  curl -sS -X POST "$NAKAMA_HTTP/v2/rpc/$rpc_id" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    --data "$payload"
}

echo "[INFO] cf_start_match..."
START_RESP="$(rpc_call "cf_start_match" "{\"match_id\":\"$MATCH_ID\",\"attacker_id\":\"$ATTACKER_ID\",\"defender_id\":\"$DEFENDER_ID\"}")"
echo "$START_RESP"

echo "[INFO] cf_submit_turn..."
TURN_PAYLOAD="$(cat <<EOF
{
  "match_id": "$MATCH_ID",
  "turn_id": 1,
  "idempotency_key": "$IDEMPOTENCY_KEY",
  "player_id": "$ATTACKER_ID",
  "character_id": "$ATTACKER_ID",
  "target_id": "$DEFENDER_ID",
  "action_type": "NormalAttack"
}
EOF
)"
TURN_RESP_1="$(rpc_call "cf_submit_turn" "$TURN_PAYLOAD")"
echo "$TURN_RESP_1"

echo "[INFO] cf_submit_turn again (idempotency replay)..."
TURN_RESP_2="$(rpc_call "cf_submit_turn" "$TURN_PAYLOAD")"
echo "$TURN_RESP_2"

echo "[INFO] cf_get_match_state..."
STATE_RESP="$(rpc_call "cf_get_match_state" "{\"match_id\":\"$MATCH_ID\"}")"
echo "$STATE_RESP"

echo "[INFO] cf_end_match..."
END_RESP="$(rpc_call "cf_end_match" "{\"match_id\":\"$MATCH_ID\"}")"
echo "$END_RESP"

echo "[INFO] Validating idempotency consistency..."
python3 - <<PY
import json, sys
try:
    r1 = json.loads('''$TURN_RESP_1''')
    r2 = json.loads('''$TURN_RESP_2''')
    if r1 != r2:
        print("[ERRO] idempotency replay mismatch")
        sys.exit(1)
    print("[OK] idempotency replay matched")
except Exception as e:
    print("[ERRO] Exception while validating idempotency:", e)
    sys.exit(1)
PY

echo "[OK] Smoke flow completed."
