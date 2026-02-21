use std::collections::HashMap;
use std::sync::{Arc, Mutex};
#[derive(Clone)]
pub struct BotDetector { ips: Arc<Mutex<HashMap<String, u32>>> }
impl BotDetector {
    pub fn new() -> Self { Self { ips: Arc::new(Mutex::new(HashMap::new())) } }
    pub fn record_failed_login(&self, ip: &str) {
        let mut map = self.ips.lock().unwrap();
        *map.entry(ip.to_string()).or_insert(0) += 1;
    }
    pub fn is_suspicious(&self, ip: &str) -> bool {
        let map = self.ips.lock().unwrap();
        map.get(ip).map(|&c| c > 5).unwrap_or(false)
    }
}
