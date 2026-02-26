use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

pub fn init_tracing() {
    let format = tracing_subscriber::fmt::layer().json().with_writer(std::io::stdout);
    tracing_subscriber::registry().with(tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| "constellation=info".into())).with(format).init();
    tracing::info!("AWS CloudWatch Logging Initialized");
}

