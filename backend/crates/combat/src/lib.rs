pub mod character;
pub mod combat;
pub mod logic;
pub mod api;
pub mod handlers;

pub use shared::{Element, ElementalReaction, CombatAction, CombatResult, ActionType};
pub use character::Character;
pub use combat::CombatEngine;
pub use api::{CombatActionRequestV1, CombatResponseV1};
