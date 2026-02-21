use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct User { pub id: String, pub username: String, pub created_at: String }
