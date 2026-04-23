use shared::Element;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Character {
    pub id: Uuid,
    pub name: String,
    pub element: Element,
    pub level: i32,
    pub max_hp: f32,
    pub current_hp: f32,
    pub attack: f32,
    pub defense: f32,
    pub elemental_mastery: f32,
    pub critical_rate: f32,
    pub critical_damage: f32,
    pub energy: f32,
    pub max_energy: f32,
    pub active_effects: Vec<crate::effects::StatusEffect>,
}

impl Character {
    pub fn new(name: String, element: Element, level: i32) -> Self {
        let base_hp = 100.0 + (level as f32 * 10.0);
        let base_attack = 10.0 + (level as f32 * 2.0);
        let base_defense = 5.0 + (level as f32 * 1.0);
        Character {
            id: Uuid::new_v4(),
            name,
            element,
            level,
            max_hp: base_hp,
            current_hp: base_hp,
            attack: base_attack,
            defense: base_defense,
            elemental_mastery: 0.0,
            critical_rate: 0.05,
            critical_damage: 1.5,
            energy: 0.0,
            max_energy: 100.0,
            active_effects: Vec::new(),
        }
    }
    
    pub fn is_alive(&self) -> bool { self.current_hp > 0.0 }
    
    pub fn take_damage(&mut self, damage: f32) {
        self.current_hp -= damage;
        if self.current_hp < 0.0 { self.current_hp = 0.0; }
    }

    /// Processes status effects: applies DoT damage and returns total damage taken. Decrements duration.
    pub fn tick_effects(&mut self) -> f32 {
        let mut total_dot_damage = 0.0;
        
        for effect in &mut self.active_effects {
            match effect {
                crate::effects::StatusEffect::Burning { dps, .. } => total_dot_damage += *dps,
                crate::effects::StatusEffect::ElectroCharged { dps, .. } => total_dot_damage += *dps,
                _ => {}
            }
            effect.decrement_duration();
        }
        
        if total_dot_damage > 0.0 {
            self.take_damage(total_dot_damage);
        }
        
        // Remove expired effects
        self.active_effects.retain(|e| e.duration() > 0);
        
        total_dot_damage
    }

    // ========================================================================
    // PROTAGONISTS: THE THREE SIBLINGS
    // ========================================================================

    /// Kaelen: O irmão da Honestidade (Geo/Defesa)
    pub fn kaelen(level: i32) -> Self {
        let mut c = Self::new("Kaelen".to_string(), Element::Geo, level);
        c.max_hp *= 1.2; // 20% mais HP
        c.current_hp = c.max_hp;
        c.defense *= 1.5; // 50% mais Defesa
        c.attack *= 0.8;  // Menos ataque para balancear
        c
    }

    /// Elora: A irmã da Generosidade (Cryo/EM)
    pub fn elora(level: i32) -> Self {
        let mut c = Self::new("Elora".to_string(), Element::Cryo, level);
        c.elemental_mastery = 80.0 + (level as f32 * 5.0);
        c.max_energy = 120.0; // Mais energia para magias
        c.max_hp *= 0.9;      // Menos HP (Glass Cannon)
        c.current_hp = c.max_hp;
        c
    }

    /// Rion: O irmão da Lealdade (Electro/Crit)
    pub fn rion(level: i32) -> Self {
        let mut c = Self::new("Rion".to_string(), Element::Electro, level);
        c.critical_rate = 0.25;   // 25% base de Crítico
        c.critical_damage = 2.0; // 200% de dano crítico base
        c.attack *= 1.3;         // 30% mais ataque
        c
    }
}

