-- ===========================================
-- INTEGRATIONS
-- ===========================================

-- Integration Connections
CREATE TABLE IF NOT EXISTS integrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    integration_type TEXT NOT NULL,
    integration_name TEXT NOT NULL,
    description TEXT,
    config JSONB NOT NULL,
    credentials_encrypted JSONB,
    is_active BOOLEAN DEFAULT false,
    last_sync_at TIMESTAMPTZ,
    last_sync_status TEXT,
    sync_frequency TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, integration_type)
);

CREATE INDEX IF NOT EXISTS idx_integrations_org ON integrations(organization_id);
CREATE INDEX IF NOT EXISTS idx_integrations_type ON integrations(integration_type);
CREATE INDEX IF NOT EXISTS idx_integrations_active ON integrations(is_active);

-- Integration Sync Logs
CREATE TABLE IF NOT EXISTS integration_sync_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
    sync_type TEXT NOT NULL,
    sync_direction TEXT NOT NULL,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'running',
    records_fetched INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    error_log JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sync_logs_integration ON integration_sync_logs(integration_id);
CREATE INDEX IF NOT EXISTS idx_sync_logs_status ON integration_sync_logs(status);
CREATE INDEX IF NOT EXISTS idx_sync_logs_started ON integration_sync_logs(started_at);

-- External System Mappings
CREATE TABLE IF NOT EXISTS external_id_mappings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    integration_id UUID NOT NULL REFERENCES integrations(id) ON DELETE CASCADE,
    internal_entity_type TEXT NOT NULL,
    internal_entity_id UUID NOT NULL,
    external_entity_type TEXT NOT NULL,
    external_entity_id TEXT NOT NULL,
    external_data JSONB,
    last_synced_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(integration_id, internal_entity_type, internal_entity_id),
    UNIQUE(integration_id, external_entity_type, external_entity_id)
);

CREATE INDEX IF NOT EXISTS idx_ext_mappings_internal ON external_id_mappings(internal_entity_type, internal_entity_id);
CREATE INDEX IF NOT EXISTS idx_ext_mappings_external ON external_id_mappings(external_entity_type, external_entity_id);

-- SSO Configuration
CREATE TABLE IF NOT EXISTS sso_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    sso_type TEXT NOT NULL,
    provider_name TEXT NOT NULL,
    config JSONB NOT NULL,
    metadata_url TEXT,
    entity_id TEXT,
    certificate TEXT,
    is_active BOOLEAN DEFAULT false,
    is_default BOOLEAN DEFAULT false,
    attribute_mapping JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, sso_type)
);

CREATE INDEX IF NOT EXISTS idx_sso_org ON sso_configurations(organization_id);
CREATE INDEX IF NOT EXISTS idx_sso_active ON sso_configurations(is_active);
