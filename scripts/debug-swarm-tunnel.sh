#!/usr/bin/env bash
set -euo pipefail

STACK_NAME="${STACK_NAME:-constellation}"
DOMAIN="${DOMAIN:-}"
DOCKER_NETWORK="${DOCKER_NETWORK:-constellation-net}"
CF_TUNNEL_NAME="${CF_TUNNEL_NAME:-constellation-staging}"
CF_IMAGE="${CF_IMAGE:-cloudflare/cloudflared:latest}"
LOG_TAIL="${LOG_TAIL:-120}"

RED=$'\033[31m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'
CYAN=$'\033[36m'
RESET=$'\033[0m'

usage() {
  cat <<'EOF'
Usage:
  ./scripts/debug-swarm-tunnel.sh --domain constellationfabric.com [options]

Options:
  --domain <domain>              Root domain to test (required)
  --stack-name <name>            Docker stack name (default: constellation)
  --docker-network <name>        Expected docker network (default: constellation-net)
  --cf-tunnel-name <name>        Cloudflare tunnel name (default: constellation-staging)
  --log-tail <n>                 Number of log lines to show per service (default: 120)
  -h, --help                     Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain)
      DOMAIN="$2"
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
    --cf-tunnel-name)
      CF_TUNNEL_NAME="$2"
      shift 2
      ;;
    --log-tail)
      LOG_TAIL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "${RED}[ERRO]${RESET} Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "${RED}[ERRO]${RESET} --domain is required."
  usage
  exit 1
fi

API_HOST="api.$DOMAIN"
WS_HOST="ws.$DOMAIN"
AUTH_HOST="auth.$DOMAIN"

step() {
  echo
  echo "${CYAN}============================================================${RESET}"
  echo "${CYAN}$1${RESET}"
  echo "${CYAN}============================================================${RESET}"
}

ok() { echo "${GREEN}[OK]${RESET} $1"; }
warn() { echo "${YELLOW}[WARN]${RESET} $1"; }
err() { echo "${RED}[ERRO]${RESET} $1"; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

print_cmd_output() {
  local title="$1"
  local cmd="$2"
  echo "--- $title ---"
  if bash -lc "$cmd" >/tmp/debug_cmd.out 2>/tmp/debug_cmd.err; then
    cat /tmp/debug_cmd.out
  else
    cat /tmp/debug_cmd.err
  fi
  echo
}

step "Swarm + Tunnel Debugger"

for c in docker curl; do
  if ! has_cmd "$c"; then
    err "Missing command: $c"
    exit 1
  fi
done
ok "Required commands found (docker, curl)."

if ! docker version >/dev/null 2>&1; then
  err "Docker daemon not reachable."
  exit 1
fi
ok "Docker daemon reachable."

step "1) Docker / Swarm status"
print_cmd_output "docker version (short)" "docker version --format 'Client: {{.Client.Version}} | Server: {{.Server.Version}}'"
SWARM_STATE="$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || true)"
if [[ "$SWARM_STATE" == "active" ]]; then
  ok "Swarm is active on this host."
else
  warn "Swarm is NOT active on this host."
  echo "Hint: run 'docker swarm init' if this should be manager."
fi
print_cmd_output "docker info swarm" "docker info --format 'NodeState={{.Swarm.LocalNodeState}} | ControlAvailable={{.Swarm.ControlAvailable}} | NodeID={{.Swarm.NodeID}}'"
print_cmd_output "docker node ls" "docker node ls"

step "2) Stack / services / tasks"
print_cmd_output "docker stack ls" "docker stack ls"
print_cmd_output "docker stack services $STACK_NAME" "docker stack services $STACK_NAME"
print_cmd_output "docker stack ps $STACK_NAME" "docker stack ps $STACK_NAME --no-trunc"

SERVICES=(auth combat player-state nakama tunnel)
for svc in "${SERVICES[@]}"; do
  full="${STACK_NAME}_${svc}"
  if docker service inspect "$full" >/dev/null 2>&1; then
    ok "Service exists: $full"
    print_cmd_output "service ps $full" "docker service ps $full --no-trunc"
    print_cmd_output "service logs $full (last $LOG_TAIL)" "docker service logs --tail $LOG_TAIL $full"
  else
    warn "Service not found: $full"
  fi
done

step "3) Secrets / network / images"
print_cmd_output "docker secret ls" "docker secret ls"
for sec in db_url jwt_key tunnel_token; do
  if docker secret inspect "$sec" >/dev/null 2>&1; then
    ok "Secret found: $sec"
  else
    warn "Missing secret: $sec"
  fi
done

if docker network inspect "$DOCKER_NETWORK" >/dev/null 2>&1; then
  ok "Network found: $DOCKER_NETWORK"
  print_cmd_output "network inspect $DOCKER_NETWORK (name + driver)" "docker network inspect $DOCKER_NETWORK --format 'Name={{.Name}} Driver={{.Driver}} Scope={{.Scope}}'"
else
  warn "Network missing: $DOCKER_NETWORK"
fi

print_cmd_output "local images" "docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' | head -n 40"

step "4) Domain / DNS / HTTPS checks"
for host in "$API_HOST" "$WS_HOST" "$AUTH_HOST"; do
  if has_cmd nslookup; then
    if nslookup "$host" >/tmp/ns.out 2>/tmp/ns.err; then
      ok "DNS resolves: $host"
      sed -n '1,20p' /tmp/ns.out
    else
      warn "DNS failed: $host"
      cat /tmp/ns.err
    fi
  else
    warn "nslookup not installed; skipping DNS query for $host"
  fi
done

for url in "https://$API_HOST" "https://$AUTH_HOST"; do
  code="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "$url" || true)"
  if [[ "$code" =~ ^[0-9]{3}$ ]]; then
    if [[ "$code" == "200" || "$code" == "401" || "$code" == "404" ]]; then
      ok "$url -> HTTP $code (upstream responding)"
    else
      warn "$url -> HTTP $code"
    fi
  else
    warn "$url -> connection failed"
  fi
done

step "5) Optional Cloudflare tunnel inspect (if creds exist)"
if [[ -f ".cloudflared/cert.pem" ]]; then
  ok "Found .cloudflared/cert.pem, running cloudflared tunnel list..."
  if docker run --rm -v "$PWD/.cloudflared:/home/nonroot/.cloudflared" "$CF_IMAGE" tunnel list >/tmp/cf_list.out 2>/tmp/cf_list.err; then
    cat /tmp/cf_list.out
    echo
    if grep -q "$CF_TUNNEL_NAME" /tmp/cf_list.out; then
      ok "Tunnel appears in list: $CF_TUNNEL_NAME"
    else
      warn "Tunnel not found by name: $CF_TUNNEL_NAME"
    fi
  else
    warn "Could not query cloudflared tunnel list."
    cat /tmp/cf_list.err
  fi
else
  warn "No .cloudflared/cert.pem in current directory; skipping cloudflared list."
fi

step "6) Quick diagnosis summary"
echo "- If Swarm inactive: run 'docker swarm init' on intended manager."
echo "- If services missing: deploy stack with 'docker stack deploy -c docker-stack.yml $STACK_NAME'."
echo "- If secrets missing: create db_url, jwt_key, tunnel_token before deploy."
echo "- If Nakama restarting: check database endpoint/config first."
echo "- If HTTP 530: tunnel hostnames exist but upstream service is not healthy/routable."
echo
ok "Debug run finished."
