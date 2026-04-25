-- ===========================================
-- API RATE LIMITS
-- Per-endpoint rate limiting configuration
-- Enterprise security control
-- ===========================================

CREATE TABLE IF NOT EXISTS api_rate_limits (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Scope
    organization_id         UUID REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,

    -- Endpoint pattern (supports wildcards)
    endpoint_pattern        TEXT NOT NULL,          -- e.g., '/api/v1/train/*', '/api/v1/certify/assessments/*'
    http_method             TEXT DEFAULT '*' CHECK (http_method IN ('GET', 'POST', 'PUT', 'PATCH', 'DELETE', '*')),

    -- Rate limits
    limit_per_minute        INTEGER NOT NULL DEFAULT 60,
    limit_per_hour          INTEGER DEFAULT 1000,
    burst_limit             INTEGER DEFAULT 100,    -- Max requests in a 1-second burst

    -- Response behavior
    retry_after_seconds     INTEGER DEFAULT 60,     -- Retry-After header value when limited

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    priority                INTEGER DEFAULT 100,    -- Lower = higher priority (more specific rules first)

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    UNIQUE(organization_id, endpoint_pattern, http_method)
);

CREATE INDEX IF NOT EXISTS idx_rate_limits_org ON api_rate_limits(organization_id);
CREATE INDEX IF NOT EXISTS idx_rate_limits_active ON api_rate_limits(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_rate_limits_priority ON api_rate_limits(priority ASC);

-- -------------------------------------------------------
-- WEBHOOK SUBSCRIPTIONS
-- Outbound event notification configuration
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS webhook_subscriptions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Webhook details
    name                    TEXT NOT NULL,
    description             TEXT,
    target_url              TEXT NOT NULL,
    http_method             TEXT NOT NULL DEFAULT 'POST' CHECK (http_method IN ('POST', 'PUT', 'PATCH')),

    -- Events to subscribe to
    event_types             TEXT[] NOT NULL,        -- e.g., ['training.completed', 'certificate.issued', 'assessment.failed']

    -- Authentication
    auth_type               TEXT DEFAULT 'NONE' CHECK (auth_type IN ('NONE', 'BASIC', 'BEARER', 'HMAC', 'API_KEY')),
    auth_secret_ref         TEXT,                   -- Reference to secret in vault (never store actual secrets)
    auth_header_name        TEXT DEFAULT 'Authorization',

    -- Request configuration
    headers                 JSONB DEFAULT '{}',     -- Additional headers to include
    timeout_seconds         INTEGER DEFAULT 30,
    content_type            TEXT DEFAULT 'application/json',

    -- Retry configuration
    max_retries             INTEGER DEFAULT 3,
    retry_backoff_base      INTEGER DEFAULT 2,      -- Exponential backoff base (seconds)
    retry_backoff_max       INTEGER DEFAULT 3600,   -- Max backoff (1 hour)

    -- Filters
    plant_filter            UUID[],                 -- Only events from these plants (NULL = all)
    entity_filter           JSONB,                  -- Additional entity-type filters

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    last_triggered_at       TIMESTAMPTZ,
    consecutive_failures    INTEGER DEFAULT 0,
    disabled_at             TIMESTAMPTZ,            -- Auto-disabled after too many failures
    disabled_reason         TEXT,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID
);

CREATE INDEX IF NOT EXISTS idx_webhooks_org ON webhook_subscriptions(organization_id);
CREATE INDEX IF NOT EXISTS idx_webhooks_active ON webhook_subscriptions(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_webhooks_events ON webhook_subscriptions USING GIN(event_types);

-- -------------------------------------------------------
-- WEBHOOK DELIVERIES
-- Delivery attempts and status tracking
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS webhook_deliveries (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subscription_id         UUID NOT NULL REFERENCES webhook_subscriptions(id) ON DELETE CASCADE,

    -- Event details
    event_type              TEXT NOT NULL,
    event_id                UUID NOT NULL,          -- Reference to the event that triggered this delivery
    event_payload           JSONB NOT NULL,

    -- Request details
    request_url             TEXT NOT NULL,
    request_headers         JSONB,
    request_body            TEXT,

    -- Response details
    response_status         INTEGER,
    response_headers        JSONB,
    response_body           TEXT,
    response_time_ms        INTEGER,

    -- Status
    status                  TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN (
        'PENDING', 'SUCCESS', 'FAILED', 'RETRYING'
    )),
    attempt_number          INTEGER NOT NULL DEFAULT 1,
    next_retry_at           TIMESTAMPTZ,
    error_message           TEXT,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    delivered_at            TIMESTAMPTZ,

    -- HMAC signature (if auth_type = HMAC)
    signature               TEXT
);

CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_sub ON webhook_deliveries(subscription_id);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_status ON webhook_deliveries(status);
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_retry ON webhook_deliveries(next_retry_at)
    WHERE status = 'RETRYING' AND next_retry_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_webhook_deliveries_created ON webhook_deliveries(created_at DESC);

-- -------------------------------------------------------
-- INTEGRATION SECRETS
-- Secure reference storage (actual secrets in external vault)
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS integration_secrets (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    integration_id          UUID REFERENCES integrations(id) ON DELETE CASCADE,

    -- Secret identification
    secret_key              TEXT NOT NULL,          -- Logical name (e.g., 'API_KEY', 'CLIENT_SECRET')
    vault_ref               TEXT NOT NULL,          -- Reference to external vault (e.g., AWS Secrets Manager ARN)
    secret_version          TEXT,                   -- Version identifier in vault

    -- Metadata
    description             TEXT,
    expires_at              TIMESTAMPTZ,
    rotated_at              TIMESTAMPTZ,
    rotation_reminder_days  INTEGER DEFAULT 90,

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,
    last_accessed_at        TIMESTAMPTZ,
    last_accessed_by        UUID,

    UNIQUE(organization_id, secret_key)
);

CREATE INDEX IF NOT EXISTS idx_secrets_org ON integration_secrets(organization_id);
CREATE INDEX IF NOT EXISTS idx_secrets_integration ON integration_secrets(integration_id) WHERE integration_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_secrets_expires ON integration_secrets(expires_at) WHERE expires_at IS NOT NULL;

-- Audit trigger for secret access tracking
DROP TRIGGER IF EXISTS trg_secrets_audit ON integration_secrets;
CREATE TRIGGER trg_secrets_audit
    AFTER INSERT OR UPDATE OR DELETE ON integration_secrets
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

COMMENT ON TABLE api_rate_limits IS 'Per-endpoint rate limiting configuration for API protection';
COMMENT ON TABLE webhook_subscriptions IS 'Outbound webhook configuration for event-driven integrations';
COMMENT ON TABLE webhook_deliveries IS 'Webhook delivery attempts with retry tracking';
COMMENT ON TABLE integration_secrets IS 'Secure secret reference storage — actual secrets stored in external vault';
COMMENT ON COLUMN integration_secrets.vault_ref IS 'External vault reference (AWS Secrets Manager ARN, HashiCorp path, etc.)';
