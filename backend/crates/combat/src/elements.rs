use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Element {
    Pyro,
    Hydro,
    Electro,
    Cryo,
    Anemo,
    Geo,
    Dendro,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ElementalReaction {
    Burn,
    Freeze,
    ElectroCharged,
    Superconduct,
    Swirl,
    Crystallize,
    Bloom,
    None,
}

impl Element {
    pub fn get_reaction(&self, other: Element) -> ElementalReaction {
        match (self, other) {
            (Element::Pyro, Element::Hydro) | (Element::Hydro, Element::Pyro) => ElementalReaction::Burn,
            (Element::Hydro, Element::Cryo) | (Element::Cryo, Element::Hydro) => ElementalReaction::Freeze,
            (Element::Electro, Element::Hydro) | (Element::Hydro, Element::Electro) => ElementalReaction::ElectroCharged,
            (Element::Electro, Element::Cryo) | (Element::Cryo, Element::Electro) => ElementalReaction::Superconduct,
            (Element::Anemo, _) | (_, Element::Anemo) => ElementalReaction::Swirl,
            (Element::Geo, _) | (_, Element::Geo) => ElementalReaction::Crystallize,
            (Element::Dendro, Element::Hydro) | (Element::Hydro, Element::Dendro) => ElementalReaction::Bloom,
            _ => ElementalReaction::None,
        }
    }
    pub fn get_damage_multiplier(&self, reaction: ElementalReaction) -> f32 {
        match reaction {
            ElementalReaction::Burn => 1.25,
            ElementalReaction::Freeze => 1.5,
            ElementalReaction::ElectroCharged => 1.5,
            ElementalReaction::Superconduct => 1.5,
            ElementalReaction::Swirl => 1.2,
            ElementalReaction::Crystallize => 1.1,
            ElementalReaction::Bloom => 2.0,
            ElementalReaction::None => 1.0,
        }
    }
}

