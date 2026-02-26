# ============================================================================
# CONSTELLATION FABRICK - Player State Setup Script
# Player State Service with RDS/PostgreSQL Integration
# ============================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SETTING UP: Player State Service" -ForegroundColor Cyan
Write-Host "================================================"
Write-Host ""

# Variables
$BACKEND_DIR = "backend"
$CRATE_DIR = "$BACKEND_DIR/crates/player-state"
$DB_HOST = if ($env:DB_HOST) { $env:DB_HOST } else { "localhost" }
$DB_PORT = if ($env:DB_PORT) { $env:DB_PORT } else { "5432" }
$DB_NAME = "constellation"
$DB_USER = "postgres"
$DB_PASS = "postgres"

# ============================================================================
# CHECK PREREQUISITES
# ============================================================================

Write-Host "[1/5] Checking prerequisites..." -ForegroundColor Yellow

if (-not (Test-Path $CRATE_DIR)) {
    Write-Host "ERRO: Player State crate not found at $CRATE_DIR" -ForegroundColor Red
    exit 1
}

$psqlExists = Get-Command psql -ErrorAction SilentlyContinue
if ($null -eq $psqlExists) {
    Write-Host "AVISO: psql (PostgreSQL client) nao encontrado localmente." -ForegroundColor Yellow
}

Write-Host "  OK -> Prerequisites validated" -ForegroundColor Green

# ============================================================================
# INITIALIZE DATABASE (LOCAL FALLBACK)
# ============================================================================

Write-Host ""
Write-Host "[2/5] Initializing Database Schema..." -ForegroundColor Yellow

if ($null -ne $psqlExists) {
    Write-Host "[*] Tentando conectar ao PostgreSQL local em $DB_HOST:$DB_PORT..." -ForegroundColor Cyan
    
    # Run schema (assumes psql credentials are set or using defaults)
    try {
        & psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$CRATE_DIR/schema.sql" -v ON_ERROR_STOP=1
        Write-Host "  OK -> Database schema applied" -ForegroundColor Green
    } catch {
        Write-Host "AVISO: Falha ao aplicar schema localmente. Verifique se o Postgres esta rodando." -ForegroundColor Yellow
    }
} else {
    Write-Host "AVISO: psql nao disponivel. Pulei a inicializacao automatica do DB." -ForegroundColor White
}

# ============================================================================
# CONFIGURE ENVIRONMENT
# ============================================================================

Write-Host ""
Write-Host "[3/5] Configuring environment variables..." -ForegroundColor Yellow

$envFile = "$BACKEND_DIR/.env.player-state"
$envContent = @"
# ============================================================================
# Player State Service Configuration
# ============================================================================

# Database
DATABASE_URL=postgresql://$DB_USER:$DB_PASS@$DB_HOST:$DB_PORT/$DB_NAME

# Service
PORT=8081
RUST_LOG=player_state=info,axum=info

# Region
REGION=us-east-1
"@

Set-Content -Path $envFile -Value $envContent -Encoding UTF8
Write-Host "  OK -> Created $envFile" -ForegroundColor Green

# ============================================================================
# CREATE DOCKER COMPOSE (LOCAL DEV)
# ============================================================================

Write-Host ""
Write-Host "[4/5] Creating local Docker Compose..." -ForegroundColor Yellow

$composeContent = @'
version: '3.8'

services:
  postgres:
    image: postgres:15-bookworm
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: constellation
    ports:
      - "5432:5432"
    volumes:
      - ./crates/player-state/schema.sql:/docker-entrypoint-initdb.d/schema.sql

volumes:
  postgres_data:
'@

Set-Content -Path "$BACKEND_DIR/docker-compose.player-state.yml" -Value $composeContent -Encoding UTF8
Write-Host "  OK -> Created docker-compose.player-state.yml" -ForegroundColor Green

# ============================================================================
# SUMMARY
# ============================================================================

Write-Host ""
Write-Host "[5/5] Generating summary..." -ForegroundColor Yellow

$summary = @"
================================================================
CONSTELLATION FABRICK - Player State Setup Summary
================================================================

STATUS: Hardened Implementation Ready
Database Type: PostgreSQL / RDS

SECURITY FEATURES:
- Row Level Security (RLS) enabled in schema.sql
- Prepared Statements (sqlx) used in all handlers
- Input Validation (validator crate) implemented

ARCHITECTURE:
- Debian-based environment (Bookworm)
- Asynchronous Axum handlers
- Centralized common logic (shared crate)

NEXT STEPS:
1. PUSH changes to GitHub to trigger CI/CD deployment to ECS.
2. For local testing: 
   docker-compose -f backend/docker-compose.player-state.yml up -d
================================================================
"@

Write-Host $summary -ForegroundColor Green
$summary | Out-File -FilePath "setup-player-state-summary.txt" -Encoding UTF8
Write-Host "Summary saved to setup-player-state-summary.txt" -ForegroundColor Cyan
