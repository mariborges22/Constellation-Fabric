pub mod metrics;
pub mod tracing;
pub mod error;

pub use metrics::Metrics;

pub fn init() {
    tracing::init_tracing();
}
