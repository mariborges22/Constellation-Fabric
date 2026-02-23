param(
    [string]$BackendPath = "backend"
)

# Configurar encoding
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "SETUP: Todos os Crates - Estrutura Modular" -ForegroundColor Cyan
Write-Host "================================================================"
Write-Host ""

if (-not (Test-Path "$BackendPath/crates")) {
    Write-Host "[!] Caminho nao encontrado: $BackendPath/crates" -ForegroundColor Red
    exit 1
}

$crates = @(
    @{
        Name = "combat"
        Description = "Game Combat Engine"
        Modules = @("logic", "damage", "effects", "turn_manager")
        Handlers = @("attack", "defense", "special_ability")
    },
    @{
        Name = "event_publisher"
        Description = "Event Publishing System"
        Modules = @("events", "publisher", "subscribers", "handlers")
        Handlers = @("publish", "subscribe", "broadcast")
    },
    @{
        Name = "player_state"
        Description = "Player State Management"
        Modules = @("state", "persistence", "sync", "snapshots")
        Handlers = @("get_state", "update_state", "save", "load")
    },
    @{
        Name = "telemetry"
        Description = "Observability & Telemetry"
        Modules = @("metrics", "tracing", "spans", "exporters")
        Handlers = @("record_metric", "create_span", "export")
    }
)

function Create-File {
    param($Path, $Content)
    $Parent = Split-Path $Path
    if (-not (Test-Path $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
    Set-Content -Path $Path -Value $Content -Encoding UTF8 -Force
}

foreach ($crate in $crates) {
    $name = $crate.Name
    $fmtName = $name.Replace("_", "-")
    $root = "$BackendPath/crates/$fmtName"

    Write-Host "[*] Criando: $fmtName ..." -ForegroundColor Yellow

    # lib.rs
    $modList = ""
    foreach ($m in $crate.Modules) { $modList += "pub mod $m;`n" }
    
    $lib = @"
// Modulos
pub mod models;
pub mod handlers;
pub mod middleware;
$modList
pub use models::*;
pub use handlers::*;

#[cfg(test)]
mod tests {
    #[test]
    fn test_loads() { assert_eq!(2 + 2, 4); }
}
"@
    Create-File "$root/src/lib.rs" $lib

    # main.rs
    $desc = $crate.Description
    $main = @"
use tracing::info;

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt().with_max_level(tracing::Level::INFO).init();
    info!("Service: $desc v0.1.0");
    info!("Status: Ready");
}
"@
    Create-File "$root/src/main.rs" $main

    # models/mod.rs
    $models = @'
use serde::{Deserialize, Serialize};
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Request { pub data: String }
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Response { pub status: String, pub data: Option<String> }
'@
    Create-File "$root/src/models/mod.rs" $models

    # handlers/mod.rs
    $hFuncs = ""
    foreach ($h in $crate.Handlers) {
        $hFuncs += "pub async fn $h(_state: State<Arc<ServiceState>>) -> (StatusCode, Json<super::models::Response>) {`n"
        $hFuncs += "    (StatusCode::OK, Json(super::models::Response { status: `"ok`".to_string(), data: Some(`"$h`".to_string()) }))`n"
        $hFuncs += "}`n`n"
    }
    
    $handlers = @"
use axum::{extract::State, http::StatusCode, Json};
use std::sync::Arc;

#[derive(Clone)]
pub struct ServiceState { pub service_name: String }

$hFuncs
"@
    Create-File "$root/src/handlers/mod.rs" $handlers

    # middleware/mod.rs
    Create-File "$root/src/middleware/mod.rs" "pub struct ServiceMiddleware;"

    # Modules
    foreach ($m in $crate.Modules) {
        Create-File "$root/src/$m/mod.rs" "pub struct Module;"
    }

    # Cargo.toml
    $cargo = @"
[package]
name = "$fmtName"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.7"
tokio = { version = "1.35", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing_subscriber = { version = "0.3", features = ["env-filter", "json"] }
chrono = { version = "0.4", features = ["serde"] }
uuid = { version = "1.0", features = ["v4", "serde"] }

[[bin]]
name = "$fmtName"
path = "src/main.rs"
"@
    Create-File "$root/Cargo.toml" $cargo

    Write-Host "  [OK]" -ForegroundColor Green
}

# Workspace
$workspace = @'
[workspace]
members = [
    "crates/auth",
    "crates/combat",
    "crates/event-publisher",
    "crates/player-state",
    "crates/telemetry",
]

[workspace.package]
version = "0.1.0"
edition = "2021"
authors = ["Constellation Fabric Team"]
license = "MIT"

[workspace.dependencies]
tokio = { version = "1.35", features = ["full"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
tracing = "0.1"
tracing-subscriber = "0.3"
axum = "0.7"
hyper = "1.0"
uuid = { version = "1.0", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
'@
Create-File "$BackendPath/Cargo.toml" $workspace

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "OK -> Crates criados e Workspace configurado!" -ForegroundColor Green
Write-Host "================================================================"
Write-Host ""
pause
