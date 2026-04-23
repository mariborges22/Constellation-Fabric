use axum::{routing::{get, post}, Router};
use std::net::SocketAddr;
use std::sync::Arc;
use std::collections::HashMap;
use tokio::sync::Mutex;
use tracing::{info, Level};
use combat::handlers::{
    combat_handler, end_match_handler, get_match_state_handler, health_check_handler, start_match_handler,
    submit_turn_handler, AppState,
};
use combat::persistence::DynamoCombatRepository;
use combat::CombatEngine;
use combat::config::Config;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoClient;

#[tokio::main]
async fn main() {
    telemetry::tracing::init_tracing();
    
    info!("⚔️  Constellation Fabric - Equestria Odyssey - Combat Engine v1.1.0");

    let config = Config::from_env();
    info!("Config loaded - Port: {}", config.port);

    let aws_config = aws_config::load_defaults(BehaviorVersion::latest()).await;
    let dynamo_client = DynamoClient::new(&aws_config);
    let table_name = std::env::var("COMBAT_LOGS_TABLE")
        .unwrap_or_else(|_| "constellation-fabric-staging-combat-logs".to_string());
    
    let player_state_api = std::env::var("PLAYER_STATE_API")
        .unwrap_or_else(|_| "http://localhost:8081/api/v1/players".to_string());

    let combat_repo = Arc::new(DynamoCombatRepository::new(
        dynamo_client,
        table_name,
        player_state_api.clone(),
    ));

    let state = Arc::new(AppState {
        combat_engine: Arc::new(CombatEngine::new()),
        player_state_api,
        matches: Arc::new(Mutex::new(HashMap::new())),
        idempotency_cache: Arc::new(Mutex::new(HashMap::new())),
        combat_repo,
    });

    let app = Router::new()
        .route("/api/v1/combat/health", get(health_check_handler))
        .route("/api/v1/combat/attack", post(combat_handler))
        .route("/api/v1/combat/matches", post(start_match_handler))
        .route("/api/v1/combat/matches/:match_id", get(get_match_state_handler))
        .route("/api/v1/combat/matches/turns", post(submit_turn_handler))
        .route("/api/v1/combat/matches/end", post(end_match_handler))
        .route("/metrics", get(telemetry::handlers::metrics_handler))
        .with_state(state);

    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    
    info!("Service listening on http://{}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}
