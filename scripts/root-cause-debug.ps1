# Root Cause Diagnostic Script - Kinesis Issues
# Este script investiga as 3 falhas mais comuns: IAM, Configuração e Rede.

param (
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$ServiceName
)

Write-Host "`n================================================================" -ForegroundColor Yellow
Write-Host "INVESTIGANDO CAUSA RAIZ: $Region | $ServiceName" -ForegroundColor Yellow
Write-Host "================================================================`n"

# 1. Auditoria de IAM (Permissões de Escrita)
Write-Host "[1/4] Verificando Permissões (IAM)..." -ForegroundColor Cyan
$task_def_arn = aws ecs describe-services --cluster $ClusterName --service $ServiceName --region $Region --query "services[0].taskDefinition" --output text
$task_role_arn = aws ecs describe-task-definition --task-definition $task_def_arn --region $Region --query "taskDefinition.taskRoleArn" --output text

if ($task_role_arn -and $task_role_arn -ne "None") {
    $role_name = $task_role_arn.Split("/")[-1]
    Write-Host "Task Role detectada: $role_name"
    Write-Host "Policies Anexadas:"
    aws iam list-attached-role-policies --role-name $role_name --query "AttachedPolicies[].PolicyName" --output table
    Write-Host "Policies Inline:"
    aws iam list-role-policies --role-name $role_name --query "PolicyNames" --output table
} else {
    Write-Host "X - ERRO: A Task nao tem uma 'Task Role' configurada. Ela nao consegue falar com o Kinesis." -ForegroundColor Red
}

# 2. Auditoria de Configuração (Variaveis de Ambiente)
Write-Host "`n[2/4] Verificando Configuração (Env Vars)..." -ForegroundColor Cyan
aws ecs describe-task-definition --task-definition $task_def_arn --region $Region --query "taskDefinition.containerDefinitions[0].environment" --output json

# 3. Auditoria de Rede (Saída para Kinesis)
Write-Host "`n[3/4] Verificando Conectividade com a API do Kinesis..." -ForegroundColor Cyan
$subnet_id = aws ecs describe-services --cluster $ClusterName --service $ServiceName --region $Region --query "services[0].networkConfiguration.awsvpcConfiguration.subnets[0]" --output text
$vpc_id = aws ec2 describe-subnets --subnet-ids $subnet_id --region $Region --query "Subnets[0].VpcId" --output text

# Verificando se existe VPC Endpoint para Kinesis
$endpoints = aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$vpc_id" --region $Region --query "VpcEndpoints[?contains(ServiceName, 'kinesis')].ServiceName" --output table
if ($endpoints) {
    Write-Host "VPC Endpoint detectado (Tráfico Privado Ativo)." -ForegroundColor Green
} else {
    Write-Host "Nenhum VPC Endpoint. O tráfego depende de NAT Gateway ou Internet Gateway." -ForegroundColor Yellow
}

# 4. Auditoria de Logs de Erro (App)
Write-Host "`n[4/4] Coletando Logs para arquivo (Bypassing Encoding Errors)..." -ForegroundColor Cyan

$log_group = "/ecs/constellation-fabric-combat"
$streams = aws logs describe-log-streams --log-group-name $log_group --region $Region --order-by LastEventTime --descending --limit 1 --query "logStreams[0].logStreamName" --output text

if ($streams -and $streams -ne "None") {
    Write-Host "Extraindo logs de $streams para 'logs_debug.txt'..." -ForegroundColor Gray
    # Salvar em arquivo com UTF8 explicitamente
    aws logs get-log-events --log-group-name $log_group --log-stream-name $streams --region $Region --limit 100 --query "events[].message" --output text > logs_debug.txt
    
    Write-Host "`n--- RESUMO DOS LOGS (Primeiras 15 linhas) ---" -ForegroundColor White
    Get-Content logs_debug.txt -Head 15
    Write-Host "`nLog completo salvo em: $(Get-Location)\logs_debug.txt" -ForegroundColor Yellow
} else {
    Write-Host "X - Nenhum stream de log encontrado no grupo $log_group" -ForegroundColor Red
}

Write-Host "`n================================================================"
Write-Host "Dica SAA-C03: Se o log mostrar 'Timeout', é REDE. Se mostrar 'AccessDenied', é IAM." -ForegroundColor Yellow
Write-Host "================================================================"
