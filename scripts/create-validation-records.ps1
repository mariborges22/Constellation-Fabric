param(
    [string]$CertificateArn,
    [string]$ZoneId
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "ACM CERTIFICATE - CRIAR REGISTROS DE VALIDAÇÃO DNS" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

if ([string]::IsNullOrEmpty($CertificateArn) -or [string]::IsNullOrEmpty($ZoneId)) {
    Write-Host "Uso:" -ForegroundColor Yellow
    Write-Host "  .\scripts\create-validation-records.ps1 -CertificateArn <arn> -ZoneId <zone-id>"
    Write-Host ""
    Write-Host "Exemplo:" -ForegroundColor Cyan
    Write-Host "  .\scripts\create-validation-records.ps1 -CertificateArn 'arn:aws:acm:us-east-1:123456789012:certificate/xxxxx' -ZoneId 'Z1234567890ABC'"
    exit 1
}

# ============================================================
# STEP 1: Obter dados de validação do certificado
# ============================================================
Write-Host "[STEP 1] Obtendo dados de validação do certificado..." -ForegroundColor Yellow

try {
    $certJson = aws acm describe-certificate --certificate-arn $CertificateArn --region us-east-1
    $cert = $certJson | ConvertFrom-Json
    
    Write-Host "OK: Certificado encontrado" -ForegroundColor Green
    Write-Host "  Domain: $($cert.Certificate.DomainName)" -ForegroundColor Cyan
    Write-Host "  Status: $($cert.Certificate.Status)" -ForegroundColor Cyan
    
    if ($cert.Certificate.Status -eq "ISSUED") {
        Write-Host "✅ Certificado já está VALIDADO e EMITIDO." -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "Erro: Erro ao obter certificado. Verifique o ARN e suas credenciais AWS." -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# STEP 2: Extrair registros CNAME
# ============================================================
Write-Host "[STEP 2] Extraindo registros CNAME para validação..." -ForegroundColor Yellow
Write-Host ""

$validationOptions = $cert.Certificate.DomainValidationOptions
$recordsToCreate = @()

foreach ($option in $validationOptions) {
    if ($option.ValidationMethod -eq "DNS" -and $option.ResourceRecord) {
        $domain = $option.DomainName
        $name = $option.ResourceRecord.Name
        $type = $option.ResourceRecord.Type
        $value = $option.ResourceRecord.Value
        
        Write-Host "Domain: $domain" -ForegroundColor Cyan
        Write-Host "  Name:  $name" -ForegroundColor Gray
        Write-Host "  Type:  $type" -ForegroundColor Gray
        Write-Host "  Value: $value" -ForegroundColor Gray
        Write-Host ""
        
        $recordsToCreate += @{
            Name = $name
            Type = $type
            Value = $value
        }
    }
}

if ($recordsToCreate.Count -eq 0) {
    Write-Host "Erro: Nenhum registro de validação DNS encontrado. O método de validação é DNS?" -ForegroundColor Red
    exit 1
}

Write-Host "OK: Total de registros a criar: $($recordsToCreate.Count)" -ForegroundColor Green
Write-Host ""

# ============================================================
# STEP 3: Criar registros no Route 53
# ============================================================
Write-Host "[STEP 3] Criando registros no Route 53..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$errorCount = 0
$attempt = 0

foreach ($record in $recordsToCreate) {
    $name = $record.Name
    $type = $record.Type
    $value = $record.Value
    
    Write-Host "Criando: $name" -ForegroundColor Yellow
    
    try {
        # Criar o batch objeto
        $changeBatch = @{
            Comment = "ACM Validation Record"
            Changes = @(
                @{
                    Action = "UPSERT"
                    ResourceRecordSet = @{
                        Name = $name
                        Type = $type
                        TTL = 300
                        ResourceRecords = @(
                            @{ Value = $value }
                        )
                    }
                }
            )
        }
        
        # Usar arquivo temporário para evitar Erro de Parsing do JSON no Windows CLI
        $tempJson = Join-Path $env:TEMP "acm_validation_$($attempt).json"
        $changeBatch | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempJson -Encoding ascii -Force
        
        aws route53 change-resource-record-sets `
            --hosted-zone-id $ZoneId `
            --change-batch "file://$tempJson" | Out-Null
        
        if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
        
        Write-Host "  OK: Criado/Atualizado com sucesso" -ForegroundColor Green
        $successCount++
    } catch {
        Write-Host "  Erro: $_" -ForegroundColor Red
        $errorCount++
    }
    $attempt++
}

Write-Host ""
Write-Host "Resumo:" -ForegroundColor Cyan
Write-Host "  OK: Criados: $successCount" -ForegroundColor Green
Write-Host "  Erro: Erros: $errorCount" -ForegroundColor Red
Write-Host ""

if ($errorCount -gt 0) {
    Write-Host "AVISO: Alguns registros falharam. Verifique os erros acima." -ForegroundColor Yellow
}

# ============================================================
# STEP 4: Aguardar validação
# ============================================================
Write-Host "[STEP 4] Aguardando validação do certificado..." -ForegroundColor Yellow
Write-Host "Isso pode levar de 2 a 10 minutos. Pressione Ctrl+C para interromper se desejar." -ForegroundColor Gray
Write-Host ""

$maxLoops = 60
$loop = 0
$status = ""

while ($loop -lt $maxLoops) {
    try {
        $checkJson = aws acm describe-certificate --certificate-arn $CertificateArn --region us-east-1
        $check = $checkJson | ConvertFrom-Json
        $status = $check.Certificate.Status
        
        Write-Host "Tentativa $($loop+1)/$maxLoops - Status: $status" -ForegroundColor Yellow
        
        if ($status -eq "ISSUED") {
            Write-Host ""
            Write-Host "✅ CERTIFICADO VALIDADO E EMITIDO!" -ForegroundColor Green
            Write-Host ""
            break
        }
    } catch {
        Write-Host "Erro ao verificar status." -ForegroundColor Gray
    }
    
    Start-Sleep -Seconds 15
    $loop++
}

if ($status -eq "ISSUED") {
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "✅ SUCESSO! TUDO PRONTO." -ForegroundColor Green
    Write-Host "================================================================"
    Write-Host ""
    Write-Host "Próximos passos:" -ForegroundColor Cyan
    Write-Host "1. Volte para a pasta staging: cd infra/enviroments/staging"
    Write-Host "2. Execute: terraform apply"
} else {
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "⏳ AINDA PENDENTE" -ForegroundColor Yellow
    Write-Host "================================================================"
    Write-Host ""
    Write-Host "O DNS pode demorar um pouco para propagar. Tente rodar o script novamente em alguns minutos."
}

Read-Host "Pressione ENTER para fechar"
