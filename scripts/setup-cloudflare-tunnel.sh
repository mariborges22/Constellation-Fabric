#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${DOMAIN:-}"
TUNNEL_NAME="${TUNNEL_NAME:-constellation-staging}"
STACK_NAME="${STACK_NAME:-constellation}"
DOCKER_NETWORK="${DOCKER_NETWORK:-constellation-net}"
CLOUDFLARED_IMAGE="${CLOUDFLARED_IMAGE:-cloudflare/cloudflared:latest}"
SKIP_DNS_VALIDATION="${SKIP_DNS_VALIDATION:-false}"
SKIP_HTTP_VALIDATION="${SKIP_HTTP_VALIDATION:-false}"
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -d|--domain)
      DOMAIN="$2"
      shift 2
      ;;
    -t|--tunnel-name)
      TUNNEL_NAME="$2"
      shift 2
      ;;
    --stack-name)
      STACK_NAME="$2"
      shift 2
      ;;
    --docker-network)
      DOCKER_NETWORK="$2"
      shift 2
      ;;
    --skip-dns-validation)
      SKIP_DNS_VALIDATION="true"
      shift
      ;;
    --skip-http-validation)
      SKIP_HTTP_VALIDATION="true"
      shift
      ;;
    --non-interactive)
      NON_INTERACTIVE="true"
      shift
      ;;
    -h|--help)
      cat <<'EOF'
Usage:
  ./scripts/setup-cloudflare-tunnel.sh --domain constellationfabric.com [options]

Options:
  -d, --domain <domain>             Domain root (required)
  -t, --tunnel-name <name>          Tunnel name (default: constellation-staging)
      --stack-name <name>           Docker stack name (default: constellation)
      --docker-network <name>       Docker network name (default: constellation-net)
      --skip-dns-validation         Skip nslookup checks
      --skip-http-validation        Skip curl HTTPS checks
      --non-interactive             Do not prompt for tunnel login
  -h, --help                        Show this help
EOF
      exit 0
      ;;
    *)
      echo "[ERRO] Unknown argument: $1"
      exit 1
      ;;
  esac
done

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

run_cf() {
  docker run --rm \
    -v "$PWD/.cloudflared:/home/nonroot/.cloudflared" \
    "$CLOUDFLARED_IMAGE" "$@"
}

extract_tunnel_id() {
  local list_output="$1"
  local name="$2"
  awk -v tname="$name" '$2==tname {print $1}' <<<"$list_output" | head -n1
}

step "Constellation Fabric - Setup Cloudflare Tunnel + DNS (WSL/Bash)"

require_cmd docker
require_cmd nslookup
require_cmd curl

if ! docker version >/dev/null 2>&1; then
  err "Docker daemon is not reachable from this shell."
  err "If using WSL, make sure Docker Engine is running."
  exit 1
fi
ok "Docker is available."

if [[ -z "$DOMAIN" ]]; then
  read -rp "Domain root (e.g. constellationfabric.com): " DOMAIN
fi
DOMAIN="${DOMAIN,,}"
if [[ -z "$DOMAIN" ]]; then
  err "Domain is required."
  exit 1
fi

API_HOST="api.$DOMAIN"
WS_HOST="ws.$DOMAIN"
AUTH_HOST="auth.$DOMAIN"

mkdir -p .cloudflared
ok "Credential directory: .cloudflared"

step "1) Cloudflare login"
if [[ "$NON_INTERACTIVE" == "false" ]]; then
  read -rp "Run cloudflared login now? (y/N): " ans
  ans="${ans,,}"
  if [[ "$ans" == "y" || "$ans" == "yes" ]]; then
    docker run --rm -it \
      -v "$PWD/.cloudflared:/home/nonroot/.cloudflared" \
      "$CLOUDFLARED_IMAGE" tunnel login
    ok "Login completed."
  else
    warn "Skipping login. Ensure cert exists in .cloudflared."
  fi
else
  warn "Non-interactive mode: skipping login prompt."
fi

step "2) Create or reuse tunnel"
LIST_OUTPUT="$(run_cf tunnel list 2>&1 || true)"
if grep -qiE "error|failed|unauthorized|forbidden" <<<"$LIST_OUTPUT"; then
  err "Unable to list tunnels. Did you login successfully?"
  echo "$LIST_OUTPUT"
  exit 1
fi

TUNNEL_ID="$(extract_tunnel_id "$LIST_OUTPUT" "$TUNNEL_NAME" || true)"
if [[ -z "$TUNNEL_ID" ]]; then
  echo "Tunnel '$TUNNEL_NAME' not found. Creating..."
  CREATE_OUTPUT="$(run_cf tunnel create "$TUNNEL_NAME" 2>&1 || true)"
  if grep -qiE "error|failed|unauthorized|forbidden" <<<"$CREATE_OUTPUT"; then
    err "Failed to create tunnel."
    echo "$CREATE_OUTPUT"
    exit 1
  fi
  TUNNEL_ID="$(grep -Eo '[a-f0-9-]{36}' <<<"$CREATE_OUTPUT" | head -n1 || true)"
fi

if [[ -z "$TUNNEL_ID" ]]; then
  err "Could not detect tunnel ID automatically."
  echo "$LIST_OUTPUT"
  exit 1
fi
ok "Tunnel in use: $TUNNEL_NAME ($TUNNEL_ID)"

step "3) Create DNS routes"
for host in "$API_HOST" "$WS_HOST" "$AUTH_HOST"; do
  echo "Routing DNS for $host ..."
  ROUTE_OUT="$(run_cf tunnel route dns "$TUNNEL_NAME" "$host" 2>&1 || true)"
  if grep -qiE "error|failed|unauthorized|forbidden" <<<"$ROUTE_OUT"; then
    warn "Route for $host may already exist or failed:"
    echo "$ROUTE_OUT"
  else
    ok "DNS route created/confirmed: $host"
  fi
done

step "4) Generate tunnel token for Docker Swarm secret"
TOKEN_OUT="$(run_cf tunnel token "$TUNNEL_NAME" 2>&1 || true)"
if grep -qiE "error|failed|unauthorized|forbidden" <<<"$TOKEN_OUT"; then
  err "Failed to generate tunnel token."
  echo "$TOKEN_OUT"
  exit 1
fi
TUNNEL_TOKEN="$(echo "$TOKEN_OUT" | tail -n1 | tr -d '\r')"
if [[ -z "$TUNNEL_TOKEN" ]]; then
  err "Tunnel token output is empty."
  exit 1
fi
ok "Tunnel token generated."

echo
echo "Use this on swarm manager:"
echo "  echo '<TOKEN>' | docker secret create tunnel_token -"
echo "If secret exists:"
echo "  docker secret rm tunnel_token && echo '<TOKEN>' | docker secret create tunnel_token -"

step "5) Validate swarm/network/services"
SWARM_STATE="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)"
if [[ "$SWARM_STATE" == "active" ]]; then
  ok "Swarm is active."
else
  warn "Swarm is not active on this host (ignore if remote manager)."
fi

if docker network ls --format '{{.Name}}' | grep -qx "$DOCKER_NETWORK"; then
  ok "Docker network found: $DOCKER_NETWORK"
else
  warn "Docker network '$DOCKER_NETWORK' not found on this host."
fi

for svc in auth nakama tunnel; do
  FULL_NAME="${STACK_NAME}_${svc}"
  if docker service ls --format '{{.Name}}' 2>/dev/null | grep -qx "$FULL_NAME"; then
    ok "Service found: $FULL_NAME"
  else
    warn "Service not found: $FULL_NAME (might be on another host/cluster)."
  fi
done

if [[ "$SKIP_DNS_VALIDATION" != "true" ]]; then
  step "6) DNS validation"
  for host in "$API_HOST" "$WS_HOST" "$AUTH_HOST"; do
    if nslookup "$host" >/tmp/nslookup.out 2>&1; then
      ok "DNS resolves: $host"
    else
      warn "DNS lookup failed for $host"
      cat /tmp/nslookup.out
    fi
  done
fi

if [[ "$SKIP_HTTP_VALIDATION" != "true" ]]; then
  step "7) HTTPS smoke tests"
  for host in "$API_HOST" "$AUTH_HOST"; do
    URL="https://$host"
    if curl -sS -m 20 -o /dev/null -w "%{http_code}" "$URL" >/tmp/http_code.out 2>/tmp/http_err.out; then
      CODE="$(cat /tmp/http_code.out)"
      if [[ "$CODE" =~ ^[0-9]{3}$ ]]; then
        ok "$URL -> HTTP $CODE"
      else
        warn "$URL returned non-standard response: $CODE"
      fi
    else
      warn "Connection failed to $URL"
      cat /tmp/http_err.out || true
    fi
  done
fi

step "8) Final checklist"
echo "Configure these Public Hostnames in Zero Trust tunnel:"
echo "  - $API_HOST  -> http://nakama:7350"
echo "  - $WS_HOST   -> http://nakama:7350"
echo "  - $AUTH_HOST -> http://auth:8080"
echo
echo "Then update swarm secret tunnel_token and redeploy stack."
echo "Client WebSocket should use: wss://$WS_HOST"
ok "Setup finished."
