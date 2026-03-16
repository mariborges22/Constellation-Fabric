# Stress Test Simulator
# Simula dezenas de jogadores simultâneos disparando ações globais.

param (
    [Parameter(Mandatory=$true)]
    [string]$UrlList,
    
    [int]$Concurrency = 5,
    [int]$EventsPerThread = 50
)

$urls = $UrlList -split ","

Write-Host "`n[!IMPORTANT] INICIANDO TESTE DE CARRA PESADO (Load Test)" -ForegroundColor Red
Write-Host "Config: $Concurrency Threads | $EventsPerThread Eventos/Thread`n" -ForegroundColor Yellow

$jobs = @()

foreach ($url in $urls) {
    $clean_url = $url.Trim()
    
    for ($t=1; $t -le $Concurrency; $t++) {
        $scriptBlock = {
            param($url, $count)
            $actionTypes = @("NormalAttack", "ChargedAttack", "ElementalSkill", "ElementalBurst")
            for ($i=1; $i -le $count; $i++) {
                $payload = @{
                    idempotency_key = [guid]::NewGuid().ToString()
                    player_id       = [guid]::NewGuid().ToString()
                    character_id    = [guid]::NewGuid().ToString()
                    target_id       = [guid]::NewGuid().ToString()
                    action_type     = $actionTypes[(Get-Random -Maximum $actionTypes.Count)]
                } | ConvertTo-Json
                
                try {
                    Invoke-RestMethod -Uri "$url/api/v1/combat/attack" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 5 | Out-Null
                } catch {}
            }
        }
        $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $clean_url, $EventsPerThread
    }
}

Write-Host "Aguardando conclusão das threads..." -ForegroundColor Cyan
Wait-Job $jobs | Out-Null
Remove-Job $jobs

Write-Host "`n[SUCESSO] Teste concluído!" -ForegroundColor Green
Write-Host "Verifique os resultados no Grafana e CloudWatch agora." -ForegroundColor Yellow
