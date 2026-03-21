# scripts/check-auth-error.ps1
# Script para buscar os ÚLTIMOS logs do Auth e ver por que está dando 500.

$Project = "constellation-fabric"
$Env = "production"
$LogGroup = "/ecs/$Project-$Env-auth"

Write-Host "--- Buscando últimos logs de: $LogGroup ---" -ForegroundColor Cyan

# 1. Acha o log stream mais recente
$Stream = aws logs describe-log-streams --log-group-name $LogGroup --order-by LastEventTime --descending --limit 1 --query "logStreams[0].logStreamName" --output text --region us-east-1

if ($Stream -eq "None" -or [string]::IsNullOrEmpty($Stream)) {
    Write-Host "[ERRO] Nenhum log stream encontrado!" -ForegroundColor Red
    return
}

Write-Host "Log Stream: $Stream" -ForegroundColor Gray

# 2. Mostra as últimas 50 linhas
aws logs get-log-events --log-group-name $LogGroup --log-stream-name $Stream --limit 50 --query "events[*].message" --output text --region us-east-1
