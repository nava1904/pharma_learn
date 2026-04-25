-- ===========================================
-- SSO CONFIGURATIONS
-- AD/OIDC/SAML/LDAP Single Sign-On integration
-- Alfa URS §4.5.2-7, EE URS §5.4.2, §5.6.10
-- ===========================================

-- -------------------------------------------------------
-- SSO PROVIDER CONFIGURATIONS
-- One row per identity provider per organization
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS sso_configurations (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,   -- NULL = all plants

    -- Provider identity
    provider_name           TEXT NOT NULL,        -- e.g. 'Alfa Active Directory', 'Google Workspace'
    provider_type           TEXT NOT NULL
                                CHECK (provider_type IN ('OIDC', 'SAML', 'LDAP', 'AZURE_AD', 'GOOGLE', 'OKTA', 'CUSTOM')),
    protocol                TEXT NOT NULL
                                CHECK (protocol IN ('OIDC', 'SAML2', 'LDAP', 'LDAPS')),

    -- OIDC configuration
    issuer_url              TEXT,
    authorization_endpoint  TEXT,
    token_endpoint          TEXT,
    userinfo_endpoint       TEXT,
    jwks_uri                TEXT,
    client_id               TEXT,
    -- Secret is stored by reference — actual secret lives in vault
    client_secret_vault_ref TEXT,   -- e.g. 'vault://pharmalearn/sso/client-secret'

    -- SAML configuration
    sp_entity_id            TEXT,        -- our Service Provider entity ID
    idp_entity_id           TEXT,        -- Identity Provider entity ID
    idp_sso_url             TEXT,        -- IdP SSO endpoint
    idp_certificate         TEXT,        -- IdP X.509 signing certificate (PEM, NOT the key)
    sp_certificate_vault_ref TEXT,       -- our SP certificate vault reference

    -- LDAP/AD configuration
    ldap_host               TEXT,
    ldap_port               INTEGER DEFAULT 636 CHECK (ldap_port BETWEEN 1 AND 65535),
    ldap_base_dn            TEXT,
    ldap_bind_dn            TEXT,
    ldap_bind_secret_ref    TEXT,   -- vault reference for bind password
    ldap_user_filter        TEXT DEFAULT '(&(objectClass=person)(sAMAccountName={username}))',
    ldap_group_filter       TEXT,
    ldap_use_starttls       BOOLEAN NOT NULL DEFAULT TRUE,

    -- JIT (Just-In-Time) provisioning
    -- When TRUE: a new employee record is created on first SSO login if none exists
    jit_provisioning        BOOLEAN NOT NULL DEFAULT FALSE,
    default_role_id         UUID REFERENCES roles(id) ON DELETE SET NULL,
    default_plant_id        UUID REFERENCES plants(id) ON DELETE SET NULL,

    -- Attribute mapping: IdP claim → employee field
    -- e.g. {"email": "mail", "employee_id": "employeeID", "department": "department"}
    attribute_mapping       JSONB NOT NULL DEFAULT '{}',

    -- Behavior
    is_primary              BOOLEAN NOT NULL DEFAULT FALSE,   -- primary SSO = shown first on login page
    enforce_sso             BOOLEAN NOT NULL DEFAULT FALSE,   -- if TRUE, local password login is disabled
    allow_local_fallback    BOOLEAN NOT NULL DEFAULT TRUE,    -- allow local password if SSO is down

    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    UNIQUE(organization_id, provider_name)
);

CREATE INDEX IF NOT EXISTS idx_sso_configs_org    ON sso_configurations(organization_id);
CREATE INDEX IF NOT EXISTS idx_sso_configs_active ON sso_configurations(is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trg_sso_configs_updated ON sso_configurations;
CREATE TRIGGER trg_sso_configs_updated
    BEFORE UPDATE ON sso_configurations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_sso_configs_audit ON sso_configurations;
CREATE TRIGGER trg_sso_configs_audit
    AFTER INSERT OR UPDATE OR DELETE ON sso_configurations
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- SSO USER MAPPINGS
-- Links internal employee records to external IdP identities
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS sso_user_mappings (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    employee_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    sso_config_id       UUID NOT NULL REFERENCES sso_configurations(id) ON DELETE CASCADE,

    -- External identity
    external_id         TEXT NOT NULL,      -- e.g. IdP subject claim, AD objectGUID, LDAP DN
    external_email      TEXT,
    external_username   TEXT,

    -- When was this mapping created/last used
    first_linked_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_used_at        TIMESTAMPTZ,

    -- Whether this mapping was created by JIT or manual linking
    is_jit_created      BOOLEAN NOT NULL DEFAULT FALSE,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(sso_config_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_sso_mappings_employee ON sso_user_mappings(employee_id);
CREATE INDEX IF NOT EXISTS idx_sso_mappings_config   ON sso_user_mappings(sso_config_id);
CREATE INDEX IF NOT EXISTS idx_sso_mappings_ext_id   ON sso_user_mappings(external_id);

COMMENT ON TABLE  sso_configurations IS 'OIDC/SAML/LDAP/AD SSO provider configuration per organization (Alfa §4.5.2-7, EE §5.4.2)';
COMMENT ON COLUMN sso_configurations.client_secret_vault_ref IS 'Vault path for OAuth client secret — NEVER store secrets directly';
COMMENT ON COLUMN sso_configurations.jit_provisioning IS 'Just-in-time: creates employee record on first SSO login if none exists';
COMMENT ON COLUMN sso_configurations.enforce_sso IS 'When TRUE, local password login is disabled; users must authenticate via SSO';
COMMENT ON TABLE  sso_user_mappings IS 'Links employee records to external IdP identities; supports multiple providers per employee';
