use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum AuthError {
    #[error("Authentication failed: {0}")]
    InvalidCredentials(String),

    #[error("Token error: {0}")]
    TokenError(String),

    #[error("Rate limit exceeded")]
    RateLimitExceeded,

    #[error("Suspicious activity detected")]
    SuspiciousActivity,

    #[error("Internal server error: {0}")]
    InternalError(String),

    #[error("Database error: {0}")]
    DatabaseError(String),

    #[error("Missing configuration: {0}")]
    ConfigError(String),
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let (status, error_code) = match self {
            AuthError::InvalidCredentials(_) => (StatusCode::UNAUTHORIZED, "INVALID_CREDENTIALS"),
            AuthError::TokenError(_) => (StatusCode::UNAUTHORIZED, "TOKEN_ERROR"),
            AuthError::RateLimitExceeded => (StatusCode::TOO_MANY_REQUESTS, "RATE_LIMIT_EXCEEDED"),
            AuthError::SuspiciousActivity => (StatusCode::FORBIDDEN, "SUSPICIOUS_ACTIVITY"),
            AuthError::InternalError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"),
            AuthError::DatabaseError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "DATABASE_ERROR"),
            AuthError::ConfigError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "CONFIG_ERROR"),
        };

        let body = Json(json!({
            "error": {
                "code": error_code,
                "message": self.to_string(),
            }
        }));

        (status, body).into_response()
    }
}

pub type AuthResult<T> = std::result::Result<T, AuthError>;
