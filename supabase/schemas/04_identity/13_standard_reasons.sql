-- ===========================================
-- STANDARD REASONS TABLE
-- Pre-defined reasons for audit trail standardization
-- Learn-IQ: Prevents inconsistent manual notes
-- ===========================================

CREATE TABLE IF NOT EXISTS standard_reasons (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    reason TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Applicability
    applicable_actions TEXT[] DEFAULT '{}', -- ['approve', 'return', 'drop', 'modify', 'deactivate', etc.]
    applicable_modules TEXT[] DEFAULT '{}', -- ['course_manager', 'document_manager', 'training_manager', etc.]
    applicable_entities TEXT[] DEFAULT '{}', -- ['course', 'document', 'session', etc.]
    
    -- Categorization
    category TEXT, -- 'modification', 'cancellation', 'rejection', 'correction', 'compliance', etc.
    
    -- Behavior
    requires_additional_text BOOLEAN DEFAULT false, -- Require additional free text explanation
    is_mandatory_selection BOOLEAN DEFAULT false, -- Must select a standard reason
    
    -- Display
    display_order INTEGER DEFAULT 0,
    
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
CREATE INDEX IF NOT EXISTS idx_standard_reasons_org ON standard_reasons(organization_id);
CREATE INDEX IF NOT EXISTS idx_standard_reasons_status ON standard_reasons(status);
CREATE INDEX IF NOT EXISTS idx_standard_reasons_active ON standard_reasons(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_standard_reasons_actions ON standard_reasons USING GIN(applicable_actions);
CREATE INDEX IF NOT EXISTS idx_standard_reasons_modules ON standard_reasons USING GIN(applicable_modules);

-- Triggers
DROP TRIGGER IF EXISTS trg_standard_reasons_revision ON standard_reasons;
CREATE TRIGGER trg_standard_reasons_revision
    BEFORE UPDATE ON standard_reasons
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_standard_reasons_audit ON standard_reasons;
CREATE TRIGGER trg_standard_reasons_audit
    AFTER INSERT OR UPDATE OR DELETE ON standard_reasons
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_standard_reasons_created ON standard_reasons;
CREATE TRIGGER trg_standard_reasons_created
    BEFORE INSERT ON standard_reasons
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Function to get applicable reasons
CREATE OR REPLACE FUNCTION get_applicable_reasons(
    p_org_id UUID,
    p_action TEXT DEFAULT NULL,
    p_module TEXT DEFAULT NULL,
    p_entity TEXT DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    reason TEXT,
    unique_code TEXT,
    category TEXT,
    requires_additional_text BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sr.id,
        sr.reason,
        sr.unique_code,
        sr.category,
        sr.requires_additional_text
    FROM standard_reasons sr
    WHERE sr.organization_id = p_org_id
      AND sr.is_active = true
      AND sr.status = 'active'
      AND (p_action IS NULL OR p_action = ANY(sr.applicable_actions) OR array_length(sr.applicable_actions, 1) IS NULL)
      AND (p_module IS NULL OR p_module = ANY(sr.applicable_modules) OR array_length(sr.applicable_modules, 1) IS NULL)
      AND (p_entity IS NULL OR p_entity = ANY(sr.applicable_entities) OR array_length(sr.applicable_entities, 1) IS NULL)
    ORDER BY sr.display_order, sr.reason;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE standard_reasons IS 'Learn-IQ: Pre-defined reasons for standardized audit documentation';
COMMENT ON COLUMN standard_reasons.applicable_actions IS 'Actions this reason can be used for (approve, return, drop, modify, etc.)';
