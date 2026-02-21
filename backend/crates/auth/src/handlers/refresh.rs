use axum::{extract::{Json, State}, http::StatusCode};
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn refresh_token(State(_state): State<Arc<AppState>>, Json(payload): Json<RefreshRequest>) -> Result<(StatusCode, Json<RefreshResponse>), StatusCode> {
    Ok((StatusCode::OK, Json(RefreshResponse { token: format!("{}_new", payload.token), expires_in: 3600 })))
}
