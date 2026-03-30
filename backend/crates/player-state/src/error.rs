use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PlayerStateError {
    #[error("Player not found: {0}")]
    NotFound(String),

    #[error("Conflict: {0}")]
    Conflict(String),

    #[error("Validation error: {0}")]
    ValidationError(String),

    #[error("Database error: {0}")]
    DatabaseError(String),

    #[error("Internal error: {0}")]
    InternalError(String),
}

impl IntoResponse for PlayerStateError {
    fn into_response(self) -> Response {
        let (status, error_code) = match self {
            PlayerStateError::NotFound(_) => (StatusCode::NOT_FOUND, "PLAYER_NOT_FOUND"),
            PlayerStateError::Conflict(_) => (StatusCode::CONFLICT, "PLAYER_CONFLICT"),
            PlayerStateError::ValidationError(_) => (StatusCode::BAD_REQUEST, "VALIDATION_ERROR"),
            PlayerStateError::DatabaseError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "DATABASE_ERROR"),
            PlayerStateError::InternalError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"),
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

pub type PlayerStateResult<T> = std::result::Result<T, PlayerStateError>;
