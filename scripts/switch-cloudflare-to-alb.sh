#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-.env.cloudflare}"
DOMAIN=""
ALB_DNS=""
PROXIED="${PROXIED:-true}"
TTL="${TTL:-1}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/switch-cloudflare-to-alb.sh --domain constellationfabric.com --alb-dns <alb-dns>

Options:
  --domain <domain>              Root domain (required)
  --alb-dns <dns>                ALB DNS name (required)
  --env-file <path>              Env file path (default: .env.cloudflare)
  --proxied <true|false>         Cloudflare proxy mode (default: true)
  --ttl <seconds|1>              DNS TTL (1 = auto, default: 1)
  -h, --help                     Show this help

Expected env vars in env file:
  CF_API_TOKEN=...
  CF_ZONE_ID=...
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --alb-dns) ALB_DNS="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --proxied) PROXIED="$2"; shift 2 ;;
    --ttl) TTL="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERRO] Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$ALB_DNS" ]]; then
  echo "[ERRO] --domain and --alb-dns are required."
  usage
  exit 1
fi

step() {
  echo
  echo "============================================================"
  echo "$1"
  echo "============================================================"
}
ok() { echo "[OK] $1"; }
warn() { echo "[WARN] $1"; }
err() { echo "[ERRO] $1" >&2; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "Command '$1' not found."
    exit 1
  fi
}

trim_cr() {
  local value="${1:-}"
  # Remove trailing carriage return from CRLF-loaded env vars.
  printf '%s' "${value%$'\r'}"
}

upsert_env_var() {
  local file="$1"
  local key="$2"
  local value="$3"
  if grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${value}|g" "$file"
  else
    echo "${key}=${value}" >> "$file"
  fi
}

cf_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"
  if [[ -n "$data" ]]; then
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4${endpoint}" \
      -H "Authorization: Bearer $CF_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "$data"
  else
    curl -sS -X "$method" "https://api.cloudflare.com/client/v4${endpoint}" \
      -H "Authorization: Bearer $CF_API_TOKEN"
  fi
}

extract_json_field() {
  local json="$1"
  local py="$2"
  python3 - <<PY
import json
data=json.loads('''$json''')
$py
PY
}

step "Cloudflare -> ALB DNS switch"
require_cmd curl
require_cmd python3
require_cmd sed

if [[ ! -f "$ENV_FILE" ]]; then
  warn "Env file '$ENV_FILE' not found. Creating it now."
  touch "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

# shellcheck disable=SC1090
source "$ENV_FILE" || true

CF_API_TOKEN="$(trim_cr "${CF_API_TOKEN:-}")"
CF_ZONE_ID="$(trim_cr "${CF_ZONE_ID:-}")"

if [[ -z "${CF_API_TOKEN:-}" ]]; then
  read -rsp "Cloudflare API Token (CF_API_TOKEN): " CF_API_TOKEN
  echo
  if [[ -z "$CF_API_TOKEN" ]]; then
    err "CF_API_TOKEN is required."
    exit 1
  fi
  upsert_env_var "$ENV_FILE" "CF_API_TOKEN" "$CF_API_TOKEN"
  ok "Saved CF_API_TOKEN to $ENV_FILE"
fi

if [[ -z "${CF_ZONE_ID:-}" ]]; then
  step "Resolving zone id for $DOMAIN"
  zone_resp="$(cf_api GET "/zones?name=$DOMAIN&status=active")"
  zone_id="$(extract_json_field "$zone_resp" "print((data.get('result') or [{}])[0].get('id',''))")"
  if [[ -z "$zone_id" ]]; then
    err "Could not auto-resolve CF_ZONE_ID for $DOMAIN."
    echo "$zone_resp"
    exit 1
  fi
  CF_ZONE_ID="$zone_id"
  upsert_env_var "$ENV_FILE" "CF_ZONE_ID" "$CF_ZONE_ID"
  ok "Resolved and saved CF_ZONE_ID to $ENV_FILE"
fi

if [[ -n "${CF_ZONE_ID:-}" && ! "$CF_ZONE_ID" =~ ^[a-fA-F0-9]{32}$ ]]; then
  warn "CF_ZONE_ID looks invalid ('$CF_ZONE_ID'). Re-entering interactively."
  CF_ZONE_ID=""
fi

if [[ -z "${CF_ZONE_ID:-}" ]]; then
  read -rp "Cloudflare Zone ID (CF_ZONE_ID): " CF_ZONE_ID
  CF_ZONE_ID="$(trim_cr "$CF_ZONE_ID")"
  if [[ -z "$CF_ZONE_ID" || ! "$CF_ZONE_ID" =~ ^[a-fA-F0-9]{32}$ ]]; then
    err "Invalid CF_ZONE_ID format."
    exit 1
  fi
  upsert_env_var "$ENV_FILE" "CF_ZONE_ID" "$CF_ZONE_ID"
  ok "Saved CF_ZONE_ID to $ENV_FILE"
fi

step "Validating API token and zone access"
verify_zone="$(cf_api GET "/zones/$CF_ZONE_ID")"
zone_ok="$(extract_json_field "$verify_zone" "print('1' if data.get('success') else '0')")"
if [[ "$zone_ok" != "1" ]]; then
  err "Token cannot access zone $CF_ZONE_ID."
  echo "$verify_zone"
  exit 1
fi
ok "Token and zone validated."

HOSTS=("api.$DOMAIN" "auth.$DOMAIN" "ws.$DOMAIN")

for host in "${HOSTS[@]}"; do
  step "Upserting DNS record for $host"

  list_resp="$(cf_api GET "/zones/$CF_ZONE_ID/dns_records?type=CNAME&name=$host")"
  existing_id="$(extract_json_field "$list_resp" "res=data.get('result') or []; print(res[0].get('id','') if res else '')")"

  payload="$(python3 - <<PY
import json
print(json.dumps({
  "type": "CNAME",
  "name": "$host",
  "content": "$ALB_DNS",
  "ttl": int("$TTL"),
  "proxied": "$PROXIED".lower() == "true"
}))
PY
)"

  if [[ -n "$existing_id" ]]; then
    update_resp="$(cf_api PUT "/zones/$CF_ZONE_ID/dns_records/$existing_id" "$payload")"
    success="$(extract_json_field "$update_resp" "print('1' if data.get('success') else '0')")"
    if [[ "$success" == "1" ]]; then
      ok "Updated CNAME: $host -> $ALB_DNS"
    else
      err "Failed to update record for $host"
      echo "$update_resp"
      exit 1
    fi
  else
    create_resp="$(cf_api POST "/zones/$CF_ZONE_ID/dns_records" "$payload")"
    success="$(extract_json_field "$create_resp" "print('1' if data.get('success') else '0')")"
    if [[ "$success" == "1" ]]; then
      ok "Created CNAME: $host -> $ALB_DNS"
    else
      err "Failed to create record for $host"
      echo "$create_resp"
      exit 1
    fi
  fi
done

step "Optional: list tunnel DNS records for review"
all_records="$(cf_api GET "/zones/$CF_ZONE_ID/dns_records?per_page=100")"
python3 - <<PY
import json
data=json.loads('''$all_records''')
for rec in data.get("result", []):
    n=rec.get("name","")
    if n.startswith(("api.","auth.","ws.")):
        print(f"- {n} [{rec.get('type')}] -> {rec.get('content')} | proxied={rec.get('proxied')}")
PY

step "Done"
ok "Hosts now point to ALB DNS through Cloudflare."
ok "Saved credentials and zone in $ENV_FILE (chmod 600 recommended)."
echo
echo "Next validation:"
echo "  nslookup api.$DOMAIN"
echo "  curl -I https://api.$DOMAIN"
echo "  curl -I https://auth.$DOMAIN"
