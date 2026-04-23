use prometheus::{Encoder, IntCounter, IntCounterVec, HistogramVec, Registry, TextEncoder, opts, register_int_counter_vec, register_histogram_vec};
use lazy_static::lazy_static;

lazy_static! {
    pub static ref REGISTRY: Registry = Registry::new();

    pub static ref HTTP_REQUESTS_TOTAL: IntCounterVec = register_int_counter_vec!(
        opts!("http_requests_total", "Total number of HTTP requests"),
        &["method", "path", "status"]
    ).expect("Can't create http_requests_total");

    pub static ref HTTP_REQUEST_DURATION_SECONDS: HistogramVec = register_histogram_vec!(
        "http_request_duration_seconds",
        "HTTP request duration in seconds",
        &["method", "path"]
    ).expect("Can't create http_request_duration_seconds");

    pub static ref COMBAT_ACTIONS_TOTAL: IntCounterVec = register_int_counter_vec!(
        opts!("combat_actions_total", "Total number of combat actions executed"),
        &["action_type", "result"]
    ).expect("Can't create combat_actions_total");
    
    pub static ref COMBAT_DAMAGE_TOTAL: IntCounter = prometheus::register_int_counter!(
        opts!("combat_damage_total", "Total damage dealt in the game")
    ).expect("Can't create combat_damage_total");
}

pub struct Metrics;

impl Metrics {
    pub fn new() -> Self {
        Metrics
    }

    pub fn record_http_request(method: &str, path: &str, status: u16, duration: f64) {
        HTTP_REQUESTS_TOTAL.with_label_values(&[method, path, &status.to_string()]).inc();
        HTTP_REQUEST_DURATION_SECONDS.with_label_values(&[method, path]).observe(duration);
    }

    pub fn record_combat_action(action_type: &str, result: &str, damage: f32) {
        COMBAT_ACTIONS_TOTAL.with_label_values(&[action_type, result]).inc();
        COMBAT_DAMAGE_TOTAL.inc_by(damage as u64);
    }

    /// Gera a string no formato Prometheus para o endpoint /metrics
    pub fn gather_metrics() -> String {
        let encoder = TextEncoder::new();
        let metric_families = prometheus::gather();
        let mut buffer = vec![];
        encoder.encode(&metric_families, &mut buffer).unwrap();
        String::from_utf8(buffer).unwrap()
    }
}
