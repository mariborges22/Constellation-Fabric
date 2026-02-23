use serde::{Deserialize, Serialize};
use shared::Element;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Character {
    pub id: String,
    pub name: String,
    pub element: Element,
    pub level: u32,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Party {
    pub members: Vec<Character>,
    pub active_index: usize,
}

impl Party {
    pub fn get_active_character(&self) -> Option<&Character> {
        self.members.get(self.active_index)
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Player {
    pub id: String,
    pub position: (f32, f32),
    pub party: Party,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SyncRequest {
    pub player_id: String,
    pub position: (f32, f32),
    pub timestamp: u64,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct SyncResponse {
    pub status: String,
    pub server_time: u64,
}
