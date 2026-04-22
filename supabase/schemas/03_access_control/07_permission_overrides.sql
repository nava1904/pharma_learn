-- ===========================================
-- EMPLOYEE PERMISSION OVERRIDES
-- Direct permission grants/revocations beyond role-based permissions
-- ===========================================

-- -------------------------------------------------------
-- PERMISSION OVERRIDE TABLE
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS employee_permission_overrides (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    permission TEXT NOT NULL,
    granted BOOLEAN NOT NULL DEFAULT true,  -- true = grant, false = deny
    granted_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,                 -- NULL = permanent
    reason TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT uq_employee_permission UNIQUE (employee_id, permission)
);

CREATE INDEX IF NOT EXISTS idx_perm_override_employee ON employee_permission_overrides(employee_id);
CREATE INDEX IF NOT EXISTS idx_perm_override_active ON employee_permission_overrides(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_perm_override_expires ON employee_permission_overrides(expires_at) WHERE expires_at IS NOT NULL;

-- -------------------------------------------------------
-- FUNCTION: Get effective permissions for an employee
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_employee_effective_permissions(p_employee_id UUID)
RETURNS TABLE (
    permission TEXT,
    source TEXT,
    granted BOOLEAN
) AS $$
BEGIN
    -- Return all permissions with their sources
    RETURN QUERY
    
    -- Permissions from roles via global profiles
    SELECT DISTINCT
        p.permission::TEXT,
        'role:' || r.name AS source,
        true AS granted
    FROM employee_roles er
    JOIN roles r ON r.id = er.role_id
    JOIN global_profiles gp ON gp.id = r.global_profile_id
    CROSS JOIN LATERAL jsonb_array_elements_text(gp.permissions) AS p(permission)
    WHERE er.employee_id = p_employee_id
      AND (er.effective_to IS NULL OR er.effective_to > NOW())
    
    UNION ALL
    
    -- Direct overrides (will override role permissions in application logic)
    SELECT
        epo.permission,
        CASE WHEN epo.granted THEN 'direct_grant' ELSE 'direct_deny' END AS source,
        epo.granted
    FROM employee_permission_overrides epo
    WHERE epo.employee_id = p_employee_id
      AND epo.is_active = true
      AND (epo.expires_at IS NULL OR epo.expires_at > NOW());
END;
$$ LANGUAGE plpgsql STABLE;

-- -------------------------------------------------------
-- FUNCTION: Check if employee has a specific permission
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION employee_has_permission(p_employee_id UUID, p_permission TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_has_direct_denial BOOLEAN;
    v_has_direct_grant BOOLEAN;
    v_has_role_grant BOOLEAN;
BEGIN
    -- Check for direct denial first (highest priority)
    SELECT EXISTS (
        SELECT 1 FROM employee_permission_overrides
        WHERE employee_id = p_employee_id
          AND permission = p_permission
          AND granted = false
          AND is_active = true
          AND (expires_at IS NULL OR expires_at > NOW())
    ) INTO v_has_direct_denial;
    
    IF v_has_direct_denial THEN
        RETURN false;
    END IF;
    
    -- Check for direct grant
    SELECT EXISTS (
        SELECT 1 FROM employee_permission_overrides
        WHERE employee_id = p_employee_id
          AND permission = p_permission
          AND granted = true
          AND is_active = true
          AND (expires_at IS NULL OR expires_at > NOW())
    ) INTO v_has_direct_grant;
    
    IF v_has_direct_grant THEN
        RETURN true;
    END IF;
    
    -- Check role-based permissions
    SELECT EXISTS (
        SELECT 1
        FROM employee_roles er
        JOIN roles r ON r.id = er.role_id
        JOIN global_profiles gp ON gp.id = r.global_profile_id
        WHERE er.employee_id = p_employee_id
          AND (er.effective_to IS NULL OR er.effective_to > NOW())
          AND gp.permissions ? p_permission
    ) INTO v_has_role_grant;
    
    RETURN v_has_role_grant;
END;
$$ LANGUAGE plpgsql STABLE;

-- -------------------------------------------------------
-- TRIGGER: Auto-expire permissions
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION expire_employee_permissions()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE employee_permission_overrides
    SET is_active = false,
        updated_at = NOW()
    WHERE expires_at IS NOT NULL
      AND expires_at <= NOW()
      AND is_active = true;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Run periodically via pg_cron or background job
-- CREATE EXTENSION IF NOT EXISTS pg_cron;
-- SELECT cron.schedule('expire-permissions', '0 * * * *', 'SELECT expire_employee_permissions()');

COMMENT ON TABLE employee_permission_overrides IS 'Direct permission grants or denials for specific employees, overriding role-based permissions';
COMMENT ON FUNCTION get_employee_effective_permissions IS 'Returns all permissions for an employee with their sources (role or direct)';
COMMENT ON FUNCTION employee_has_permission IS 'Checks if an employee has a specific permission, considering role and direct overrides';
