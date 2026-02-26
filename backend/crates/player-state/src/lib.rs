use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
    routing::{get, post, put},
    Json, Router,
};
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
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
// DATABASE INTERACTIONS (PREPARED STATEMENTS)
// ============================================================================

pub async fn create_player(
    pool: &PgPool,
    req: CreatePlayerRequest,
) -> Result<Player, StatusCode> {
    // SQLx uses prepared statements by default with the bind() method
    let player = sqlx::query_as::<_, Player>(
        "INSERT INTO players (username, email) VALUES ($1, $2) 
         RETURNING id, username, email, level, experience, health, max_health, region"
    )
    .bind(&req.username)
    .bind(&req.email)
    .fetch_one(pool)
    .await
    .map_err(|e| {
        tracing::error!("Database error creating player: {}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })?;

    Ok(player)
}

pub async fn get_player(
    pool: &PgPool,
    player_id: Uuid,
) -> Result<Player, StatusCode> {
    sqlx::query_as::<_, Player>(
        "SELECT id, username, email, level, experience, health, max_health, region 
         FROM players WHERE id = $1"
    )
    .bind(player_id)
    .fetch_one(pool)
    .await
    .map_err(|e| {
        tracing::error!("Database error getting player: {}", e);
        StatusCode::NOT_FOUND
    })
}

pub async fn update_player_state(
    pool: &PgPool,
    player_id: Uuid,
    req: UpdatePlayerStateRequest,
) -> Result<PlayerStateResponse, StatusCode> {
    // Secure query with COALESCE to handle partial updates without string interpolation
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
    .fetch_one(pool)
    .await
    .map_err(|e| {
        tracing::error!("Database error updating player state: {}", e);
        StatusCode::INTERNAL_SERVER_ERROR
    })
}

// ============================================================================
// ROUTER & HANDLERS
// ============================================================================

pub fn build_router(pool: PgPool) -> Router {
    Router::new()
        .route("/api/players", post(handlers::create_player_handler))
        .route("/api/players/:id", get(handlers::get_player_handler))
        .route("/api/players/:id/state", put(handlers::update_player_state_handler))
        .with_state(pool)
}

pub mod handlers {
    use super::*;
    use axum::{extract::{State, Path}, Json};

    pub async fn create_player_handler(
        State(pool): State<PgPool>,
        Json(req): Json<CreatePlayerRequest>,
    ) -> impl IntoResponse {
        if let Err(e) = req.validate() {
            return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": e.to_string()}))).into_response();
        }

        match create_player(&pool, req).await {
            Ok(player) => (StatusCode::CREATED, Json(player)).into_response(),
            Err(err) => (err, Json(serde_json::json!({"error": "Failed to create player"}))).into_response(),
        }
    }

    pub async fn get_player_handler(
        State(pool): State<PgPool>,
        Path(player_id): Path<Uuid>,
    ) -> impl IntoResponse {
        match get_player(&pool, player_id).await {
            Ok(player) => (StatusCode::OK, Json(player)).into_response(),
            Err(err) => (err, Json(serde_json::json!({"error": "Player not found"}))).into_response(),
        }
    }

    pub async fn update_player_state_handler(
        State(pool): State<PgPool>,
        Path(player_id): Path<Uuid>,
        Json(req): Json<UpdatePlayerStateRequest>,
    ) -> impl IntoResponse {
        if let Err(e) = req.validate() {
            return (StatusCode::BAD_REQUEST, Json(serde_json::json!({"error": e.to_string()}))).into_response();
        }

        match update_player_state(&pool, player_id, req).await {
            Ok(state) => (StatusCode::OK, Json(state)).into_response(),
            Err(err) => (err, Json(serde_json::json!({"error": "Failed to update state"}))).into_response(),
        }
    }
}
