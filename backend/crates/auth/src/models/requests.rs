use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LoginRequest { pub username: String, pub password: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RegisterRequest { pub username: String, pub email: String, pub password: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct VerifyRequest { pub token: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct RefreshRequest { pub token: String }
