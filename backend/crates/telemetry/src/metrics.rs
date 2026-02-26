use std::time::Instant;

pub struct Metrics;
impl Metrics {
    pub fn new() -> Self { Metrics }
    pub fn record_http_request(&self, method: &str, path: &str, duration: f64) {
        tracing::info!(metric = "http_request", method = method, path = path, duration_ms = duration * 1000.0);
    }
    pub fn record_combat_action(&self, action: &str, damage: f32) {
        tracing::info!(metric = "combat_action", action = action, damage = damage);
    }
}
