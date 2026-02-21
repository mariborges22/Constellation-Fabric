pub struct CryptoProvider;
impl CryptoProvider {
    pub fn hash_password(p: &str) -> String { format!("hashed_{}", p) }
}
