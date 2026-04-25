-- ===========================================
-- RLS POLICIES FOR CONFIG MODULE
-- Phase 2: Configurability layer security
-- ===========================================

-- -------------------------------------------------------
-- HELPER: Check if user has config management permission
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION can_manage_config()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM employee_roles er
        JOIN roles r ON er.role_id = r.id
        JOIN employees e ON er.employee_id = e.id
        WHERE e.auth_user_id = auth.uid()
          AND r.is_active = TRUE
          AND (r.is_admin_role = TRUE OR r.name IN ('System Administrator', 'QA Manager', 'IT Admin'))
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- -------------------------------------------------------
-- RETENTION POLICIES
-- -------------------------------------------------------
ALTER TABLE retention_policies ENABLE ROW LEVEL SECURITY;

CREATE POLICY retention_policies_select ON retention_policies
    FOR SELECT USING (
        organization_id IS NULL  -- Global policies visible to all
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY retention_policies_insert ON retention_policies
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY retention_policies_update ON retention_policies
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

CREATE POLICY retention_policies_delete ON retention_policies
    FOR DELETE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- NUMBERING SCHEMES
-- -------------------------------------------------------
ALTER TABLE numbering_schemes ENABLE ROW LEVEL SECURITY;

CREATE POLICY numbering_schemes_select ON numbering_schemes
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY numbering_schemes_insert ON numbering_schemes
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY numbering_schemes_update ON numbering_schemes
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- APPROVAL MATRICES
-- -------------------------------------------------------
ALTER TABLE approval_matrices ENABLE ROW LEVEL SECURITY;

CREATE POLICY approval_matrices_select ON approval_matrices
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY approval_matrices_insert ON approval_matrices
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY approval_matrices_update ON approval_matrices
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- PASSWORD POLICIES
-- -------------------------------------------------------
ALTER TABLE password_policies ENABLE ROW LEVEL SECURITY;

CREATE POLICY password_policies_select ON password_policies
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY password_policies_insert ON password_policies
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY password_policies_update ON password_policies
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- VALIDATION RULES
-- -------------------------------------------------------
ALTER TABLE validation_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY validation_rules_select ON validation_rules
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY validation_rules_insert ON validation_rules
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY validation_rules_update ON validation_rules
    FOR UPDATE USING (
        organization_id = get_user_organization_id()
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- SYSTEM SETTINGS
-- -------------------------------------------------------
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY system_settings_select ON system_settings
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY system_settings_insert ON system_settings
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY system_settings_update ON system_settings
    FOR UPDATE USING (
        (organization_id IS NULL OR organization_id = get_user_organization_id())
        AND can_manage_config()
    );

-- -------------------------------------------------------
-- FEATURE FLAGS
-- -------------------------------------------------------
ALTER TABLE feature_flags ENABLE ROW LEVEL SECURITY;

CREATE POLICY feature_flags_select ON feature_flags
    FOR SELECT USING (TRUE);  -- All users can see feature flags

CREATE POLICY feature_flags_insert ON feature_flags
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY feature_flags_update ON feature_flags
    FOR UPDATE USING (can_manage_config());

-- -------------------------------------------------------
-- TENANT FEATURE FLAGS
-- -------------------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'tenant_feature_flags') THEN
        ALTER TABLE tenant_feature_flags ENABLE ROW LEVEL SECURITY;
        
        CREATE POLICY tenant_feature_flags_select ON tenant_feature_flags
            FOR SELECT USING (
                organization_id = get_user_organization_id()
                OR plant_id IN (SELECT id FROM plants WHERE organization_id = get_user_organization_id())
            );

        CREATE POLICY tenant_feature_flags_insert ON tenant_feature_flags
            FOR INSERT WITH CHECK (can_manage_config());

        CREATE POLICY tenant_feature_flags_update ON tenant_feature_flags
            FOR UPDATE USING (can_manage_config());
    END IF;
END
$$;

-- -------------------------------------------------------
-- MAIL SETTINGS
-- -------------------------------------------------------
ALTER TABLE mail_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY mail_settings_select ON mail_settings
    FOR SELECT USING (
        organization_id IS NULL
        OR organization_id = get_user_organization_id()
    );

CREATE POLICY mail_settings_insert ON mail_settings
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY mail_settings_update ON mail_settings
    FOR UPDATE USING (can_manage_config());

-- -------------------------------------------------------
-- TIME ZONE REGISTRY
-- -------------------------------------------------------
ALTER TABLE time_zone_registry ENABLE ROW LEVEL SECURITY;

CREATE POLICY time_zone_registry_select ON time_zone_registry
    FOR SELECT USING (TRUE);  -- All users can see time zones

CREATE POLICY time_zone_registry_insert ON time_zone_registry
    FOR INSERT WITH CHECK (can_manage_config());

CREATE POLICY time_zone_registry_update ON time_zone_registry
    FOR UPDATE USING (can_manage_config());

COMMENT ON FUNCTION can_manage_config IS 'Check if current user has permission to manage system configuration';
