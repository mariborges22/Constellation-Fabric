use async_trait::async_trait;
use axum::{
    http::{StatusCode, HeaderMap},
    response::IntoResponse,
    routing::{get, post, put},
    Router,
};
use serde::{Deserialize, Serialize};
use aws_sdk_dynamodb::{Client as DynamoClient, types::AttributeValue};
use std::sync::Arc;
use uuid::Uuid;
use validator::Validate;

mod error;
pub use error::{PlayerStateError, PlayerStateResult};

// ============================================================================
// MODELS
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Player {
    pub id: Uuid,
    pub username: String,
    pub email: String,
    pub level: i32,
    pub experience: i32,
    pub health: i32,
    pub max_health: i32,
    pub region: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlayerStateResponse {
    pub id: Uuid,
    pub health: i32,
    pub level: i32,
    pub experience: i32,
}

#[derive(Debug, Serialize, Deserialize, Validate)]
pub struct CreatePlayerRequest {
    #[validate(length(min = 3, max = 50))]
    pub username: String,
    #[validate(email)]
    pub email: String,
}

#[derive(Debug, Serialize, Deserialize, Validate)]
pub struct UpdatePlayerStateRequest {
    #[validate(range(min = 0, max = 1000))]
    pub health: Option<i32>,
    #[validate(range(min = 0, max = 1000000))]
    pub experience: Option<i32>,
    #[validate(range(min = 1, max = 100))]
    pub level: Option<i32>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct InitPlayerRequest {
    pub initial_character: String,
    pub account_id: String,
}

// ============================================================================
// HEXAGONAL ARCHITECTURE: PORTS (TRAITS)
// ============================================================================

#[async_trait]
pub trait PlayerRepository: Send + Sync {
    async fn create_player(&self, req: CreatePlayerRequest) -> PlayerStateResult<Player>;
    async fn get_player(&self, player_id: Uuid) -> PlayerStateResult<Player>;
    async fn update_player_state(&self, player_id: Uuid, req: UpdatePlayerStateRequest) -> PlayerStateResult<PlayerStateResponse>;
    async fn initialize_team(&self, player_id: Uuid, req: InitPlayerRequest) -> PlayerStateResult<()>;
    async fn check_idempotency(&self, key: Uuid) -> PlayerStateResult<Option<(serde_json::Value, i16)>>;
    async fn save_idempotency(&self, key: Uuid, response: &serde_json::Value, status: u16) -> PlayerStateResult<()>;
}

// ============================================================================
// HEXAGONAL ARCHITECTURE: ADAPTERS (DYNAMODB)
// ============================================================================

pub struct DynamoPlayerRepository {
    client: DynamoClient,
    table_name: String,
}

impl DynamoPlayerRepository {
    pub fn new(client: DynamoClient, table_name: String) -> Self {
        Self { client, table_name }
    }
}

#[async_trait]
impl PlayerRepository for DynamoPlayerRepository {
    async fn create_player(&self, req: CreatePlayerRequest) -> PlayerStateResult<Player> {
        let id = Uuid::new_v4();
        let player = Player {
            id,
            username: req.username.clone(),
            email: req.email.clone(),
            level: 1,
            experience: 0,
            health: 100,
            max_health: 100,
            region: "us-east-1".to_string(), // Default
        };

        let item: std::collections::HashMap<String, AttributeValue> = serde_dynamo::to_item(&player)
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        let mut request = self.client.put_item()
            .table_name(&self.table_name)
            .item("pk", AttributeValue::S(format!("PLAYER#{}", id)))
            .item("sk", AttributeValue::S("METADATA".to_string()))
            .item("username_index", AttributeValue::S(format!("USERNAME#{}", req.username)))
            .item("email_index", AttributeValue::S(format!("EMAIL#{}", req.email)));

        for (k, v) in item {
            request = request.item(k, v);
        }

        request.send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        Ok(player)
    }

    async fn get_player(&self, player_id: Uuid) -> PlayerStateResult<Player> {
        let res = self.client.get_item()
            .table_name(&self.table_name)
            .key("pk", AttributeValue::S(format!("PLAYER#{}", player_id)))
            .key("sk", AttributeValue::S("METADATA".to_string()))
            .send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        if let Some(item) = res.item {
            let player: Player = serde_dynamo::from_item(item)
                .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;
            Ok(player)
        } else {
            Err(PlayerStateError::NotFound(player_id.to_string()))
        }
    }

    async fn update_player_state(&self, player_id: Uuid, req: UpdatePlayerStateRequest) -> PlayerStateResult<PlayerStateResponse> {
        // Implementação simplificada de update no Dynamo
        // Nota: Em produção, usaríamos UpdateItem com expressões de atualização
        let mut player = self.get_player(player_id).await?;
        
        if let Some(h) = req.health { player.health = h; }
        if let Some(e) = req.experience { player.experience += e; }
        if let Some(l) = req.level { player.level = l; }

        let item: std::collections::HashMap<String, AttributeValue> = serde_dynamo::to_item(&player)
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        let mut request = self.client.put_item()
            .table_name(&self.table_name)
            .item("pk", AttributeValue::S(format!("PLAYER#{}", player_id)))
            .item("sk", AttributeValue::S("METADATA".to_string()));

        for (k, v) in item {
            request = request.item(k, v);
        }

        request.send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        Ok(PlayerStateResponse {
            id: player.id,
            health: player.health,
            level: player.level,
            experience: player.experience,
        })
    }

    async fn initialize_team(&self, player_id: Uuid, req: InitPlayerRequest) -> PlayerStateResult<()> {
        // Criamos o registro da equipe no DynamoDB (Single Table Design)
        // PK: PLAYER#id, SK: TEAM#ACTIVE
        
        self.client.put_item()
            .table_name(&self.table_name)
            .item("pk", AttributeValue::S(format!("PLAYER#{}", player_id)))
            .item("sk", AttributeValue::S("TEAM#ACTIVE".to_string()))
            .item("active_leader", AttributeValue::S(req.initial_character.clone()))
            .item("unlocked_siblings", AttributeValue::Ss(vec![
                "Kaelen".to_string(), "Elora".to_string(), "Rion".to_string()
            ]))
            .item("created_at", AttributeValue::N(chrono::Utc::now().timestamp().to_string()))
            .send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;
            
        // Log de telemetria
        tracing::info!(player_id = %player_id, sibling = %req.initial_character, "Equipe inicializada com sucesso");
        
        Ok(())
    }

    async fn check_idempotency(&self, key: Uuid) -> PlayerStateResult<Option<(serde_json::Value, i16)>> {
        let res = self.client.get_item()
            .table_name(&self.table_name)
            .key("pk", AttributeValue::S(format!("IDEM#{}", key)))
            .key("sk", AttributeValue::S("STATE".to_string()))
            .send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;

        if let Some(item) = res.item {
            let body: String = item.get("response_body").and_then(|v| v.as_s().ok()).cloned().unwrap_or_default();
            let status: i16 = item.get("status_code").and_then(|v| v.as_n().ok()).and_then(|n| n.parse::<i16>().ok()).unwrap_or(200);
            let val = serde_json::from_str(&body).unwrap_or_default();
            Ok(Some((val, status)))
        } else {
            Ok(None)
        }
    }

    async fn save_idempotency(&self, key: Uuid, response: &serde_json::Value, status: u16) -> PlayerStateResult<()> {
        let body = response.to_string();
        self.client.put_item()
            .table_name(&self.table_name)
            .item("pk", AttributeValue::S(format!("IDEM#{}", key)))
            .item("sk", AttributeValue::S("STATE".to_string()))
            .item("response_body", AttributeValue::S(body))
            .item("status_code", AttributeValue::N(status.to_string()))
            .item("ttl", AttributeValue::N((chrono::Utc::now().timestamp() + 86400).to_string())) // 24h TTL
            .send().await
            .map_err(|e| PlayerStateError::DatabaseError(e.to_string()))?;
        Ok(())
    }
}

// ============================================================================
// HEXAGONAL ARCHITECTURE: ADAPTERS (IN-MEMORY MOCK)
// ============================================================================

use std::collections::HashMap;
use tokio::sync::Mutex;

pub struct InMemoryPlayerRepository {
    players: Mutex<HashMap<Uuid, Player>>,
    idempotency: Mutex<HashMap<Uuid, (serde_json::Value, i16)>>,
}

impl InMemoryPlayerRepository {
    pub fn new() -> Self {
        Self {
            players: Mutex::new(HashMap::new()),
            idempotency: Mutex::new(HashMap::new()),
        }
    }
}

#[async_trait]
impl PlayerRepository for InMemoryPlayerRepository {
    async fn create_player(&self, req: CreatePlayerRequest) -> PlayerStateResult<Player> {
        let id = Uuid::new_v4();
        let player = Player {
            id,
            username: req.username,
            email: req.email,
            level: 1,
            experience: 0,
            health: 100,
            max_health: 100,
            region: "local".to_string(),
        };
        self.players.lock().await.insert(id, player.clone());
        Ok(player)
    }

    async fn get_player(&self, player_id: Uuid) -> PlayerStateResult<Player> {
        self.players.lock().await.get(&player_id).cloned()
            .ok_or_else(|| PlayerStateError::NotFound(player_id.to_string()))
    }

    async fn update_player_state(&self, player_id: Uuid, req: UpdatePlayerStateRequest) -> PlayerStateResult<PlayerStateResponse> {
        let mut players = self.players.lock().await;
        let player = players.get_mut(&player_id)
            .ok_or_else(|| PlayerStateError::NotFound(player_id.to_string()))?;

        if let Some(h) = req.health { player.health = h; }
        if let Some(e) = req.experience { player.experience += e; }
        if let Some(l) = req.level { player.level = l; }

        Ok(PlayerStateResponse {
            id: player.id,
            health: player.health,
            level: player.level,
            experience: player.experience,
        })
    }

    async fn initialize_team(&self, _player_id: Uuid, _req: InitPlayerRequest) -> PlayerStateResult<()> {
        // En um mock simples, apenas retornamos OK
        Ok(())
    }

    async fn check_idempotency(&self, key: Uuid) -> PlayerStateResult<Option<(serde_json::Value, i16)>> {
        Ok(self.idempotency.lock().await.get(&key).cloned())
    }

    async fn save_idempotency(&self, key: Uuid, response: &serde_json::Value, status: u16) -> PlayerStateResult<()> {
        self.idempotency.lock().await.insert(key, (response.clone(), status as i16));
        Ok(())
    }
}


// ============================================================================
// ROUTER & HANDLERS
// ============================================================================

pub type SharedRepo = Arc<dyn PlayerRepository>;

pub fn build_router(repo: SharedRepo) -> Router {
    Router::new()
        .route("/api/v1/players/health", get(handlers::health_check_handler))
        .route("/api/v1/players", post(handlers::create_player_handler))
        .route("/api/v1/players/:id", get(handlers::get_player_handler))
        .route("/api/v1/players/:id/init", post(handlers::init_player_handler))
        .route("/api/v1/players/:id/state", put(handlers::update_player_state_handler))
        .route("/metrics", get(telemetry::handlers::metrics_handler))
        .with_state(repo)
}

pub mod handlers {
    use super::*;
    use axum::{extract::{State, Path}, Json};

    pub async fn health_check_handler() -> impl IntoResponse {
        (StatusCode::OK, Json(serde_json::json!({"status": "ok"})))
    }

    pub async fn create_player_handler(
        State(repo): State<SharedRepo>,
        Json(req): Json<CreatePlayerRequest>,
    ) -> PlayerStateResult<impl IntoResponse> {
        req.validate().map_err(|e| PlayerStateError::ValidationError(e.to_string()))?;

        let player = repo.create_player(req).await?;
        Ok((StatusCode::CREATED, Json(player)))
    }

    pub async fn get_player_handler(
        State(repo): State<SharedRepo>,
        Path(player_id): Path<Uuid>,
    ) -> PlayerStateResult<impl IntoResponse> {
        let player = repo.get_player(player_id).await?;
        Ok((StatusCode::OK, Json(player)))
    }

    pub async fn update_player_state_handler(
        State(repo): State<SharedRepo>,
        headers: HeaderMap,
        Path(player_id): Path<Uuid>,
        Json(req): Json<UpdatePlayerStateRequest>,
    ) -> PlayerStateResult<impl IntoResponse> {
        req.validate().map_err(|e| PlayerStateError::ValidationError(e.to_string()))?;

        let idempotency_key = headers.get("X-Idempotency-Key")
            .and_then(|h| h.to_str().ok())
            .and_then(|s: &str| Uuid::parse_str(s).ok());

        if let Some(key) = idempotency_key {
            if let Ok(Some((body, status))) = repo.check_idempotency(key).await {
                let status = StatusCode::from_u16(status as u16).unwrap_or(StatusCode::OK);
                return Ok((status, Json(body)).into_response());
            }
        }

        let state = repo.update_player_state(player_id, req).await?;
        let res_body = serde_json::to_value(&state).unwrap_or_default();
        if let Some(key) = idempotency_key {
            let _ = repo.save_idempotency(key, &res_body, StatusCode::OK.as_u16()).await;
        }
        Ok((StatusCode::OK, Json(state)).into_response())
    }

    pub async fn init_player_handler(
        State(repo): State<SharedRepo>,
        Path(player_id): Path<Uuid>,
        Json(req): Json<InitPlayerRequest>,
    ) -> PlayerStateResult<impl IntoResponse> {
        repo.initialize_team(player_id, req).await?;
        Ok((StatusCode::OK, Json(serde_json::json!({"status": "initialized"}))))
    }
}
