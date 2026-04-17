// Modulos
pub mod config;
pub mod models;
pub mod security;
pub mod rate_limit;
pub mod bot_detection;
pub mod handlers;
pub mod middleware;
pub mod state;
pub mod error;

use aws_sdk_dynamodb::Client as DynamoClient;

// AppState definition
#[derive(Clone)]
pub struct AppState {
    pub version: String,
    pub rate_limiter: rate_limit::RateLimiter,
    pub bot_detector: bot_detection::BotDetector,
    pub jwt_keys: Option<security::JwtKeys>,
    pub dynamo_client: DynamoClient,
    pub table_name: String,
}

impl AppState {
    pub fn new(
        version: &str,
        rate_limit_requests: usize,
        jwt_keys: Option<security::JwtKeys>,
        dynamo_client: DynamoClient,
        table_name: String,
    ) -> Self {
        Self {
            version: version.to_string(),
            rate_limiter: rate_limit::RateLimiter::new(rate_limit_requests),
            bot_detector: bot_detection::BotDetector::new(),
            jwt_keys,
            dynamo_client,
            table_name,
        }
    }
}

// Re-exportar tipos principais
pub use models::{LoginRequest, LoginResponse, ErrorResponse, RefreshResponse, RefreshRequest};
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
