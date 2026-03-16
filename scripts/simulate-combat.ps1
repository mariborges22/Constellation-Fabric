# Combat Trial Simulator
# Este script gera eventos artificiais para validar o fluxo Kinesis em ambas as regioes.

param (
    [Parameter(Mandatory=$false)]
    [string]$UrlList = "http://localhost:8082", # Default para o Combat Engine local
    
    [int]$EventsCount = 3
)

$urls = $UrlList -split ","

Write-Host "`n================================================================" -ForegroundColor Yellow
Write-Host "INICIANDO SIMULACAO DE COMBATE (Gerecao de Eventos)" -ForegroundColor Yellow
Write-Host "================================================================`n"

foreach ($url in $urls) {
    $clean_url = $url.Trim()
    Write-Host ">>> Region Endpoint: $clean_url" -ForegroundColor Cyan
    
    # Lista de tipos de acao disponiveis no Rust
    $actionTypes = @("NormalAttack", "ChargedAttack", "ElementalSkill", "ElementalBurst")
    
    for ($i=1; $i -le $EventsCount; $i++) {
        $randomAction = $actionTypes[(Get-Random -Maximum $actionTypes.Count)]
        
        # Payload de ataque simulado dinâmico
        $payload = @{
            idempotency_key = [guid]::NewGuid().ToString()
            player_id       = [guid]::NewGuid().ToString()  # Simula jogadores diferentes
            character_id    = [guid]::NewGuid().ToString()  # Simula personagens diferentes
            target_id       = [guid]::NewGuid().ToString()
            action_type     = $randomAction
        } | ConvertTo-Json
        
        Write-Host "Enviando Evento #$i ($randomAction) ..." -NoNewline
        try {
            $response = Invoke-RestMethod -Uri "$clean_url/api/v1/combat/attack" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10
            Write-Host " [OK] - Damage: $($response.damage_dealt) | Enemy Alive: $($response.enemy_alive)" -ForegroundColor Green
        } catch {
            Write-Host " [FALHA] - $($_.Exception.Message)" -ForegroundColor Red
        }
        Start-Sleep -Milliseconds 500
    }
    Write-Host ""
}

Write-Host "----------------------------------------------------------------"
Write-Host "Simulacao Concluida! Agora rode o Kinesis Debugger para ver os dados." -ForegroundColor Green
Write-Host "----------------------------------------------------------------`n"
