-- ============================================================================
-- Constellation Fabrick - Secure Player State Schema (Migration 1)
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Players table
CREATE TABLE IF NOT EXISTS players (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  username VARCHAR(255) NOT NULL UNIQUE,
  email VARCHAR(255) NOT NULL UNIQUE,
  level INT NOT NULL DEFAULT 1 CHECK (level >= 1),
  experience INT NOT NULL DEFAULT 0 CHECK (experience >= 0),
  health INT NOT NULL DEFAULT 100 CHECK (health >= 0 AND health <= max_health),
  max_health INT NOT NULL DEFAULT 100 CHECK (max_health > 0),
  region VARCHAR(50) NOT NULL DEFAULT 'us-east-1',
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 2. Player inventory
CREATE TABLE IF NOT EXISTS player_inventory (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  player_id UUID NOT NULL REFERENCES players(id) ON DELETE CASCADE,
  character_slot INT NOT NULL CHECK (character_slot BETWEEN 1 AND 4),
  character_name VARCHAR(255) NOT NULL,
  character_element VARCHAR(50) NOT NULL,
  level INT NOT NULL DEFAULT 1 CHECK (level >= 1),
  experience INT NOT NULL DEFAULT 0 CHECK (experience >= 0),
  health INT NOT NULL DEFAULT 100 CHECK (health >= 0),
  attack INT NOT NULL DEFAULT 10,
  defense INT NOT NULL DEFAULT 5,
  created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(player_id, character_slot)
);

-- ============================================================================
-- SECURITY: ROW LEVEL SECURITY (RLS)
-- ============================================================================

ALTER TABLE players ENABLE ROW LEVEL SECURITY;
ALTER TABLE player_inventory ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'player_isolation_policy') THEN
        CREATE POLICY player_isolation_policy ON players
            FOR ALL
            USING (id::text = current_setting('app.current_player_id', true));
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_policy WHERE polname = 'inventory_isolation_policy') THEN
        CREATE POLICY inventory_isolation_policy ON player_inventory
            FOR ALL
            USING (player_id::text = current_setting('app.current_player_id', true));
    END IF;
END
$$;

-- ============================================================================
-- AUDIT TRIGGERS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_players_modtime ON players;
CREATE TRIGGER update_players_modtime
    BEFORE UPDATE ON players
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_inventory_modtime ON player_inventory;
CREATE TRIGGER update_inventory_modtime
    BEFORE UPDATE ON player_inventory
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_players_email ON players(email);
CREATE INDEX IF NOT EXISTS idx_inventory_player_id ON player_inventory(player_id);
