use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
pub enum Element {
    Anemo,
    Pyro,
    Hydro,
    Electro,
    Cryo,
    Geo,
    Dendro,
    None,
}

pub fn common_logic() {
    println!("Shared logic");
}
