use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;
use crate::{AppState, models::HealthResponse};
pub async fn health_check(State(state): State<Arc<AppState>>) -> (StatusCode, Json<HealthResponse>) {
    let res = HealthResponse { status: "ok".to_string(), version: state.version.clone(), timestamp: "now".to_string() };
    (StatusCode::OK, Json(res))
}
