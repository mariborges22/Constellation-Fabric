# Script para limpar rotas conflitantes do Constellation-Fabric
# Isso resolve o erro "RouteAlreadyExists" no Terraform

$Project = "constellation-fabric"
$Env = "staging"
$Regions = @("us-east-1", "eu-west-1")

foreach ($Region in $Regions) {
    Write-Host "--- Processando Região: $Region ---" -ForegroundColor Cyan
    
    # Busca o ID da Route Table usando a tag Name que definimos no Terraform
    $TagName = "$Project-$Env-$Region-private-rt"
    Write-Host "Buscando Route Table com tag: $TagName"
    
    $RouteTableId = aws ec2 describe-route-tables `
        --region $Region `
        --filters "Name=tag:Name,Values=$TagName" `
        --query "RouteTables[0].RouteTableId" `
        --output text

    if ($RouteTableId -eq "None" -or [string]::IsNullOrEmpty($RouteTableId)) {
        Write-Host "Erro: Route Table não encontrada em $Region" -ForegroundColor Yellow
        continue
    }

    Write-Host "ID Encontrado: $RouteTableId" -ForegroundColor Green

    # Tenta deletar a rota 0.0.0.0/0
    Write-Host "Tentando remover a rota 0.0.0.0/0..."
    try {
        aws ec2 delete-route `
            --region $Region `
            --route-table-id $RouteTableId `
            --destination-cidr-block "0.0.0.0/0" `
            2>$null
        
        Write-Host "Sucesso: Rota removida (ou já não existia)." -ForegroundColor Green
    } catch {
        Write-Host "Aviso: Não foi possível remover a rota ou ela não existe." -ForegroundColor Gray
    }
}

Write-Host "`nLimpeza concluída! Agora você pode rodar o 'terraform apply' novamente." -ForegroundColor White -BackgroundColor Blue
