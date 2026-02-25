use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;
use crate::{AppState, models::*};

pub async fn register(
    State(_state): State<Arc<AppState>>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    // Mock registration logic
    Ok((
        StatusCode::CREATED,
        Json(LoginResponse {
            token: "mock_register_token".to_string(),
            expires_in: 3600,
            user_id: payload.username,
        }),
    ))
}
