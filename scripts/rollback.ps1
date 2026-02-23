param (
    [Parameter(Mandatory=$true)]
    [string]$ServiceName
)

$ClusterName = "constellation-cluster"
$FamilyName = "constellation-$ServiceName"

Write-Host "🚀 Iniciando Rollback para o serviço: $ServiceName" -ForegroundColor Cyan

# 1. Obter a Task Definition atual
$CurrentTask = aws ecs describe-services --cluster $ClusterName --services "$ServiceName-service" --query "services[0].taskDefinition" --output text

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao descrever serviço."
    exit 1
}

Write-Host "📍 Task Definition atual: $CurrentTask"

# 2. Obter a versão anterior (Revision - 1)
$Parts = $CurrentTask -split ":"
$Revision = [int]$Parts[-1]
$PreviousRevision = $Revision - 1
$TargetTask = "$($Parts[0..($Parts.Length-2)] -join ':'):$PreviousRevision"

Write-Host "⏪ Revertendo para a versão: $TargetTask" -ForegroundColor Yellow

# 3. Aplicar Rollback
aws ecs update-service --cluster $ClusterName --service "$ServiceName-service" --task-definition $TargetTask --force-new-deployment

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Rollback solicitado com sucesso! Monitore o deployment no console da AWS." -ForegroundColor Green
} else {
    Write-Error "❌ Falha ao executar rollback automatizado."
}
