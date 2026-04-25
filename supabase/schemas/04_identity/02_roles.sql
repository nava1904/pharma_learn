-- ===========================================
-- ROLES TABLE
-- User roles with hierarchical levels
-- Learn-IQ: Level 1 = highest seniority, 99.99 = lowest
-- CRITICAL: Approval flow - lower level number can approve higher level number
-- ===========================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name TEXT NOT NULL,
    display_name TEXT,
    description TEXT,
    
    -- Learn-IQ Level System (1-99.99)
    -- CRITICAL: Lower number = Higher authority
    -- Level 1 = Top Authority (e.g., CEO, Plant Head)
    -- Level 99.99 = Lowest (e.g., Trainee)
    level NUMERIC(5,2) NOT NULL CHECK (level >= 1 AND level <= 99.99),
    
    -- Category (login vs non-login)
    category role_category NOT NULL DEFAULT 'login',
    role_category_id UUID REFERENCES role_categories(id),
    
    -- Permissions scope
    is_global BOOLEAN DEFAULT false, -- Can access all plants
    can_approve BOOLEAN DEFAULT false, -- Can participate in approval workflows
    can_initiate BOOLEAN DEFAULT true,  -- Can initiate workflows (default true for non-viewer roles)
    max_approval_level NUMERIC(5,2), -- Can approve up to this level (legacy; use approval_matrices going forward)

    -- Explicit approval tier (DS-03 fix — replaces the fragile inverted NUMERIC level convention)
    -- Lower = higher authority. Use this for approval routing in approval_matrices (Phase 2).
    -- Range: 1 (top authority — e.g., Plant Head) to 99 (lowest — e.g., Trainee)
    approval_tier INTEGER NOT NULL DEFAULT 50 CHECK (approval_tier BETWEEN 1 AND 99),

    -- System role flags
    is_system_role BOOLEAN DEFAULT false, -- Cannot be deleted
    is_admin_role BOOLEAN DEFAULT false, -- Has admin privileges
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    UNIQUE(organization_id, name)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_roles_org ON roles(organization_id);
CREATE INDEX IF NOT EXISTS idx_roles_level ON roles(level);
CREATE INDEX IF NOT EXISTS idx_roles_category ON roles(category);
CREATE INDEX IF NOT EXISTS idx_roles_status ON roles(status);
CREATE INDEX IF NOT EXISTS idx_roles_active ON roles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_roles_can_approve ON roles(can_approve) WHERE can_approve = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_roles_revision ON roles;
CREATE TRIGGER trg_roles_revision
    BEFORE UPDATE ON roles
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_roles_audit ON roles;
CREATE TRIGGER trg_roles_audit
    AFTER INSERT OR UPDATE OR DELETE ON roles
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_roles_created ON roles;
CREATE TRIGGER trg_roles_created
    BEFORE INSERT ON roles
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Function to get roles that can approve a given level
CREATE OR REPLACE FUNCTION get_approver_roles(
    p_org_id UUID,
    p_initiator_level NUMERIC
) RETURNS TABLE (
    role_id UUID,
    role_name TEXT,
    role_level NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.name, r.level
    FROM roles r
    WHERE r.organization_id = p_org_id
      AND r.is_active = true
      AND r.can_approve = true
      AND r.level < p_initiator_level  -- LOWER level = HIGHER authority
    ORDER BY r.level;
END;
$$ LANGUAGE plpgsql;

-- Function to check if a role level can approve another
CREATE OR REPLACE FUNCTION can_level_approve(
    p_approver_level NUMERIC,
    p_initiator_level NUMERIC
) RETURNS BOOLEAN AS $$
BEGIN
    -- Learn-IQ Rule: Approver must have LOWER level number (higher authority)
    RETURN p_approver_level < p_initiator_level;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON TABLE  roles IS 'User roles with hierarchical levels (Learn-IQ: 1=highest, 99.99=lowest)';
COMMENT ON COLUMN roles.level IS 'Learn-IQ seniority: Level 1=Top Authority, 99.99=Lowest. Legacy; use approval_tier going forward.';
COMMENT ON COLUMN roles.approval_tier IS 'DS-03 fix: explicit 1-99 tier. 1=highest authority (Plant Head). Used by approval_matrices.';
COMMENT ON COLUMN roles.can_approve IS 'If true, role can participate in approval workflows';
COMMENT ON COLUMN roles.can_initiate IS 'If true, role can initiate/submit documents and workflows';
COMMENT ON COLUMN roles.max_approval_level IS 'Legacy: can approve requests from users with level >= this value. Use approval_matrices instead.';

-- -------------------------------------------------------
-- ALTER: idempotent column additions for existing databases
-- -------------------------------------------------------
ALTER TABLE roles ADD COLUMN IF NOT EXISTS can_initiate  BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE roles ADD COLUMN IF NOT EXISTS approval_tier INTEGER NOT NULL DEFAULT 50;

-- Add CHECK constraint on approval_tier (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'roles_approval_tier_check'
          AND constraint_schema = 'public'
    ) THEN
        ALTER TABLE roles ADD CONSTRAINT roles_approval_tier_check
            CHECK (approval_tier BETWEEN 1 AND 99);
    END IF;
END
$$;

-- Index for approval routing queries
CREATE INDEX IF NOT EXISTS idx_roles_approval_tier ON roles(approval_tier);
CREATE INDEX IF NOT EXISTS idx_roles_can_initiate  ON roles(can_initiate) WHERE can_initiate = true;
