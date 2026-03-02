pub mod elements;
pub mod character;
pub mod combat;
pub mod logic;
pub mod api;

pub use elements::{Element, ElementalReaction};
pub use character::Character;
pub use combat::{CombatEngine, CombatAction, CombatResult, ActionType};
pub use api::{CombatActionRequestV1, CombatResponseV1};
