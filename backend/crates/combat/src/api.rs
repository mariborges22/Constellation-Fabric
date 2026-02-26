use crate::{Character, ActionType, CombatEngine};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct CombatActionRequestV1 {
    pub idempotency_key: Uuid, pub player_id: Uuid, pub character_id: Uuid, pub target_id: Uuid, pub action_type: ActionType,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CombatResponseV1 {
    pub success: bool, pub damage_dealt: f32, pub enemy_alive: bool, pub player_team_state: Vec<Character>, pub enemy_state: Vec<Character>, pub idempotency_key: Uuid,
}

