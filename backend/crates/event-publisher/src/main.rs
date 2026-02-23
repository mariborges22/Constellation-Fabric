use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).init();
    info!("Service: Event Publishing System v0.1.0");
    info!("Status: Ready");
}
