$privateKeyPath = "jwt_private.pem"
$publicKeyPath = "jwt_public.pem"

Write-Host "Gerando chaves RSA 2048 bits via ssh-keygen..." -ForegroundColor Cyan

# Gerar chave privada em formato PEM
# -m PEM garante o formato compatível com a maioria dos backends
& ssh-keygen -t rsa -b 2048 -m PEM -f jwt_key -N "" -q

# Mover para o nome esperado
if (Test-Path "jwt_key") {
    Move-Item -Path "jwt_key" -Destination $privateKeyPath -Force
}

# Gerar chave pública em formato PEM (PKCS#8/SPKI)
# ssh-keygen -e -m PKCS8 exporta a chave pública no formato PEM padrão
& ssh-keygen -e -m PKCS8 -f $privateKeyPath | Out-File -FilePath $publicKeyPath -Encoding ascii

# Limpar arquivos temporários
if (Test-Path "jwt_key.pub") {
    Remove-Item -Path "jwt_key.pub" -Force
}

Write-Host "OK: Chaves geradas com sucesso:" -ForegroundColor Green
Write-Host "  - $privateKeyPath"
Write-Host "  - $publicKeyPath"
