use combat::{CombatEngine, Character, Element, ActionType, ElementalReaction};

#[test]
fn test_elemental_reaction_vaporize_multipliers() {
    let engine = CombatEngine::new(None);
    
    // Hydro hitting Pyro (Strong Side) -> 2.0x
    let mut attacker_hydro = Character::new("HydroUser".to_string(), Element::Hydro, 10);
    attacker_hydro.critical_rate = 0.0; // Disable crit for determinism
    let mut defender_pyro = Character::new("PyroTarget".to_string(), Element::Pyro, 10);
    
    let result_strong = engine.execute_action(&attacker_hydro, &mut defender_pyro, ActionType::NormalAttack);
    dbg!(&result_strong);
    assert_eq!(result_strong.action.reaction, ElementalReaction::Vaporize);
    assert!(result_strong.final_damage > 40.0, "Strong side damage: {}", result_strong.final_damage);

    // Pyro hitting Hydro (Weak Side) -> 1.5x
    let mut attacker_pyro = Character::new("PyroUser".to_string(), Element::Pyro, 10);
    attacker_pyro.critical_rate = 0.0; // Disable crit for determinism
    let mut defender_hydro = Character::new("HydroTarget".to_string(), Element::Hydro, 10);
    
    let result_weak = engine.execute_action(&attacker_pyro, &mut defender_hydro, ActionType::NormalAttack);
    dbg!(&result_weak);
    assert_eq!(result_weak.action.reaction, ElementalReaction::Vaporize);
    assert!(result_weak.final_damage < result_strong.final_damage, 
        "Weak side ({}) should be less than Strong side ({})", 
        result_weak.final_damage, result_strong.final_damage);
}

#[test]
fn test_critical_hits_consistency() {
    let engine = CombatEngine::new(None);
    let mut attacker = Character::new("CritFarmer".to_string(), Element::Physical, 10);
    attacker.critical_rate = 1.0; // 100% crit
    attacker.critical_damage = 2.0;

    let mut defender = Character::new("Target".to_string(), Element::Physical, 10);
    
    let result = engine.execute_action(&attacker, &mut defender, ActionType::NormalAttack);
    assert!(result.is_critical);
    assert!(result.final_damage > 50.0);
}

#[test]
fn test_elemental_mastery_scaling() {
    let engine = CombatEngine::new(None);
    
    // Low EM
    let mut attacker_low = Character::new("LowEM".to_string(), Element::Hydro, 10);
    attacker_low.elemental_mastery = 0.0;
    
    // High EM
    let mut attacker_high = Character::new("HighEM".to_string(), Element::Hydro, 10);
    attacker_high.elemental_mastery = 1000.0;
    
    let mut defender = Character::new("Target".to_string(), Element::Pyro, 10);
    let mut defender2 = defender.clone();

    let res_low = engine.execute_action(&attacker_low, &mut defender, ActionType::NormalAttack);
    let res_high = engine.execute_action(&attacker_high, &mut defender2, ActionType::NormalAttack);
    
    assert!(res_high.final_damage > res_low.final_damage, "Higher EM should deal more reaction damage");
}
