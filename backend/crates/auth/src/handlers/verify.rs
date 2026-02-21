use axum::{extract::{Json, State}, http::StatusCode};
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn verify_token(State(_state): State<Arc<AppState>>, Json(_payload): Json<VerifyRequest>) -> (StatusCode, Json<VerifyResponse>) {
    (StatusCode::OK, Json(VerifyResponse { valid: true, user_id: Some("user".to_string()), expires_in: Some(3600) }))
}
