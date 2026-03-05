use player_state::build_router;
use std::net::SocketAddr;
use sqlx::postgres::PgPoolOptions;
use std::time::Duration;
use tracing::info;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    tracing_subscriber::fmt()
        .with_max_level(tracing::Level::INFO)
        .init();

    info!("Constellation Fabric - Player State Service");

    let database_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgresql://postgres:postgres@localhost:5432/constellation".to_string());

    let pool = PgPoolOptions::new()
        .max_connections(5)
        .acquire_timeout(Duration::from_secs(300))
        .connect(&database_url)
        .await?;

    info!("Connected to database. Running migrations...");
    sqlx::migrate!("./migrations").run(&pool).await?;
    info!("Migrations applied successfully.");

    let repo = std::sync::Arc::new(player_state::PostgresPlayerRepository::new(pool));
    let app = build_router(repo);

    let port = std::env::var("PORT")
        .unwrap_or_else(|_| "8081".to_string())
        .parse::<u16>()?;

    let addr = SocketAddr::from(([0, 0, 0, 0], port));
    info!("Server listening on http://{}", addr);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}
