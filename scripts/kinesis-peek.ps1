param(
    [string]$StreamName = "constellation-fabric-combat-events",
    [string]$Region = "us-east-1",
    [int]$Limit = 5
)

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "KINESIS EVENT INSPECTOR - Constellation Fabric" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host "Stream: $StreamName" -ForegroundColor Gray
Write-Host "Region: $Region" -ForegroundColor Gray
Write-Host ""

try {
    # 1. Obter o ID do primeiro shard (assumindo single shard para staging)
    $shardId = aws kinesis describe-stream --stream-name $StreamName --region $Region --query 'StreamDescription.Shards[0].ShardId' --output text
    
    if ($null -eq $shardId -or $shardId -eq "None") {
        Write-Host "Erro: Não foi possível encontrar shards para o stream $StreamName" -ForegroundColor Red
        exit 1
    }

    Write-Host "Inspecionando Shard: $shardId" -ForegroundColor Yellow

    # 2. Obter o Shard Iterator (TRIM_HORIZON para pegar o que já está lá ou LATEST para novos)
    $iterator = aws kinesis get-shard-iterator --stream-name $StreamName --shard-id $shardId --shard-iterator-type TRIM_HORIZON --region $Region --query 'ShardIterator' --output text

    # 3. Buscar registros
    $responseJson = aws kinesis get-records --shard-iterator $iterator --limit $Limit --region $Region
    $response = $responseJson | ConvertFrom-Json

    if ($response.Records.Count -eq 0) {
        Write-Host "Nenhum dado encontrado no stream no momento." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Encontrados $($response.Records.Count) registros recentes:" -ForegroundColor Green
    Write-Host ""

    foreach ($record in $response.Records) {
        $dataBase64 = $record.Data
        # Decode Base64 para String UTF8
        $bytes = [System.Convert]::FromBase64String($dataBase64)
        $decodedData = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        Write-Host "--- Registro: $($record.SequenceNumber) ---" -ForegroundColor Gray
        try {
            # Tentar formatar como JSON se possível
            $jsonObj = $decodedData | ConvertFrom-Json
            $jsonObj | ConvertTo-Json -Depth 10 | Write-Host
        } catch {
            # Se não for JSON, mostra o texto puro
            Write-Host $decodedData -ForegroundColor White
        }
        Write-Host ""
    }

} catch {
    Write-Host "Erro inesperado: $_" -ForegroundColor Red
}
