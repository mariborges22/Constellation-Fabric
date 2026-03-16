use aws_sdk_secretsmanager::Client;
use tracing::{info, error};

#[derive(Clone, Debug)]
pub struct JwtKeys {
    pub private_key: Vec<u8>,
    pub public_key: Vec<u8>,
}

pub struct SecretLoader;

impl SecretLoader {
    pub async fn load_jwt_keys(secret_arn: &str) -> Option<JwtKeys> {
        if secret_arn.is_empty() {
            return None;
        }

        info!("Iniciando carregamento de chaves JWT via Secrets Manager: {}", secret_arn);
        
        let config = aws_config::load_from_env().await;
        let client = Client::new(&config);

        match client.get_secret_value().secret_id(secret_arn).send().await {
            Ok(output) => {
                if let Some(secret_string) = output.secret_string() {
                    match serde_json::from_str::<serde_json::Value>(secret_string) {
                        Ok(json) => {
                            let private = json["private"].as_str()?;
                            let public = json["public"].as_str()?;
                            
                            info!("Chaves JWT carregadas com sucesso.");
                            Some(JwtKeys {
                                private_key: private.as_bytes().to_vec(),
                                public_key: public.as_bytes().to_vec(),
                            })
                        },
                        Err(e) => {
                            error!("Falha ao parsear JSON do segredo JWT: {}", e);
                            None
                        }
                    }
                } else {
                    error!("Segredo JWT não contém string de valor.");
                    None
                }
            },
            Err(e) => {
                error!("Falha ao buscar segredo JWT do Secrets Manager: {}", e);
                None
            }
        }
    }
}
