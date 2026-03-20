# scripts/check-production-health.ps1
# Script para verificar a saúde da infraestrutura de produção e diagnosticar falhas de imagem.

$Project = "constellation-fabric"
$Env = "production"
$Region = "us-east-1"
$Cluster = "$Project-$Env-cluster"

Write-Host "--- Verificando Saúde da Produção: $Cluster ---" -ForegroundColor Cyan

# 1. Verificar Repositórios ECR
$Services = @("auth", "combat", "player_state")
foreach ($Svc in $Services) {
    $Repo = "$Project-$Env-$Svc"
    $Images = aws ecr list-images --repository-name $Repo --region $Region --query 'imageIds' --output json | ConvertFrom-Json
    if ($Images.Count -eq 0) {
        Write-Host "[ERRO] Repositório $Repo está VAZIO! Nenhuma imagem encontrada." -ForegroundColor Red
    } else {
        Write-Host "[OK] Repositório $Repo contém $($Images.Count) imagens." -ForegroundColor Green
    }
}

# 2. Verificar Status do ECS Service
Write-Host "`n--- Status dos Serviços ECS ---" -ForegroundColor Cyan
$EcsServices = aws ecs list-services --cluster $Cluster --region $Region --query 'serviceArns[]' --output text
if ($EcsServices) {
    foreach ($SvcArn in $EcsServices.Split("`t ")) {
        $SvcName = $SvcArn.Split("/")[-1]
        $Details = aws ecs describe-services --cluster $Cluster --services $SvcName --region $Region --query 'services[0].{Desired:desiredCount, Running:runningCount, Pending:pendingCount}' --output json | ConvertFrom-Json
        Write-Host "Serviço: $SvcName | Desejado: $($Details.Desired) | Rodando: $($Details.Running) | Pendente: $($Details.Pending)"
        
        if ($Details.Running -lt $Details.Desired) {
            Write-Host "  [AVISO] Alerta de Saúde! Verificando últimos eventos..." -ForegroundColor Yellow
            aws ecs describe-services --cluster $Cluster --services $SvcName --region $Region --query 'services[0].events[0:3].message' --output table
        }
    }
}

# 3. Verificar Target Groups do ALB
Write-Host "`n--- Status dos Target Groups (ALB) ---" -ForegroundColor Cyan
$Tgs = aws elbv2 describe-target-groups --region $Region --query 'TargetGroups[?contains(TargetGroupName, "prod")].{Name:TargetGroupName, Arn:TargetGroupArn}' --output json | ConvertFrom-Json
foreach ($Tg in $Tgs) {
    $Health = aws elbv2 describe-target-health --target-group-arn $Tg.Arn --region $Region --query 'TargetHealthDescriptions[].TargetHealth.State' --output text
    Write-Host "Target Group: $($Tg.Name) | Saúde: $Health"
    if ($Health -notcontains "healthy") {
        Write-Host "  [FALHA] Nenhum target saudável encontrado para $($Tg.Name)" -ForegroundColor Red
    }
}

Write-Host "`nDiagnóstico concluído!" -ForegroundColor Cyan
