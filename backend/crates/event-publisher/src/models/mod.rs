use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request { pub data: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Response { pub status: String, pub data: Option<String> }
