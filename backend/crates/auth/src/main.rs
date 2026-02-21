use auth::{config, state, AppState};
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    info!("ðŸŽ® Constellation Fabric - Auth Service");

    let config = config::Config::from_env();
    info!("Config loaded - Port: {}", config.port);

    let app_state = AppState::new(
        &config.version,
        config.rate_limit_requests,
    );

    state::start_server(Arc::new(app_state), &config).await;
}
