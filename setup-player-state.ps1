# ============================================================================
# CONSTELLATION FABRICK - Player State Remote Discovery Script
# For ECS-based Player State & Postgres
# ============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "DISCOVERING: Player State Remote Environment" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host ""

# Variables
$PROJECT_NAME = "constellation"
$REGION = "us-east-1"

# ============================================================================
# CHECK AWS RESOURCES
# =============================================================

Write-Host "[1/3] Checking ECS Cluster $PROJECT_NAME-cluster..." -ForegroundColor Yellow

$cluster = aws ecs describe-clusters --clusters "$PROJECT_NAME-cluster" --region $REGION | ConvertFrom-Json
if ($null -eq $cluster.clusters) {
    Write-Host "AVISO: Cluster nao encontrado. Certifique-se de que o Terraform foi aplicado." -ForegroundColor Red
} else {
    Write-Host "  OK -> Cluster is $($cluster.clusters[0].status)" -ForegroundColor Green
}

Write-Host ""
Write-Host "[2/3] Checking Services..." -ForegroundColor Yellow

$services = @("player-state-service", "postgres-service")
foreach ($svc in $services) {
    $status = aws ecs describe-services --cluster "$PROJECT_NAME-cluster" --services $svc --region $REGION | ConvertFrom-Json
    if ($status.services.Count -gt 0) {
        Write-Host "  OK -> $svc is $($status.services[0].status) (Running: $($status.services[0].runningCount))" -ForegroundColor Green
    } else {
        Write-Host "  AVISO -> $svc nao encontrado." -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "[3/3] Discovering ALB Endpoint..." -ForegroundColor Yellow

$alb = aws elbv2 describe-load-balancers --region $REGION | ConvertFrom-Json
$gameAlb = $alb.LoadBalancers | Where-Object { $_.LoadBalancerName -like "*$PROJECT_NAME*" }

if ($null -ne $gameAlb) {
    $dns = $gameAlb.DNSName
    Write-Host "  OK -> Application Load Balancer: http://$dns" -ForegroundColor Green
    Write-Host "  [*] Player State API: http://$dns/api/v1/players" -ForegroundColor Cyan
} else {
    Write-Host "  AVISO -> ALB nao encontrado." -ForegroundColor Yellow
}

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SUMMARY & NEXT STEPS" -ForegroundColor Cyan
Write-Host "================================================"

$summary = @"
STATUS: ECS Infrastructure Provisioned
Database: Remote PostgreSQL (ECS Service)
Migrations: Automatic (Managed by Rust service)

CONNECTIVITY:
- Internal DB: postgres.local:5432
- External API: http://$dns/api/v1/players

NEXT STEPS:
1. git add .
2. git commit -m "feat: implement /v1 API and idempotency"
3. git push
4. Wait for CI/CD to deploy to ECR and reach Staging.
================================================
"@

Write-Host $summary -ForegroundColor White
$summary | Out-File -FilePath "setup-player-state-remote-summary.txt" -Encoding UTF8
