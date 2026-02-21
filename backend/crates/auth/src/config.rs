#[derive(Clone, Debug)]
pub struct Config {
    pub version: String,
    pub port: u16,
    pub rate_limit_requests: usize,
    pub log_level: String,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            version: "0.1.0".to_string(),
            port: std::env::var("PORT")
                .unwrap_or("3000".to_string())
                .parse()
                .unwrap_or(3000),
            rate_limit_requests: std::env::var("RATE_LIMIT")
                .unwrap_or("100".to_string())
                .parse()
                .unwrap_or(100),
            log_level: std::env::var("LOG_LEVEL")
                .unwrap_or("info".to_string()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn test_config_defaults() {
        let config = Config::from_env();
        assert_eq!(config.port, 3000);
    }
}
