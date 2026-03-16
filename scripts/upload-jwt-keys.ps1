param (
    [string]$ProjectName = "constellation-fabric",
    [string]$SecretName = "constellation-fabric-jwt-keys-v1",
    [string]$PrivateKeyPath = "jwt_private.pem",
    [string]$PublicKeyPath = "jwt_public.pem"
)

Write-Host "Iniciando upload das chaves JWT para o AWS Secrets Manager..." -ForegroundColor Cyan

if (-not (Test-Path $PrivateKeyPath)) {
    Write-Error "Erro: Chave privada não encontrada em $PrivateKeyPath. Rode scripts/generate-jwt-keys.ps1 primeiro."
    exit 1
}

if (-not (Test-Path $PublicKeyPath)) {
    Write-Error "Erro: Chave pública não encontrada em $PublicKeyPath."
    exit 1
}

$privateKey = Get-Content -Path $PrivateKeyPath -Raw
$publicKey = Get-Content -Path $PublicKeyPath -Raw

# Criar o JSON para o segredo
$secretJson = @{
    private = $privateKey
    public  = $publicKey
} | ConvertTo-Json -Compress

Write-Host "Enviando segredo para a AWS ($SecretName)..." -ForegroundColor Cyan

try {
    & aws secretsmanager put-secret-value --secret-id $SecretName --secret-string $secretJson
    Write-Host "✅ SUCESSO: Chaves JWT enviadas com sucesso!" -ForegroundColor Green
    Write-Host "Agora você pode deletar os arquivos .pem locais com segurança." -ForegroundColor Yellow
} catch {
    Write-Error "Falha ao enviar segredo para a AWS: $_"
    exit 1
}
