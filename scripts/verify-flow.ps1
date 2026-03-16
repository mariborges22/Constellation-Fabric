# Verification Kit - Constellation Fabric
# Este script verifica se o túnel VPC Peering está sendo usado e se os eventos estão chegando.

$US_REGION = "us-east-1"
$EU_REGION = "eu-west-1"

Write-Host "================================================================" -ForegroundColor Green
Write-Host "VERIFICAÇÃO FINAL: TÚNEL US <-> EU ATIVO" -ForegroundColor Green
Write-Host "================================================================`n"

# 1. Logs da Europa (Verificar Conexão com Banco)
Write-Host "[1/3] Olhando o 'Coração' da Europa (Logs do Combat)..." -ForegroundColor Cyan
$log_group = "/ecs/constellation-fabric-combat"
$stream = aws logs describe-log-streams --log-group-name $log_group --region $EU_REGION --order-by LastEventTime --descending --limit 1 --query "logStreams[0].logStreamName" --output text

if ($stream -and $stream -ne "None") {
    Write-Host "Últimos logs de: $stream"
    aws logs get-log-events --log-group-name $log_group --log-stream-name $stream --region $EU_REGION --limit 10 --query "events[].message" --output table
} else {
    Write-Host "X - Nenhum log encontrado na Europa. A task pode estar travada no pull ou crashando antes de logar." -ForegroundColor Red
}

# 2. Verificação de Kinesis (Onde o ouro está)
Write-Host "`n[2/3] Verificando Streams de Eventos..." -ForegroundColor Cyan

function Peek-Kinesis($region, $stream_name) {
    Write-Host "-> Analisando $stream_name em $region..."
    $shard = aws kinesis describe-stream --stream-name $stream_name --region $region --query "StreamDescription.Shards[0].ShardId" --output text
    if ($shard -and $shard -ne "None") {
        $iterator = aws kinesis get-shard-iterator --stream-name $stream_name --region $region --shard-id $shard --shard-iterator-type LATEST --query "ShardIterator" --output text
        $records = aws kinesis get-records --shard-iterator $iterator --region $region --limit 5
        $count = ($records | ConvertFrom-Json).Records.Count
        if ($count -gt 0) {
            Write-Host "VITORIA! Recebidos $count eventos em $region." -ForegroundColor Green
        } else {
            Write-Host "Aguardando eventos... O stream está ativo mas vazio." -ForegroundColor Yellow
        }
    }
}

Peek-Kinesis $US_REGION "constellation-fabric-combat-events"
Peek-Kinesis $EU_REGION "constellation-fabric-combat-events-eu-west-1"

# 3. Target Group Health (Europe)
Write-Host "`n[3/3] Saúde do Load Balancer (Europa)..." -ForegroundColor Cyan
aws elbv2 describe-target-groups --region $EU_REGION --query "TargetGroups[?contains(TargetGroupName, 'cb-tg')].TargetGroupArn" --output text | ForEach-Object {
    aws elbv2 describe-target-health --target-group-arn $_ --region $EU_REGION --query "TargetHealthDescriptions[].{Id:Target.Id, Health:TargetHealth.State}" --output table
}

Write-Host "`n================================================================"
Write-Host "Verificacao Concluida" -ForegroundColor Green
Write-Host "================================================================"
