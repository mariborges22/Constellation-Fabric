# Get Monitoring IPs
# Este script localiza os IPs públicos das tasks de monitoramento (Grafana/Prometheus).

param (
    [string]$ClusterName = "constellation-fabric-cluster",
    [string]$Region = "us-east-1"
)

Write-Host "`n=== Localizando IPs de Monitoramento ($Region) ===" -ForegroundColor Cyan

$services = @("grafana-service", "prometheus-service")

foreach ($svc in $services) {
    Write-Host "Serviço: $svc" -NoNewline
    
    $taskArn = aws ecs list-tasks --cluster $ClusterName --service-name $svc --region $Region --query "taskArns[0]" --output text
    
    if ($taskArn -eq "None" -or [string]::IsNullOrWhiteSpace($taskArn)) {
        Write-Host " [Nenhuma Task Rodando]" -ForegroundColor Red
        continue
    }

    $eniId = aws ecs describe-tasks --cluster $ClusterName --tasks $taskArn --region $Region --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" --output text
    
    if ($eniId -eq "None") {
        Write-Host " [ENI não encontrada]" -ForegroundColor Red
        continue
    }

    $publicIp = aws ec2 describe-network-interfaces --network-interface-ids $eniId --region $Region --query "NetworkInterfaces[0].Association.PublicIp" --output text
    
    if ($svc -match "grafana") {
        Write-Host " -> http://$($publicIp):3000" -ForegroundColor Green
    } else {
        Write-Host " -> http://$($publicIp):9090" -ForegroundColor Green
    }
}

Write-Host "`nNota: Certifique-se de que os Security Groups permitem entrada nas portas 3000 e 9090." -ForegroundColor Gray
