pub fn validate_token_format(token: &str) -> bool {
    token.starts_with("token_")
}
