#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ENV_FILE="${ENV_FILE:-.env.cloudflare}"
DOMAIN=""
ALB_ARN=""
CERT_ARN=""
DEFAULT_TG_ARN=""
OPEN_443_CIDR="${OPEN_443_CIDR:-0.0.0.0/0}"
WAIT_TIMEOUT_SEC="${WAIT_TIMEOUT_SEC:-900}"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/enable-alb-https-strict.sh --domain constellationfabric.com --alb-arn <alb-arn> [options]

Required:
  --domain <domain>                     Root domain (e.g. constellationfabric.com)
  --alb-arn <alb-arn>                   ALB ARN

Optional:
  --region <aws-region>                 AWS region (default: us-east-1)
  --env-file <path>                     Env file with Cloudflare API creds (default: .env.cloudflare)
  --cert-arn <acm-cert-arn>             Reuse existing ACM cert (skip request/validation)
  --default-target-group-arn <tg-arn>   Target group for HTTPS listener default action
  --open-443-cidr <cidr>                Add inbound 443 on ALB SG(s), default 0.0.0.0/0
  --wait-timeout-sec <seconds>          Wait timeout for ACM issuance (default 900)
  -h, --help                            Show help

Env vars expected in env file:
  CF_API_TOKEN=...
  CF_ZONE_ID=...
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --alb-arn) ALB_ARN="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --env-file) ENV_FILE="$2"; shift 2 ;;
    --cert-arn) CERT_ARN="$2"; shift 2 ;;
    --default-target-group-arn) DEFAULT_TG_ARN="$2"; shift 2 ;;
    --open-443-cidr) OPEN_443_CIDR="$2"; shift 2 ;;
    --wait-timeout-sec) WAIT_TIMEOUT_SEC="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERRO] Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$DOMAIN" || -z "$ALB_ARN" ]]; then
  echo "[ERRO] --domain and --alb-arn are required."
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

awsq() {
  aws --region "$AWS_REGION" "$@" | tr -d '\r'
}

step "Enable ALB HTTPS for Cloudflare Full (strict)"
require_cmd aws
require_cmd curl
require_cmd python3
require_cmd sed

if ! awsq sts get-caller-identity >/dev/null 2>&1; then
  err "AWS auth failed in region $AWS_REGION."
  exit 1
fi
ok "AWS authentication valid."

if [[ ! -f "$ENV_FILE" ]]; then
  err "Env file '$ENV_FILE' not found. Create from .env.cloudflare.example first."
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE" || true
CF_API_TOKEN="$(trim_cr "${CF_API_TOKEN:-}")"
CF_ZONE_ID="$(trim_cr "${CF_ZONE_ID:-}")"

if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" ]]; then
  err "CF_API_TOKEN and CF_ZONE_ID are required in $ENV_FILE."
  exit 1
fi
if [[ ! "$CF_ZONE_ID" =~ ^[a-fA-F0-9]{32}$ ]]; then
  err "CF_ZONE_ID format looks invalid."
  exit 1
fi

verify_zone="$(cf_api GET "/zones/$CF_ZONE_ID")"
zone_ok="$(python3 - <<PY
import json
d=json.loads('''$verify_zone''')
print("1" if d.get("success") else "0")
PY
)"
if [[ "$zone_ok" != "1" ]]; then
  err "Cloudflare token cannot access zone $CF_ZONE_ID."
  echo "$verify_zone"
  exit 1
fi
ok "Cloudflare token + zone access validated."

step "1) Ensure ALB security groups allow inbound 443"
SG_IDS="$(awsq elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --query "LoadBalancers[0].SecurityGroups[]" --output text)"
if [[ -z "$SG_IDS" ]]; then
  err "Could not resolve ALB security groups."
  exit 1
fi
for sg in $SG_IDS; do
  sg="$(trim_cr "$sg")"
  has_443="$(awsq ec2 describe-security-groups --group-ids "$sg" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`443\` && ToPort==\`443\` && IpProtocol=='tcp'] | length(@)" \
    --output text)"
  if [[ "$has_443" == "0" ]]; then
    warn "Adding 443/tcp ingress to SG $sg for $OPEN_443_CIDR"
    awsq ec2 authorize-security-group-ingress \
      --group-id "$sg" \
      --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=$OPEN_443_CIDR,Description=Cloudflare-to-ALB HTTPS}]"
    ok "Ingress 443 added on SG $sg"
  else
    ok "SG $sg already allows 443"
  fi
done

if [[ -z "$CERT_ARN" ]]; then
  step "2) Request ACM certificate (DNS validation)"
  req_json="$(awsq acm request-certificate \
    --domain-name "$DOMAIN" \
    --subject-alternative-names "*.$DOMAIN" \
    --validation-method DNS \
    --idempotency-token "cf$(date +%s | tail -c 9)" \
    --query '{CertificateArn:CertificateArn}' \
    --output json)"
  CERT_ARN="$(python3 - <<PY
import json
d=json.loads('''$req_json''')
print(d.get("CertificateArn",""))
PY
)"
  if [[ -z "$CERT_ARN" ]]; then
    err "Failed to request ACM certificate."
    exit 1
  fi
  ok "Requested ACM certificate: $CERT_ARN"

  upsert_env_var "$ENV_FILE" "ACM_CERT_ARN" "$CERT_ARN"
  ok "Saved ACM_CERT_ARN to $ENV_FILE"

  step "3) Create DNS validation records in Cloudflare"
  cert_desc="$(awsq acm describe-certificate --certificate-arn "$CERT_ARN" --output json)"
  python3 - <<PY > /tmp/acm_records.txt
import json
d=json.loads('''$cert_desc''')
for opt in d.get("Certificate", {}).get("DomainValidationOptions", []):
    rr=opt.get("ResourceRecord") or {}
    name=rr.get("Name")
    value=rr.get("Value")
    rtype=rr.get("Type")
    if name and value and rtype:
        print(f"{name}|{rtype}|{value}")
PY

  if [[ ! -s /tmp/acm_records.txt ]]; then
    warn "ACM validation records not ready yet. Waiting..."
    start_records_ts="$(date +%s)"
    while true; do
      cert_desc="$(awsq acm describe-certificate --certificate-arn "$CERT_ARN" --output json)"
      python3 - <<PY > /tmp/acm_records.txt
import json
d=json.loads('''$cert_desc''')
for opt in d.get("Certificate", {}).get("DomainValidationOptions", []):
    rr=opt.get("ResourceRecord") or {}
    name=rr.get("Name")
    value=rr.get("Value")
    rtype=rr.get("Type")
    if name and value and rtype:
        print(f"{name}|{rtype}|{value}")
PY
      if [[ -s /tmp/acm_records.txt ]]; then
        ok "ACM validation records are now available."
        break
      fi
      now_records_ts="$(date +%s)"
      if (( now_records_ts - start_records_ts > WAIT_TIMEOUT_SEC )); then
        err "Timed out waiting for ACM validation records."
        exit 1
      fi
      sleep 10
    done
  fi

  while IFS='|' read -r rec_name rec_type rec_value; do
    rec_name="${rec_name%.}"
    payload="$(python3 - <<PY
import json
print(json.dumps({
  "type":"$rec_type",
  "name":"$rec_name",
  "content":"$rec_value",
  "ttl":120,
  "proxied":False
}))
PY
)"
    # Upsert by name+type
    list_resp="$(cf_api GET "/zones/$CF_ZONE_ID/dns_records?type=$rec_type&name=$rec_name")"
    rec_id="$(python3 - <<PY
import json
d=json.loads('''$list_resp''')
r=d.get("result") or []
print(r[0].get("id","") if r else "")
PY
)"
    if [[ -n "$rec_id" ]]; then
      cf_api PUT "/zones/$CF_ZONE_ID/dns_records/$rec_id" "$payload" >/dev/null
      ok "Updated validation record: $rec_name"
    else
      cf_api POST "/zones/$CF_ZONE_ID/dns_records" "$payload" >/dev/null
      ok "Created validation record: $rec_name"
    fi
  done < /tmp/acm_records.txt

  step "4) Wait for certificate issuance"
  start_ts="$(date +%s)"
  while true; do
    status="$(awsq acm describe-certificate --certificate-arn "$CERT_ARN" --query "Certificate.Status" --output text)"
    if [[ "$status" == "ISSUED" ]]; then
      ok "Certificate issued."
      break
    fi
    if [[ "$status" == "FAILED" ]]; then
      err "Certificate validation failed."
      exit 1
    fi
    now_ts="$(date +%s)"
    if (( now_ts - start_ts > WAIT_TIMEOUT_SEC )); then
      err "Timed out waiting for ACM issuance (status=$status)."
      exit 1
    fi
    echo "Waiting for ACM issuance... current status=$status"
    sleep 15
  done
else
  ok "Using existing certificate ARN: $CERT_ARN"
fi

step "5) Resolve default target group for HTTPS listener"
if [[ -z "$DEFAULT_TG_ARN" ]]; then
  DEFAULT_TG_ARN="$(awsq elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
    --query "Listeners[?Port==\`80\`].DefaultActions[0].TargetGroupArn | [0]" \
    --output text)"
  if [[ "$DEFAULT_TG_ARN" == "None" || -z "$DEFAULT_TG_ARN" ]]; then
    err "Could not infer target group from port 80 listener. Pass --default-target-group-arn."
    exit 1
  fi
fi
ok "HTTPS default target group: $DEFAULT_TG_ARN"

step "6) Create or update ALB listener 443"
existing_443="$(awsq elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" \
  --query "Listeners[?Port==\`443\`].ListenerArn | [0]" --output text)"

if [[ "$existing_443" == "None" || -z "$existing_443" ]]; then
  new_listener="$(awsq elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTPS \
    --port 443 \
    --certificates "CertificateArn=$CERT_ARN" \
    --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
    --default-actions "Type=forward,TargetGroupArn=$DEFAULT_TG_ARN" \
    --query "Listeners[0].ListenerArn" \
    --output text)"
  ok "Created HTTPS listener: $new_listener"
else
  awsq elbv2 modify-listener \
    --listener-arn "$existing_443" \
    --certificates "CertificateArn=$CERT_ARN" \
    --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
    --default-actions "Type=forward,TargetGroupArn=$DEFAULT_TG_ARN" >/dev/null
  ok "Updated existing HTTPS listener: $existing_443"
fi

step "Done"
ok "ALB now serves HTTPS with ACM cert."
echo "Cloudflare SSL/TLS mode can stay on Full (strict)."
echo "Validate now:"
echo "  curl -I https://$DOMAIN"
echo "  curl -I https://api.$DOMAIN"
echo "  curl -I https://auth.$DOMAIN"
