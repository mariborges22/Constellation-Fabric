use super::{CombatPersistenceError, CombatRepository};
use async_trait::async_trait;
use shared::CombatResult;
use std::sync::Mutex;
use uuid::Uuid;

pub struct InMemoryCombatRepository {
    pub saved_results: Mutex<Vec<(Uuid, u64, f32)>>,
    pub hp_updates: Mutex<Vec<(Uuid, f32)>>,
}

impl InMemoryCombatRepository {
    pub fn new() -> Self {
        Self {
            saved_results: Mutex::new(vec![]),
            hp_updates: Mutex::new(vec![]),
        }
    }
}

#[async_trait]
impl CombatRepository for InMemoryCombatRepository {
    async fn save_match_result(
        &self,
        match_id: Uuid,
        turn_id: u64,
        result: &CombatResult,
    ) -> Result<(), CombatPersistenceError> {
        self.saved_results.lock().unwrap()
            .push((match_id, turn_id, result.final_damage));
        Ok(())
    }

    async fn update_player_hp(
        &self,
        player_id: Uuid,
        remaining_hp: f32,
        _match_id: Uuid,
    ) -> Result<(), CombatPersistenceError> {
        self.hp_updates.lock().unwrap().push((player_id, remaining_hp));
        Ok(())
    }
}
