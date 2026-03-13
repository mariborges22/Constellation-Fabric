use crate::character::Character;
use shared::{Element, ElementalReaction, ActionType, CombatAction, CombatResult};
use event_publisher::publisher::KinesisPublisher;
use crate::logic::math::{CombatMath, AuthoritativeCombatMath};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use tracing::{info, span, Level};

pub struct CombatEngine {
    math: Box<dyn CombatMath>,
    publisher: Option<KinesisPublisher>,
}

impl CombatEngine {
    pub fn new(publisher: Option<KinesisPublisher>) -> Self {
        Self {
            math: Box::new(AuthoritativeCombatMath),
            publisher,
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

        let result = CombatResult {
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
        };

        if let Some(publisher) = &self.publisher {
            publisher.publish_event(result.action.actor_id.to_string(), &result.action);
        }

        result
    }
}

