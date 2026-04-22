use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use uuid::Uuid;
use crate::{
    Character, CombatActionRequestV1, CombatEngine, CombatResponseV1, EndMatchRequestV1,
    EndMatchResponseV1, MatchStateResponseV1, StartMatchRequestV1, StartMatchResponseV1,
    SubmitTurnRequestV1,
};
use crate::error::{CombatError, CombatResult};

#[derive(Clone)]
pub struct AppState {
    pub combat_engine: Arc<CombatEngine>,
    pub player_state_api: String,
    pub matches: Arc<Mutex<HashMap<Uuid, MatchSession>>>,
    pub idempotency_cache: Arc<Mutex<HashMap<Uuid, CombatResponseV1>>>,
}

#[derive(Debug, Clone)]
pub struct MatchSession {
    pub match_id: Uuid,
    pub active: bool,
    pub last_turn_id: u64,
    pub attacker: Character,
    pub defender: Character,
    pub last_action: Option<CombatActionRequestV1>,
}

#[derive(Debug, serde::Deserialize)]
struct PlayerStateDto {
    id: Uuid,
    username: String,
    level: i32,
    health: i32,
}

async fn fetch_character_or_fallback(player_state_api: &str, player_id: Uuid) -> Character {
    let url = format!("{}/{}", player_state_api.trim_end_matches('/'), player_id);
    let response = reqwest::get(&url).await;

    if let Ok(resp) = response {
        if resp.status().is_success() {
            if let Ok(player) = resp.json::<PlayerStateDto>().await {
                let mut c = Character::new(player.username, crate::Element::Physical, player.level.max(1));
                c.id = player.id;
                c.max_hp = player.health.max(1) as f32;
                c.current_hp = c.max_hp;
                return c;
            }
        }
    }

    let mut fallback = Character::new("Fallback".to_string(), crate::Element::Physical, 10);
    fallback.id = player_id;
    fallback
}

pub async fn submit_turn_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<SubmitTurnRequestV1>,
) -> CombatResult<impl IntoResponse> {
    if req.action.idempotency_key.is_nil() {
        return Err(CombatError::InvalidAction("Missing idempotency key".to_string()));
    }

    // Real idempotency handling for submit_turn.
    if let Some(cached) = state.idempotency_cache.lock().await.get(&req.action.idempotency_key).cloned() {
        return Ok(Json(cached));
    }

    let mut matches = state.matches.lock().await;
    let session = matches
        .get_mut(&req.match_id)
        .ok_or_else(|| CombatError::CharacterNotFound("Match not found".to_string()))?;

    if !session.active {
        return Err(CombatError::InvalidAction("Match already ended".to_string()));
    }
    if req.turn_id <= session.last_turn_id {
        return Err(CombatError::InvalidAction("Out-of-order turn submission".to_string()));
    }

    let result = state
        .combat_engine
        .execute_action(&session.attacker, &mut session.defender, req.action.action_type, &[session.attacker.clone()]);

    session.last_turn_id = req.turn_id;
    session.last_action = Some(req.action.clone());

    let response = CombatResponseV1 {
        success: true,
        damage_dealt: result.final_damage,
        enemy_alive: session.defender.is_alive(),
        player_team_state: vec![session.attacker.clone()],
        enemy_state: vec![session.defender.clone()],
        idempotency_key: req.action.idempotency_key,
    };

    drop(matches);
    state
        .idempotency_cache
        .lock()
        .await
        .insert(req.action.idempotency_key, response.clone());

    Ok(Json(response))
}

pub async fn combat_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CombatActionRequestV1>,
) -> CombatResult<impl IntoResponse> {
    // Backward-compatible endpoint maps to a synthetic match id.
    let synthetic_match = Uuid::new_v4();
    let start = StartMatchRequestV1 {
        match_id: synthetic_match,
        attacker_id: req.player_id,
        defender_id: req.target_id,
    };
    let _ = start_match_handler(State(state.clone()), Json(start)).await?;
    submit_turn_handler(
        State(state),
        Json(SubmitTurnRequestV1 {
            match_id: synthetic_match,
            turn_id: 1,
            action: req,
        }),
    )
    .await
}

pub async fn start_match_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<StartMatchRequestV1>,
) -> CombatResult<impl IntoResponse> {
    let attacker = fetch_character_or_fallback(&state.player_state_api, req.attacker_id).await;
    let defender = fetch_character_or_fallback(&state.player_state_api, req.defender_id).await;

    let session = MatchSession {
        match_id: req.match_id,
        active: true,
        last_turn_id: 0,
        attacker,
        defender,
        last_action: None,
    };

    state.matches.lock().await.insert(req.match_id, session);

    Ok((StatusCode::CREATED, Json(StartMatchResponseV1 {
        match_id: req.match_id,
        status: "started".to_string(),
    })))
}

pub async fn get_match_state_handler(
    State(state): State<Arc<AppState>>,
    Path(match_id): Path<Uuid>,
) -> CombatResult<impl IntoResponse> {
    let matches = state.matches.lock().await;
    let session = matches
        .get(&match_id)
        .ok_or_else(|| CombatError::CharacterNotFound("Match not found".to_string()))?;

    Ok(Json(MatchStateResponseV1 {
        match_id: session.match_id,
        active: session.active,
        last_turn_id: session.last_turn_id,
        attacker: session.attacker.clone(),
        defender: session.defender.clone(),
        last_action: session.last_action.clone(),
    }))
}

pub async fn end_match_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<EndMatchRequestV1>,
) -> CombatResult<impl IntoResponse> {
    let mut matches = state.matches.lock().await;
    let session = matches
        .get_mut(&req.match_id)
        .ok_or_else(|| CombatError::CharacterNotFound("Match not found".to_string()))?;
    session.active = false;

    Ok(Json(EndMatchResponseV1 {
        match_id: req.match_id,
        status: "ended".to_string(),
    }))
}

pub async fn health_check_handler() -> impl IntoResponse {
    (StatusCode::OK, Json(serde_json::json!({
        "status": "ok",
        "service": "combat",
        "version": "1.0.0"
    })))
}


