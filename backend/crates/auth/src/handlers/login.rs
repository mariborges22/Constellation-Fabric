use axum::{extract::{Json, State}, http::StatusCode};
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn login(State(state): State<Arc<AppState>>, Json(payload): Json<LoginRequest>) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    let token = crate::security::TokenManager::generate_token(&payload.username, &state.jwt_keys);
    Ok((StatusCode::OK, Json(LoginResponse { token, expires_in: 3600, user_id: payload.username })))
}
