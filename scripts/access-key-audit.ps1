param()

# Configuração de encoding para evitar erros de caracteres especiais no console
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SECURITY: Limpar chaves comprometidas e validar OIDC" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

# ============================================================
# PRE-REQUISITOS: Verificar AWS CLI
# ============================================================
$awsExists = Get-Command aws -ErrorAction SilentlyContinue
if ($null -eq $awsExists) {
    Write-Host "ERRO: AWS CLI nao encontrado. Por favor, instale o AWS CLI." -ForegroundColor Red
    exit 1
}

# Verificar se esta autenticado
$identityRaw = aws sts get-caller-identity --output json | Out-String
if ($null -eq $identityRaw -or $identityRaw -eq "") {
    Write-Host "ERRO: Falha ao obter identidade AWS. Verifique suas credenciais." -ForegroundColor Red
    exit 1
}
$identity = $identityRaw | ConvertFrom-Json

# ============================================================
# PASSO 1: Listar todas as access keys
# ============================================================
Write-Host "[PASSO 1] Auditando Access Keys..." -ForegroundColor Yellow
Write-Host ""

$userRaw = aws iam get-user --output json | Out-String
$user = $userRaw | ConvertFrom-Json
$userName = $user.User.UserName

Write-Host "Usuario: $userName" -ForegroundColor Cyan
Write-Host ""

$accessKeysJson = aws iam list-access-keys --user-name $userName --output json | Out-String
$accessKeys = $accessKeysJson | ConvertFrom-Json

Write-Host "Access Keys encontradas:" -ForegroundColor Yellow
Write-Host ""

$activeKeys = @()
if ($accessKeys -and $accessKeys.AccessKeyMetadata) {
    foreach ($key in $accessKeys.AccessKeyMetadata) {
        $keyId = $key.AccessKeyId
        $status = $key.Status
        $createDate = $key.CreateDate
        
        $statusColor = "Gray"
        if ($status -eq "Active") { $statusColor = "Green" }
        
        Write-Host "Key ID: $keyId" -ForegroundColor Cyan
        Write-Host "  Status: $status" -ForegroundColor $statusColor
        Write-Host "  Criada em: $createDate" -ForegroundColor Cyan
        Write-Host ""
        
        if ($status -eq "Active") {
            $activeKeys += $keyId
        }
    }
} else {
    Write-Host "Nenhuma chave encontrada para este usuario." -ForegroundColor Gray
}

Write-Host "Total de chaves ativas: $($activeKeys.Count)" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# PASSO 2: Listar quais estao sendo usadas
# ============================================================
Write-Host "[PASSO 2] Checando quais chaves estao em uso..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Chaves ativas configuradas em:" -ForegroundColor Cyan
Write-Host "  - ~/.aws/credentials" -ForegroundColor Gray
Write-Host "  - Variaveis de ambiente (AWS_ACCESS_KEY_ID, etc)" -ForegroundColor Gray
Write-Host "  - GitHub Secrets (AWS_ACCESS_KEY_ID)" -ForegroundColor Gray
Write-Host ""

if ($activeKeys.Count -gt 0) {
    Write-Host "AVISO: Se desativou uma chave no Console, verifique se ela ainda e necessaria localmente." -ForegroundColor Yellow
}
Write-Host ""

# ============================================================
# PASSO 3: Informacoes sobre OIDC
# ============================================================
Write-Host "[PASSO 3] Validando OIDC..." -ForegroundColor Yellow
Write-Host ""

try {
    $oidcProvidersJson = aws iam list-open-id-connect-providers --output json | Out-String
    $oidcProviders = $oidcProvidersJson | ConvertFrom-Json
    
    if ($oidcProviders -and $oidcProviders.OpenIDConnectProviderList -and $oidcProviders.OpenIDConnectProviderList.Count -gt 0) {
        Write-Host "OIDC Providers encontrados:" -ForegroundColor Green
        Write-Host ""
        
        foreach ($provider in $oidcProviders.OpenIDConnectProviderList) {
            $arn = $provider.Arn
            Write-Host "  ARN: $arn" -ForegroundColor Cyan
            
            # Obter detalhes
            $oidcDetailsJson = aws iam get-open-id-connect-provider --open-id-connect-provider-arn $arn --output json | Out-String
            $oidcDetails = $oidcDetailsJson | ConvertFrom-Json
            Write-Host "  URL: $($oidcDetails.Url)" -ForegroundColor Cyan
            Write-Host "  Client IDs: $($oidcDetails.ClientIDList -join ', ')" -ForegroundColor Cyan
            Write-Host ""
        }
    } else {
        Write-Host "Nenhum OIDC Provider encontrado" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Erro ao verificar OIDC: $_" -ForegroundColor Yellow
}

# ============================================================
# PASSO 4: Checar GitHub Actions role
# ============================================================
Write-Host "[PASSO 4] Validando GitHub Actions Role..." -ForegroundColor Yellow
Write-Host ""

$roleName = "constellation-fabric-github-actions-role"
try {
    $roleOutput = aws iam get-role --role-name $roleName --output json 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $roleOutput -ne "") {
        $gitHubRole = $roleOutput | ConvertFrom-Json
        
        Write-Host "GitHub Actions Role ($roleName) existe:" -ForegroundColor Green
        Write-Host "  Role ARN: $($gitHubRole.Role.Arn)" -ForegroundColor Cyan
        Write-Host "  Criada em: $($gitHubRole.Role.CreateDate)" -ForegroundColor Cyan
        
        # Verificar assume role policy
        $assumeRolePolicy = $gitHubRole.Role.AssumeRolePolicyDocument
        if ($assumeRolePolicy -is [string]) {
            $assumeRolePolicy = $assumeRolePolicy | ConvertFrom-Json
        }
        
        Write-Host ""
        Write-Host "Trust Relationship (OIDC):" -ForegroundColor Yellow
        
        $hasOidc = $false
        foreach ($statement in $assumeRolePolicy.Statement) {
            $principal = $statement.Principal
            if ($null -ne $principal.Federated -and $principal.Federated -match "token.actions.githubusercontent.com") {
                $hasOidc = $true
                Write-Host "  OK: GitHub Actions pode assumir esta role" -ForegroundColor Green
                Write-Host "  Conditions:" -ForegroundColor Cyan
                if ($statement.Condition) {
                    $conditionJson = $statement.Condition | ConvertTo-Json -Depth 10
                    Write-Host "    $conditionJson" -ForegroundColor Gray
                }
            }
        }
        if (-not $hasOidc) {
            Write-Host "  Erro: Esta role nao parece estar configurada para OIDC do GitHub." -ForegroundColor Red
        }
    } else {
        Write-Host "GitHub Actions Role ($roleName) nao encontrada" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Erro ao verificar Role: $_" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# PASSO 5: Recomendar acoes
# ============================================================
Write-Host "[PASSO 5] Recomendacoes de Seguranca..." -ForegroundColor Yellow
Write-Host ""

Write-Host "Checklist de Seguranca:" -ForegroundColor Yellow
Write-Host "  1. Desative chaves comprometidas ou antigas imediatamente." -ForegroundColor Cyan
Write-Host "  2. Use OIDC para GitHub Actions (nao requer secrets fixos)." -ForegroundColor Cyan
Write-Host "  3. Rotacione chaves ativas a cada 90 dias." -ForegroundColor Cyan
Write-Host ""

# ============================================================
# PASSO 6: Opcao de deletar chave
# ============================================================
Write-Host "[PASSO 6] Gerenciamento de Access Keys" -ForegroundColor Yellow
Write-Host ""

if ($activeKeys.Count -gt 0) {
    Write-Host "Voce possui $($activeKeys.Count) chave(s) ativa(s)." -ForegroundColor Yellow
    Write-Host "Deseja deletar alguma chave? (CUIDADO: Isso e irreversivel)" -ForegroundColor Red
    
    for ($i = 0; $i -lt $activeKeys.Count; $i++) {
        Write-Host "$($i + 1). $($activeKeys[$i])" -ForegroundColor Cyan
    }
    
    $choice = Read-Host "Escolha o numero para deletar ou pressione ENTER para pular"
    
    if (![string]::IsNullOrEmpty($choice) -and $choice -match '^\d+$') {
        $index = [int]$choice - 1
        if ($index -ge 0 -and $index -lt $activeKeys.Count) {
            $selectedKey = $activeKeys[$index]
            
            Write-Host ""
            Write-Host "AVISO: Voce escolheu deletar a chave $selectedKey" -ForegroundColor Red
            $confirm = Read-Host "Digite 'DELETAR' para confirmar"
            
            if ($confirm -eq "DELETAR") {
                Write-Host "Deletando chave $selectedKey..." -ForegroundColor Yellow
                aws iam delete-access-key --user-name $userName --access-key-id $selectedKey
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Sucesso: Chave deletada com sucesso!" -ForegroundColor Green
                } else {
                    Write-Host "Erro: Falha ao deletar a chave." -ForegroundColor Red
                }
            } else {
                Write-Host "Operacao cancelada." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Escolha invalida." -ForegroundColor Red
        }
    }
} else {
    Write-Host "Nenhuma chave ativa encontrada para deletar." -ForegroundColor Green
}

# ============================================================
# PASSO 7: Resumo final
# ============================================================
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SESSAO DE AUDITORIA FINALIZADA" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""

Read-Host "Pressione ENTER para fechar"
