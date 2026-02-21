$ErrorActionPreference = "Stop"

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "CONSTELLATION FABRIC - HTTPS/TLS SETUP (Hybrid Ver.)" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

# ============================================================
# STEP 1: Coletar informações
# ============================================================
Write-Host "[STEP 1] Coletando informações..." -ForegroundColor Yellow

$DOMAIN = (Read-Host "Domain principal (ex: constellation.com)").Trim()
if (-not $DOMAIN) { Write-Error "O domínio é obrigatório."; exit 1 }

$AWS_REGION = (Read-Host "AWS Region (padrão: us-east-1)").Trim()
if (-not $AWS_REGION) { $AWS_REGION = "us-east-1" }

Write-Host ""
Write-Host "OK: Informações básicas coletadas" -ForegroundColor Green
Write-Host ""

# ============================================================
# STEP 2: Validar credenciais AWS
# ============================================================
Write-Host "[STEP 2] Validando credenciais AWS..." -ForegroundColor Yellow

try {
    $identityJson = aws sts get-caller-identity
    $identity = $identityJson | ConvertFrom-Json
    $ACCOUNT_ID = $identity.Account
    Write-Host "OK: Autenticado na conta $ACCOUNT_ID" -ForegroundColor Green
} catch {
    Write-Host "ERRO: Falha na autenticação AWS. Verifique suas credenciais." -ForegroundColor Red
    exit 1
}

# ============================================================
# STEP 3: Configurar Route 53 Zone
# ============================================================
Write-Host ""
Write-Host "[STEP 3] Configurando Route 53 Zone..." -ForegroundColor Yellow

$ZONE_ID = (Read-Host "Possui um Hosted Zone ID no Route 53? (Cole aqui ou deixe em branco para tentar criar)").Trim()

if (-not $ZONE_ID) {
    Write-Host "Tentando detectar/criar automaticamente..."
    $ZONE_ID = aws route53 list-hosted-zones-by-name --query "HostedZones[?Name=='$($DOMAIN).'].Id" --output text
    if ($ZONE_ID -and $ZONE_ID.StartsWith("/hostedzone/")) {
        $ZONE_ID = $ZONE_ID.Replace("/hostedzone/", "")
        Write-Host "OK: Zone detectada." -ForegroundColor Green
    } else {
        try {
            Write-Host "Criando Route 53 Zone para $DOMAIN..."
            $callerRef = Get-Date -Format "yyyyMMddHHmmss"
            $zoneOutputJson = aws route53 create-hosted-zone --name "$DOMAIN" --caller-reference "$callerRef" --hosted-zone-config "Comment=Constellation Fabric Zone"
            $zoneOutput = $zoneOutputJson | ConvertFrom-Json
            $ZONE_ID = $zoneOutput.HostedZone.Id.Replace("/hostedzone/", "")
            Write-Host "OK: Zone criada." -ForegroundColor Green
        } catch {
            Write-Host "ERRO: Não foi possível criar a zona automaticamente (Provável restrição de conta)." -ForegroundColor Red
            Write-Host "DICA: Crie a zona publicamente pelo Console AWS e rode o script novamente fornecendo o ID." -ForegroundColor Cyan
            exit 1
        }
    }
}

Write-Host "Zone ID: $ZONE_ID"

# ============================================================
# STEP 4: Salvar Configs (Parcial)
# ============================================================
$envFile = ".env.route53"
$route53Env = @(
    "ZONE_ID=$ZONE_ID",
    "DOMAIN=$DOMAIN",
    "AWS_REGION=$AWS_REGION"
)
$route53Env | Out-File -FilePath $envFile -Encoding ascii -Force

# ============================================================
# STEP 5: Configurar ACM Certificate
# ============================================================
Write-Host ""
Write-Host "[STEP 5] Configurando ACM Certificate..." -ForegroundColor Yellow

$CERT_ARN = (Read-Host "Possui um Certificate ARN configurado? (Cole aqui ou deixe em branco para tentar criar)").Trim()

if (-not $CERT_ARN) {
    Write-Host "Procurando certificado existente..."
    $CERT_ARN = aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text

    if (-not $CERT_ARN -or $CERT_ARN -eq "None" -or $CERT_ARN -eq "") {
        try {
            Write-Host "Solicitando novo certificado..."
            $certOutputJson = aws acm request-certificate `
                --domain-name "$DOMAIN" `
                --subject-alternative-names "*.$DOMAIN" "api.$DOMAIN" "game.$DOMAIN" "auth.$DOMAIN" `
                --validation-method DNS `
                --region "$AWS_REGION"
            $certOutput = $certOutputJson | ConvertFrom-Json
            $CERT_ARN = $certOutput.CertificateArn
            Write-Host "OK: Certificado solicitado." -ForegroundColor Green
        } catch {
            Write-Host "ERRO: Não foi possível solicitar o certificado automaticamente." -ForegroundColor Red
            Write-Host "DICA: Solicite o certificado manualmente no Console ACM (us-east-1) e cole o ARN aqui." -ForegroundColor Cyan
            exit 1
        }
    } else {
        Write-Host "OK: Certificado detectado." -ForegroundColor Green
    }
}

# Validar se o ARN tem o formato correto antes de prosseguir
if (-not $CERT_ARN.StartsWith("arn:aws:acm")) {
    Write-Error "O ARN do certificado fornecido parece inválido: $CERT_ARN"
    exit 1
}

Write-Host "Certificate ARN: $CERT_ARN"
"ACM_CERT_ARN=$CERT_ARN" | Out-File -FilePath $envFile -Encoding ascii -Append

# ============================================================
# STEP 6: Validar Certificado (Opcional se fornecido ARN)
# ============================================================
Write-Host ""
Write-Host "[STEP 6] Configurando validação DNS..." -ForegroundColor Yellow

try {
    $certInfoJson = aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION"
    $certInfo = $certInfoJson | ConvertFrom-Json
} catch {
    Write-Host "ERRO: Não foi possível descrever o certificado. Verifique se o ARN está correto e completo." -ForegroundColor Red
    Write-Host "ARN tentado: $CERT_ARN" -ForegroundColor Gray
    exit 1
}

if ($certInfo.Certificate.Status -eq "ISSUED") {
    Write-Host "OK: Certificado já está VALIDADO." -ForegroundColor Green
} else {
    Write-Host "Iniciando processo de validação DNS..."
    $VALIDATION_RECORDS = $certInfo.Certificate.DomainValidationOptions.ResourceRecord

    if (-not $VALIDATION_RECORDS) {
        Write-Host "Aguardando registros de validação aparecerem (10s)..."
        Start-Sleep -Seconds 10
        $certInfoJson = aws acm describe-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION"
        $certInfo = $certInfoJson | ConvertFrom-Json
        $VALIDATION_RECORDS = $certInfo.Certificate.DomainValidationOptions.ResourceRecord
    }

    foreach ($record in $VALIDATION_RECORDS) {
        $name = $record.Name
        $type = $record.Type
        $value = $record.Value
        Write-Host "  Adicionando registro CNAME: $name ($value)"
        
        $batchObj = @{
            Changes = @(@{
                Action = "UPSERT"
                ResourceRecordSet = @{
                    Name = $name
                    Type = $type
                    TTL  = 300
                    ResourceRecords = @(@{ Value = $value })
                }
            })
        }
        $tempJson = Join-Path $env:TEMP "route53_batch.json"
        $batchObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $tempJson -Encoding ascii -Force
        aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "file://$tempJson" | Out-Null
    }
    Write-Host "OK: Registros de validação configurados no Route 53." -ForegroundColor Green
}

# ============================================================
# STEP 8: Gerar Arquivos Terraform
# ============================================================
Write-Host ""
Write-Host "[STEP 8] Gerando arquivos Terraform para HTTPS..." -ForegroundColor Yellow

$httpsModulePath = "infra/modules/https"
if (-not (Test-Path $httpsModulePath)) { New-Item -Path $httpsModulePath -ItemType Directory -Force }

$variablesTf = @'
variable "domain_name" { type = string }
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "acm_certificate_arn" { type = string }
variable "route53_zone_id" { type = string }
variable "alb_dns_name_us" { type = string }
variable "alb_zone_id_us" { type = string }
'@

$mainTf = @'
# HTTPS Setup (Resumo do modulo original)
resource "aws_lb_listener" "https_us" {
  load_balancer_arn = var.alb_dns_name_us
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = "AJUSTAR_TG"
  }
}

resource "aws_route53_record" "api" {
  zone_id = var.route53_zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name_us
    zone_id                = var.alb_zone_id_us
    evaluate_target_health = true
  }
}
'@

$variablesTf | Out-File -FilePath (Join-Path $httpsModulePath "variables.tf") -Encoding ascii -Force
$mainTf | Out-File -FilePath (Join-Path $httpsModulePath "main.tf") -Encoding ascii -Force

Write-Host "OK: Módulo Terraform gerado com sucesso." -ForegroundColor Green

# ============================================================
# STEP 9: Gerar .env.https
# ============================================================
$envHttps = @(
    "DOMAIN=$DOMAIN",
    "API_URL=https://api.$DOMAIN",
    "ACM_CERT_ARN=$CERT_ARN",
    "ZONE_ID=$ZONE_ID"
)
$envHttps | Out-File -FilePath ".env.https" -Encoding ascii -Force
Write-Host "OK: Arquivo .env.https gerado." -ForegroundColor Green

Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SETUP CONCLUÍDO COM SUCESSO!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host "Agora basta revisar os arquivos gerados em $httpsModulePath"
Write-Host "E prosseguir com o Terraform Apply."
