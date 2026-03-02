use axum::{routing::{get, post}, Router};
use std::net::SocketAddr;
use std::sync::Arc;
use tracing::info;
use combat::handlers::{combat_handler, health_check_handler, AppState};
use combat::CombatEngine;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).init();
    info!("⚔️  Constellation Fabric - Authoritative Combat Engine v1.0.0");

    let state = Arc::new(AppState {
        combat_engine: Arc::new(CombatEngine::new()),
    });

    let app = Router::new()
        .route("/api/v1/combat/health", get(health_check_handler))
        .route("/api/v1/combat/attack", post(combat_handler))
        .with_state(state);

    let port = std::env::var("PORT").unwrap_or_else(|_| "8082".to_string()).parse::<u16>().unwrap();
    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    
    info!("Service listening on http://{}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
