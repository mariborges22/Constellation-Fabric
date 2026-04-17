use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter, Registry};
use tracing_subscriber::fmt::format::FmtSpan;

pub fn init_tracing() {
    // Configuração do filtro de logs via variável de ambiente (padrão: info)
    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new("constellation=info,combat=debug,auth=info"));

    // 1. Camada de Formatação (JSON para CloudWatch/Logs)
    let formatting_layer = tracing_subscriber::fmt::layer()
        .json()
        .with_writer(std::io::stdout)
        .with_span_events(FmtSpan::CLOSE);

    // Inicialização da Registry
    let subscriber = Registry::default()
        .with(env_filter)
        .with(formatting_layer);

    // Se no futuro quisermos injetar o layer de OTLP/X-Ray:
    // .with(otlp_layer) 

    subscriber.init();

    tracing::info!(
        version = env!("CARGO_PKG_VERSION"),
        "🚀 Constellation Observability - Hardened Logging Inicializado"
    );
}
