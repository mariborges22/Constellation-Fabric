-- ============================================================================
-- Idempotency Keys Table
-- Fixes non-idempotent XP increments by tracking requests
-- ============================================================================

CREATE TABLE IF NOT EXISTS idempotency_keys (
    key UUID PRIMARY KEY,
    response_body JSONB NOT NULL,
    status_code SMALLINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index for cleanup (e.g., delete keys older than 24h)
CREATE INDEX IF NOT EXISTS idx_idempotency_keys_created_at ON idempotency_keys(created_at);
