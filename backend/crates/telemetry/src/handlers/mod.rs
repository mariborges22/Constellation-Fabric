use axum::{extract::State, http::StatusCode, Json, response::IntoResponse};
use std::sync::Arc;
use crate::metrics::Metrics;

pub async fn metrics_handler() -> impl IntoResponse {
    Metrics::gather_metrics()
}

#[derive(Clone)]
pub struct ServiceState { pub service_name: String }

pub async fn record_metric(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("record_metric".to_string()) }))
}

pub async fn create_span(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("create_span".to_string()) }))
}

pub async fn export(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("export".to_string()) }))
}


