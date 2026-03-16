# Kinesis Debugging Script - Constellation Fabric
# Este script lista, decodifica e formata eventos dos streams Kinesis.

param (
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$StreamName,
    
    [Parameter(Mandatory=$false)]
    [int]$Limit = 5
)

Write-Host "`n--- Investigando Kinesis: $StreamName em $Region ---" -ForegroundColor Cyan

# 1. Pegar Shards
$shards = aws kinesis describe-stream --stream-name $StreamName --region $Region | ConvertFrom-Json
$shardId = $shards.StreamDescription.Shards[0].ShardId

if (-not $shardId) {
    Write-Host "X - Nenhum Shard encontrado para o stream $StreamName" -ForegroundColor Red
    return
}

Write-Host "Shard Detectado: $shardId"

# 2. Pegar Iterator (AT_TIMESTAMP de 1 hora atrás para pegar dados recentes)
$ago = (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ssZ")
$iterator = aws kinesis get-shard-iterator --stream-name $StreamName --region $Region --shard-id $shardId --shard-iterator-type TRIM_HORIZON --query "ShardIterator" --output text

if ($iterator -eq "None") {
    Write-Host "X - Nao foi possivel obter o Shard Iterator" -ForegroundColor Red
    return
}

# 3. Buscar Records
$records_raw = aws kinesis get-records --shard-iterator $iterator --region $Region --limit $Limit | ConvertFrom-Json

if ($records_raw.Records.Count -eq 0) {
    Write-Host "--- Stream Vazio: Nenhum registro encontrado nos últimos 60 minutos ---" -ForegroundColor Yellow
    Write-Host "Dica SAA-C03: Verifique se as ECS Tasks tem a policy 'kinesis:PutRecord' e se estao enviando dados."
} else {
    Write-Host "!!! SUCESSO !!! Encontrados $($records_raw.Records.Count) registros.`n" -ForegroundColor Green
    
    foreach ($record in $records_raw.Records) {
        # Decodificar Base64
        $bytes = [System.Convert]::FromBase64String($record.Data)
        $decoded = [System.Text.Encoding]::UTF8.GetString($bytes)
        
        Write-Host "--- Evento (ID: $($record.SequenceNumber)) ---" -ForegroundColor Gray
        try {
            # Tentar formatar como JSON bonito
            $decoded | ConvertFrom-Json | ConvertTo-Json
        } catch {
            # Se não for JSON, imprime texto puro
            Write-Host $decoded
        }
        Write-Host "--------------------------------------------------`n"
    }
}
