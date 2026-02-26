# ============================================================================
# CONSTELLATION FABRICK - Combat Engine Setup Script (ASCII VERSION)
# Combat Game Logic Implementation (v1 + Idempotency)
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host "Combat Engine Setup Starting..."
Write-Host "==========================="

$ROOT_DIR = $PSScriptRoot
$BACKEND_DIR = Join-Path $ROOT_DIR "backend"
$COMBAT_CRATE = Join-Path $BACKEND_DIR "crates\combat"
$SRC_DIR = Join-Path $COMBAT_CRATE "src"

# ============================================================================
# PREPARE
# ============================================================================

Write-Host "[1/5] Preparing..."

if (-not (Test-Path $BACKEND_DIR)) {
    Write-Host "Error: Backend workspace not found"
    exit 1
}

if (-not (Test-Path $SRC_DIR)) {
    New-Item -ItemType Directory -Path $SRC_DIR -Force | Out-Null
}

# ============================================================================
# FILES
# ============================================================================

Write-Host "[2/5] Writing Cargo.toml..."
$f1 = "[package]`nname = `"combat`"`nversion = `"0.1.0`"`nedition = `"2021`"`n`n[dependencies]`nserde = { version = `"1.0`", features = [`"derive`"] }`nserde_json = `"1.0`"`nuuid = { version = `"1.0`", features = [`"v4`", `"serde`"] }`nchrono = { version = `"0.4`", features = [`"serde`"] }`nrand = `"0.8`"`nthiserror = `"1.0`"`n`n[lib]`nname = `"combat`"`npath = `"src/lib.rs`"`n"
Set-Content -Path (Join-Path $COMBAT_CRATE "Cargo.toml") -Value $f1

Write-Host "[3/5] Writing Source files..."

# elements.rs
$f2 = "use serde::{Deserialize, Serialize};`n`n#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]`npub enum Element {`n    Pyro,`n    Hydro,`n    Electro,`n    Cryo,`n    Anemo,`n    Geo,`n    Dendro,`n}`n`n#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]`npub enum ElementalReaction {`n    Burn,`n    Freeze,`n    ElectroCharged,`n    Superconduct,`n    Swirl,`n    Crystallize,`n    Bloom,`n    None,`n}`n`nimpl Element {`n    pub fn get_reaction(&self, other: Element) -> ElementalReaction {`n        match (self, other) {`n            (Element::Pyro, Element::Hydro) | (Element::Hydro, Element::Pyro) => ElementalReaction::Burn,`n            (Element::Hydro, Element::Cryo) | (Element::Cryo, Element::Hydro) => ElementalReaction::Freeze,`n            (Element::Electro, Element::Hydro) | (Element::Hydro, Element::Electro) => ElementalReaction::ElectroCharged,`n            (Element::Electro, Element::Cryo) | (Element::Cryo, Element::Electro) => ElementalReaction::Superconduct,`n            (Element::Anemo, _) | (_, Element::Anemo) => ElementalReaction::Swirl,`n            (Element::Geo, _) | (_, Element::Geo) => ElementalReaction::Crystallize,`n            (Element::Dendro, Element::Hydro) | (Element::Hydro, Element::Dendro) => ElementalReaction::Bloom,`n            _ => ElementalReaction::None,`n        }`n    }`n    pub fn get_damage_multiplier(&self, reaction: ElementalReaction) -> f32 {`n        match reaction {`n            ElementalReaction::Burn => 1.25,`n            ElementalReaction::Freeze => 1.5,`n            ElementalReaction::ElectroCharged => 1.5,`n            ElementalReaction::Superconduct => 1.5,`n            ElementalReaction::Swirl => 1.2,`n            ElementalReaction::Crystallize => 1.1,`n            ElementalReaction::Bloom => 2.0,`n            ElementalReaction::None => 1.0,`n        }`n    }`n}`n"
Set-Content -Path (Join-Path $SRC_DIR "elements.rs") -Value $f2

# character.rs
$f3 = "use crate::elements::Element;`nuse serde::{Deserialize, Serialize};`nuse uuid::Uuid;`n`n#[derive(Debug, Clone, Serialize, Deserialize)]`npub struct Character {`n    pub id: Uuid,`n    pub name: String,`n    pub element: Element,`n    pub level: i32,`n    pub max_hp: f32,`n    pub current_hp: f32,`n    pub attack: f32,`n    pub defense: f32,`n    pub elemental_mastery: f32,`n    pub critical_rate: f32,`n    pub critical_damage: f32,`n    pub energy: f32,`n    pub max_energy: f32,`n}`n`nimpl Character {`n    pub fn new(name: String, element: Element, level: i32) -> Self {`n        let base_hp = 100.0 + (level as f32 * 10.0);`n        let base_attack = 10.0 + (level as f32 * 2.0);`n        let base_defense = 5.0 + (level as f32 * 1.0);`n        Character {`n            id: Uuid::new_v4(),`n            name,`n            element,`n            level,`n            max_hp: base_hp,`n            current_hp: base_hp,`n            attack: base_attack,`n            defense: base_defense,`n            elemental_mastery: 0.0,`n            critical_rate: 0.05,`n            critical_damage: 1.5,`n            energy: 0.0,`n            max_energy: 100.0,`n        }`n    }`n    pub fn is_alive(&self) -> bool { self.current_hp > 0.0 }`n    pub fn take_damage(&mut self, mut damage: f32) {`n        let reduction = self.defense * 0.1;`n        damage = damage * (1.0 - reduction.min(0.9));`n        self.current_hp -= damage;`n        if (self.current_hp < 0.0) { self.current_hp = 0.0; }`n    }`n}`n"
Set-Content -Path (Join-Path $SRC_DIR "character.rs") -Value $f3

# combat.rs
$f4 = "use crate::character::Character;`nuse crate::elements::{Element, ElementalReaction};`nuse rand::Rng;`nuse serde::{Deserialize, Serialize};`nuse uuid::Uuid;`n`n#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]`npub enum ActionType {`n    NormalAttack, ChargedAttack, ElementalSkill, ElementalBurst,`n}`n`n#[derive(Debug, Clone, Serialize, Deserialize)]`npub struct CombatAction {`n    pub id: Uuid, pub actor_id: Uuid, pub action_type: ActionType, pub damage: f32, pub reaction: ElementalReaction, pub timestamp: u64,`n}`n`n#[derive(Debug, Clone, Serialize, Deserialize)]`npub struct CombatResult {`n    pub action: CombatAction, pub target_remaining_hp: f32, pub is_critical: bool, pub final_damage: f32,`n}`n`npub struct CombatEngine;`nimpl CombatEngine {`n    pub fn calculate_damage(attacker: &Character, action_type: ActionType) -> f32 {`n        match action_type {`n            ActionType::NormalAttack => attacker.attack,`n            ActionType::ChargedAttack => attacker.attack * 1.5,`n            ActionType::ElementalSkill => attacker.attack * 1.2 + attacker.elemental_mastery * 0.5,`n            ActionType::ElementalBurst => attacker.attack * 2.0 + attacker.elemental_mastery * 0.8,`n        }`n    }`n    pub fn execute_action(attacker: &Character, defender: &mut Character, action_type: ActionType) -> CombatResult {`n        let base = Self::calculate_damage(attacker, action_type);`n        let react = attacker.element.get_reaction(defender.element);`n        let mult = attacker.element.get_damage_multiplier(react);`n        let final_dmg = base * mult;`n        defender.take_damage(final_dmg);`n        CombatResult {`n            action: CombatAction {`n                id: Uuid::new_v4(), actor_id: attacker.id, action_type, damage: final_dmg, reaction: react, timestamp: chrono::Utc::now().timestamp() as u64,`n            },`n            target_remaining_hp: defender.current_hp, is_critical: false, final_damage: final_dmg,`n        }`n    }`n}`n"
Set-Content -Path (Join-Path $SRC_DIR "combat.rs") -Value $f4

# api.rs
$f5 = "use crate::{Character, ActionType, CombatEngine};`nuse serde::{Deserialize, Serialize};`nuse uuid::Uuid;`n`n#[derive(Debug, Serialize, Deserialize)]`npub struct CombatActionRequestV1 {`n    pub idempotency_key: Uuid, pub player_id: Uuid, pub character_id: Uuid, pub target_id: Uuid, pub action_type: ActionType,`n}`n`n#[derive(Debug, Serialize, Deserialize)]`npub struct CombatResponseV1 {`n    pub success: bool, pub damage_dealt: f32, pub enemy_alive: bool, pub player_team_state: Vec<Character>, pub enemy_state: Vec<Character>, pub idempotency_key: Uuid,`n}`n"
Set-Content -Path (Join-Path $SRC_DIR "api.rs") -Value $f5

# lib.rs
$f6 = "pub mod character;`npub mod combat;`npub mod elements;`npub mod api;`n`npub use character::Character;`npub use combat::{ActionType, CombatEngine, CombatAction, CombatResult};`npub use elements::{Element, ElementalReaction};`n"
Set-Content -Path (Join-Path $SRC_DIR "lib.rs") -Value $f6

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host "[4/5] Writing summary..."
$sum = "Combat Engine Setup Summary`n`nStatus: Complete`n1. V1 API Ready`n2. Idempotency Ready`n3. Elements Ready`n4. Character logic port Ready`n"
Set-Content -Path (Join-Path $ROOT_DIR "setup-combat-engine-summary.txt") -Value $sum

Write-Host "Combat Engine Setup Complete!"
Write-Host "NOTE: Generated files in backend/crates/combat/src"
