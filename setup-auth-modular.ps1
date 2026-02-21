param(
    [string]$AuthCratePath = "backend/crates/auth"
)

# Configurar encoding para evitar caracteres estranhos
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SETUP: Estrutura Modular - Auth Crate" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

if (-not (Test-Path $AuthCratePath)) {
    Write-Host "[!] Caminho nao encontrado: $AuthCratePath" -ForegroundColor Red
    exit 1
}

Write-Host "[+] Caminho: $AuthCratePath" -ForegroundColor Green
Write-Host ""

Write-Host "[PASSO 1] Criando estrutura de pastas..." -ForegroundColor Yellow
$folders = @(
    "src/models",
    "src/security",
    "src/rate_limit",
    "src/bot_detection",
    "src/handlers",
    "src/middleware",
    "tests"
)

foreach ($folder in $folders) {
    $fullPath = Join-Path $AuthCratePath $folder
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host "  OK -> $folder" -ForegroundColor Green
    }
}

# Helper function para escrever arquivos sem erros de encoding ou parse
function Create-File {
    param($RelativePath, $Content)
    $Target = Join-Path $AuthCratePath $RelativePath
    Set-Content -Path $Target -Value $Content -Encoding UTF8 -Force
}

Write-Host "[PASSO 2-11] Gerando arquivos Rust..." -ForegroundColor Yellow

Create-File "src/lib.rs" @'
// Modulos
pub mod config;
pub mod models;
pub mod security;
pub mod rate_limit;
pub mod bot_detection;
pub mod handlers;
pub mod middleware;
pub mod state;

// Re-exportar tipos principais
pub use state::AppState;
pub use models::{LoginRequest, LoginResponse, ErrorResponse};
pub use security::sanitizer::sanitize_input;
pub use security::validator::validate_token_format;
pub use rate_limit::RateLimiter;
pub use bot_detection::BotDetector;

#[cfg(test)]
mod tests {
    #[test]
    fn test_lib_loads() {
        assert_eq!(2 + 2, 4);
    }
}
'@

Create-File "src/main.rs" @'
use auth::{config, state, AppState};
use std::sync::Arc;
use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    info!("🎮 Constellation Fabric - Auth Service");

    let config = config::Config::from_env();
    info!("Config loaded - Port: {}", config.port);

    let app_state = AppState::new(
        &config.version,
        config.rate_limit_requests,
    );

    state::start_server(Arc::new(app_state), &config).await;
}
'@

Create-File "src/config.rs" @'
#[derive(Clone, Debug)]
pub struct Config {
    pub version: String,
    pub port: u16,
    pub rate_limit_requests: usize,
    pub log_level: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            version: "0.1.0".to_string(),
            port: std::env::var("PORT")
                .unwrap_or("3000".to_string())
                .parse()
                .unwrap_or(3000),
            rate_limit_requests: std::env::var("RATE_LIMIT")
                .unwrap_or("100".to_string())
                .parse()
                .unwrap_or(100),
            log_level: std::env::var("LOG_LEVEL")
                .unwrap_or("info".to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_config_defaults() {
        let config = Config::from_env();
        assert_eq!(config.port, 3000);
    }
}
'@

Create-File "src/state.rs" @'
use crate::{AppState, config};
use axum::{Router, routing::{get, post}};
use std::sync::Arc;
use tracing::info;
use std::net::SocketAddr;

impl AppState {
    pub fn new(version: &str, rate_limit_requests: usize) -> Self {
        Self {
            version: version.to_string(),
            rate_limiter: crate::rate_limit::RateLimiter::new(rate_limit_requests),
            bot_detector: crate::bot_detection::BotDetector::new(),
        }
    }
}

pub fn build_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/health", get(crate::handlers::health_check))
        .route("/", get(crate::handlers::root))
        .route("/api/auth/login", post(crate::handlers::login))
        .route("/api/auth/verify", post(crate::handlers::verify_token))
        .route("/api/auth/refresh", post(crate::handlers::refresh_token))
        .with_state(state)
}

pub async fn start_server(state: Arc<AppState>, config: &config::Config) {
    let app = build_router(state);
    let addr = SocketAddr::from(([0, 0, 0, 0], config.port));
    let listener = tokio::net::TcpListener::bind(&addr).await.expect("Failed to bind");

    info!("Server listening on http://{}", addr);
    axum::serve(listener, app).await.expect("Server error");
}
'@

Create-File "src/models/mod.rs" @'
pub mod requests;
pub mod responses;
pub mod domain;
pub use requests::*;
pub use responses::*;
pub use domain::*;
'@

Create-File "src/models/requests.rs" @'
use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LoginRequest { pub username: String, pub password: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct VerifyRequest { pub token: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RefreshRequest { pub token: String }
'@

Create-File "src/models/responses.rs" @'
use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LoginResponse { pub token: String, pub expires_in: u64, pub user_id: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct VerifyResponse { pub valid: bool, pub user_id: Option<String>, pub expires_in: Option<u64> }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ErrorResponse { pub error: String, pub message: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct HealthResponse { pub status: String, pub version: String, pub timestamp: String }
'@

Create-File "src/models/domain.rs" @'
use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct User { pub id: String, pub username: String, pub created_at: String }
'@

Create-File "src/security/mod.rs" @'
pub mod sanitizer;
pub mod validator;
pub mod token;
pub mod crypto;
pub use sanitizer::sanitize_input;
pub use validator::*;
pub use token::TokenManager;
pub use crypto::CryptoProvider;
'@

Create-File "src/security/sanitizer.rs" @'
pub fn sanitize_input(input: &str) -> Result<String, String> {
    if input.contains("DROP TABLE") { return Err("Invalid input".to_string()); }
    Ok(input.to_string())
}
'@

Create-File "src/security/validator.rs" @'
pub fn validate_token_format(token: &str) -> bool {
    token.starts_with("token_")
}
'@

Create-File "src/security/token.rs" @'
pub struct TokenManager;
impl TokenManager {
    pub fn generate_token(user_id: &str) -> String {
        format!("token_{}_{}", user_id, chrono::Utc::now().timestamp())
    }
}
'@

Create-File "src/security/crypto.rs" @'
pub struct CryptoProvider;
impl CryptoProvider {
    pub fn hash_password(p: &str) -> String { format!("hashed_{}", p) }
}
'@

Create-File "src/rate_limit/mod.rs" @'
pub mod limiter;
pub mod storage;
pub use limiter::RateLimiter;
'@

Create-File "src/rate_limit/limiter.rs" @'
use super::storage::RequestStorage;
use std::sync::Arc;
#[derive(Clone)]
pub struct RateLimiter { storage: Arc<RequestStorage>, max_requests: usize }
impl RateLimiter {
    pub fn new(m: usize) -> Self { Self { storage: Arc::new(RequestStorage::new()), max_requests: m } }
    pub fn check_rate_limit(&self, ip: &str) -> bool { self.storage.check_limit(ip, self.max_requests) }
}
'@

Create-File "src/rate_limit/storage.rs" @'
use std::collections::HashMap;
use std::sync::Mutex;
pub struct RequestStorage { requests: Mutex<HashMap<String, Vec<std::time::Instant>>> }
impl RequestStorage {
    pub fn new() -> Self { Self { requests: Mutex::new(HashMap::new()) } }
    pub fn check_limit(&self, ip: &str, max: usize) -> bool {
        let mut reqs = self.requests.lock().unwrap();
        let client = reqs.entry(ip.to_string()).or_insert_with(Vec::new);
        if client.len() >= max { return false; }
        client.push(std::time::Instant::now());
        true
    }
}
'@

Create-File "src/bot_detection/mod.rs" @'
pub mod detector;
pub mod activity;
pub use detector::BotDetector;
'@

Create-File "src/bot_detection/detector.rs" @'
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
#[derive(Clone)]
pub struct BotDetector { ips: Arc<Mutex<HashMap<String, u32>>> }
impl BotDetector {
    pub fn new() -> Self { Self { ips: Arc::new(Mutex::new(HashMap::new())) } }
    pub fn record_failed_login(&self, ip: &str) {
        let mut map = self.ips.lock().unwrap();
        *map.entry(ip.to_string()).or_insert(0) += 1;
    }
    pub fn is_suspicious(&self, ip: &str) -> bool {
        let map = self.ips.lock().unwrap();
        map.get(ip).map(|&c| c > 5).unwrap_or(false)
    }
}
'@

Create-File "src/bot_detection/activity.rs" @'
pub struct SuspiciousActivity { pub failed_logins: u32 }
'@

Create-File "src/handlers/mod.rs" @'
pub mod health;
pub mod root;
pub mod login;
pub mod verify;
pub mod refresh;
pub use health::*;
pub use root::*;
pub use login::*;
pub use verify::*;
pub use refresh::*;
'@

Create-File "src/handlers/health.rs" @'
use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;
use crate::{AppState, models::HealthResponse};
pub async fn health_check(State(state): State<Arc<AppState>>) -> (StatusCode, Json<HealthResponse>) {
    let res = HealthResponse { status: "ok".to_string(), version: state.version.clone(), timestamp: "now".to_string() };
    (StatusCode::OK, Json(res))
}
'@

Create-File "src/handlers/root.rs" @'
use axum::extract::State;
use std::sync::Arc;
use crate::AppState;
pub async fn root(State(state): State<Arc<AppState>>) -> String {
    format!("Constellation Fabric - Auth Service v{}", state.version)
}
'@

Create-File "src/handlers/login.rs" @'
use axum::{extract::{ConnectInfo, Json, State}, http::StatusCode};
use std::net::SocketAddr;
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn login(ConnectInfo(addr): ConnectInfo<SocketAddr>, State(state): State<Arc<AppState>>, Json(payload): Json<LoginRequest>) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    Ok((StatusCode::OK, Json(LoginResponse { token: "token".to_string(), expires_in: 3600, user_id: payload.username })))
}
'@

Create-File "src/handlers/verify.rs" @'
use axum::{extract::{Json, State}, http::StatusCode};
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn verify_token(State(_state): State<Arc<AppState>>, Json(_payload): Json<VerifyRequest>) -> (StatusCode, Json<VerifyResponse>) {
    (StatusCode::OK, Json(VerifyResponse { valid: true, user_id: Some("user".to_string()), expires_in: Some(3600) }))
}
'@

Create-File "src/handlers/refresh.rs" @'
use axum::{extract::{Json, State}, http::StatusCode};
use std::sync::Arc;
use crate::{AppState, models::*};
pub async fn refresh_token(State(_state): State<Arc<AppState>>, Json(payload): Json<RefreshRequest>) -> Result<(StatusCode, Json<RefreshResponse>), StatusCode> {
    Ok((StatusCode::OK, Json(RefreshResponse { token: format!("{}_new", payload.token), expires_in: 3600 })))
}
'@

Create-File "src/middleware/mod.rs" @'
pub mod rate_limit;
pub mod auth;
pub mod logging;
'@

Create-File "src/middleware/rate_limit.rs" @'
pub struct RateLimitMiddleware;
'@

Create-File "src/middleware/auth.rs" @'
pub struct AuthMiddleware;
'@

Create-File "src/middleware/logging.rs" @'
pub struct LoggingMiddleware;
'@

Write-Host "[PASSO 12] Atualizando Cargo.toml..." -ForegroundColor Yellow

Create-File "Cargo.toml" @'
[package]
name = "auth"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.7"
tokio = { version = "1.35", features = ["full"] }
tower = "0.4"
tower-http = { version = "0.5", features = ["trace", "cors"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }

[[bin]]
name = "auth"
path = "src/main.rs"
'@

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "OK -> ESTRUTURA MODULAR CRIADA!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""
Write-Host "Proximos passos:" -ForegroundColor Yellow
Write-Host "  1. cd $AuthCratePath" -ForegroundColor Cyan
Write-Host "  2. cargo build" -ForegroundColor Cyan
Write-Host ""
pause
