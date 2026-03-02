use axum::{extract::State, http::StatusCode, response::IntoResponse, Json};
use std::sync::Arc;
use crate::{CombatEngine, CombatActionRequestV1, CombatResponseV1, Character};

#[derive(Clone)]
pub struct AppState {
    pub combat_engine: Arc<CombatEngine>,
}

pub async fn combat_handler(
    State(state): State<Arc<AppState>>,
    Json(req): Json<CombatActionRequestV1>,
) -> impl IntoResponse {
    // 1. Validate Idempotency (in production, we'd check a redis/db cache)
    // For now, we assume it's valid or handled at infrastructure level.

    // 2. Fetch Characters (Mocking data for now; in production, call player-state service)
    // Here we simulate the authoritative state retrieval
    let mut attacker = Character::new("Player".to_string(), crate::Element::Pyro, 10);
    let mut defender = Character::new("Enemy".to_string(), crate::Element::Hydro, 10);
    
    attacker.elemental_mastery = 100.0;
    attacker.critical_rate = 0.5;
    attacker.critical_damage = 2.0;

    // 3. Execute Combat Math (Authoritative)
    let result = state.combat_engine.execute_action(&attacker, &mut defender, req.action_type);

    // 4. Trace & Response
    let response = CombatResponseV1 {
        success: true,
        damage_dealt: result.final_damage,
        enemy_alive: defender.is_alive(),
        player_team_state: vec![attacker],
        enemy_state: vec![defender],
        idempotency_key: req.idempotency_key,
    };

    (StatusCode::OK, Json(response))
}

pub async fn health_check_handler() -> impl IntoResponse {
    (StatusCode::OK, Json(serde_json::json!({
        "status": "ok",
        "service": "combat",
        "version": "1.0.0"
    })))
}


