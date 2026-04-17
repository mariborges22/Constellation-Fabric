use axum::{extract::{ConnectInfo, Json, State}, http::StatusCode};
use std::net::SocketAddr;
use std::sync::Arc;
use aws_sdk_dynamodb::types::AttributeValue;
use crate::{AppState, models::*};

pub async fn login(
    ConnectInfo(_addr): ConnectInfo<SocketAddr>, 
    State(state): State<Arc<AppState>>, 
    Json(payload): Json<LoginRequest>
) -> Result<(StatusCode, Json<LoginResponse>), StatusCode> {
    
    // Busca usuário pelo GSI2 (username_index)
    let res = state.dynamo_client.query()
        .table_name(&state.table_name)
        .index_name("gsi2")
        .key_condition_expression("username_index = :u")
        .expression_attribute_values(":u", AttributeValue::S(format!("USERNAME#{}", payload.username)))
        .send()
        .await
        .map_err(|e| {
            tracing::error!("Erro de query no DynamoDB: {:?}", e);
            StatusCode::INTERNAL_SERVER_ERROR
        })?;

    let items = res.items.unwrap_or_default();
    if items.is_empty() {
        return Err(StatusCode::UNAUTHORIZED);
    }

    let item = &items[0];
    let password_hash = item.get("password_hash").and_then(|v| v.as_s().ok()).unwrap();
    
    // Verificação simplificada (em prod: usar bcrypt::verify)
    if password_hash != &payload.password {
        return Err(StatusCode::UNAUTHORIZED);
    }

    let token = crate::security::TokenManager::generate_token(&payload.username, &state.jwt_keys);
    
    Ok((StatusCode::OK, Json(LoginResponse { 
        token, 
        expires_in: 3600, 
        user_id: payload.username 
    })))
}
