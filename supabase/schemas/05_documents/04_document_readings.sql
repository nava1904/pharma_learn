-- ===========================================
-- DOCUMENT READINGS (DOC_READ TRAINING)
-- Tracks employee acknowledgement of document reading
-- URS Alfa §4.2.1.34 — Each entry requires e-signature
-- ===========================================

-- Document readings - employee acknowledgement of reading a document
CREATE TABLE IF NOT EXISTS document_readings (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE SET NULL,
    department_id           UUID REFERENCES departments(id) ON DELETE SET NULL,

    -- Document reference
    document_id             UUID NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
    document_version_id     UUID REFERENCES document_versions(id) ON DELETE SET NULL,

    -- Reader
    employee_id             UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- Assignment context
    obligation_id           UUID REFERENCES employee_training_obligations(id) ON DELETE SET NULL,
    assignment_id           UUID REFERENCES training_assignments(id) ON DELETE SET NULL,
    change_control_id       UUID REFERENCES change_controls(id) ON DELETE SET NULL,

    -- Progress tracking
    status                  TEXT NOT NULL DEFAULT 'ASSIGNED' CHECK (status IN (
        'ASSIGNED', 'IN_PROGRESS', 'COMPLETED', 'OVERDUE', 'WAIVED', 'CANCELLED'
    )),
    assigned_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date                DATE,
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    time_spent_minutes      INTEGER,

    -- E-signature (mandatory per URS §4.2.1.34)
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    standard_reason_id      UUID REFERENCES standard_reasons(id) ON DELETE SET NULL,

    -- For doc reading, we track:
    -- - pages_viewed (if applicable)
    -- - scroll_completion (for web content)
    pages_viewed            INTEGER,
    total_pages             INTEGER,
    scroll_completion_pct   NUMERIC(5, 2),

    -- Quiz (optional — some doc reads require a quiz)
    requires_quiz           BOOLEAN NOT NULL DEFAULT FALSE,
    quiz_passed             BOOLEAN,
    quiz_score              NUMERIC(5, 2),
    quiz_attempt_id         UUID REFERENCES assessment_attempts(id) ON DELETE SET NULL,

    -- Waiver/override
    waived_at               TIMESTAMPTZ,
    waived_by               UUID REFERENCES employees(id) ON DELETE SET NULL,
    waived_reason_id        UUID REFERENCES standard_reasons(id) ON DELETE SET NULL,
    waived_esignature_id    UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    -- Constraints
    UNIQUE(document_id, document_version_id, employee_id),
    CONSTRAINT chk_esig_on_completion
        CHECK (status != 'COMPLETED' OR esignature_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_doc_readings_org ON document_readings(organization_id);
CREATE INDEX IF NOT EXISTS idx_doc_readings_document ON document_readings(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_readings_employee ON document_readings(employee_id);
CREATE INDEX IF NOT EXISTS idx_doc_readings_status ON document_readings(status);
CREATE INDEX IF NOT EXISTS idx_doc_readings_due ON document_readings(due_date) WHERE status IN ('ASSIGNED', 'IN_PROGRESS');
CREATE INDEX IF NOT EXISTS idx_doc_readings_overdue ON document_readings(due_date)
    WHERE status IN ('ASSIGNED', 'IN_PROGRESS') AND due_date < CURRENT_DATE;
CREATE INDEX IF NOT EXISTS idx_doc_readings_obligation ON document_readings(obligation_id) WHERE obligation_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_doc_readings_cc ON document_readings(change_control_id) WHERE change_control_id IS NOT NULL;

-- Audit trigger
DROP TRIGGER IF EXISTS trg_doc_readings_audit ON document_readings;
CREATE TRIGGER trg_doc_readings_audit
    AFTER INSERT OR UPDATE OR DELETE ON document_readings
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- Function to complete a document reading with e-sig
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION complete_document_reading(
    p_reading_id UUID,
    p_esignature_id UUID,
    p_time_spent_minutes INTEGER DEFAULT NULL,
    p_pages_viewed INTEGER DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_reading document_readings%ROWTYPE;
BEGIN
    SELECT * INTO v_reading FROM document_readings WHERE id = p_reading_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document reading not found: %', p_reading_id;
    END IF;

    IF v_reading.status = 'COMPLETED' THEN
        RAISE EXCEPTION 'Document reading already completed';
    END IF;

    IF v_reading.status IN ('WAIVED', 'CANCELLED') THEN
        RAISE EXCEPTION 'Cannot complete a waived or cancelled reading';
    END IF;

    -- E-signature is mandatory
    IF p_esignature_id IS NULL THEN
        RAISE EXCEPTION 'E-signature is required to complete document reading (URS §4.2.1.34)';
    END IF;

    UPDATE document_readings
    SET status = 'COMPLETED',
        completed_at = NOW(),
        esignature_id = p_esignature_id,
        time_spent_minutes = COALESCE(p_time_spent_minutes, time_spent_minutes),
        pages_viewed = COALESCE(p_pages_viewed, pages_viewed),
        updated_at = NOW()
    WHERE id = p_reading_id;

    -- Update linked obligation if exists
    IF v_reading.obligation_id IS NOT NULL THEN
        UPDATE employee_training_obligations
        SET status = 'completed',
            completed_at = NOW(),
            completion_esignature_id = p_esignature_id,
            updated_at = NOW()
        WHERE id = v_reading.obligation_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- View: Pending document readings (dashboard)
-- -------------------------------------------------------
CREATE OR REPLACE VIEW v_pending_document_readings AS
SELECT
    dr.id,
    dr.employee_id,
    e.first_name || ' ' || e.last_name AS employee_name,
    e.employee_id AS employee_code,
    d.name AS document_name,
    d.document_number,
    dv.version_number,
    dr.status,
    dr.assigned_at,
    dr.due_date,
    CASE
        WHEN dr.due_date < CURRENT_DATE THEN TRUE
        ELSE FALSE
    END AS is_overdue,
    dr.due_date - CURRENT_DATE AS days_until_due,
    dr.organization_id,
    dr.plant_id,
    dr.department_id
FROM document_readings dr
JOIN employees e ON e.id = dr.employee_id
JOIN documents d ON d.id = dr.document_id
LEFT JOIN document_versions dv ON dv.id = dr.document_version_id
WHERE dr.status IN ('ASSIGNED', 'IN_PROGRESS');

COMMENT ON TABLE document_readings IS 'Document reading acknowledgements with mandatory e-signature per URS §4.2.1.34';
COMMENT ON COLUMN document_readings.esignature_id IS 'Mandatory e-signature for completion — enforced by CHECK constraint';
COMMENT ON FUNCTION complete_document_reading IS 'Complete a doc reading with required e-signature; updates linked obligation';
