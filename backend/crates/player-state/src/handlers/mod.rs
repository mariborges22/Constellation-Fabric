use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;

#[derive(Clone)]
pub struct ServiceState { pub service_name: String }

use crate::models::{SyncRequest, SyncResponse};

#[derive(Clone)]
pub struct ServiceState { pub service_name: String }

pub async fn sync_position(
    _state: State<Arc<ServiceState>>,
    Json(payload): Json<SyncRequest>
) -> (StatusCode, Json<SyncResponse>) {
    // In a real app, logic would go here to update the state and broadcast to other players
    (StatusCode::OK, Json(SyncResponse { 
        status: "synced".to_string(), 
        server_time: payload.timestamp + 10 // Dummy sync response
    }))
}

pub async fn get_state(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<SyncResponse>) {
    (StatusCode::OK, Json(SyncResponse { status: "ready".to_string(), server_time: 0 }))
}


