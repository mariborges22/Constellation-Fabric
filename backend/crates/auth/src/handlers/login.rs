use axum::{extract::{ConnectInfo, Json, State}, http::StatusCode};
use std::net::SocketAddr;
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn login(ConnectInfo(_addr): ConnectInfo<SocketAddr>, State(_state): State<Arc<AppState>>, Json(payload): Json<LoginRequest>) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    Ok((StatusCode::OK, Json(LoginResponse { token: "token".to_string(), expires_in: 3600, user_id: payload.username })))
}
