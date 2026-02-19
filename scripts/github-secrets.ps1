param()

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "STEP 2/4: Configurando GitHub Secrets" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

# Configuracoes
$githubRepoOwner = "mariborges22"
$githubRepoName = "constellation-fabric"
$secretName = "AWS_ROLE_TO_ASSUME"

# Tentar ler ARN do arquivo anterior
$arnFile = "$PSScriptRoot\..\oidc-role-arn.txt"
if (Test-Path $arnFile) {
    $roleArn = Get-Content $arnFile
    Write-Host "ARN carregado do Step 1:" -ForegroundColor Green
    Write-Host "$roleArn" -ForegroundColor Yellow
} else {
    Write-Host "Arquivo de ARN nao encontrado." -ForegroundColor Red
    Write-Host "Certifique-se de executar o Step 1 primeiro!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "OPCAO 1: Configurar via GitHub CLI (Automatico)" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

# Verificar se GitHub CLI esta instalado
$ghCliExists = Get-Command gh -ErrorAction SilentlyContinue
if ($null -ne $ghCliExists) {
    Write-Host "GitHub CLI encontrado!" -ForegroundColor Green
    Write-Host ""
    
    $useGhCli = Read-Host "Usar GitHub CLI para configurar? (s/n)"
    
    if ($useGhCli -eq "s" -or $useGhCli -eq "S") {
        Write-Host "Configurando secret via GitHub CLI..." -ForegroundColor Cyan
        
        & gh secret set $secretName --body $roleArn -R "$githubRepoOwner/$githubRepoName"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Secret configurado com sucesso!" -ForegroundColor Green
        } else {
            Write-Host "Erro ao configurar secret. Tente a OPCAO 2." -ForegroundColor Red
        }
    }
} else {
    Write-Host "GitHub CLI nao esta instalado." -ForegroundColor Yellow
    Write-Host "Voce pode instalar com: winget install GitHub.cli" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "OPCAO 2: Configurar Manualmente no GitHub (Web)" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Se a OPCAO 1 nao funcionou, siga estes passos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Abra seu repositorio: https://github.com/mariborges22/constellation-fabric" -ForegroundColor Cyan
Write-Host "2. Va para: Settings -> Secrets and variables -> Actions" -ForegroundColor Cyan
Write-Host "3. Clique em 'New repository secret'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Nome do Secret:" -ForegroundColor Yellow
Write-Host "$secretName" -ForegroundColor Green
Write-Host ""
Write-Host "Valor:" -ForegroundColor Yellow
Write-Host "$roleArn" -ForegroundColor Green
Write-Host ""

# Copiar para clipboard (Windows)
Write-Host "Copiando ARN para clipboard..." -ForegroundColor Cyan
$roleArn | Set-Clipboard
Write-Host "ARN copiado! Cole no GitHub." -ForegroundColor Green

Write-Host ""
Write-Host "================================================================" -ForegroundColor Yellow
Write-Host "VERIFICACAO" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

$verified = Read-Host "Ja configurou o secret no GitHub? (s/n)"

if ($verified -eq "s" -or $verified -eq "S") {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "STEP 2 CONCLUIDO!" -ForegroundColor Green
    Write-Host "================================================================"
    Write-Host ""
    Write-Host "PROXIMO PASSO: Prossiga com o provisionamento de redes." -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Configure o secret antes de continuar!" -ForegroundColor Red
    Write-Host "Depois execute novamente este script." -ForegroundColor Yellow
    exit 1
}