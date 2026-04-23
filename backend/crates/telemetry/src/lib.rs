pub mod metrics;
pub mod tracing;
pub mod error;
pub mod handlers;

pub use metrics::Metrics;

pub fn init() {
    tracing::init_tracing();
}
