use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum CombatError {
    #[error("Character not found: {0}")]
    CharacterNotFound(String),

    #[error("Invalid combat action: {0}")]
    InvalidAction(String),

    #[error("Internal engine error: {0}")]
    InternalEngineError(String),

    #[error("External service error: {0}")]
    ExternalServiceError(String),

    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
}

impl IntoResponse for CombatError {
    fn into_response(self) -> Response {
        let (status, error_code) = match self {
            CombatError::CharacterNotFound(_) => (StatusCode::NOT_FOUND, "CHARACTER_NOT_FOUND"),
            CombatError::InvalidAction(_) => (StatusCode::BAD_REQUEST, "INVALID_ACTION"),
            CombatError::InternalEngineError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"),
            CombatError::ExternalServiceError(_) => (StatusCode::BAD_GATEWAY, "EXTERNAL_SERVICE_ERROR"),
            CombatError::SerializationError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "SERIALIZATION_ERROR"),
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

pub type CombatResult<T> = std::result::Result<T, CombatError>;
