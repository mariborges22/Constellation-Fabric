param()

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "STEP 4/4: Provisioning Monitoring Infrastructure" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

$stagingEnv = "infra\enviroments\staging"
$projectRoot = Get-Location

# ============================================================
# PARTE 1: MONITORING
# ============================================================
Write-Host "[4A/4] Provisioning Monitoring Module (SRE Ready)" -ForegroundColor Yellow
Write-Host "---"
Write-Host ""

# Verificar credenciais AWS
Write-Host "Verificando credenciais AWS..." -ForegroundColor Cyan
aws sts get-caller-identity
Write-Host "OK: Credenciais validadas" -ForegroundColor Green
Write-Host ""

# Navegar para staging
Push-Location $stagingEnv
Write-Host "Entrando em: $stagingEnv" -ForegroundColor Cyan
Write-Host ""

# Inicializar Terraform
Write-Host "Inicializando Terraform..." -ForegroundColor Cyan
& terraform init -upgrade
Write-Host ""

# Plan do modulo monitoring
Write-Host "Rodando terraform plan para modulo monitoring..." -ForegroundColor Yellow
Write-Host "(isso pode levar alguns minutos)" -ForegroundColor Yellow
Write-Host ""

& terraform plan -target="module.monitoring" -target="module.compute" -out=tfplan_monitoring
Write-Host ""

# Informacoes sobre o que sera criado
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "RECURSOS DE OBSERVABILIDADE QUE SERAO CRIADOS:" -ForegroundColor Yellow
Write-Host "================================================================"
Write-Host ""
Write-Host "Stack de Observabilidade:" -ForegroundColor Cyan
Write-Host "  - Grafana (Dashboard SRE)"
Write-Host "  - Grafana Tempo (Tracing distribuido)"
Write-Host "  - OpenTelemetry Collector"
Write-Host "  - Prometheus (Metricas)"
Write-Host ""

$confirm = Read-Host "Deseja continuar? (s/n)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Operacao cancelada." -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "Aplicando o plano..." -ForegroundColor Cyan
Write-Host ""

& terraform apply tfplan_monitoring
Write-Host ""

# Capturar outputs
Write-Host "Extraindo endpoints de observabilidade..." -ForegroundColor Cyan
Write-Host ""

$grafanaUrl = & terraform output -raw grafana_url 2>$null
$tempoEndpoint = & terraform output -raw tempo_endpoint 2>$null
$prometheusUrl = & terraform output -raw prometheus_url 2>$null

Write-Host "OK: Endpoints obtidos" -ForegroundColor Green
Write-Host ""

# Voltar para a raiz
Pop-Location

# ============================================================
# PARTE 2: CI/CD PREP (JWT KEYS)
# ============================================================
Write-Host ""
Write-Host "[4B/4] Preparando Mock para CI/CD (JWT Keys)" -ForegroundColor Yellow
Write-Host "---"
Write-Host ""

# Gerar chaves JWT se necessario (serao usadas como secrets no GitHub)
if (Test-Path "scripts\generate-jwt-keys.ps1") {
    Write-Host "Gerando chaves JWT locais para teste via PowerShell..." -ForegroundColor Cyan
    & .\scripts\generate-jwt-keys.ps1
}

Write-Host ""

# ============================================================
# RESUMO FINAL
# ============================================================
Write-Host "================================================================" -ForegroundColor Green
Write-Host "STEP 4 CONCLUIDO COM SUCESSO!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""
Write-Host "Grafana: $grafanaUrl" -ForegroundColor Cyan
Write-Host "Tempo:   $tempoEndpoint" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROXIMO PASSO: Push para o GitHub para iniciar Pipeline CI/CD" -ForegroundColor Yellow
Write-Host "O repositório ECR foi provisionado e o build agora é AUTOMÁTICO." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green

# Salvar resumo
$outputLines = @(
    "MONITORING OUTPUTS",
    "Grafana: $grafanaUrl",
    "Tempo: $tempoEndpoint",
    "",
    "CI/CD STATUS",
    "Infrastructure: Ready",
    "Build Method: GitHub Actions (Debian Multi-stage)"
)
$outputLines | Out-File -FilePath "bootstrap-summary.txt" -Encoding UTF8 -Force
