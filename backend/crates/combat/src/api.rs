use crate::Character;
use shared::ActionType;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CombatActionRequestV1 {
    pub idempotency_key: Uuid, pub player_id: Uuid, pub character_id: Uuid, pub target_id: Uuid, pub action_type: ActionType,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CombatResponseV1 {
    pub success: bool, pub damage_dealt: f32, pub enemy_alive: bool, pub player_team_state: Vec<Character>, pub enemy_state: Vec<Character>, pub idempotency_key: Uuid,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StartMatchRequestV1 {
    pub match_id: Uuid,
    pub attacker_id: Uuid,
    pub defender_id: Uuid,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct StartMatchResponseV1 {
    pub match_id: Uuid,
    pub status: String,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct SubmitTurnRequestV1 {
    pub match_id: Uuid,
    pub turn_id: u64,
    pub action: CombatActionRequestV1,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct MatchStateResponseV1 {
    pub match_id: Uuid,
    pub active: bool,
    pub last_turn_id: u64,
    pub attacker: Character,
    pub defender: Character,
    pub last_action: Option<CombatActionRequestV1>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EndMatchRequestV1 {
    pub match_id: Uuid,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct EndMatchResponseV1 {
    pub match_id: Uuid,
    pub status: String,
}

