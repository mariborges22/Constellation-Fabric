use std::collections::HashMap;
use tokio::sync::Mutex;

pub struct RequestStorage {
    requests: Mutex<HashMap<String, Vec<std::time::Instant>>>,
}

impl RequestStorage {
    pub fn new() -> Self {
        Self {
            requests: Mutex::new(HashMap::new()),
        }
    }

    pub async fn check_limit(&self, ip: &str, max: usize) -> bool {
        let mut reqs = self.requests.lock().await;
        let client = reqs.entry(ip.to_string()).or_insert_with(Vec::new);
        if client.len() >= max {
            return false;
        }
        client.push(std::time::Instant::now());
        true
    }
}
