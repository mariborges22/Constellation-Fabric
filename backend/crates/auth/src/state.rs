use crate::{AppState, config};
use axum::{Router, routing::{get, post}};
use std::sync::Arc;
use tracing::info;
use std::net::SocketAddr;

// AppState implementation is in lib.rs

pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(crate::handlers::health_check))
        .route("/", get(crate::handlers::root))
        .route("/api/v1/auth/login", post(crate::handlers::login))
        .route("/api/v1/auth/register", post(crate::handlers::register))
        .route("/api/v1/auth/verify", post(crate::handlers::verify_token))
        .route("/api/v1/auth/refresh", post(crate::handlers::refresh_token))
        .route("/metrics", get(telemetry::handlers::metrics_handler))
        .with_state(state)
}

pub async fn start_server(state: Arc<AppState>, config: &config::Config) {
    let app = build_router(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    let listener = tokio::net::TcpListener::bind(&addr).await.expect("Failed to bind");

    info!("Server listening on http://{}", addr);
    axum::serve(listener, app).await.expect("Server error");
}
