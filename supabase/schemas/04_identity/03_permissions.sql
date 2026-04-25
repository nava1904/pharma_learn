-- ===========================================
-- PERMISSIONS TABLE
-- RBAC: Role → Module → Action matrix
-- ===========================================

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    
    -- Permission scope
    module TEXT NOT NULL,
    sub_module TEXT,
    action TEXT NOT NULL,
    
    -- Permission value
    is_allowed BOOLEAN DEFAULT true,
    
    -- Constraints (optional)
    max_approval_level NUMERIC(5,2), -- Can only approve up to this level
    plant_restriction UUID[], -- If set, only these plants
    
    -- Metadata
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint
    UNIQUE(role_id, module, COALESCE(sub_module, ''), action)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_permissions_role ON permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_permissions_module ON permissions(module);
CREATE INDEX IF NOT EXISTS idx_permissions_action ON permissions(action);

-- Module constants for reference
COMMENT ON TABLE permissions IS 'RBAC permissions: role → module → action mapping';

-- Learn-IQ Modules:
-- system_manager: Roles, Standard Reasons, Global Profile, Bio Metrics
-- user_manager: User Groups, Subgroups, Groups, Job Responsibility
-- document_manager: Document Categories, Documents, Document Versions
-- course_manager: Categories, Subjects, Topics, Courses, Trainers, Venues
-- training_manager: GTP, Schedules, Sessions, Batches, Attendance
-- assessment_manager: Question Banks, Questions, Papers, Evaluations
-- compliance_manager: Training Records, Certificates, Assignments, Matrix
-- analytics: Dashboards, Reports, Compliance Monitoring
-- notifications: Mail Templates, Notifications

-- Standard Actions:
-- view, create, edit, delete, initiate, approve, activate, deactivate
-- export, print, import, assign, schedule, evaluate

-- Function to check permission
CREATE OR REPLACE FUNCTION has_permission(
    p_user_id UUID,
    p_module TEXT,
    p_action TEXT,
    p_sub_module TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_allowed BOOLEAN;
BEGIN
    SELECT COALESCE(bool_or(p.is_allowed), false) INTO v_allowed
    FROM permissions p
    JOIN employee_roles er ON er.role_id = p.role_id
    JOIN roles r ON r.id = er.role_id AND r.is_active = true
    WHERE er.employee_id = p_user_id
      AND p.module = p_module
      AND p.action = p_action
      AND (p_sub_module IS NULL OR p.sub_module IS NULL OR p.sub_module = p_sub_module);
    
    RETURN v_allowed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all permissions for a user
CREATE OR REPLACE FUNCTION get_user_permissions(p_user_id UUID)
RETURNS TABLE (
    module TEXT,
    sub_module TEXT,
    action TEXT,
    is_allowed BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT
        p.module,
        p.sub_module,
        p.action,
        bool_or(p.is_allowed) as is_allowed
    FROM permissions p
    JOIN employee_roles er ON er.role_id = p.role_id
    JOIN roles r ON r.id = er.role_id AND r.is_active = true
    WHERE er.employee_id = p_user_id
    GROUP BY p.module, p.sub_module, p.action;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
