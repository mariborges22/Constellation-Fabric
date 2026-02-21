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
