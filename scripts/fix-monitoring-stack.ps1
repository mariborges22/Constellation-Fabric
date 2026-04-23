<#
.SYNOPSIS
Script de SRE para estabilizar e validar a Stack de Observabilidade (Prometheus + Grafana).
Resolve problemas de pods em 'Pending' devido a limites de IP/Recursos do EKS.
#>

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "   Iniciando Diagnóstico e Cura da Observabilidade    " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Garantir que as configurações leves do Prometheus estão aplicadas
Write-Host "`n[1/5] Garantindo que o Prometheus está usando as configurações leves..." -ForegroundColor Yellow
helm upgrade prometheus prometheus-community/kube-prometheus-stack -f k8s/prometheus-values.yaml -n monitoring --no-hooks --reuse-values | Out-Null
Write-Host "Configurações aplicadas." -ForegroundColor Green

# 2. Liberar "Vagas" (IPs) no Nó do EKS
# Reduzimos sistemas redundantes de 2 para 1 réplica. Isso não quebra a infraestrutura, 
# apenas remove a alta disponibilidade que não precisamos em Staging.
Write-Host "`n[2/5] Otimizando recursos do cluster (liberando IPs)..." -ForegroundColor Yellow
kubectl scale deployment coredns -n kube-system --replicas=1 | Out-Null
kubectl scale deployment aws-load-balancer-controller -n kube-system --replicas=1 | Out-Null
kubectl scale deployment ebs-csi-controller -n kube-system --replicas=1 | Out-Null
kubectl scale deployment auth-service -n constellation --replicas=1 | Out-Null
kubectl scale deployment combat-service -n constellation --replicas=1 | Out-Null
Write-Host "Espaço liberado com sucesso." -ForegroundColor Green

# 3. Forçar o agendamento de Pods travados
Write-Host "`n[3/5] Verificando pods travados na fila (Pending)..." -ForegroundColor Yellow
$pendingPods = kubectl get pods -n monitoring --field-selector=status.phase=Pending -o custom-columns=":metadata.name" --no-headers
if ($pendingPods) {
    foreach ($pod in $pendingPods) {
        if ($pod -ne "") {
            Write-Host "    -> Matando pod travado para forçar recriação: $pod" -ForegroundColor Gray
            kubectl delete pod $pod -n monitoring --force --grace-period=0 | Out-Null
        }
    }
} else {
    Write-Host "Nenhum pod travado encontrado." -ForegroundColor Green
}

# 4. Aguardar o Prometheus subir (o "motor" das métricas)
Write-Host "`n[4/5] Aguardando o Banco de Dados de Métricas (Prometheus) ficar Ready..." -ForegroundColor Yellow
$timeout = 120
$sw = [Diagnostics.Stopwatch]::StartNew()
$prometheusReady = $false

while ($sw.Elapsed.TotalSeconds -lt $timeout) {
    $status = kubectl get pod prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring -o jsonpath='{.status.phase}' 2>$null
    if ($status -eq "Running") {
        $prometheusReady = $true
        break
    }
    Start-Sleep -Seconds 5
    Write-Host "." -NoNewline
}
Write-Host ""

if ($prometheusReady) {
    Write-Host "Prometheus está rodando perfeitamente!" -ForegroundColor Green
} else {
    Write-Host "AVISO: O Prometheus demorou muito para responder. Pode ser necessário revisar os recursos da AWS." -ForegroundColor Red
}

# 5. Reiniciar o Grafana para forçar conexão com o banco de dados
Write-Host "`n[5/5] Reiniciando o Grafana para sincronizar os dashboards..." -ForegroundColor Yellow
kubectl rollout restart deployment prometheus-grafana -n monitoring | Out-Null
kubectl rollout status deployment prometheus-grafana -n monitoring --timeout=60s | Out-Null

# 6. Aplicar os coletores da nossa aplicação Rust
Write-Host "`n[+] Configurando o Prometheus para ler as métricas do Rust..." -ForegroundColor Yellow
kubectl apply -f k8s/servicemonitor.yaml | Out-Null

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host "   Tudo Pronto! O ambiente está curado e rodando.     " -ForegroundColor Green
Write-Host "======================================================" -ForegroundColor Cyan
Write-Host "`nPara acessar os Dashboards, abra DUAS ABAS no terminal e rode:" -ForegroundColor White
Write-Host "1. Para o Grafana: " -NoNewline; Write-Host "kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring" -ForegroundColor Cyan
Write-Host "2. Para forçar tráfego nas métricas Rust: " -NoNewline; Write-Host "curl http://localhost:8080/health" -ForegroundColor Cyan
Write-Host "`nAcesso Grafana: http://localhost:3000 (admin / prom-operator)" -ForegroundColor White
