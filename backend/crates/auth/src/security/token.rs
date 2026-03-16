use jsonwebtoken::{encode, EncodingKey, Header};
use serde::{Deserialize, Serialize};
use crate::security::JwtKeys;

#[derive(Debug, Serialize, Deserialize)]
struct Claims {
    sub: String,
    exp: usize,
    iat: usize,
}

pub struct TokenManager;

impl TokenManager {
    pub fn generate_token(user_id: &str, keys: &Option<JwtKeys>) -> String {
        if let Some(keys) = keys {
            let my_claims = Claims {
                sub: user_id.to_owned(),
                exp: (chrono::Utc::now() + chrono::Duration::hours(24)).timestamp() as usize,
                iat: chrono::Utc::now().timestamp() as usize,
            };

            match EncodingKey::from_rsa_pem(&keys.private_key) {
                Ok(key) => {
                    encode(&Header::new(jsonwebtoken::Algorithm::RS256), &my_claims, &key)
                        .unwrap_or_else(|_| "error_generating_token".to_string())
                },
                Err(_) => "invalid_rsa_private_key".to_string(),
            }
        } else {
            // Fallback para desenvolvimento local sem AWS
            format!("dev_token_{}_{}", user_id, chrono::Utc::now().timestamp())
        }
    }
}
