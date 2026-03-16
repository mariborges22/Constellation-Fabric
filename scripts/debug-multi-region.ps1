# Multi-Region Diagnostic Script - Constellation Fabric (v5 - Extremely Simple)
# Este script evita QUALQUER query complexa do AWS CLI para não brigar com o PowerShell.

$US_REGION = "us-east-1"
$EU_REGION = "eu-west-1"

Write-Host "`n=== 1. VPCs na Europa ($EU_REGION) ===" -ForegroundColor Cyan
$vpcs = aws ec2 describe-vpcs --region $EU_REGION | ConvertFrom-Json
if ($vpcs.Vpcs) {
    foreach ($v in $vpcs.Vpcs) {
        $name = ($v.Tags | Where-Object Key -eq "Name").Value
        Write-Host "VPC: $($v.VpcId) | CIDR: $($v.CidrBlock) | Nome: $name"
    }
}

Write-Host "`n=== 2. VPC Peering (US <-> EU) ===" -ForegroundColor Cyan
$peering = aws ec2 describe-vpc-peering-connections --region $US_REGION | ConvertFrom-Json
if ($peering.VpcPeeringConnections) {
    foreach ($p in $peering.VpcPeeringConnections) {
        Write-Host "ID: $($p.VpcPeeringConnectionId) | Status: $($p.Status.Code)"
    }
} else {
    Write-Host "Nenhum peering encontrado."
}

Write-Host "`n=== 3. Status ECS (Combat) ===" -ForegroundColor Cyan
Write-Host "EUA:"
$svc_us = aws ecs describe-services --cluster constellation-fabric-cluster --services combat-service --region $US_REGION | ConvertFrom-Json
Write-Host "Running: $($svc_us.Services[0].RunningCount) / Desired: $($svc_us.Services[0].DesiredCount)"

Write-Host "Europa:"
$svc_eu = aws ecs describe-services --cluster constellation-fabric-cluster-eu-west-1 --services combat-service --region $EU_REGION | ConvertFrom-Json
if ($svc_eu.Services) {
    Write-Host "Running: $($svc_eu.Services[0].RunningCount) / Desired: $($svc_eu.Services[0].DesiredCount)"
}

Write-Host "`n=== 4. Erro da última Task (Europa) ===" -ForegroundColor Cyan
$tasks = aws ecs list-tasks --cluster constellation-fabric-cluster-eu-west-1 --region $EU_REGION --desired-status STOPPED --max-items 1 | ConvertFrom-Json
if ($tasks.TaskArns) {
    $detail = aws ecs describe-tasks --cluster constellation-fabric-cluster-eu-west-1 --region $EU_REGION --tasks $tasks.TaskArns[0] | ConvertFrom-Json
    Write-Host "Task: $($tasks.TaskArns[0])"
    Write-Host "Motivo: $($detail.Tasks[0].StoppedReason)"
    Write-Host "Imagem: $($detail.Tasks[0].Containers[0].Image)"
}

Write-Host "`n=== 5. RDS e Kinesis ===" -ForegroundColor Cyan
$db = aws rds describe-db-instances --db-instance-identifier constellation-fabric-db --region $US_REGION | ConvertFrom-Json
Write-Host "RDS Publico: $($db.DBInstances[0].PubliclyAccessible)"
Write-Host "Kinesis US:"
(aws kinesis list-streams --region $US_REGION | ConvertFrom-Json).StreamNames
Write-Host "Kinesis EU:"
(aws kinesis list-streams --region $EU_REGION | ConvertFrom-Json).StreamNames

Write-Host "`n================================================================"
Write-Host "DIAGNOSTICO CONCLUIDO"
Write-Host "================================================================"
