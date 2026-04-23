use super::{CombatPersistenceError, CombatRepository};
use async_trait::async_trait;
use aws_sdk_dynamodb::{Client as DynamoClient, types::AttributeValue};
use chrono::Utc;
use shared::CombatResult;
use uuid::Uuid;
use tracing::{info, warn};

pub struct DynamoCombatRepository {
    client: DynamoClient,
    table_name: String,
    player_state_api: String,
}

impl DynamoCombatRepository {
    pub fn new(client: DynamoClient, table_name: String, player_state_api: String) -> Self {
        Self { client, table_name, player_state_api }
    }
}

#[async_trait]
impl CombatRepository for DynamoCombatRepository {
    async fn save_match_result(
        &self,
        match_id: Uuid,
        turn_id: u64,
        result: &CombatResult,
    ) -> Result<(), CombatPersistenceError> {
        let log_id = Uuid::new_v4();
        let timestamp = Utc::now().timestamp().to_string();
        let pk = format!("MATCH#{}", match_id);
        let sk = format!("TURN#{:010}", turn_id); // Zero-padded para ordenação lexicográfica

        info!(
            match_id = %match_id,
            turn_id = turn_id,
            damage = result.final_damage,
            is_critical = result.is_critical,
            "Persisting combat action"
        );

        self.client
            .put_item()
            .table_name(&self.table_name)
            .item("pk", AttributeValue::S(pk))
            .item("sk", AttributeValue::S(sk))
            .item("log_id", AttributeValue::S(log_id.to_string()))
            .item("actor_id", AttributeValue::S(result.action.actor_id.to_string()))
            .item("action_type", AttributeValue::S(format!("{:?}", result.action.action_type)))
            .item("final_damage", AttributeValue::N(result.final_damage.to_string()))
            .item("target_remaining_hp", AttributeValue::N(result.target_remaining_hp.to_string()))
            .item("reaction", AttributeValue::S(format!("{:?}", result.action.reaction)))
            .item("is_critical", AttributeValue::Bool(result.is_critical))
            .item("timestamp", AttributeValue::N(timestamp))
            // TTL de 30 dias para controlar custos de armazenamento
            .item("ttl", AttributeValue::N(
                (Utc::now().timestamp() + 60 * 60 * 24 * 30).to_string()
            ))
            .send()
            .await
            .map_err(|e| CombatPersistenceError::DynamoError(e.to_string()))?;

        Ok(())
    }

    async fn update_player_hp(
        &self,
        player_id: Uuid,
        remaining_hp: f32,
        match_id: Uuid,
    ) -> Result<(), CombatPersistenceError> {
        let health_as_int = remaining_hp.ceil() as i32;
        let url = format!(
            "{}/{}/state",
            self.player_state_api.trim_end_matches('/'),
            player_id
        );

        info!(
            player_id = %player_id,
            remaining_hp = remaining_hp,
            match_id = %match_id,
            "Syncing player HP back to player-state service"
        );

        let client = reqwest::Client::new();
        let res = client
            .put(&url)
            .json(&serde_json::json!({ "health": health_as_int }))
            .send()
            .await
            .map_err(|e| CombatPersistenceError::PlayerStateError(e.to_string()))?;

        if !res.status().is_success() {
            let status = res.status();
            warn!(
                player_id = %player_id,
                status = %status,
                "player-state service returned non-200 on HP sync"
            );
            return Err(CombatPersistenceError::PlayerStateError(
                format!("player-state returned HTTP {}", status)
            ));
        }

        Ok(())
    }
}
