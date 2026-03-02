use crate::character::Character;
use crate::elements::{Element, ElementalReaction};
use crate::logic::math::{CombatMath, AuthoritativeCombatMath};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use tracing::{info, span, Level};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ActionType {
    NormalAttack, ChargedAttack, ElementalSkill, ElementalBurst,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CombatAction {
    pub id: Uuid, pub actor_id: Uuid, pub action_type: ActionType, pub damage: f32, pub reaction: ElementalReaction, pub timestamp: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CombatResult {
    pub action: CombatAction, pub target_remaining_hp: f32, pub is_critical: bool, pub final_damage: f32,
}

pub struct CombatEngine {
    math: Box<dyn CombatMath>,
}

impl CombatEngine {
    pub fn new() -> Self {
        Self {
            math: Box::new(AuthoritativeCombatMath),
        }
    }

    pub fn execute_action(&self, attacker: &Character, defender: &mut Character, action_type: ActionType) -> CombatResult {
        let span = span!(Level::INFO, "combat_action", 
            actor_id = %attacker.id, 
            defender_id = %defender.id, 
            action = ?action_type
        );
        let _enter = span.enter();

        // 1. Calculate Base Damage
        let base_dmg = self.math.calculate_base_damage(attacker, action_type);
        
        // 2. Handle Elemental Reactions
        let (reaction, multiplier) = attacker.element.calculate_reaction(defender.element);
        let reaction_dmg = self.math.calculate_reaction_bonus(attacker, reaction, base_dmg * multiplier);
        
        // 3. Handle Critical Hits
        let (crit_dmg, is_critical) = self.math.calculate_critical_hit(attacker, reaction_dmg);
        
        // 4. Defense Mitigation
        let final_dmg = self.math.calculate_defense_mitigation(defender, crit_dmg);

        info!(
            final_damage = final_dmg, 
            reaction = ?reaction, 
            critical = is_critical, 
            "Damage calculated"
        );

        defender.take_damage(final_dmg);

        CombatResult {
            action: CombatAction {
                id: Uuid::new_v4(),
                actor_id: attacker.id,
                action_type,
                damage: final_dmg,
                reaction,
                timestamp: chrono::Utc::now().timestamp() as u64,
            },
            target_remaining_hp: defender.current_hp,
            is_critical,
            final_damage: final_dmg,
        }
    }
}

