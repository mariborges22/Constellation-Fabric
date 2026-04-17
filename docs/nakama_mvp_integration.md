# Nakama MVP Integration (Combat Bridge)

Este guia descreve o fluxo mínimo para integrar Nakama com o serviço `combat` no Constellation.

## RPCs registradas

No runtime Lua (`nakama/data/modules/constellation.lua`) foram registradas as seguintes RPCs:

- `cf_start_match`
- `cf_submit_turn`
- `cf_get_match_state`
- `cf_end_match`

Todas elas fazem bridge para a API do combat:

- `POST /api/v1/combat/matches`
- `POST /api/v1/combat/matches/turns`
- `GET /api/v1/combat/matches/:match_id`
- `POST /api/v1/combat/matches/end`

## Variáveis importantes

- `COMBAT_API_BASE_URL` (default: `http://combat:8082`)

## Exemplo de payloads

### 1) Start match
RPC: `cf_start_match`

```json
{
  "match_id": "c4606b8b-4970-4b84-bbe5-64f83f51513a",
  "attacker_id": "9a0e26dd-65d2-42dd-b08a-ea6e0f3b1c5e",
  "defender_id": "e0871254-641f-4231-b7dd-a03226c0d2e3"
}
```

### 2) Submit turn
RPC: `cf_submit_turn`

```json
{
  "match_id": "c4606b8b-4970-4b84-bbe5-64f83f51513a",
  "turn_id": 1,
  "idempotency_key": "524f5d45-57d6-4b9e-889a-4518f41efd29",
  "player_id": "9a0e26dd-65d2-42dd-b08a-ea6e0f3b1c5e",
  "character_id": "9a0e26dd-65d2-42dd-b08a-ea6e0f3b1c5e",
  "target_id": "e0871254-641f-4231-b7dd-a03226c0d2e3",
  "action_type": "NormalAttack"
}
```

### 3) Get match state
RPC: `cf_get_match_state`

```json
{
  "match_id": "c4606b8b-4970-4b84-bbe5-64f83f51513a"
}
```

### 4) End match
RPC: `cf_end_match`

```json
{
  "match_id": "c4606b8b-4970-4b84-bbe5-64f83f51513a"
}
```

## Próximos passos (P0)

1. Buildar e publicar a imagem Nakama com este módulo Lua.
2. Subir Nakama no mesmo network namespace do `combat`.
3. Testar chamadas RPC via cliente Nakama.
4. Ajustar auth/jogador para usar IDs reais de conta.

## Smoke test rápido

Script disponível em `scripts/smoke-nakama-combat.sh`.

Exemplo:

```bash
chmod +x scripts/smoke-nakama-combat.sh
SERVER_KEY="seu_server_key" \
NAKAMA_HTTP="https://api-stg.seu-dominio.com" \
./scripts/smoke-nakama-combat.sh
```
