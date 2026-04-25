-- ===========================================
-- GROUPS TABLE
-- Groups composed of multiple subgroups
-- Used for Group Training Plans (GTP)
-- ===========================================

CREATE TABLE IF NOT EXISTS groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
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
    UNIQUE(organization_id, unique_code)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_groups_org ON groups(organization_id);
CREATE INDEX IF NOT EXISTS idx_groups_status ON groups(status);
CREATE INDEX IF NOT EXISTS idx_groups_active ON groups(is_active) WHERE is_active = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_groups_revision ON groups;
CREATE TRIGGER trg_groups_revision
    BEFORE UPDATE ON groups
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_groups_audit ON groups;
CREATE TRIGGER trg_groups_audit
    AFTER INSERT OR UPDATE OR DELETE ON groups
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_groups_created ON groups;
CREATE TRIGGER trg_groups_created
    BEFORE INSERT ON groups
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

COMMENT ON TABLE groups IS 'Learn-IQ groups: collections of subgroups for Group Training Plans';
