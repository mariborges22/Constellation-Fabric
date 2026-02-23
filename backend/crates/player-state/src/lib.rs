// Modulos
pub mod models;
pub mod handlers;
pub mod middleware;
pub mod state;
pub mod persistence;
pub mod sync;
pub mod snapshots;

pub use models::*;
pub use handlers::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_loads() { assert_eq!(2 + 2, 4); }
}
