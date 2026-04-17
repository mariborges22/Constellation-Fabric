#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
LISTENER_80_ARN=""
LISTENER_443_ARN=""
DRY_RUN="true"
REPLACE_EXISTING="false"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/sync-alb-rules-80-to-443.sh --listener-80-arn <arn> --listener-443-arn <arn> [options]

Required:
  --listener-80-arn <arn>      Source listener (HTTP 80)
  --listener-443-arn <arn>     Target listener (HTTPS 443)

Optional:
  --region <aws-region>        AWS region (default: us-east-1)
  --apply                      Apply changes (default is dry-run)
  --replace-existing           Delete non-default rules on 443 before copying
  -h, --help                   Show this help

Examples:
  # preview only
  ./scripts/sync-alb-rules-80-to-443.sh \
    --listener-80-arn arn:.../47061976d57e71f4 \
    --listener-443-arn arn:.../0913089201f2f849

  # apply for real
  ./scripts/sync-alb-rules-80-to-443.sh \
    --listener-80-arn arn:.../47061976d57e71f4 \
    --listener-443-arn arn:.../0913089201f2f849 \
    --apply --replace-existing
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --listener-80-arn) LISTENER_80_ARN="$2"; shift 2 ;;
    --listener-443-arn) LISTENER_443_ARN="$2"; shift 2 ;;
    --region) AWS_REGION="$2"; shift 2 ;;
    --apply) DRY_RUN="false"; shift ;;
    --replace-existing) REPLACE_EXISTING="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "[ERRO] Unknown argument: $1"; usage; exit 1 ;;
  esac
done

if [[ -z "$LISTENER_80_ARN" || -z "$LISTENER_443_ARN" ]]; then
  echo "[ERRO] --listener-80-arn and --listener-443-arn are required."
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

awsq() {
  aws --region "$AWS_REGION" "$@" | tr -d '\r'
}

require_cmd aws
require_cmd python3

if ! awsq sts get-caller-identity >/dev/null 2>&1; then
  err "AWS auth failed in region $AWS_REGION."
  exit 1
fi

step "Sync ALB rules 80 -> 443"
ok "Mode: $([[ "$DRY_RUN" == "true" ]] && echo 'dry-run' || echo 'apply')"
ok "Region: $AWS_REGION"
ok "Source listener: $LISTENER_80_ARN"
ok "Target listener: $LISTENER_443_ARN"

SRC_JSON="$(awsq elbv2 describe-rules --listener-arn "$LISTENER_80_ARN" --output json)"
DST_JSON="$(awsq elbv2 describe-rules --listener-arn "$LISTENER_443_ARN" --output json)"

python3 - <<PY > /tmp/alb_sync_plan.json
import json

src=json.loads('''$SRC_JSON''').get("Rules", [])
dst=json.loads('''$DST_JSON''').get("Rules", [])

src_non_default=[r for r in src if str(r.get("Priority")) != "default"]
dst_non_default=[r for r in dst if str(r.get("Priority")) != "default"]

def normalize_conditions(conds):
    out=[]
    for c in conds:
        c=dict(c)
        c.pop("Values", None)  # keep modern configs only
        out.append(c)
    return out

def normalize_action(a):
    t=a.get("Type")
    if t=="forward":
        tg=a.get("TargetGroupArn")
        if tg:
            return {"Type":"forward","TargetGroupArn":tg}
        fc=a.get("ForwardConfig")
        if fc:
            return {"Type":"forward","ForwardConfig":fc}
    if t=="redirect":
        return {"Type":"redirect","RedirectConfig":a.get("RedirectConfig",{})}
    if t=="fixed-response":
        return {"Type":"fixed-response","FixedResponseConfig":a.get("FixedResponseConfig",{})}
    if t=="authenticate-cognito":
        return {"Type":"authenticate-cognito","AuthenticateCognitoConfig":a.get("AuthenticateCognitoConfig",{})}
    if t=="authenticate-oidc":
        return {"Type":"authenticate-oidc","AuthenticateOidcConfig":a.get("AuthenticateOidcConfig",{})}
    return {"Type":t}

plan=[]
for r in src_non_default:
    actions=[normalize_action(a) for a in r.get("Actions",[])]
    item={
        "priority": str(r.get("Priority")),
        "conditions": normalize_conditions(r.get("Conditions",[])),
        "actions": actions
    }
    plan.append(item)

print(json.dumps({
    "src_rule_count": len(src_non_default),
    "dst_rule_count": len(dst_non_default),
    "dst_rule_arns": [r.get("RuleArn") for r in dst_non_default],
    "plan": plan
}, indent=2))
PY

step "Plan summary"
python3 - <<'PY'
import json
p=json.load(open("/tmp/alb_sync_plan.json"))
print(f"Source non-default rules: {p['src_rule_count']}")
print(f"Target non-default rules: {p['dst_rule_count']}")
for item in p["plan"]:
    print(f"- priority {item['priority']} (conditions={len(item['conditions'])}, actions={len(item['actions'])})")
PY

if [[ "$DRY_RUN" == "true" ]]; then
  ok "Dry-run only. No changes applied."
  echo "To apply:"
  echo "  $0 --listener-80-arn \"$LISTENER_80_ARN\" --listener-443-arn \"$LISTENER_443_ARN\" --region \"$AWS_REGION\" --apply --replace-existing"
  exit 0
fi

if [[ "$REPLACE_EXISTING" == "true" ]]; then
  step "Deleting existing non-default rules from 443"
  python3 - <<'PY' > /tmp/alb_dst_rule_arns.txt
import json
p=json.load(open("/tmp/alb_sync_plan.json"))
for arn in p["dst_rule_arns"]:
    if arn:
        print(arn)
PY
  if [[ -s /tmp/alb_dst_rule_arns.txt ]]; then
    while IFS= read -r arn; do
      awsq elbv2 delete-rule --rule-arn "$arn" >/dev/null </dev/null
      ok "Deleted existing rule: $arn"
    done < /tmp/alb_dst_rule_arns.txt
  else
    ok "No existing non-default rules on 443."
  fi
else
  warn "Keeping existing rules on 443. Creation may fail on duplicate priorities."
fi

step "Creating rules on 443"
python3 - <<'PY' > /tmp/alb_create_commands.txt
import json, base64
p=json.load(open("/tmp/alb_sync_plan.json"))
for item in p["plan"]:
    payload=json.dumps(item, separators=(",",":"))
    print(base64.b64encode(payload.encode()).decode())
PY

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  decoded="$(python3 - <<PY
import base64
print(base64.b64decode("$line").decode())
PY
)"
  priority="$(python3 - <<PY
import json
d=json.loads('''$decoded''')
print(d["priority"])
PY
)"
  conditions="$(python3 - <<PY
import json
d=json.loads('''$decoded''')
print(json.dumps(d["conditions"], separators=(",",":")))
PY
)"
  actions="$(python3 - <<PY
import json
d=json.loads('''$decoded''')
print(json.dumps(d["actions"], separators=(",",":")))
PY
)"
  awsq elbv2 create-rule \
    --listener-arn "$LISTENER_443_ARN" \
    --priority "$priority" \
    --conditions "$conditions" \
    --actions "$actions" >/dev/null </dev/null
  ok "Created rule on 443 with priority $priority"
done < /tmp/alb_create_commands.txt

step "Done"
ok "Rules from 80 listener copied to 443."
ok "Validate with: aws elbv2 describe-rules --region $AWS_REGION --listener-arn $LISTENER_443_ARN --output json"
