# Staging -> Production Rollout (Nakama + Combat)

Este runbook define o processo mínimo para promover integração Nakama/Combat com segurança, observabilidade e rollback rápido.

## 1) Pré-requisitos

- Domínios separados por ambiente (ex.: `api-stg.*`, `ws-stg.*`, `api.*`, `ws.*`).
- Secrets separados por ambiente (AWS Secrets Manager/SSM).
- Imagens pinadas por digest (sem `latest`).
- TLS válido em ALB + Cloudflare em `Full (strict)`.

## 2) Gate de Segurança (obrigatório)

- [ ] Todas as imagens usadas no deploy estão pinadas por digest.
- [ ] Scan de vulnerabilidade sem findings críticos abertos.
- [ ] Sem credenciais hardcoded em `config.yml`, `Dockerfile`, scripts.
- [ ] Variáveis sensíveis vêm apenas de Secrets Manager/SSM.

## 3) Gate Funcional em Staging

Executar smoke do fluxo de partida:

1. `cf_start_match`
2. `cf_submit_turn` (turno 1)
3. Repetir `cf_submit_turn` com mesma `idempotency_key` (espera replay idempotente)
4. `cf_get_match_state`
5. `cf_end_match`

Critérios:

- [ ] `start_match` retorna `201/200`.
- [ ] `submit_turn` retorna dano > 0 sem erro.
- [ ] Repetição da mesma chave retorna resposta idêntica.
- [ ] `get_match_state` retorna `last_turn_id` atualizado.
- [ ] `end_match` marca `status=ended`.

## 4) Gate Não Funcional em Staging

- [ ] p95 de `submit_turn` dentro do alvo (definir baseline inicial).
- [ ] Taxa de erro HTTP < 1% em carga curta.
- [ ] Sem reinício anormal de task ECS.
- [ ] Logs sem erro crítico/retry infinito.

## 5) Promoção para Produção

1. Deploy com mesma imagem validada em staging (mesmo digest).
2. Promoção gradual (canary) se possível.
3. Monitorar por 30-60 min:
   - erros 5xx,
   - latência,
   - reinício de tasks,
   - falhas de RPC Nakama.

## 6) Go / No-Go

Go:

- Todos os gates de segurança + staging aprovados.
- Sem regressão de latência/erro após canary.

No-Go:

- Qualquer falha de idempotência/consistência de estado.
- Erro crítico de TLS/routing.
- Vulnerabilidade crítica não mitigada.

## 7) Rollback

- Reverter task definition/service para revisão anterior.
- Reverter rota canary para 0%.
- Revalidar smoke básico (`health`, auth, combat, nakama rpc).

