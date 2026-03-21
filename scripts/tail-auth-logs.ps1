# scripts/tail-auth-logs.ps1
# Script para acompanhar os logs do serviço Auth em tempo real e capturar Erros 500.

$Project = "constellation-fabric"
$Env = "production"
$LogGroup = "/ecs/$Project-$Env-auth" # Verifique se este é o nome correto no seu Console

Write-Host "--- Tailing Logs: $LogGroup ---" -ForegroundColor Cyan
Write-Host "Rodando... (Pressione Ctrl+C para parar)"

# Tenta capturar os últimos 10 minutos de logs e continua ouvindo
aws logs tail $LogGroup --follow --region us-east-1
