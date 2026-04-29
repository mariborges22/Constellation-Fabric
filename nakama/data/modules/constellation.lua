-- Constellation Fabric - Nakama Bridge Module
-- Integrates Nakama with Rust-based services (Auth, Combat, PlayerState)

local nk = require("nakama")

-- Helper: Base URLs for internal services
local function player_state_base_url()
  return os.getenv("PLAYER_STATE_API") or "http://player-state:8081"
end

local function combat_base_url()
  return os.getenv("COMBAT_API") or "http://combat:8082"
end

-- Helper: Ensure required fields are present in the payload
local function ensure_fields(input, fields)
  for _, field in ipairs(fields) do
    if input[field] == nil then
      error(string.format("Missing required field: %s", field))
    end
  end
end

-- Helper: Decode JSON payload
local function decode_payload(payload)
  if payload == nil or payload == "" then
    return {}
  end
  return nk.json_decode(payload)
end

-- Helper: Generic API Request
local function api_request(base_url, path, method, body_table)
  local url = base_url .. path
  local headers = {
    ["Content-Type"] = "application/json",
  }
  local body = body_table and nk.json_encode(body_table) or nil
  local code, _, response_body = nk.http_request(url, method, headers, body, 10000)
  
  if code < 200 or code >= 300 then
    nk.logger_error(string.format("API request failed [%d] to %s: %s", code, url, response_body or ""))
    error(string.format("Service unavailable: %s", path))
  end
  
  return (response_body and response_body ~= "") and nk.json_decode(response_body) or {}
end

-- RPC: Select Initial Sibling (Player Initialization)
local function rpc_select_initial_sibling(context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"sibling_name"}) -- "Kaelen", "Elora", "Rion"
  
  local user_id = context.user_id
  
  -- Call Rust player-state service
  local response = api_request(player_state_base_url(), "/api/v1/players/" .. user_id .. "/init", "post", {
    initial_character = input.sibling_name,
    account_id = user_id
  })
  
  return nk.json_encode(response)
end

-- RPC: Start Match
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

-- RPC: Submit Turn
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

-- RPC: Get Match State
local function rpc_get_match_state(_context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"match_id"})

  local response = api_request(combat_base_url(), "/api/v1/combat/matches/" .. input.match_id, "get", nil)
  return nk.json_encode(response)
end

-- RPC: End Match
local function rpc_end_match(_context, payload)
  local input = decode_payload(payload)
  ensure_fields(input, {"match_id"})

  local response = api_request(combat_base_url(), "/api/v1/combat/matches/end", "post", {
    match_id = input.match_id
  })
  return nk.json_encode(response)
end

-- Initialize Module
local function init_module(_ctx, _nk, initializer)
  initializer.register_rpc(rpc_select_initial_sibling, "cf_select_initial_sibling")
  initializer.register_rpc(rpc_start_match, "cf_start_match")
  initializer.register_rpc(rpc_submit_turn, "cf_submit_turn")
  initializer.register_rpc(rpc_get_match_state, "cf_get_match_state")
  initializer.register_rpc(rpc_end_match, "cf_end_match")
  
  nk.logger_info("Constellation Bridge Module Loaded Successfully")
end

return {
  init = init_module
}
