-- ===========================================
-- SUBGROUPS TABLE
-- Learn-IQ User Groups (functional role groupings)
-- Used for training assignment and job responsibility
-- ===========================================

CREATE TABLE IF NOT EXISTS subgroups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Job responsibility template (Learn-IQ feature)
    -- Auto-fill template when creating job responsibility for employees in this subgroup
    job_responsibility_template TEXT,
    
    -- Training defaults
    default_training_types training_type[],
    mandatory_courses UUID[], -- Default mandatory courses for this subgroup
    
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
CREATE INDEX IF NOT EXISTS idx_subgroups_org ON subgroups(organization_id);
CREATE INDEX IF NOT EXISTS idx_subgroups_status ON subgroups(status);
CREATE INDEX IF NOT EXISTS idx_subgroups_active ON subgroups(is_active) WHERE is_active = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_subgroups_revision ON subgroups;
CREATE TRIGGER trg_subgroups_revision
    BEFORE UPDATE ON subgroups
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_subgroups_audit ON subgroups;
CREATE TRIGGER trg_subgroups_audit
    AFTER INSERT OR UPDATE OR DELETE ON subgroups
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_subgroups_created ON subgroups;
CREATE TRIGGER trg_subgroups_created
    BEFORE INSERT ON subgroups
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

COMMENT ON TABLE subgroups IS 'Learn-IQ subgroups: functional role groupings for training assignments';
COMMENT ON COLUMN subgroups.job_responsibility_template IS 'Auto-fill template for job responsibility document';
