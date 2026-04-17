local function player_state_base_url()
  return os.getenv("PLAYER_STATE_API") or "http://player-state:8081"
end

local function decode_payload(payload)
  if payload == nil or payload == "" then
    return {}
  end
  return nk.json_decode(payload)
end

local function api_request(base_url, path, method, body_table)
  local url = base_url .. path
  local headers = {
    ["Content-Type"] = "application/json",
  }
  local body = body_table and nk.json_encode(body_table) or nil
  local code, _, response_body = nk.http_request(url, method, headers, body, 10000)
  
  if code < 200 or code >= 300 then
    error(string.format("API request failed [%d] to %s: %s", code, url, response_body or ""))
  end
  
  return (response_body and response_body ~= "") and nk.json_decode(response_body) or {}
end

-- Rpc: Selecionar o Irmão Inicial
local function rpc_select_initial_sibling(context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"sibling_name"}) -- "Kaelen", "Elora", "Rion"
  
  local user_id = context.user_id
  
  -- Chama o serviço player-state em Rust para registrar o personagem
  local response = api_request(player_state_base_url(), "/api/v1/players/" .. user_id .. "/init", "post", {
    initial_character = input.sibling_name,
    account_id = user_id
  })
  
  return nk.json_encode(response)
end

-- Rpc: Iniciar Combate
local function rpc_start_match(_context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"match_id", "attacker_id", "defender_id"})

  local response = api_request(combat_base_url(), "/api/v1/combat/matches", "post", {
    match_id = input.match_id,
    attacker_id = input.attacker_id,
    defender_id = input.defender_id,
  })
  return nk.json_encode(response)
end

-- (Outros RPCs permanecem os mesmos, mas usando api_request simplificado)
local function rpc_submit_turn(_context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"match_id", "turn_id", "idempotency_key", "player_id", "character_id", "target_id", "action_type"})

  local response = api_request(combat_base_url(), "/api/v1/combat/matches/turns", "post", {
    match_id = input.match_id,
    turn_id = input.turn_id,
    action = {
      idempotency_key = input.idempotency_key,
      player_id = input.player_id,
      character_id = input.character_id,
      target_id = input.target_id,
      action_type = input.action_type,
    }
  })
  return nk.json_encode(response)
end

local function init_module(_ctx, _nk, initializer)
  initializer.register_rpc(rpc_select_initial_sibling, "cf_select_initial_sibling")
  initializer.register_rpc(rpc_start_match, "cf_start_match")
  initializer.register_rpc(rpc_submit_turn, "cf_submit_turn")
  initializer.register_rpc(rpc_get_match_state, "cf_get_match_state")
  initializer.register_rpc(rpc_end_match, "cf_end_match")
end

init_module = init_module
