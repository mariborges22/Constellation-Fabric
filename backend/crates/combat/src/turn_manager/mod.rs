use crate::Character;
use shared::ActionType;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TurnActor {
    Player,
    Enemy,
}

#[derive(Debug, Clone)]
pub struct TurnManager {
    pub current_actor: TurnActor,
    pub turn_count: u64,
}

impl TurnManager {
    pub fn new() -> Self {
        Self {
            current_actor: TurnActor::Player, // Player always goes first for now
            turn_count: 1,
        }
    }

    /// Advances the turn to the next actor.
    pub fn advance_turn(&mut self) {
        self.current_actor = match self.current_actor {
            TurnActor::Player => TurnActor::Enemy,
            TurnActor::Enemy => TurnActor::Player,
        };
        self.turn_count += 1;
    }

    /// Validates if the given character is allowed to act this turn.
    pub fn can_act(&self, character_id: Uuid, player_id: Uuid, enemy_id: Uuid) -> bool {
        match self.current_actor {
            TurnActor::Player => character_id == player_id,
            TurnActor::Enemy => character_id == enemy_id,
        }
    }

    /// Generates energy for a character based on their action.
    pub fn generate_energy(character: &mut Character, action_type: ActionType) {
        let energy_gain = match action_type {
            ActionType::NormalAttack => 10.0,
            ActionType::ChargedAttack => 15.0,
            ActionType::ElementalSkill => 25.0,
            ActionType::ElementalBurst => -character.max_energy, // Consumes all energy
        };

        character.energy += energy_gain;
        if character.energy < 0.0 {
            character.energy = 0.0;
        } else if character.energy > character.max_energy {
            character.energy = character.max_energy;
        }
    }
}
