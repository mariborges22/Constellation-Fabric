use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LoginResponse { pub token: String, pub expires_in: u64, pub user_id: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct VerifyResponse { pub valid: bool, pub user_id: Option<String>, pub expires_in: Option<u64> }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ErrorResponse { pub error: String, pub message: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct HealthResponse { pub status: String, pub version: String, pub timestamp: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RefreshResponse { pub token: String, pub expires_in: u64 }
