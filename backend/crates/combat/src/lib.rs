// Modulos
pub mod models;
pub mod handlers;
pub mod middleware;
pub mod logic;
pub mod damage;
pub mod effects;
pub mod turn_manager;

pub use models::*;
pub use handlers::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_loads() { assert_eq!(2 + 2, 4); }
}
