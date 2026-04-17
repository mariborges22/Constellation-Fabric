#!/usr/bin/env bash
set -euo pipefail

DOMAIN=""
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-}"
ALB_DNS_NAME="${ALB_DNS_NAME:-}"
ALB_ARN="${ALB_ARN:-}"
AUTH_HOST=""
API_HOST=""
WS_HOST=""
TAIL_LINES="${TAIL_LINES:-40}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/debug-fargate-cloudflare.sh --domain constellationfabric.com [options]

Required:
  --domain <domain>                  Root domain (e.g. constellationfabric.com)

Optional:
  --region <aws-region>              AWS region (default: us-east-1)
  --cluster <ecs-cluster-name>       ECS cluster name (if omitted, auto-detect attempted)
  --alb-dns <alb-dns-name>           ALB DNS name (if omitted, auto-detect attempted)
  --alb-arn <alb-arn>                ALB ARN (if omitted, derived from --alb-dns or auto-detect)
  --api-host <host>                  Override api host (default: api.<domain>)
  --auth-host <host>                 Override auth host (default: auth.<domain>)
  --ws-host <host>                   Override ws host (default: ws.<domain>)
  --tail-lines <n>                   Number of ECS event lines (default: 40)
  -h, --help                         Show this help

Examples:
  ./scripts/debug-fargate-cloudflare.sh --domain constellationfabric.com --region us-east-1
  ./scripts/debug-fargate-cloudflare.sh --domain constellationfabric.com --cluster constellation-fabric-staging
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --cluster) CLUSTER_NAME="$2"; shift 2 ;;
    --alb-dns) ALB_DNS_NAME="$2"; shift 2 ;;
    --alb-arn) ALB_ARN="$2"; shift 2 ;;
    --api-host) API_HOST="$2"; shift 2 ;;
    --auth-host) AUTH_HOST="$2"; shift 2 ;;
    --ws-host) WS_HOST="$2"; shift 2 ;;
    --tail-lines) TAIL_LINES="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERRO] Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" ]]; then
  echo "[ERRO] --domain is required."
  usage
  exit 1
fi

API_HOST="${API_HOST:-api.$DOMAIN}"
AUTH_HOST="${AUTH_HOST:-auth.$DOMAIN}"
WS_HOST="${WS_HOST:-ws.$DOMAIN}"

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

awsq() {
  aws --region "$AWS_REGION" "$@"
}

first_non_empty_line() {
  awk 'NF {print; exit}'
}

http_check() {
  local url="$1"
  local code
  code="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' "$url" || true)"
  if [[ "$code" =~ ^[0-9]{3}$ ]]; then
    echo "$code"
  else
    echo "000"
  fi
}

step "Fargate + Cloudflare diagnostics"
require_cmd aws
require_cmd curl
if ! command -v nslookup >/dev/null 2>&1; then
  warn "nslookup not found (install dnsutils for richer DNS output)."
fi

if ! awsq sts get-caller-identity >/dev/null 2>&1; then
  err "AWS CLI auth failed for region $AWS_REGION."
  exit 1
fi
ok "AWS authentication is valid in region $AWS_REGION."

step "1) DNS and Cloudflare edge checks"
for host in "$API_HOST" "$AUTH_HOST" "$WS_HOST"; do
  if command -v nslookup >/dev/null 2>&1; then
    if nslookup "$host" >/tmp/ns.out 2>/tmp/ns.err; then
      ok "DNS resolves: $host"
      sed -n '1,18p' /tmp/ns.out
    else
      warn "DNS lookup failed: $host"
      sed -n '1,18p' /tmp/ns.err
    fi
  fi
done

for url in "https://$API_HOST" "https://$AUTH_HOST"; do
  code="$(http_check "$url")"
  if [[ "$code" == "530" ]]; then
    warn "$url -> HTTP 530 (Cloudflare cannot reach healthy origin)"
  elif [[ "$code" == "000" ]]; then
    warn "$url -> connection failure"
  else
    ok "$url -> HTTP $code"
  fi
done

step "2) Discover ALB and ECS cluster (if needed)"
if [[ -z "$ALB_ARN" && -n "$ALB_DNS_NAME" ]]; then
  ALB_ARN="$(awsq elbv2 describe-load-balancers \
    --query "LoadBalancers[?DNSName=='$ALB_DNS_NAME'].LoadBalancerArn | [0]" \
    --output text 2>/dev/null || true)"
  [[ "$ALB_ARN" == "None" ]] && ALB_ARN=""
fi

if [[ -z "$ALB_ARN" ]]; then
  # Try best-effort auto-detect by domain hint in tags/name
  ALB_ARN="$(awsq elbv2 describe-load-balancers \
    --query "LoadBalancers[?contains(DNSName, 'constellation')].LoadBalancerArn | [0]" \
    --output text 2>/dev/null || true)"
  [[ "$ALB_ARN" == "None" ]] && ALB_ARN=""
fi

if [[ -n "$ALB_ARN" && -z "$ALB_DNS_NAME" ]]; then
  ALB_DNS_NAME="$(awsq elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query "LoadBalancers[0].DNSName" \
    --output text 2>/dev/null || true)"
  [[ "$ALB_DNS_NAME" == "None" ]] && ALB_DNS_NAME=""
fi

if [[ -z "$CLUSTER_NAME" ]]; then
  CLUSTER_NAME="$(awsq ecs list-clusters --query "clusterArns[0]" --output text 2>/dev/null || true)"
  if [[ -n "$CLUSTER_NAME" && "$CLUSTER_NAME" != "None" ]]; then
    CLUSTER_NAME="${CLUSTER_NAME##*/}"
  else
    CLUSTER_NAME=""
  fi
fi

if [[ -n "$ALB_ARN" ]]; then
  ok "Using ALB ARN: $ALB_ARN"
else
  warn "ALB ARN not resolved automatically. Pass --alb-arn for full ALB checks."
fi

if [[ -n "$ALB_DNS_NAME" ]]; then
  ok "Using ALB DNS: $ALB_DNS_NAME"
else
  warn "ALB DNS not resolved automatically. Pass --alb-dns for origin comparison."
fi

if [[ -n "$CLUSTER_NAME" ]]; then
  ok "Using ECS cluster: $CLUSTER_NAME"
else
  warn "ECS cluster not resolved automatically. Pass --cluster for ECS checks."
fi

step "3) ALB health path checks"
if [[ -n "$ALB_DNS_NAME" ]]; then
  for path in "/" "/api/v1/auth/health" "/api/v1/combat/health" "/api/v1/players/health"; do
    code="$(http_check "http://$ALB_DNS_NAME$path")"
    if [[ "$code" == "000" ]]; then
      warn "ALB http://$ALB_DNS_NAME$path -> connection failure"
    else
      ok "ALB http://$ALB_DNS_NAME$path -> HTTP $code"
    fi
  done
else
  warn "Skipping ALB path checks (missing ALB DNS)."
fi

step "4) Target groups and target health"
if [[ -n "$ALB_ARN" ]]; then
  TG_ARNS="$(awsq elbv2 describe-target-groups --load-balancer-arn "$ALB_ARN" \
    --query "TargetGroups[].TargetGroupArn" --output text 2>/dev/null || true)"
  if [[ -z "$TG_ARNS" ]]; then
    warn "No target groups found for ALB."
  else
    for tg in $TG_ARNS; do
      name="$(awsq elbv2 describe-target-groups --target-group-arns "$tg" \
        --query "TargetGroups[0].TargetGroupName" --output text 2>/dev/null || true)"
      ok "Target group: $name"
      awsq elbv2 describe-target-health --target-group-arn "$tg" \
        --query "TargetHealthDescriptions[].{Id:Target.Id,Port:Target.Port,State:TargetHealth.State,Reason:TargetHealth.Reason,Description:TargetHealth.Description}" \
        --output table || true
    done
  fi
else
  warn "Skipping target group checks (missing ALB ARN)."
fi

step "5) ECS services, running tasks, and recent events"
if [[ -n "$CLUSTER_NAME" ]]; then
  SERVICE_ARNS="$(awsq ecs list-services --cluster "$CLUSTER_NAME" --query "serviceArns[]" --output text 2>/dev/null || true)"
  if [[ -z "$SERVICE_ARNS" ]]; then
    warn "No ECS services found in cluster $CLUSTER_NAME."
  else
    # shellcheck disable=SC2206
    services=( $SERVICE_ARNS )
    for svc_arn in "${services[@]}"; do
      svc_name="${svc_arn##*/}"
      ok "Service: $svc_name"
      awsq ecs describe-services --cluster "$CLUSTER_NAME" --services "$svc_name" \
        --query "services[0].{Desired:desiredCount,Running:runningCount,Pending:pendingCount,Status:status,LaunchType:launchType,TaskDef:taskDefinition}" \
        --output table || true

      echo "--- Recent events ($TAIL_LINES) for $svc_name ---"
      awsq ecs describe-services --cluster "$CLUSTER_NAME" --services "$svc_name" \
        --query "services[0].events[:$TAIL_LINES].[createdAt,message]" --output table || true
      echo
    done
  fi
else
  warn "Skipping ECS checks (missing cluster)."
fi

step "6) Quick interpretation"
echo "- DNS OK + HTTP 530 on Cloudflare host => Cloudflare cannot reach healthy origin."
echo "- ALB health endpoints failing => service/target group/task issue (ECS side)."
echo "- Targets unhealthy => check ECS task logs, SG rules, container port mapping and health checks."
echo "- ECS desired > running/pending stuck => capacity/task-def/secrets/env issue."
echo "- If ALB responds but Cloudflare host still 530 => verify Cloudflare DNS/proxy mode and tunnel/public hostname origin mapping."

ok "Diagnostics complete."
