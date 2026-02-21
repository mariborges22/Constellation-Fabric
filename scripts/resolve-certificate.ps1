param(
    [string]$CertificateArn,
    [string]$ZoneId,
    [string]$AwsRegion = "us-east-1"
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "ACM CERTIFICATE - RESOLUCAO DEFINITIVA" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

if ([string]::IsNullOrEmpty($CertificateArn) -or [string]::IsNullOrEmpty($ZoneId)) {
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  .\scripts\resolve-certificate.ps1 -CertificateArn <arn> -ZoneId <zone-id>"
    exit 1
}

# ============================================================
# PARTE 1: Diagnosticar
# ============================================================
Write-Host "--- PARTE 1: DIAGNOSTICO ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Obtendo informacoes do certificado..." -ForegroundColor Yellow

try {
    $certJson = aws acm describe-certificate `
        --certificate-arn $CertificateArn `
        --region $AwsRegion
    $cert = $certJson | ConvertFrom-Json
} catch {
    Write-Host "ERRO: Erro ao obter certificado. Verifique o ARN e suas credenciais." -ForegroundColor Red
    exit 1
}

$status = $cert.Certificate.Status
$domain = $cert.Certificate.DomainName

Write-Host "Status: $status" -ForegroundColor Cyan
Write-Host "Domain: $domain" -ForegroundColor Cyan
Write-Host ""

if ($status -eq "ISSUED") {
    Write-Host "OK: CERTIFICADO JA ESTA VALIDO!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximo passo: terraform apply" -ForegroundColor Green
    exit 0
}

if ($status -ne "PENDING_VALIDATION") {
    Write-Host "ERRO: Status inesperado: $status" -ForegroundColor Red
    exit 1
}

Write-Host "AGUARDANDO: Status PENDING_VALIDATION (precisa validar)" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# PARTE 2: Extrair registros necessarios
# ============================================================
Write-Host "--- PARTE 2: REGISTROS NECESSARIOS ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Copie EXATAMENTE os registros abaixo e crie no Route 53:" -ForegroundColor Yellow
Write-Host ""

$validationOptions = $cert.Certificate.DomainValidationOptions

if ($null -eq $validationOptions) {
    Write-Host "ERRO: Nenhuma opcao de validacao encontrada" -ForegroundColor Red
    exit 1
}

$recordCount = 0

foreach ($option in $validationOptions) {
    if ($option.ResourceRecord) {
        $name = $option.ResourceRecord.Name
        $type = $option.ResourceRecord.Type
        $value = $option.ResourceRecord.Value
        $domainName = $option.DomainName
        
        Write-Host "REGISTRO #$($recordCount + 1)" -ForegroundColor Yellow
        Write-Host "  Domain: $domainName" -ForegroundColor Cyan
        Write-Host "  Name:   $name" -ForegroundColor Cyan
        Write-Host "  Type:   $type" -ForegroundColor Cyan
        Write-Host "  Value:  $value" -ForegroundColor Cyan
        Write-Host ""
        
        $recordCount++
    }
}

# ============================================================
# PARTE 3: Mostrar como criar via AWS CLI
# ============================================================
Write-Host "--- PARTE 3: COMO CRIAR VIA AWS CLI ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Copie e execute este comando no PowerShell:" -ForegroundColor Yellow
Write-Host ""

if ($validationOptions.Count -gt 0 -and $validationOptions[0].ResourceRecord) {
    $firstRecord = $validationOptions[0]
    $rName = $firstRecord.ResourceRecord.Name
    $rType = $firstRecord.ResourceRecord.Type
    $rValue = $firstRecord.ResourceRecord.Value

    # Usando string formatada para evitar problemas com heredoc complexo e JSON
    $cliCommand = 'aws route53 change-resource-record-sets --hosted-zone-id {0} --change-batch ''{{"Changes": [{{"Action": "UPSERT", "ResourceRecordSet": {{"Name": "{1}", "Type": "{2}", "TTL": 300, "ResourceRecords": [{{"Value": "{3}"}}]}}}}]}}''' -f $ZoneId, $rName, $rType, $rValue

    Write-Host $cliCommand -ForegroundColor Green
} else {
    Write-Host "AVISO: Nao foi possivel gerar comando CLI (registros nao disponiveis)." -ForegroundColor Gray
}
Write-Host ""

# ============================================================
# PARTE 4: Mostrar como criar via AWS Console
# ============================================================
Write-Host "--- PARTE 4: COMO CRIAR VIA AWS CONSOLE ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Se preferir criar manualmente no Console AWS:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Va para: Route 53 -> Hosted Zones -> $domain" -ForegroundColor Cyan
Write-Host "2. Clique em: 'Create record'" -ForegroundColor Cyan
Write-Host "3. Preencha:" -ForegroundColor Cyan
Write-Host ""

foreach ($option in $validationOptions) {
    if ($option.ResourceRecord) {
        $name = $option.ResourceRecord.Name
        $type = $option.ResourceRecord.Type
        $value = $option.ResourceRecord.Value
        
        Write-Host "   Record #" -ForegroundColor Yellow
        Write-Host "   - Name: $name" -ForegroundColor Cyan
        Write-Host "   - Type: $type" -ForegroundColor Cyan
        Write-Host "   - Value: $value" -ForegroundColor Cyan
        Write-Host ""
    }
}

# ============================================================
# PARTE 5: Verificar registros existentes
# ============================================================
Write-Host "--- PARTE 5: VALIDAR REGISTROS NO ROUTE 53 ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Verificando registros ja criados no Route 53..." -ForegroundColor Yellow
Write-Host ""

$recordsJson = aws route53 list-resource-record-sets --hosted-zone-id $ZoneId
$records = $recordsJson | ConvertFrom-Json

$existingCount = 0
$totalRequired = 0

foreach ($option in $validationOptions) {
    if ($option.ResourceRecord) {
        $totalRequired++
        $expectedName = $option.ResourceRecord.Name
        $foundRecord = $records.ResourceRecordSets | Where-Object { $_.Name.TrimEnd('.') -eq $expectedName.TrimEnd('.') }
        
        if ($foundRecord) {
            Write-Host "OK: ENCONTRADO: $expectedName" -ForegroundColor Green
            $existingCount++
        } else {
            Write-Host "FALTA: NAO ENCONTRADO: $expectedName" -ForegroundColor Red
        }
    }
}

Write-Host ""

if ($existingCount -eq $totalRequired -and $totalRequired -gt 0) {
    Write-Host "OK: TODOS OS REGISTROS JA FORAM CRIADOS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Aguardando validacao... isso pode levar 5-10 minutos" -ForegroundColor Cyan
} else {
    Write-Host "AVISO: ALGUNS REGISTROS AINDA NAO FORAM CRIADOS" -ForegroundColor Yellow
    Write-Host "Crie os registros acima usando AWS CLI ou Console" -ForegroundColor Yellow
}

# ============================================================
# PARTE 6: Monitorar validacao
# ============================================================
Write-Host ""
Write-Host "--- PARTE 6: MONITORAR VALIDACAO ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

Write-Host "Voce pode monitorar com este comando:" -ForegroundColor Yellow
Write-Host ""
Write-Host "aws acm describe-certificate --certificate-arn $CertificateArn --region $AwsRegion --query 'Certificate.Status'" -ForegroundColor Green
Write-Host ""

Write-Host "Ou execute este script novamente para verificar:" -ForegroundColor Yellow
Write-Host ""
Write-Host ".\scripts\resolve-certificate.ps1 -CertificateArn '$CertificateArn' -ZoneId '$ZoneId'" -ForegroundColor Green
Write-Host ""

# ============================================================
# PARTE 7: Aguardar validacao (opcional)
# ============================================================
Write-Host "--- PARTE 7: AGUARDAR VALIDACAO ---" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

$waitForValidation = Read-Host "Deseja aguardar validacao? (s/n)"

if ($waitForValidation -eq "s" -or $waitForValidation -eq "S") {
    Write-Host ""
    Write-Host "Aguardando... (maximo 5 minutos)" -ForegroundColor Yellow
    Write-Host ""
    
    $maxAttempts = 30
    $attempt = 0
    
    while ($attempt -lt $maxAttempts) {
        $statusJson = aws acm describe-certificate `
            --certificate-arn $CertificateArn `
            --region $AwsRegion `
            --query 'Certificate.Status' `
            --output text
        
        if ($statusJson -eq "ISSUED") {
            Write-Host ""
            Write-Host "OK: CERTIFICADO VALIDADO!" -ForegroundColor Green
            Write-Host ""
            Write-Host "Proximo passo: terraform apply" -ForegroundColor Green
            Write-Host ""
            exit 0
        }
        
        Write-Host "Tentativa $($attempt + 1)/30 - Status: $statusJson" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $attempt++
    }
    
    Write-Host ""
    Write-Host "Timeout! Certificado ainda nao validou depois de 5 minutos" -ForegroundColor Red
    Write-Host "Verifique se os registros foram criados corretamente" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "FIM DO SCRIPT" -ForegroundColor Cyan
Write-Host "================================================================"
