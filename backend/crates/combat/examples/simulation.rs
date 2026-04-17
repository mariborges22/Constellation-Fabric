use shared::{ActionType, Element};
use combat::character::Character;
use combat::CombatEngine;

fn main() {
    println!("--- Constellation: Equestria Odyssey ---");
    println!("--- Simulador de Combate: O Trio Banido ---\n");

    let engine = CombatEngine::new();

    // 1. Instanciando os Protagonistas no Nível 10
    let kaelen = Character::kaelen(10);
    let elora = Character::elora(10);
    let rion = Character::rion(10);

    let party = vec![kaelen.clone(), elora.clone(), rion.clone()];

    // 2. Criando o Inimigo (Espectro do Abismo - Elemento Hydro)
    let mut enemy = Character::new("Espectro do Abismo".to_string(), Element::Hydro, 10);
    enemy.max_hp = 500.0;
    enemy.current_hp = 500.0;
    enemy.defense = 30.0;

    println!("Batalha iniciada!");
    println!("Equipe: {}, {} e {}", kaelen.name, elora.name, rion.name);
    println!("Inimigo: {} (HP: {})\n", enemy.name, enemy.current_hp);

    // --- TURNO 1: KAELEN (Geo - Proteção) ---
    println!(">> Turno 1: {} avança com seu escudo!", kaelen.name);
    let res1 = engine.execute_action(&kaelen, &mut enemy, ActionType::NormalAttack, &party);
    println!("Dano provocado: {:.2} (Resonância Ativa!)", res1.final_damage);
    println!("{} HP restante: {:.2}\n", enemy.name, enemy.current_hp);

    // --- TURNO 2: ELORA (Cryo - Reação de Congelamento) ---
    println!(">> Turno 2: {} tece o gelo primordial!", elora.name);
    let res2 = engine.execute_action(&elora, &mut enemy, ActionType::ElementalSkill, &party);
    println!("Dano provocado: {:.2} (Reação: {:?} + Bônus EM)", res2.final_damage, res2.action.reaction);
    println!("{} HP restante: {:.2}\n", enemy.name, enemy.current_hp);

    // --- TURNO 3: RION (Electro - Finalizador Crítico) ---
    println!(">> Turno 3: {} libera a tempestade de lealdade!", rion.name);
    let res3 = engine.execute_action(&rion, &mut enemy, ActionType::ElementalBurst, &party);
    if res3.is_critical {
        println!("*** GOLPE CRÍTICO! ***");
    }
    println!("Dano provocado: {:.2} (Ataque Massivo!)", res3.final_damage);
    println!("{} HP restante: {:.2}\n", enemy.name, enemy.current_hp);

    println!("--- Simulação Concluída ---");
}
