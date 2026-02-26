use crate::elements::Element;
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
        }
    }
    pub fn is_alive(&self) -> bool { self.current_hp > 0.0 }
    pub fn take_damage(&mut self, mut damage: f32) {
        let reduction = self.defense * 0.1;
        damage = damage * (1.0 - reduction.min(0.9));
        self.current_hp -= damage;
        if (self.current_hp < 0.0) { self.current_hp = 0.0; }
    }
}

