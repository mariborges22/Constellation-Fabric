use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;

#[derive(Clone)]
pub struct ServiceState { pub service_name: String }

pub async fn attack(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("attack".to_string()) }))
}

pub async fn defense(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("defense".to_string()) }))
}

pub async fn special_ability(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {
    (StatusCode::OK, Json(super::models::Response { status: "ok".to_string(), data: Some("special_ability".to_string()) }))
}


