Write-Host "Inicializando Terraform..." -ForegroundColor Cyan

$environments = @("staging", "production")

foreach ($env in $environments) {
    Write-Host "Entrando em: infra/enviroments/$env" -ForegroundColor Yellow
    
    $tfPath = "infra\enviroments\$env"
    
    if (Test-Path $tfPath) {
        Push-Location $tfPath
        terraform init
        Pop-Location
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Terraform init concluido para $env!" -ForegroundColor Green
        } else {
            Write-Host "Erro ao inicializar Terraform para $env!" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    } else {
        Write-Host "Diretorio nao encontrado: $tfPath" -ForegroundColor Red
    }
}

Write-Host "Todos os ambientes inicializados!" -ForegroundColor Green
