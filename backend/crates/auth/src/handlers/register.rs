use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;
use uuid::Uuid;
use aws_sdk_dynamodb::types::AttributeValue;
use crate::{AppState, models::*};

pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    let user_id = Uuid::new_v4().to_string();
    
    // Inserção no DynamoDB (Single Table Design)
    state.dynamo_client.put_item()
        .table_name(&state.table_name)
        .item("pk", AttributeValue::S(format!("USER#{}", user_id)))
        .item("sk", AttributeValue::S("METADATA".to_string()))
        .item("username", AttributeValue::S(payload.username.clone()))
        .item("email", AttributeValue::S(payload.email.clone()))
        .item("password_hash", AttributeValue::S(payload.password)) // Em prod: usar hash (argon2/bcrypt)
        .send()
        .await
        .map_err(|e| {
            tracing::error!("Erro ao registrar no DynamoDB: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    let token = crate::security::TokenManager::generate_token(&payload.username, &state.jwt_keys);

    Ok((
        StatusCode::CREATED,
        Json(LoginResponse {
            token,
            expires_in: 3600,
            user_id: payload.username,
        }),
    ))
}
