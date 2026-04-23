use shared::{ElementalReaction, ActionType};
use crate::character::Character;

pub trait CombatMath: Send + Sync {
    fn calculate_base_damage(&self, attacker: &Character, action_type: ActionType) -> f32;
    fn calculate_reaction_bonus(&self, attacker: &Character, reaction: ElementalReaction, base_multiplier: f32) -> f32;
    fn calculate_critical_hit(&self, attacker: &Character, base_damage: f32) -> (f32, bool);
    fn calculate_defense_mitigation(&self, defender: &Character, incoming_damage: f32) -> f32;
    fn calculate_harmony_resonance(&self, party: &[Character]) -> f32;
}

pub struct AuthoritativeCombatMath;

impl CombatMath for AuthoritativeCombatMath {
    fn calculate_base_damage(&self, attacker: &Character, action_type: ActionType) -> f32 {
        match action_type {
            ActionType::NormalAttack => attacker.attack,
            ActionType::ChargedAttack => attacker.attack * 1.5,
            ActionType::ElementalSkill => attacker.attack * 1.2 + attacker.elemental_mastery * 0.5,
            ActionType::ElementalBurst => attacker.attack * 2.0 + attacker.elemental_mastery * 0.8,
        }
    }

    fn calculate_reaction_bonus(&self, attacker: &Character, _reaction: ElementalReaction, base_multiplier: f32) -> f32 {
        // Elemental Mastery bonus: (2.78 * EM) / (EM + 1400)
        let em_bonus = (2.78 * attacker.elemental_mastery) / (attacker.elemental_mastery + 1400.0);
        base_multiplier * (1.0 + em_bonus)
    }

    fn calculate_critical_hit(&self, attacker: &Character, base_damage: f32) -> (f32, bool) {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        if rng.gen_range(0.0..1.0) <= attacker.critical_rate {
            (base_damage * attacker.critical_damage, true)
        } else {
            (base_damage, false)
        }
    }

    fn calculate_defense_mitigation(&self, defender: &Character, incoming_damage: f32) -> f32 {
        let mut effective_defense = defender.defense;
        
        for effect in &defender.active_effects {
            if let crate::effects::StatusEffect::Superconduct { defense_reduction, .. } = effect {
                effective_defense *= 1.0 - defense_reduction;
            }
        }

        // Standard defense formula: damage * (1 - Def / (Def + 5 * Level + 500))
        let def_factor = effective_defense / (effective_defense + 5.0 * defender.level as f32 + 500.0);
        incoming_damage * (1.0 - def_factor.min(0.95))
    }

    fn calculate_harmony_resonance(&self, party: &[Character]) -> f32 {
        let siblings = ["Kaelen", "Elora", "Rion"];
        let count = party.iter()
            .filter(|c| siblings.contains(&c.name.as_str()))
            .count();

        match count {
            3 => 1.15, // Ressonância Completa (Família Unida)
            2 => 1.07, // Ressonância Parcial
            _ => 1.0,  // Sem bônus
        }
    }
}
