use axum::extract::State;
use std::sync::Arc;
use crate::AppState;
pub async fn root(State(state): State<Arc<AppState>>) -> String {
    format!("Constellation Fabric - Auth Service v{}", state.version)
}
