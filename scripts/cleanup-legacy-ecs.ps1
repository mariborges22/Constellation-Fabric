# scripts/cleanup-legacy-ecs.ps1
# Script para limpar serviços e tasks de clusters ECS antigos para permitir o renaming via Terraform.

$LegacyClusters = @(
    @{ Name = "constellation-fabric-cluster"; Region = "us-east-1" },
    @{ Name = "constellation-fabric-cluster-eu-west-1"; Region = "eu-west-1" }
)

foreach ($Cluster in $LegacyClusters) {
    Write-Host "--- Limpando Cluster: $($Cluster.Name) ($($Cluster.Region)) ---" -ForegroundColor Cyan
    
    # 1. Listar e parar os Services
    $Services = aws ecs list-services --cluster $Cluster.Name --region $Cluster.Region --query 'serviceArns[]' --output text
    if ($Services) {
        foreach ($ServiceArn in $Services.Split("`t ")) {
            $ServiceName = $ServiceArn.Split("/")[-1]
            Write-Host "Atualizando Service $ServiceName para 0 tasks..."
            aws ecs update-service --cluster $Cluster.Name --service $ServiceName --region $Cluster.Region --desired-count 0 > $null
            
            Write-Host "Deletando Service $ServiceName..."
            aws ecs delete-service --cluster $Cluster.Name --service $ServiceName --region $Cluster.Region --force > $null
        }
    } else {
        Write-Host "Nenhum serviço encontrado."
    }

    # 2. Listar e parar Tasks órfãs (se houver)
    $Tasks = aws ecs list-tasks --cluster $Cluster.Name --region $Cluster.Region --query 'taskArns[]' --output text
    if ($Tasks) {
        foreach ($TaskArn in $Tasks.Split("`t ")) {
            Write-Host "Parando Task $($TaskArn.Split("/")[-1])..."
            aws ecs stop-task --cluster $Cluster.Name --task $TaskArn --region $Cluster.Region > $null
        }
    } else {
        Write-Host "Nenhuma task pendente."
    }

    Write-Host "Cluster $($Cluster.Name) pronto para ser deletado pelo Terraform!`n" -ForegroundColor Green
}

Write-Host "Pronto! Agora você pode rodar 'terraform apply' novamente." -ForegroundColor Green
