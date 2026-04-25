-- ===========================================
-- SYSTEM SETTINGS
-- Configurable key-value store for all tunable behaviors
-- Alfa URS §3.1.46-47, §4.4.5
-- Replaces all hardcoded thresholds in application code
-- ===========================================

CREATE TABLE IF NOT EXISTS system_settings (
    -- Primary key is the setting key itself for O(1) lookup
    setting_key         TEXT NOT NULL,

    -- Scope: NULL plant_id = org-wide default
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,

    PRIMARY KEY (setting_key, organization_id, COALESCE(plant_id, '00000000-0000-0000-0000-000000000000'::UUID)),

    -- Value (always stored as JSONB for type flexibility)
    value               JSONB NOT NULL,

    -- Metadata
    data_type           TEXT NOT NULL DEFAULT 'string'
                            CHECK (data_type IN ('string','integer','decimal','boolean','json','duration_seconds','percentage')),
    description         TEXT NOT NULL,
    category            TEXT NOT NULL DEFAULT 'general'
                            CHECK (category IN (
                                'general','compliance','training','assessment','notifications',
                                'security','performance','integrations','ui','archival'
                            )),

    -- Change control
    requires_esig       BOOLEAN NOT NULL DEFAULT FALSE,   -- Whether changing this setting requires e-sig
    last_changed_by     UUID REFERENCES employees(id) ON DELETE SET NULL,
    last_changed_at     TIMESTAMPTZ,
    change_reason       TEXT,

    -- Allowed range/values for validation
    min_value           JSONB,
    max_value           JSONB,
    allowed_values      JSONB,          -- JSON array of allowed values

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_settings_org      ON system_settings(organization_id);
CREATE INDEX IF NOT EXISTS idx_system_settings_category ON system_settings(category);
CREATE INDEX IF NOT EXISTS idx_system_settings_plant    ON system_settings(plant_id);

DROP TRIGGER IF EXISTS trg_system_settings_updated ON system_settings;
CREATE TRIGGER trg_system_settings_updated
    BEFORE UPDATE ON system_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_system_settings_audit ON system_settings;
CREATE TRIGGER trg_system_settings_audit
    AFTER INSERT OR UPDATE OR DELETE ON system_settings
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- HELPER FUNCTIONS
-- -------------------------------------------------------

-- Get a setting value (with plant-level override support)
CREATE OR REPLACE FUNCTION get_setting(
    p_key           TEXT,
    p_org_id        UUID,
    p_plant_id      UUID DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_value JSONB;
BEGIN
    -- Try plant-specific first
    IF p_plant_id IS NOT NULL THEN
        SELECT value INTO v_value
        FROM system_settings
        WHERE setting_key = p_key
          AND organization_id = p_org_id
          AND plant_id = p_plant_id
          AND is_active = TRUE;
    END IF;

    -- Fall back to org-wide
    IF v_value IS NULL THEN
        SELECT value INTO v_value
        FROM system_settings
        WHERE setting_key = p_key
          AND organization_id = p_org_id
          AND plant_id IS NULL
          AND is_active = TRUE;
    END IF;

    RETURN v_value;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Typed convenience wrappers
CREATE OR REPLACE FUNCTION get_setting_int(p_key TEXT, p_org_id UUID, p_plant_id UUID DEFAULT NULL)
RETURNS INTEGER AS $$
    SELECT (get_setting(p_key, p_org_id, p_plant_id))::INTEGER;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_setting_bool(p_key TEXT, p_org_id UUID, p_plant_id UUID DEFAULT NULL)
RETURNS BOOLEAN AS $$
    SELECT (get_setting(p_key, p_org_id, p_plant_id))::BOOLEAN;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION get_setting_text(p_key TEXT, p_org_id UUID, p_plant_id UUID DEFAULT NULL)
RETURNS TEXT AS $$
    SELECT (get_setting(p_key, p_org_id, p_plant_id))::TEXT;
$$ LANGUAGE SQL STABLE;

-- -------------------------------------------------------
-- SEED: GxP-appropriate defaults
-- All keys that were previously hardcoded in application logic live here.
-- -------------------------------------------------------
-- NOTE: organization_id will be replaced per-org on first setup.
-- This seed uses a placeholder org_id that the setup wizard replaces.
-- In a multi-tenant system, the setup migration creates one row per org.

-- Using a DO block so we can reference variables
DO $$
DECLARE
    v_placeholder_org UUID := '00000000-0000-0000-0000-000000000001'::UUID;
BEGIN
    -- Only seed if the placeholder org exists (skip on fresh multi-tenant installs)
    IF NOT EXISTS (SELECT 1 FROM organizations WHERE id = v_placeholder_org) THEN
        RETURN;
    END IF;

    INSERT INTO system_settings
        (setting_key, organization_id, value, data_type, description, category, requires_esig)
    VALUES
        -- Training
        ('training.remedial_deadline_days',      v_placeholder_org, '14',      'integer',  'Days to complete remedial training after failure', 'training', false),
        ('training.min_attendance_percent',      v_placeholder_org, '75',      'percentage', 'Minimum attendance % to be eligible for assessment', 'training', false),
        ('training.reminder_days_before_due',    v_placeholder_org, '7',       'integer',  'Days before due date to send training reminder', 'notifications', false),
        ('training.overdue_escalation_days',     v_placeholder_org, '3',       'integer',  'Days after due date before escalating to manager', 'training', false),
        ('training.max_assessment_attempts',     v_placeholder_org, '3',       'integer',  'Maximum attempts allowed per assessment', 'assessment', false),
        ('training.certificate_expiry_warn_days', v_placeholder_org,'30',      'integer',  'Days before certificate expiry to send warning', 'notifications', false),

        -- Compliance
        ('compliance.record_retention_years',    v_placeholder_org, '10',      'integer',  'GxP baseline record retention in years', 'compliance', true),
        ('compliance.allow_reprint_old_docs',    v_placeholder_org, 'false',   'boolean',  'Allow reprinting superseded document versions', 'compliance', true),
        ('compliance.induction_grace_days',      v_placeholder_org, '30',      'integer',  'Days after hire to complete induction training', 'compliance', false),

        -- Security
        ('security.session_timeout_seconds',     v_placeholder_org, '900',     'duration_seconds', 'Session idle timeout (default 15 min)', 'security', false),
        ('security.max_concurrent_sessions',     v_placeholder_org, '1',       'integer',  'Maximum concurrent sessions per user', 'security', true),
        ('security.require_mfa_for_esig',        v_placeholder_org, 'false',   'boolean',  'Require MFA confirmation before e-signing', 'security', true),
        ('security.password_reauth_window_min',  v_placeholder_org, '30',      'integer',  'Minutes of re-auth validity window for e-sig', 'security', false),

        -- Notifications
        ('notifications.email_enabled',          v_placeholder_org, 'true',    'boolean',  'Enable email notifications globally', 'notifications', false),
        ('notifications.from_address',           v_placeholder_org, '"noreply@pharmalearn.internal"', 'string', 'Sender email address', 'notifications', false),

        -- UI
        ('ui.date_format',                       v_placeholder_org, '"DD-MMM-YYYY"', 'string', 'Date display format (DD-MMM-YYYY for pharma)', 'ui', false),
        ('ui.timezone',                          v_placeholder_org, '"Asia/Kolkata"', 'string', 'Default timezone for the organization', 'ui', false),
        ('ui.items_per_page',                    v_placeholder_org, '25',      'integer',  'Default pagination size', 'ui', false)
    ON CONFLICT DO NOTHING;
END
$$;

COMMENT ON TABLE  system_settings IS 'Configurable KV store for all tunable system behaviors — replaces hardcoded constants (Alfa §3.1.46-47)';
COMMENT ON COLUMN system_settings.requires_esig IS 'When TRUE, changing this setting requires an electronic signature (for GxP critical settings)';
COMMENT ON COLUMN system_settings.category IS 'Logical grouping for settings UI display and filtering';
COMMENT ON FUNCTION get_setting IS 'Get a setting value with plant-override fallback to org-wide default';
