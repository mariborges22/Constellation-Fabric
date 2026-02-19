param()

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "STEP 1/4: Provisioning Security Module (OIDC Bridge)" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

$stagingEnv = "infra\enviroments\staging"

# Verificar ferramentas e credenciais AWS
Write-Host "Verificando ferramentas e credenciais..." -ForegroundColor Cyan

$awsExists = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $awsExists) {
    Write-Host "ERRO: AWS CLI nao encontrado. Por favor, instale o AWS CLI." -ForegroundColor Red
    exit 1
}

aws sts get-caller-identity
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao verificar credenciais AWS. Execute 'aws configure' primeiro." -ForegroundColor Red
    exit 1
}

Write-Host "Credenciais OK" -ForegroundColor Green
Write-Host ""

# Navegar para staging
if (-not (Test-Path $stagingEnv)) {
    Write-Host "ERRO: Caminho nao encontrado: $stagingEnv" -ForegroundColor Red
    exit 1
}

Push-Location $stagingEnv
Write-Host "Entrando em: $stagingEnv" -ForegroundColor Cyan
Write-Host ""

# Inicializar Terraform (necessario para baixar novos modulos)
Write-Host "Inicializando Terraform..." -ForegroundColor Yellow
& terraform init -reconfigure

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao inicializar terraform." -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host ""

# Plan do modulo security
Write-Host "Rodando terraform plan para modulo security..." -ForegroundColor Yellow
& terraform plan -target="module.security" -out="tfplan"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao executar terraform plan." -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host ""

# Confirmacao antes de aplicar
Write-Host "AVISO: Voce esta prestes a provisionar o OIDC Bridge na AWS" -ForegroundColor Red
Write-Host "Isso criara:" -ForegroundColor Yellow
Write-Host "  - IAM OpenID Connect Provider"
Write-Host "  - IAM Role para GitHub Actions"
Write-Host ""

$confirm = Read-Host "Deseja continuar? (s/n)"
if ($confirm -ne "s" -and $confirm -ne "S") {
    Write-Host "Operacao cancelada." -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "Aplicando o plano..." -ForegroundColor Cyan
& terraform apply tfplan

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao aplicar o Terraform." -ForegroundColor Red
    Pop-Location
    exit 1
}
Write-Host ""

# Capturar ARN da Role
Write-Host "Extraindo ARN da Role OIDC..." -ForegroundColor Cyan
$roleArn = & terraform output -raw oidc_role_arn 2>$null

if ($null -eq $roleArn -or $roleArn -eq "") {
    Write-Host "Erro ao extrair ARN. Verifique os outputs do Terraform." -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "STEP 1 CONCLUIDO!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""
Write-Host "Role ARN criada com sucesso:" -ForegroundColor Green
Write-Host "$roleArn" -ForegroundColor Yellow
Write-Host ""
Write-Host "PROXIMO PASSO:" -ForegroundColor Cyan
Write-Host "Execute: .\scripts\github-secrets.ps1" -ForegroundColor Yellow
Write-Host ""

# Salvar ARN em arquivo para proximo step
$roleArn | Out-File -FilePath "$PSScriptRoot\..\oidc-role-arn.txt" -Encoding UTF8 -Force

Pop-Location