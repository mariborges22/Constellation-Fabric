use super::storage::RequestStorage;
use std::sync::Arc;
#[derive(Clone)]
pub struct RateLimiter { storage: Arc<RequestStorage>, max_requests: usize }
impl RateLimiter {
    pub fn new(m: usize) -> Self { Self { storage: Arc::new(RequestStorage::new()), max_requests: m } }
    pub fn check_rate_limit(&self, ip: &str) -> bool { self.storage.check_limit(ip, self.max_requests) }
}
