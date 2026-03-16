# IAM Policy Inspector
# Este script lê o JSON da policy inline para confirmar as permissões.

param (
    [Parameter(Mandatory=$true)]
    [string]$Region,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$true)]
    [string]$ServiceName
)

Write-Host "`n--- Inspecionando JSON da Policy: $ServiceName em $Region ---" -ForegroundColor Cyan

# 1. Pegar Task Def e Task Role
$task_def = aws ecs describe-services --cluster $ClusterName --service $ServiceName --region $Region --query "services[0].taskDefinition" --output text
$task_role_arn = aws ecs describe-task-definition --task-definition $task_def --region $Region --query "taskDefinition.taskRoleArn" --output text

if ($task_role_arn -eq "None") {
    Write-Host "X - Sem Task Role configurada!" -ForegroundColor Red
    return
}

$role_name = $task_role_arn.Split("/")[-1]
Write-Host "Role Name: $role_name"

# 2. Ler Policy Inline
$policy_name = "ecs-task-monitoring-policy"
Write-Host "Lendo policy: $policy_name ..."

$policy_json = aws iam get-role-policy --role-name $role_name --policy-name $policy_name --query "PolicyDocument" --output json

if ($policy_json) {
    Write-Host "`nJSON da Policy Ativa:" -ForegroundColor Gray
    $policy_json | ConvertFrom-Json | ConvertTo-Json
} else {
    Write-Host "X - Policy nao encontrada!" -ForegroundColor Red
}

Write-Host "`n--------------------------------------------------" 
