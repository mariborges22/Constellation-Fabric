pub struct TokenManager;
impl TokenManager {
    pub fn generate_token(user_id: &str) -> String {
        format!("token_{}_{}", user_id, chrono::Utc::now().timestamp())
    }
}
