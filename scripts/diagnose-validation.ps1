param(
    [string]$Domain,
    [string]$CertificateArn,
    [string]$ZoneId,
    [string]$AwsRegion = "us-east-1"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "DIAGNOSTICO COMPLETO - POR QUE CERTIFICADO NAO VALIDA" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

if ([string]::IsNullOrEmpty($Domain) -or [string]::IsNullOrEmpty($ZoneId)) {
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  .\scripts\diagnose-validation.ps1 -Domain <domain> -ZoneId <zone-id> -CertificateArn <arn>"
    exit 1
}

# ============================================================
# 1. VERIFICAR NAMESERVERS DO DOMAIN
# ============================================================
Write-Host "[1] VERIFICANDO NAMESERVERS DO DOMAIN" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Domain: $Domain" -ForegroundColor Yellow
Write-Host ""

Write-Host "Obtendo nameservers do Route 53..." -ForegroundColor Cyan
try {
    $zoneInfo = aws route53 get-hosted-zone --id $ZoneId | ConvertFrom-Json
    $route53NameServers = $zoneInfo.DelegationSet.NameServers

    Write-Host "Route 53 Nameservers:" -ForegroundColor Green
    $route53NameServers | ForEach-Object { Write-Host "  $_" }
} catch {
    Write-Host "ERRO: Nao foi possivel obter informacoes da zona no Route 53." -ForegroundColor Red
}
Write-Host ""

Write-Host "Verificando nameservers resolvidos no DNS..." -ForegroundColor Cyan
Write-Host "(Isso leva alguns segundos...)" -ForegroundColor Gray
Write-Host ""

try {
    $nslookupResult = nslookup -type=NS $Domain 2>$null
    
    if ($nslookupResult -match "nameserver") {
        Write-Host "Nameservers resolvidos no DNS:" -ForegroundColor Green
        $nslookupResult | Where-Object { $_ -match "nameserver" } | ForEach-Object { 
            Write-Host "  $_" 
        }
    } else {
        Write-Host "AVISO: Nslookup pode nao estar funcionando corretamente ou nao encontrou registros." -ForegroundColor Yellow
    }
} catch {
    Write-Host "AVISO: Nao foi possivel fazer nslookup." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 2. VERIFICAR REGISTROS CNAME NO ROUTE 53
# ============================================================
Write-Host "[2] VERIFICANDO REGISTROS CNAME NO ROUTE 53" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

try {
    $records = aws route53 list-resource-record-sets --hosted-zone-id $ZoneId | ConvertFrom-Json

    Write-Host "Procurando registros CNAME com 'acm-validations'..." -ForegroundColor Cyan
    Write-Host ""

    $acmRecords = $records.ResourceRecordSets | Where-Object { 
        $_.Type -eq "CNAME" -and $_.Name -like "*acm*" 
    }

    if (-not $acmRecords) {
        Write-Host "ERR: NENHUM REGISTRO ACM ENCONTRADO!" -ForegroundColor Red
        Write-Host ""
        Write-Host "Isso significa que os registros CNAME de validacao NAO foram criados." -ForegroundColor Red
        Write-Host ""
    } else {
        Write-Host "OK: Registros CNAME encontrados:" -ForegroundColor Green
        Write-Host ""
        $acmRecords | ForEach-Object {
            Write-Host "  Name:  $($_.Name)" -ForegroundColor Cyan
            Write-Host "  Value: $($_.ResourceRecords[0].Value)" -ForegroundColor Cyan
            Write-Host ""
        }
    }
} catch {
    Write-Host "ERRO ao listar registros do Route 53." -ForegroundColor Red
}

# ============================================================
# 3. OBTER REGISTROS NECESSARIOS DO CERTIFICADO
# ============================================================
Write-Host "[3] REGISTROS NECESSARIOS DO CERTIFICADO" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

try {
    $cert = aws acm describe-certificate --certificate-arn $CertificateArn --region $AwsRegion | ConvertFrom-Json

    Write-Host "Status do Certificado: $($cert.Certificate.Status)" -ForegroundColor Yellow
    Write-Host ""

    $validationOptions = $cert.Certificate.DomainValidationOptions

    Write-Host "Registros que DEVEM ser criados:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($option in $validationOptions) {
        if ($option.ResourceRecord) {
            $expectedName = $option.ResourceRecord.Name
            $expectedType = $option.ResourceRecord.Type
            $expectedValue = $option.ResourceRecord.Value
            
            Write-Host "Domain: $($option.DomainName)" -ForegroundColor Cyan
            Write-Host "  Name:  $expectedName" -ForegroundColor Gray
            Write-Host "  Type:  $expectedType" -ForegroundColor Gray
            Write-Host "  Value: $expectedValue" -ForegroundColor Gray
            
            # Verificar se existe (normalizando nomes)
            $found = $records.ResourceRecordSets | Where-Object { 
                $_.Name.TrimEnd('.') -eq $expectedName.TrimEnd('.') -and $_.Type -eq $expectedType 
            }
            
            if ($found) {
                Write-Host "  Status: OK (CRIADO)" -ForegroundColor Green
            } else {
                Write-Host "  Status: FALTA (NAO CRIADO)" -ForegroundColor Red
            }
            Write-Host ""
        }
    }
} catch {
    Write-Host "ERRO ao descrever certificado ACM." -ForegroundColor Red
}

# ============================================================
# 4. PROBLEMA: DOMAIN NAO APONTA PARA ROUTE 53
# ============================================================
Write-Host "[4] POSSIVEL PROBLEMA: DOMAIN NAO APONTA PARA ROUTE 53" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Se seu domain eh registrado em GoDaddy/Namecheap/etc:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Voce precisa aponta-lo para estes nameservers (Route 53):" -ForegroundColor Cyan
Write-Host ""
if ($route53NameServers) {
    $route53NameServers | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
}
Write-Host ""
Write-Host "2. Va para seu registrador (GoDaddy, Namecheap, etc)" -ForegroundColor Cyan
Write-Host "3. Altere os nameservers para os acima" -ForegroundColor Cyan
Write-Host "4. Aguarde 24-48 horas para propagacao DNS" -ForegroundColor Cyan
Write-Host "5. Depois tente validar novamente" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 5. SOLUCAO: CRIAR REGISTROS MANUALMENTE
# ============================================================
Write-Host "[5] SOLUCAO: CRIAR REGISTROS MANUALMENTE" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Execute estes comandos no PowerShell se faltar algum registro:" -ForegroundColor Yellow
Write-Host ""

$index = 1
foreach ($option in $validationOptions) {
    if ($option.ResourceRecord) {
        $name = $option.ResourceRecord.Name
        $type = $option.ResourceRecord.Type
        $value = $option.ResourceRecord.Value
        
        Write-Host "# Registro $index" -ForegroundColor Gray
        
        $command = 'aws route53 change-resource-record-sets --hosted-zone-id {0} --change-batch ''{{"Changes": [{{"Action": "UPSERT", "ResourceRecordSet": {{"Name": "{1}", "Type": "{2}", "TTL": 300, "ResourceRecords": [{{"Value": "{3}"}}]}}}}]}}''' -f $ZoneId, $name, $type, $value
        
        Write-Host $command -ForegroundColor Green
        Write-Host ""
        
        $index++
    }
}

# ============================================================
# 6. SOLUCAO ALTERNATIVA
# ============================================================
Write-Host "[6] SOLUCAO ALTERNATIVA" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Se o domain nao esta em Route 53 e voce nao quer mudar:" -ForegroundColor Yellow
Write-Host ""
Write-Host "Opcao A: Usar CloudFlare" -ForegroundColor Cyan
Write-Host "  1. Crie conta em cloudflare.com" -ForegroundColor Gray
Write-Host "  2. Aponte seu domain para CloudFlare" -ForegroundColor Gray
Write-Host "  3. Adicione os registros CNAME la manualmente" -ForegroundColor Gray
Write-Host ""

Write-Host "Opcao B: Mover domain para Route 53" -ForegroundColor Cyan
Write-Host "  1. Transfira o domain de GoDaddy/Namecheap para Route 53" -ForegroundColor Gray
Write-Host "  2. Certificado valida automaticamente em minutos" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 7. CHECKLIST
# ============================================================
Write-Host "[7] CHECKLIST - O QUE VERIFICAR" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "[ ] 1. Domain resolve no DNS" -ForegroundColor Yellow
Write-Host "[ ] 2. Route 53 Zone existe" -ForegroundColor Yellow
Write-Host "[ ] 3. Nameservers Route 53 apontam corretamente" -ForegroundColor Yellow
Write-Host "[ ] 4. Registros CNAME criados no Route 53" -ForegroundColor Yellow
Write-Host "[ ] 5. Certificado status PENDING_VALIDATION" -ForegroundColor Yellow
Write-Host "[ ] 6. Certificado valida (status ISSUED)" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# 8. PROXIMOS PASSOS
# ============================================================
Write-Host "[8] PROXIMOS PASSOS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "A. Se o domain eh de terceiro (GoDaddy/Namecheap):" -ForegroundColor Yellow
Write-Host "   -> Altere nameservers para o Route 53 e aguarde propagacao." -ForegroundColor Cyan
Write-Host ""
Write-Host "B. Se o domain ja eh do Route 53:" -ForegroundColor Yellow
Write-Host "   -> Garanta que os registros no item [2] estao criados." -ForegroundColor Cyan
Write-Host ""

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "FIM DO SCRIPT" -ForegroundColor Cyan
Write-Host "================================================================"

Read-Host "Pressione ENTER para fechar"
