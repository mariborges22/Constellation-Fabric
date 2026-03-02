use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Element {
    Pyro,
    Hydro,
    Electro,
    Cryo,
    Anemo,
    Geo,
    Dendro,
    Physical,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ElementalReaction {
    Vaporize,
    Melt,
    Overloaded,
    Superconduct,
    ElectroCharged,
    Frozen,
    Swirl,
    Crystallize,
    Bloom,
    Burning,
    Aggravate,
    Spread,
    None,
}

impl Element {
    /// Returns the reaction and the multiplier shift based on trigger element (self) and aura (target)
    pub fn calculate_reaction(&self, target_aura: Element) -> (ElementalReaction, f32) {
        match (self, target_aura) {
            // Amplifying Reactions
            (Element::Hydro, Element::Pyro) => (ElementalReaction::Vaporize, 2.0),
            (Element::Pyro, Element::Hydro) => (ElementalReaction::Vaporize, 1.5),
            (Element::Pyro, Element::Cryo) => (ElementalReaction::Melt, 2.0),
            (Element::Cryo, Element::Pyro) => (ElementalReaction::Melt, 1.5),

            // Transformative Reactions
            (Element::Pyro, Element::Electro) | (Element::Electro, Element::Pyro) => (ElementalReaction::Overloaded, 1.25),
            (Element::Cryo, Element::Electro) | (Element::Electro, Element::Cryo) => (ElementalReaction::Superconduct, 1.5),
            (Element::Hydro, Element::Electro) | (Element::Electro, Element::Hydro) => (ElementalReaction::ElectroCharged, 1.5),
            (Element::Hydro, Element::Cryo) | (Element::Cryo, Element::Hydro) => (ElementalReaction::Frozen, 1.0),

            // Supportive/Anemo/Geo
            (Element::Anemo, e) if e != Element::Physical && e != Element::Anemo && e != Element::Geo => (ElementalReaction::Swirl, 1.2),
            (Element::Geo, e) if e != Element::Physical && e != Element::Anemo && e != Element::Geo => (ElementalReaction::Crystallize, 1.1),

            // Dendro
            (Element::Hydro, Element::Dendro) | (Element::Dendro, Element::Hydro) => (ElementalReaction::Bloom, 2.0),
            (Element::Pyro, Element::Dendro) | (Element::Dendro, Element::Pyro) => (ElementalReaction::Burning, 1.2),

            _ => (ElementalReaction::None, 1.0),
        }
    }
}

