param()

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "STEP 3/4: Provisioning Networks Module (Multi-Region)" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

$stagingEnv = "infra\enviroments\staging"

# Verificar credenciais
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

# Plan do modulo networks (Multi-Region targeting)
Write-Host "Rodando terraform plan para modulo networks..." -ForegroundColor Yellow
Write-Host "(isso pode levar alguns minutos)" -ForegroundColor Yellow
Write-Host ""

& terraform plan -target="module.networks_us" -target="module.networks_eu" -out=tfplan_networks
Write-Host ""

# Informacoes sobre o que sera criado
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "RECURSOS QUE SERAO CRIADOS:" -ForegroundColor Yellow
Write-Host "================================================================"
Write-Host ""
Write-Host "Regioes:" -ForegroundColor Cyan
Write-Host "  - us-east-1 (Leste dos EUA)"
Write-Host "  - eu-west-1 (Irlanda)"
Write-Host ""
Write-Host "Componentes:" -ForegroundColor Cyan
Write-Host "  - VPCs em cada regiao"
Write-Host "  - Subnets (publicas + privadas)"
Write-Host "  - Internet Gateways"
Write-Host "  - Application Load Balancers (ALB)"
Write-Host ""
Write-Host "Nota: Global Accelerator desativado por padrao (evita erro de assinatura)."
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

& terraform apply tfplan_networks
Write-Host ""

# Capturar outputs
Write-Host "Extraindo outputs das redes..." -ForegroundColor Cyan
Write-Host ""

$vpcUsEast = & terraform output -raw vpc_us_east_id 2>$null
$vpcEuWest = & terraform output -raw vpc_eu_west_id 2>$null
$albUsDns = & terraform output -raw alb_us_dns 2>$null
$albEuDns = & terraform output -raw alb_eu_dns 2>$null

Write-Host "================================================================" -ForegroundColor Green
Write-Host "STEP 3 CONCLUIDO COM SUCESSO!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""
Write-Host "VPC us-east-1 ID: $vpcUsEast" -ForegroundColor Yellow
Write-Host "ALB us-east-1 DNS: $albUsDns" -ForegroundColor Cyan
Write-Host ""
Write-Host "VPC eu-west-1 ID: $vpcEuWest" -ForegroundColor Yellow
Write-Host "ALB eu-west-1 DNS: $albEuDns" -ForegroundColor Cyan
Write-Host ""
Write-Host "PROXIMO PASSO: Execute .\scripts\step-04-monitoring.ps1" -ForegroundColor Yellow
Write-Host ""

# Salvar outputs usando array de strings (mais seguro contra erros de escape)
$outputPath = "..\..\networks-outputs.txt"
$outputLines = @(
    "NETWORKS MODULE OUTPUTS",
    "=======================",
    "VPC us-east-1: $vpcUsEast",
    "ALB us-east-1 DNS: $albUsDns",
    "VPC eu-west-1: $vpcEuWest",
    "ALB eu-west-1 DNS: $albEuDns"
)

$outputLines | Out-File -FilePath $outputPath -Encoding UTF8 -Force

Pop-Location
