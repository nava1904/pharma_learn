-- ===========================================
-- FEATURE FLAGS
-- Modular roll-out per tenant/plant
-- Enables opt-in activation of extension modules
-- (gamification, KB, discussions, surveys, cost-tracking)
-- Sprint 2 / M-11
-- ===========================================

-- -------------------------------------------------------
-- GLOBAL FEATURE FLAG REGISTRY
-- Defines all features the platform supports
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS feature_flags (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Feature identifier (snake_case, no spaces)
    feature_key         TEXT UNIQUE NOT NULL,
    display_name        TEXT NOT NULL,
    description         TEXT,

    -- Module grouping
    module              TEXT NOT NULL DEFAULT 'core'
                            CHECK (module IN (
                                'core',
                                'gamification',
                                'knowledge_base',
                                'discussions',
                                'surveys',
                                'cost_tracking',
                                'analytics',
                                'integrations',
                                'experimental'
                            )),

    -- Default state for new tenants
    default_enabled     BOOLEAN NOT NULL DEFAULT FALSE,

    -- Whether this feature requires IQ/OQ validation before enablement
    requires_validation BOOLEAN NOT NULL DEFAULT FALSE,

    -- Dependency chain: feature_key of another flag that must be enabled first
    depends_on_feature  TEXT REFERENCES feature_flags(feature_key) ON DELETE SET NULL,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feature_flags_module  ON feature_flags(module);
CREATE INDEX IF NOT EXISTS idx_feature_flags_active  ON feature_flags(is_active) WHERE is_active = TRUE;

-- -------------------------------------------------------
-- TENANT FEATURE FLAGS
-- Per-organization (and optionally per-plant) flag overrides
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS tenant_feature_flags (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    feature_key         TEXT NOT NULL REFERENCES feature_flags(feature_key) ON DELETE CASCADE,

    -- Scope
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,   -- NULL = all plants

    -- State
    is_enabled          BOOLEAN NOT NULL DEFAULT FALSE,

    -- Validation reference (for requires_validation flags)
    validation_doc_ref  TEXT,
    validated_at        TIMESTAMPTZ,
    validated_by        UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Who toggled
    changed_by          UUID REFERENCES employees(id) ON DELETE SET NULL,
    changed_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_reason       TEXT,

    UNIQUE(feature_key, organization_id, COALESCE(plant_id, '00000000-0000-0000-0000-000000000000'::UUID))
);

CREATE INDEX IF NOT EXISTS idx_tenant_flags_org     ON tenant_feature_flags(organization_id);
CREATE INDEX IF NOT EXISTS idx_tenant_flags_plant   ON tenant_feature_flags(plant_id);
CREATE INDEX IF NOT EXISTS idx_tenant_flags_enabled ON tenant_feature_flags(feature_key)
    WHERE is_enabled = TRUE;

-- Audit changes to feature flags
DROP TRIGGER IF EXISTS trg_tenant_flags_audit ON tenant_feature_flags;
CREATE TRIGGER trg_tenant_flags_audit
    AFTER INSERT OR UPDATE OR DELETE ON tenant_feature_flags
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- FUNCTION: check if a feature is enabled for a given org/plant
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION is_feature_enabled(
    p_feature_key   TEXT,
    p_org_id        UUID,
    p_plant_id      UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_global    feature_flags%ROWTYPE;
    v_enabled   BOOLEAN;
BEGIN
    -- Fetch global flag definition
    SELECT * INTO v_global FROM feature_flags WHERE feature_key = p_feature_key AND is_active = TRUE;
    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Check dependency
    IF v_global.depends_on_feature IS NOT NULL THEN
        IF NOT is_feature_enabled(v_global.depends_on_feature, p_org_id, p_plant_id) THEN
            RETURN FALSE;
        END IF;
    END IF;

    -- Try plant-specific override
    IF p_plant_id IS NOT NULL THEN
        SELECT is_enabled INTO v_enabled
        FROM tenant_feature_flags
        WHERE feature_key = p_feature_key
          AND organization_id = p_org_id
          AND plant_id = p_plant_id;
        IF FOUND THEN RETURN v_enabled; END IF;
    END IF;

    -- Try org-wide override
    SELECT is_enabled INTO v_enabled
    FROM tenant_feature_flags
    WHERE feature_key = p_feature_key
      AND organization_id = p_org_id
      AND plant_id IS NULL;
    IF FOUND THEN RETURN v_enabled; END IF;

    -- Fall back to global default
    RETURN v_global.default_enabled;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- -------------------------------------------------------
-- SEED: all platform features
-- -------------------------------------------------------
INSERT INTO feature_flags (feature_key, display_name, description, module, default_enabled, requires_validation)
VALUES
    -- Core (always on)
    ('core.audit_trail',        'Audit Trail',              'Immutable audit log (21 CFR Part 11)',        'core',          TRUE,  FALSE),
    ('core.esignatures',        'Electronic Signatures',    '21 CFR Part 11 §11.200 e-signatures',        'core',          TRUE,  FALSE),
    ('core.rbac',               'Role-Based Access Control','Fine-grained RBAC with approval tiers',      'core',          TRUE,  FALSE),
    ('core.induction_gate',     'Induction Gate',           'Block access until induction is complete',   'core',          TRUE,  FALSE),
    ('core.biometric_auth',     'Biometric Authentication', 'Fingerprint/face recognition sign-in',       'core',          FALSE, TRUE),
    ('core.sso',                'Single Sign-On',           'OIDC/SAML/LDAP SSO integration',             'core',          FALSE, FALSE),
    ('core.mfa',                'Multi-Factor Auth',        'TOTP/email/SMS second factor',               'core',          FALSE, FALSE),

    -- Training
    ('training.obt',            'Online Batch Training',    'Fully online ILT delivery mode',             'core',          TRUE,  FALSE),
    ('training.ojt',            'On-the-Job Training',      'OJT workflow with witnessed sign-off',       'core',          TRUE,  FALSE),
    ('training.wbt',            'WBT/SCORM Content',        'SCORM 1.2 / xAPI content delivery',         'core',          FALSE, TRUE),
    ('training.proctoring',     'Assessment Proctoring',    'AI-assisted exam proctoring',                'experimental',  FALSE, TRUE),

    -- Extension modules (off by default — require tenant opt-in)
    ('gamification.enabled',    'Gamification',             'Badges, points, leaderboards',               'gamification',  FALSE, FALSE),
    ('kb.enabled',              'Knowledge Base',           'Article library with versioning',            'knowledge_base',FALSE, FALSE),
    ('discussions.enabled',     'Discussions',              'Threaded discussions on courses/documents',  'discussions',   FALSE, FALSE),
    ('surveys.enabled',         'Surveys & Feedback',       'Configurable survey engine',                 'surveys',       FALSE, FALSE),
    ('cost_tracking.enabled',   'Cost Tracking',            'Training budget and expense tracking',       'cost_tracking', FALSE, FALSE),

    -- Analytics
    ('analytics.kpi_dashboard', 'KPI Dashboard',            'Real-time compliance KPI visualization',     'analytics',     TRUE,  FALSE),
    ('analytics.advanced',      'Advanced Analytics',       'Predictive compliance and trend reports',    'analytics',     FALSE, FALSE),

    -- Integrations
    ('integrations.webhooks',   'Outbound Webhooks',        'Push events to external systems',            'integrations',  FALSE, FALSE),
    ('integrations.api_keys',   'API Keys',                 'Machine-to-machine API key auth',            'integrations',  FALSE, FALSE)
ON CONFLICT (feature_key) DO NOTHING;

COMMENT ON TABLE  feature_flags IS 'Global registry of all features; default_enabled controls new tenant behavior';
COMMENT ON TABLE  tenant_feature_flags IS 'Per-org/plant flag overrides — enables modular roll-out (M-11)';
COMMENT ON FUNCTION is_feature_enabled IS 'Check if feature is on for an org/plant; respects dependency chain';
