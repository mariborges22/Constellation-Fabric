use axum::{routing::get, Json, Router};
use chrono::Utc;
use serde_json::{json, Value};
use std::net::SocketAddr;
use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).init();
    info!("🎮 Constellation Fabric - Player State Service v0.1.0");

    let app = Router::new().route("/health", get(health));

    let addr = SocketAddr::from(([0, 0, 0, 0], 8081));
    info!("Listening on http://{}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn health() -> Json<Value> {
    Json(json!({
        "status": "ok",
        "service": "player-state",
        "version": "0.1.0",
        "timestamp": Utc::now().to_rfc3339()
    }))
}
