use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum StatusEffect {
    /// Deals Pyro damage over time.
    Burning { duration_turns: u8, dps: f32 },
    
    /// Stuns the character, skipping their turn.
    Frozen { duration_turns: u8 },
    
    /// Reduces defense by a percentage (e.g., 0.40 for 40%).
    Superconduct { duration_turns: u8, defense_reduction: f32 },
    
    /// Deals Electro and Hydro damage over time.
    ElectroCharged { duration_turns: u8, dps: f32 },
}

impl StatusEffect {
    pub fn duration(&self) -> u8 {
        match self {
            Self::Burning { duration_turns, .. } => *duration_turns,
            Self::Frozen { duration_turns } => *duration_turns,
            Self::Superconduct { duration_turns, .. } => *duration_turns,
            Self::ElectroCharged { duration_turns, .. } => *duration_turns,
        }
    }

    pub fn decrement_duration(&mut self) {
        match self {
            Self::Burning { duration_turns, .. } => *duration_turns = duration_turns.saturating_sub(1),
            Self::Frozen { duration_turns } => *duration_turns = duration_turns.saturating_sub(1),
            Self::Superconduct { duration_turns, .. } => *duration_turns = duration_turns.saturating_sub(1),
            Self::ElectroCharged { duration_turns, .. } => *duration_turns = duration_turns.saturating_sub(1),
        }
    }
}
