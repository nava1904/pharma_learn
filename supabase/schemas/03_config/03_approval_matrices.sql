-- ===========================================
-- APPROVAL MATRICES
-- Configurable multi-level approval workflows
-- Alfa URS §4.3.4: "number of approval levels shall be configurable per transaction type"
-- Alfa URS §4.2.1.25: approval routing for GTP, documents, sessions
-- ===========================================

-- -------------------------------------------------------
-- APPROVAL MATRICES — one per entity_type per scope
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS approval_matrices (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What entity type this matrix governs
    entity_type         TEXT NOT NULL,   -- 'document', 'training_record', 'training_session', 'gtp', etc.

    -- Optional sub-type (e.g. entity_type='document', entity_subtype='SOP')
    entity_subtype      TEXT,

    -- Routing mode
    is_serial           BOOLEAN NOT NULL DEFAULT TRUE,  -- TRUE = sequential; FALSE = parallel (any approver can pass)

    -- Whether all steps are required or just quorum
    require_all_steps   BOOLEAN NOT NULL DEFAULT TRUE,

    -- Scope (NULL = applies to entire organization)
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_default          BOOLEAN NOT NULL DEFAULT FALSE,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,

    UNIQUE(organization_id, entity_type, entity_subtype, plant_id)
);

CREATE INDEX IF NOT EXISTS idx_approval_matrices_entity ON approval_matrices(entity_type, entity_subtype);
CREATE INDEX IF NOT EXISTS idx_approval_matrices_org    ON approval_matrices(organization_id);
CREATE INDEX IF NOT EXISTS idx_approval_matrices_plant  ON approval_matrices(plant_id);
CREATE INDEX IF NOT EXISTS idx_approval_matrices_active ON approval_matrices(is_active) WHERE is_active = TRUE;

-- -------------------------------------------------------
-- APPROVAL MATRIX STEPS — ordered steps within a matrix
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS approval_matrix_steps (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matrix_id           UUID NOT NULL REFERENCES approval_matrices(id) ON DELETE CASCADE,

    -- Step ordering (1 = first to approve)
    step_order          INTEGER NOT NULL CHECK (step_order >= 1),

    -- Who can approve at this step (role-based)
    required_role_id    UUID REFERENCES roles(id) ON DELETE SET NULL,
    min_approval_tier   INTEGER CHECK (min_approval_tier BETWEEN 1 AND 99),  -- role must have approval_tier <= this

    -- Quorum (for parallel approval)
    quorum              INTEGER NOT NULL DEFAULT 1 CHECK (quorum >= 1),      -- how many approvers needed at this step

    -- Optional: specific employee override (for named approver requirements)
    required_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Behavior
    is_optional         BOOLEAN NOT NULL DEFAULT FALSE,   -- Step may be skipped if approver is unavailable
    escalation_days     INTEGER DEFAULT 3,                -- Auto-escalate if not actioned within N days
    escalate_to_tier    INTEGER CHECK (escalate_to_tier BETWEEN 1 AND 99),

    -- Signature requirement
    requires_esignature BOOLEAN NOT NULL DEFAULT TRUE,
    requires_reason     BOOLEAN NOT NULL DEFAULT FALSE,

    step_label          TEXT,    -- Human-readable label (e.g. 'HOD Review', 'QA Final Approval')

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(matrix_id, step_order)
);

CREATE INDEX IF NOT EXISTS idx_matrix_steps_matrix ON approval_matrix_steps(matrix_id);
CREATE INDEX IF NOT EXISTS idx_matrix_steps_role   ON approval_matrix_steps(required_role_id);
CREATE INDEX IF NOT EXISTS idx_matrix_steps_order  ON approval_matrix_steps(matrix_id, step_order);

-- -------------------------------------------------------
-- FUNCTION: get the approval matrix for an entity type + plant
-- Falls back to org-level matrix if no plant-specific one exists.
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_approval_matrix(
    p_org_id        UUID,
    p_entity_type   TEXT,
    p_entity_subtype TEXT DEFAULT NULL,
    p_plant_id      UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_matrix_id UUID;
BEGIN
    -- Try plant-specific first
    IF p_plant_id IS NOT NULL THEN
        SELECT id INTO v_matrix_id
        FROM approval_matrices
        WHERE organization_id = p_org_id
          AND entity_type     = p_entity_type
          AND (entity_subtype = p_entity_subtype OR (entity_subtype IS NULL AND p_entity_subtype IS NULL))
          AND plant_id        = p_plant_id
          AND is_active       = TRUE
        LIMIT 1;
    END IF;

    -- Fall back to org-level
    IF v_matrix_id IS NULL THEN
        SELECT id INTO v_matrix_id
        FROM approval_matrices
        WHERE organization_id = p_org_id
          AND entity_type     = p_entity_type
          AND (entity_subtype = p_entity_subtype OR entity_subtype IS NULL)
          AND plant_id IS NULL
          AND is_active = TRUE
        ORDER BY entity_subtype NULLS LAST
        LIMIT 1;
    END IF;

    RETURN v_matrix_id;  -- NULL if no matrix configured
END;
$$ LANGUAGE plpgsql STABLE;

-- -------------------------------------------------------
-- FUNCTION: get ordered steps for a matrix
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_matrix_steps(p_matrix_id UUID)
RETURNS TABLE (
    step_order          INTEGER,
    step_label          TEXT,
    required_role_id    UUID,
    min_approval_tier   INTEGER,
    quorum              INTEGER,
    requires_esignature BOOLEAN,
    requires_reason     BOOLEAN,
    is_optional         BOOLEAN,
    escalation_days     INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.step_order,
        s.step_label,
        s.required_role_id,
        s.min_approval_tier,
        s.quorum,
        s.requires_esignature,
        s.requires_reason,
        s.is_optional,
        s.escalation_days
    FROM approval_matrix_steps s
    WHERE s.matrix_id = p_matrix_id
    ORDER BY s.step_order;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_approval_matrices_updated ON approval_matrices;
CREATE TRIGGER trg_approval_matrices_updated
    BEFORE UPDATE ON approval_matrices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_approval_matrices_audit ON approval_matrices;
CREATE TRIGGER trg_approval_matrices_audit
    AFTER INSERT OR UPDATE OR DELETE ON approval_matrices
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_matrix_steps_audit ON approval_matrix_steps;
CREATE TRIGGER trg_matrix_steps_audit
    AFTER INSERT OR UPDATE OR DELETE ON approval_matrix_steps
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

COMMENT ON TABLE  approval_matrices IS 'Configurable multi-level approval workflows per entity type (Alfa §4.3.4)';
COMMENT ON COLUMN approval_matrices.is_serial IS 'TRUE=sequential steps, FALSE=parallel (any quorum of all steps)';
COMMENT ON TABLE  approval_matrix_steps IS 'Individual steps within an approval matrix with role and tier requirements';
COMMENT ON COLUMN approval_matrix_steps.min_approval_tier IS 'Approver role must have approval_tier <= this value (lower tier = higher authority)';
COMMENT ON COLUMN approval_matrix_steps.quorum IS 'Number of approvers required at this step (for parallel matrices)';
