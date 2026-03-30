use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde_json::json;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum TelemetryError {
    #[error("Exporter error: {0}")]
    ExporterError(String),

    #[error("Init error: {0}")]
    InitError(String),

    #[error("Internal error: {0}")]
    InternalError(String),
}

impl IntoResponse for TelemetryError {
    fn into_response(self) -> Response {
        let (status, error_code) = match self {
            TelemetryError::ExporterError(_) => (StatusCode::BAD_GATEWAY, "EXPORTER_ERROR"),
            TelemetryError::InitError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INIT_ERROR"),
            TelemetryError::InternalError(_) => (StatusCode::INTERNAL_SERVER_ERROR, "INTERNAL_ERROR"),
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

pub type TelemetryResult<T> = std::result::Result<T, TelemetryError>;
