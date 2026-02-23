// Modulos
pub mod models;
pub mod handlers;
pub mod middleware;
pub mod metrics;
pub mod tracing;
pub mod spans;
pub mod exporters;

pub use models::*;
pub use handlers::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_loads() { assert_eq!(2 + 2, 4); }
}
