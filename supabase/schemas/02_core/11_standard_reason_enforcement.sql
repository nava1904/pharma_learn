-- ===========================================
-- STANDARD REASONS ENFORCEMENT — FK ADDITIONS
-- M-03: Wire standard_reasons as enforced FK
-- Ensures all workflow/approval actions reference the approved reason bank
-- ===========================================

-- Add standard_reason_id FK to approval_history
ALTER TABLE approval_history
    ADD COLUMN IF NOT EXISTS standard_reason_id UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_approval_history_reason ON approval_history(standard_reason_id) WHERE standard_reason_id IS NOT NULL;

COMMENT ON COLUMN approval_history.standard_reason_id IS 'M-03: FK to standard_reasons bank — preferred over free-text comments';

-- Add standard_reason_id FK to workflow_history
ALTER TABLE workflow_history
    ADD COLUMN IF NOT EXISTS standard_reason_id UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_workflow_history_reason ON workflow_history(standard_reason_id) WHERE standard_reason_id IS NOT NULL;

COMMENT ON COLUMN workflow_history.standard_reason_id IS 'M-03: FK to standard_reasons bank — preferred over free-text reason';

-- Add standard_reason_id FK to revision_history (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'revision_history'
    ) THEN
        ALTER TABLE revision_history
            ADD COLUMN IF NOT EXISTS standard_reason_id UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;
        
        CREATE INDEX IF NOT EXISTS idx_revision_history_reason ON revision_history(standard_reason_id) WHERE standard_reason_id IS NOT NULL;
    END IF;
END
$$;

-- Add standard_reason_id FK to waiver_approval_history
ALTER TABLE waiver_approval_history
    ADD COLUMN IF NOT EXISTS standard_reason_id UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_waiver_history_reason ON waiver_approval_history(standard_reason_id) WHERE standard_reason_id IS NOT NULL;

COMMENT ON COLUMN waiver_approval_history.standard_reason_id IS 'M-03: FK to standard_reasons bank for waiver decisions';

-- Add standard_reason_id FK to phase_extensions (if it exists)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'phase_extensions'
    ) THEN
        ALTER TABLE phase_extensions
            ADD COLUMN IF NOT EXISTS standard_reason_id UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;
        
        CREATE INDEX IF NOT EXISTS idx_phase_ext_reason ON phase_extensions(standard_reason_id) WHERE standard_reason_id IS NOT NULL;
    END IF;
END
$$;

-- -------------------------------------------------------
-- Function to validate reason enforcement
-- Returns TRUE if the action type requires a standard reason
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION requires_standard_reason(
    p_action TEXT,
    p_entity_type TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_requires BOOLEAN;
BEGIN
    -- Check standard_reasons table for matching reason category
    SELECT EXISTS (
        SELECT 1 FROM standard_reasons
        WHERE reason_category = p_action
          AND is_active = TRUE
          AND (applies_to_entities IS NULL OR p_entity_type = ANY(applies_to_entities))
    ) INTO v_requires;
    
    -- Always require reason for these critical actions
    IF p_action IN ('returned', 'dropped', 'rejected', 'revoked', 'waived', 'extended', 'escalated') THEN
        RETURN TRUE;
    END IF;
    
    RETURN v_requires;
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON FUNCTION requires_standard_reason IS 'Check if an action type mandates a standard reason selection';

-- -------------------------------------------------------
-- Add reason category validation CHECK to standard_reasons (idempotent)
-- -------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'standard_reasons_category_check'
          AND constraint_schema = 'public'
    ) THEN
        ALTER TABLE standard_reasons
            ADD CONSTRAINT standard_reasons_category_check
            CHECK (reason_category IN (
                'approved', 'returned', 'dropped', 'rejected', 'revoked',
                'waived', 'extended', 'escalated', 'modified', 'created',
                'deactivated', 'reactivated', 'delegated', 'transferred',
                'postdated', 'other'
            ));
    END IF;
END
$$;

-- -------------------------------------------------------
-- SEED: Additional standard reasons for new categories
-- -------------------------------------------------------
INSERT INTO standard_reasons
    (reason_code, reason_text, reason_category, is_active, display_order, organization_id)
SELECT reason_code, reason_text, reason_category, TRUE, display_order, NULL
FROM (VALUES
    ('ESCLTN_OVERDUE', 'Escalated due to overdue response', 'escalated', 10),
    ('ESCLTN_URGENT', 'Escalated due to urgent priority', 'escalated', 20),
    ('ESCLTN_CRITICAL', 'Escalated due to critical finding', 'escalated', 30),
    ('PSTDT_LATE_ENTRY', 'Training completed but entry delayed', 'postdated', 10),
    ('PSTDT_SYS_DOWN', 'System unavailable at time of completion', 'postdated', 20),
    ('PSTDT_ADMIN_CORR', 'Administrative correction', 'postdated', 30),
    ('DELEG_LEAVE', 'Delegated due to planned leave', 'delegated', 10),
    ('DELEG_WORKLOAD', 'Delegated due to workload balancing', 'delegated', 20),
    ('DELEG_EXPERTISE', 'Delegated to subject matter expert', 'delegated', 30),
    ('TRANS_ROLE_CHANGE', 'Transferred due to role change', 'transferred', 10),
    ('TRANS_DEPT_MOVE', 'Transferred due to department move', 'transferred', 20),
    ('REACT_ERROR_FIX', 'Reactivated to correct error', 'reactivated', 10),
    ('REACT_AUDIT_REQ', 'Reactivated per audit requirement', 'reactivated', 20)
) AS v(reason_code, reason_text, reason_category, display_order)
WHERE NOT EXISTS (
    SELECT 1 FROM standard_reasons sr WHERE sr.reason_code = v.reason_code
);
