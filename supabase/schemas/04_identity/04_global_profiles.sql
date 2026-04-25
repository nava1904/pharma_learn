-- ===========================================
-- GLOBAL PROFILES TABLE
-- Role-level comprehensive permissions (Learn-IQ)
-- Stores full module/action matrix per role
-- ===========================================

CREATE TABLE IF NOT EXISTS global_profiles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    
    -- Profile name (optional, usually matches role name)
    name TEXT,
    description TEXT,
    
    -- Full permissions matrix as JSON
    -- Structure: { "module_name": { "sub_module": { "action": true/false } } }
    permissions_json JSONB NOT NULL DEFAULT '{}',
    
    -- Quick access flags
    has_admin_access BOOLEAN DEFAULT false,
    has_approval_access BOOLEAN DEFAULT false,
    has_report_access BOOLEAN DEFAULT false,
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Only one active profile per role
    UNIQUE(organization_id, role_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_global_profiles_org ON global_profiles(organization_id);
CREATE INDEX IF NOT EXISTS idx_global_profiles_role ON global_profiles(role_id);
CREATE INDEX IF NOT EXISTS idx_global_profiles_status ON global_profiles(status);

-- Triggers
DROP TRIGGER IF EXISTS trg_global_profiles_revision ON global_profiles;
CREATE TRIGGER trg_global_profiles_revision
    BEFORE UPDATE ON global_profiles
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_global_profiles_audit ON global_profiles;
CREATE TRIGGER trg_global_profiles_audit
    AFTER INSERT OR UPDATE OR DELETE ON global_profiles
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Function to check permission from global profile
CREATE OR REPLACE FUNCTION check_global_profile_permission(
    p_role_id UUID,
    p_module TEXT,
    p_action TEXT,
    p_sub_module TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_permissions JSONB;
    v_result BOOLEAN;
BEGIN
    SELECT permissions_json INTO v_permissions
    FROM global_profiles
    WHERE role_id = p_role_id
      AND is_active = true
      AND status = 'active';
    
    IF v_permissions IS NULL THEN
        RETURN false;
    END IF;
    
    -- Navigate JSON structure
    IF p_sub_module IS NOT NULL THEN
        v_result := (v_permissions->p_module->p_sub_module->>p_action)::BOOLEAN;
    ELSE
        v_result := (v_permissions->p_module->>p_action)::BOOLEAN;
    END IF;
    
    RETURN COALESCE(v_result, false);
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE global_profiles IS 'Learn-IQ Global Profile: Role-level comprehensive permissions matrix';
COMMENT ON COLUMN global_profiles.permissions_json IS 'Full module/action permission matrix as JSON';
