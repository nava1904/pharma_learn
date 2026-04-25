-- ===========================================
-- BEHAVIORAL CONTROLS
-- GAP 1: Configurable enforcement layer for pharma compliance rules
-- ===========================================
-- This file runs AFTER system_settings table is created (16_infrastructure/01_system_config.sql)
-- The helper functions use EXCEPTION WHEN OTHERS so they work safely even if called
-- before system_settings is populated (returns safe defaults)
-- ===========================================

-- Master registry of known behavioral control keys
CREATE TABLE IF NOT EXISTS behavioral_control_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    control_key TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL,
    description TEXT NOT NULL,
    data_type TEXT NOT NULL DEFAULT 'boolean' CHECK (data_type IN ('boolean', 'integer', 'text')),
    default_value TEXT NOT NULL,
    category TEXT NOT NULL DEFAULT 'compliance',
    is_required BOOLEAN NOT NULL DEFAULT false,      -- must be explicitly set per org
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed control definitions
INSERT INTO behavioral_control_definitions
    (control_key, display_name, description, data_type, default_value, category, is_required)
VALUES
    ('allow_reprint_old_docs',
     'Allow Reprint of Superseded Documents',
     'When false, reprinting a superseded or obsolete document version raises an error',
     'boolean', 'false', 'compliance', false),

    ('mandatory_remarks_on_approval',
     'Mandatory Remarks on Approval',
     'Requires approvers to enter a reason/remark before approving any pending approval',
     'boolean', 'true', 'compliance', true),

    ('etd_required',
     'ETD Required for Workflow Phases',
     'When true, every workflow phase must have a target completion date (ETD)',
     'boolean', 'true', 'compliance', false),

    ('mandatory_reason_on_status_change',
     'Mandatory Reason on Status Change',
     'Requires a reason (via app.current_action_reason) for any status field change audited by track_entity_changes()',
     'boolean', 'true', 'compliance', true),

    ('esig_reauth_validity_minutes',
     'E-Signature Re-Auth Validity (minutes)',
     '21 CFR Part 11: how long a re-auth session token is valid before expiry (max 15 per FDA guidance)',
     'integer', '15', 'compliance', false),

    ('max_rejection_loops',
     'Maximum Workflow Rejection Loops',
     'Maximum number of times a workflow instance can be returned and re-initiated before being dropped',
     'integer', '3', 'compliance', false),

    ('controlled_copy_required',
     'Controlled Copy Issuance Required',
     'Requires documents to be formally issued as controlled copies before distribution',
     'boolean', 'true', 'compliance', false),

    ('training_trigger_auto_assign',
     'Auto-Assign Training from Events',
     'When true, training trigger rules automatically create employee_assignments on qualifying events',
     'boolean', 'true', 'compliance', false)

ON CONFLICT (control_key) DO NOTHING;

-- Seed global system_settings defaults (org_id NULL = applies to all orgs unless overridden)
INSERT INTO system_settings
    (organization_id, setting_category, setting_key, setting_value, data_type, description, is_system)
SELECT
    NULL,
    bcd.category,
    bcd.control_key,
    to_jsonb(bcd.default_value),
    bcd.data_type,
    bcd.description,
    true
FROM behavioral_control_definitions bcd
ON CONFLICT (organization_id, setting_category, setting_key) DO NOTHING;

-- -------------------------------------------------------
-- HELPER FUNCTIONS
-- -------------------------------------------------------
-- Both functions use EXCEPTION WHEN OTHERS to return safe defaults
-- if system_settings is not yet populated (graceful during migration)

-- Read a boolean setting for an org; org-specific overrides global (NULL) default
CREATE OR REPLACE FUNCTION get_setting_bool(
    p_org_id UUID,
    p_key TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_val JSONB;
BEGIN
    -- Try org-specific first, then global fallback
    SELECT setting_value INTO v_val
    FROM system_settings
    WHERE setting_key = p_key
      AND (organization_id = p_org_id OR organization_id IS NULL)
    ORDER BY organization_id NULLS LAST
    LIMIT 1;

    RETURN COALESCE((v_val #>> '{}')::BOOLEAN, false);
EXCEPTION WHEN OTHERS THEN
    -- Safe default during schema bootstrap or if table doesn't exist yet
    RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Read a text setting for an org (includes integers, text)
CREATE OR REPLACE FUNCTION get_setting_text(
    p_org_id UUID,
    p_key TEXT
) RETURNS TEXT AS $$
DECLARE
    v_val JSONB;
BEGIN
    SELECT setting_value INTO v_val
    FROM system_settings
    WHERE setting_key = p_key
      AND (organization_id = p_org_id OR organization_id IS NULL)
    ORDER BY organization_id NULLS LAST
    LIMIT 1;

    RETURN v_val #>> '{}';
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Convenience: upsert a behavioral control for a specific org
CREATE OR REPLACE FUNCTION set_org_behavioral_control(
    p_org_id UUID,
    p_key TEXT,
    p_value TEXT
) RETURNS VOID AS $$
DECLARE
    v_def behavioral_control_definitions%ROWTYPE;
BEGIN
    SELECT * INTO v_def FROM behavioral_control_definitions WHERE control_key = p_key;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Unknown behavioral control key: %', p_key;
    END IF;

    INSERT INTO system_settings (organization_id, setting_category, setting_key, setting_value, data_type, is_system)
    VALUES (p_org_id, v_def.category, p_key, to_jsonb(p_value), v_def.data_type, false)
    ON CONFLICT (organization_id, setting_category, setting_key)
    DO UPDATE SET setting_value = to_jsonb(p_value), updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE behavioral_control_definitions IS 'Registry of configurable pharma compliance behavior controls';
COMMENT ON FUNCTION get_setting_bool IS 'Read a boolean behavioral control; org-specific value wins over global default. Returns false on error (safe for schema bootstrap).';
COMMENT ON FUNCTION get_setting_text IS 'Read any behavioral control as text; org-specific value wins over global default.';
COMMENT ON FUNCTION set_org_behavioral_control IS 'Upsert an org-specific behavioral control override';
