pub mod metrics;
pub mod tracing;

pub use metrics::Metrics;

pub fn init() {
    tracing::init_tracing();
}
