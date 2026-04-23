pub mod character;
pub mod combat;
pub mod logic;
pub mod api;
pub mod handlers;
pub mod error;
pub mod config;
pub mod persistence;
pub mod effects;
pub mod turn_manager;

pub use shared::{Element, ElementalReaction, CombatAction, CombatResult, ActionType};
pub use character::Character;
pub use combat::CombatEngine;
pub use turn_manager::TurnManager;
pub use api::{
    CombatActionRequestV1, CombatResponseV1, EndMatchRequestV1, EndMatchResponseV1,
    MatchStateResponseV1, StartMatchRequestV1, StartMatchResponseV1, SubmitTurnRequestV1,
};
