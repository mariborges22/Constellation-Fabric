# Script para limpar o estado do Terraform e resolver o erro de Identity Change
Write-Host "Iniciando limpeza de estado do Terraform..." -ForegroundColor Cyan

# Entrar na pasta de staging
cd infra/enviroments/staging

# 1. Remover os recursos antigos do estado do Terraform
# Isso diz ao Terraform: "Esqueça que esses recursos existem, não tente lê-los ou destruí-los"
Write-Host "Removendo recursos problemáticos do estado..." -ForegroundColor Yellow

terraform state rm module.kubernetes_deploy_us.kubernetes_deployment.auth
terraform state rm module.kubernetes_deploy_us.kubernetes_deployment.combat
terraform state rm module.kubernetes_deploy_us.kubernetes_deployment.nakama

# Se você já tiver tentado rodar com os novos nomes, vamos limpar eles também por segurança
terraform state rm module.kubernetes_deploy_us.kubernetes_manifest.auth_deployment
terraform state rm module.kubernetes_deploy_us.kubernetes_manifest.combat_deployment
terraform state rm module.kubernetes_deploy_us.kubernetes_manifest.nakama_deployment

Write-Host "Estado limpo com sucesso!" -ForegroundColor Green
Write-Host "Agora, tente rodar: terraform apply" -ForegroundColor White
