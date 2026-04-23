pub mod dynamo;
pub mod mock;

pub use dynamo::DynamoCombatRepository;
pub use mock::InMemoryCombatRepository;

use async_trait::async_trait;
use shared::CombatResult;
use uuid::Uuid;

// ============================================================================
// PORT: Contrato de persistência (Testável e Substituível)
// ============================================================================

#[async_trait]
pub trait CombatRepository: Send + Sync {
    /// Persiste o resultado de uma ação de combate na tabela combat_logs.
    async fn save_match_result(
        &self,
        match_id: Uuid,
        turn_id: u64,
        result: &CombatResult,
    ) -> Result<(), CombatPersistenceError>;

    /// Sincroniza o HP final do jogador de volta ao serviço player-state.
    async fn update_player_hp(
        &self,
        player_id: Uuid,
        remaining_hp: f32,
        match_id: Uuid,
    ) -> Result<(), CombatPersistenceError>;
}

// ============================================================================
// ERRORS
// ============================================================================

#[derive(Debug, thiserror::Error)]
pub enum CombatPersistenceError {
    #[error("DynamoDB error: {0}")]
    DynamoError(String),

    #[error("player-state sync error: {0}")]
    PlayerStateError(String),
}
