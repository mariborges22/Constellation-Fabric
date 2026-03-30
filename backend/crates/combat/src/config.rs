use serde::Deserialize;

#[derive(Debug, Deserialize, Clone)]
pub struct Config {
    pub kinesis_stream_name: Option<String>,
    pub port: u16,
    pub log_level: String,
}

impl Config {
    pub fn from_env() -> Self {
        dotenvy::dotenv().ok(); // Try to load .env file if it exists

        Self {
            kinesis_stream_name: std::env::var("KINESIS_STREAM_NAME").ok(),
            port: std::env::var("PORT")
                .unwrap_or_else(|_| "8082".to_string())
                .parse()
                .expect("PORT must be a valid u16"),
            log_level: std::env::var("LOG_LEVEL").unwrap_or_else(|_| "info".to_string()),
        }
    }
}
