use player_state::{build_router, DynamoPlayerRepository};
use std::net::SocketAddr;
use tracing::info;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoClient;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    telemetry::init_tracing();

    info!("Constellation Fabric - Equestria Odyssey - Player State Service");

    let config = aws_config::load_defaults(BehaviorVersion::latest()).await;
    let client = DynamoClient::new(&config);
    
    let table_name = std::env::var("DYNAMO_TABLE_NAME")
        .unwrap_or_else(|_| "constellation-staging-player-state".to_string());

    let use_in_memory = std::env::var("USE_IN_MEMORY_REPO")
        .map(|v| v.to_lowercase() == "true")
        .unwrap_or(false);

    let repo: player_state::SharedRepo = if use_in_memory {
        info!("🚀 Using InMemory Repository (DANGER: NO PERSISTENCE)");
        std::sync::Arc::new(player_state::InMemoryPlayerRepository::new())
    } else {
        info!("Using DynamoDB table: {}", table_name);
        std::sync::Arc::new(DynamoPlayerRepository::new(client, table_name))
    };

    let app = build_router(repo);

    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "8081".to_string())
        .parse::<u16>()?;

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("Server listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
