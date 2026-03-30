use axum::{routing::{get, post}, Router};
use std::net::SocketAddr;
use std::sync::Arc;
use tracing::{info, Level};
use combat::handlers::{combat_handler, health_check_handler, AppState};
use combat::CombatEngine;
use combat::config::Config;
use event_publisher::publisher::KinesisPublisher;

#[tokio::main]
async fn main() {
    let config = Config::from_env();
    
    let log_level = match config.log_level.to_lowercase().as_str() {
        "debug" => Level::DEBUG,
        "warn" => Level::WARN,
        "error" => Level::ERROR,
        _ => Level::INFO,
    };

    tracing_subscriber::fmt().with_max_level(log_level).init();
    info!("⚔️  Constellation Fabric - Authoritative Combat Engine v1.0.0");

    let publisher = if let Some(name) = &config.kinesis_stream_name {
        info!("Kinesis integration enabled for stream: {}", name);
        Some(KinesisPublisher::new(name.clone()).await)
    } else {
        info!("Kinesis integration disabled (KINESIS_STREAM_NAME not set)");
        None
    };

    let state = Arc::new(AppState {
        combat_engine: Arc::new(CombatEngine::new(publisher)),
    });

    let app = Router::new()
        .route("/api/v1/combat/health", get(health_check_handler))
        .route("/api/v1/combat/attack", post(combat_handler))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    
    info!("Service listening on http://{}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
