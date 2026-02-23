# 🚨 Manual de Rollback & Recuperação - Constellation Fabric

Este documento contém os procedimentos "Break Glass" para reverter alterações problemáticas em diferentes camadas da infraestrutura.

## 1. Rollback de Aplicação (ECS)
Se o novo container estiver instável ou com bugs críticos:

### Via Script Automatizado (Recomendado)
```powershell
./scripts/rollback.ps1 -ServiceName "auth"
```

### Manual via AWS CLI
1. Liste as definições de tarefa: `aws ecs list-task-definitions --family constellation-auth`
2. Identifique a versão anterior estável (ex: `:15`).
3. Force o update do serviço:
```bash
aws ecs update-service --cluster constellation-cluster --service auth-service --task-definition constellation-auth:15 --force-new-deployment
```

---

## 2. Rollback de Infraestrutura (Terraform)
Se o `terraform apply` quebrou a rede ou permissões:

1. **Reverter Código**: `git revert HEAD` e push para a branch afetada.
2. **Correção de Estado**: Se o estado ficou travado, use `terraform force-unlock <LOCK_ID>`.
3. **Re-Apply**: A pipeline de CI/CD aplicará a versão anterior estável automaticamente após o revert do Git.

---

## 3. Rollback de Código (Git)
Para remover um commit ruim do histórico de deploy:

```bash
# Reverter o último commit
git revert HEAD
git push origin staging
```

---

## 4. Auditoria de Logs pós-Incidente
1. **CloudFront Logs**: Verifique o bucket S3 `cf-logs` para erros 5xx.
2. **CloudWatch**: Analise os logs do container em `/ecs/constellation-fabric`.
