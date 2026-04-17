use auth::{config, state, AppState};
use std::sync::Arc;
use tracing::info;
use aws_config::BehaviorVersion;
use aws_sdk_dynamodb::Client as DynamoClient;

#[tokio::main]
async fn main() {
    telemetry::init_tracing();

    info!("🎮 Constellation Fabric - Equestria Odyssey - Auth Service");

    let config = config::Config::from_env();
    info!("Config loaded - Port: {}", config.port);

    // Inicializar AWS DynamoDB
    let aws_config = aws_config::load_defaults(BehaviorVersion::latest()).await;
    let dynamo_client = DynamoClient::new(&aws_config);
    let table_name = std::env::var("DYNAMO_TABLE_NAME")
        .unwrap_or_else(|_| "constellation-staging-player-state".to_string());

    // Carregar chaves JWT do Secrets Manager de forma assíncrona
    let jwt_keys = auth::security::SecretLoader::load_jwt_keys(&config.jwt_secret_arn).await;

    let app_state = AppState::new(
        &config.version,
        config.rate_limit_requests,
        jwt_keys,
        dynamo_client,
        table_name,
    );

    state::start_server(Arc::new(app_state), &config).await;
}
