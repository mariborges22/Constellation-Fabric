use async_trait::async_trait;
use axum::{
    http::{StatusCode, HeaderMap},
    response::IntoResponse,
    routing::{get, post, put},
    Router,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::sync::Arc;
use uuid::Uuid;
use validator::Validate;

// ============================================================================
// MODELS
// ============================================================================

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
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

#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
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

// ============================================================================
// HEXAGONAL ARCHITECTURE: PORTS (TRAITS)
// ============================================================================

#[async_trait]
pub trait PlayerRepository: Send + Sync {
    async fn create_player(&self, req: CreatePlayerRequest) -> Result<Player, StatusCode>;
    async fn get_player(&self, player_id: Uuid) -> Result<Player, StatusCode>;
    async fn update_player_state(&self, player_id: Uuid, req: UpdatePlayerStateRequest) -> Result<PlayerStateResponse, StatusCode>;
    async fn check_idempotency(&self, key: Uuid) -> Result<Option<(serde_json::Value, i16)>, StatusCode>;
    async fn save_idempotency(&self, key: Uuid, response: &serde_json::Value, status: u16) -> Result<(), StatusCode>;
}

// ============================================================================
// HEXAGONAL ARCHITECTURE: ADAPTERS (POSTGRES)
// ============================================================================

pub struct PostgresPlayerRepository {
    pool: PgPool,
}

impl PostgresPlayerRepository {
    pub fn new(pool: PgPool) -> Self {
        Self { pool }
    }
}

#[async_trait]
impl PlayerRepository for PostgresPlayerRepository {
    async fn create_player(&self, req: CreatePlayerRequest) -> Result<Player, StatusCode> {
        sqlx::query_as::<_, Player>(
            "INSERT INTO players (username, email) VALUES ($1, $2) 
             RETURNING id, username, email, level, experience, health, max_health, region"
        )
        .bind(&req.username)
        .bind(&req.email)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| {
            if let Some(db_err) = e.as_database_error() {
                if db_err.is_unique_violation() {
                    return StatusCode::CONFLICT;
                }
            }
            tracing::error!("Database error creating player: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
    }

    async fn get_player(&self, player_id: Uuid) -> Result<Player, StatusCode> {
        sqlx::query_as::<_, Player>(
            "SELECT id, username, email, level, experience, health, max_health, region 
             FROM players WHERE id = $1"
        )
        .bind(player_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| {
            tracing::error!("Database error getting player: {}", e);
            StatusCode::NOT_FOUND
        })
    }

    async fn update_player_state(&self, player_id: Uuid, req: UpdatePlayerStateRequest) -> Result<PlayerStateResponse, StatusCode> {
        sqlx::query_as::<_, PlayerStateResponse>(
            "UPDATE players 
             SET health = COALESCE($1, health),
                 experience = experience + COALESCE($2, 0),
                 level = COALESCE($3, level),
                 updated_at = CURRENT_TIMESTAMP
             WHERE id = $4
             RETURNING id, health, level, experience"
        )
        .bind(req.health)
        .bind(req.experience)
        .bind(req.level)
        .bind(player_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| {
            tracing::error!("Database error updating player state: {}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })
    }

    async fn check_idempotency(&self, key: Uuid) -> Result<Option<(serde_json::Value, i16)>, StatusCode> {
        sqlx::query_as(
            "SELECT response_body, status_code FROM idempotency_keys WHERE key = $1"
        )
        .bind(key)
        .fetch_optional(&self.pool)
        .await
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
    }

    async fn save_idempotency(&self, key: Uuid, response: &serde_json::Value, status: u16) -> Result<(), StatusCode> {
        sqlx::query(
            "INSERT INTO idempotency_keys (key, response_body, status_code) VALUES ($1, $2, $3)"
        )
        .bind(key)
        .bind(response)
        .bind(status as i16)
        .execute(&self.pool)
        .await
        .map(|_| ())
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)
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
        .route("/api/v1/players/:id/state", put(handlers::update_player_state_handler))
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
    ) -> impl IntoResponse {
        if let Err(e) = req.validate() {
            return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": e.to_string()}))).into_response();
        }

        match repo.create_player(req).await {
            Ok(player) => (StatusCode::CREATED, Json(player)).into_response(),
            Err(err) => (err, Json(serde_json::json!({"error": "Failed to create player"}))).into_response(),
        }
    }

    pub async fn get_player_handler(
        State(repo): State<SharedRepo>,
        Path(player_id): Path<Uuid>,
    ) -> impl IntoResponse {
        match repo.get_player(player_id).await {
            Ok(player) => (StatusCode::OK, Json(player)).into_response(),
            Err(err) => (err, Json(serde_json::json!({"error": "Player not found"}))).into_response(),
        }
    }

    pub async fn update_player_state_handler(
        State(repo): State<SharedRepo>,
        headers: HeaderMap,
        Path(player_id): Path<Uuid>,
        Json(req): Json<UpdatePlayerStateRequest>,
    ) -> impl IntoResponse {
        if let Err(e) = req.validate() {
            return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": e.to_string()}))).into_response();
        }

        let idempotency_key = headers.get("X-Idempotency-Key")
            .and_then(|h| h.to_str().ok())
            .and_then(|s: &str| Uuid::parse_str(s).ok());

        if let Some(key) = idempotency_key {
            if let Ok(Some((body, status))) = repo.check_idempotency(key).await {
                let status = StatusCode::from_u16(status as u16).unwrap_or(StatusCode::OK);
                return (status, Json(body)).into_response();
            }
        }

        match repo.update_player_state(player_id, req).await {
            Ok(state) => {
                let res_body = serde_json::to_value(&state).unwrap_or_default();
                if let Some(key) = idempotency_key {
                    let _ = repo.save_idempotency(key, &res_body, StatusCode::OK.as_u16()).await;
                }
                (StatusCode::OK, Json(state)).into_response()
            },
            Err(err) => (err, Json(serde_json::json!({"error": "Failed to update state"}))).into_response(),
        }
    }
}
