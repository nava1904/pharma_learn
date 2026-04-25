-- ===========================================
-- EMPLOYEE TRAINING OBLIGATIONS (CANONICAL LEDGER)
-- Single source of truth for required training per employee
-- ===========================================

CREATE TABLE IF NOT EXISTS employee_training_obligations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,

    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    item_type obligation_item_type NOT NULL,

    -- Target content
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    ojt_master_id UUID REFERENCES ojt_masters(id) ON DELETE SET NULL,
    question_paper_id UUID REFERENCES question_papers(id) ON DELETE SET NULL,

    -- Provenance (why this obligation exists)
    curriculum_id UUID,              -- will reference curricula(id) once added
    curriculum_item_id UUID,         -- will reference curriculum_items(id) once added
    matrix_id UUID REFERENCES training_matrix(id) ON DELETE SET NULL,
    matrix_item_id UUID REFERENCES training_matrix_items(id) ON DELETE SET NULL,
    assignment_id UUID REFERENCES training_assignments(id) ON DELETE SET NULL,
    change_control_id UUID REFERENCES change_controls(id) ON DELETE SET NULL,
    deviation_id UUID REFERENCES deviations(id) ON DELETE SET NULL,
    capa_record_id UUID REFERENCES capa_records(id) ON DELETE SET NULL,

    -- Lifecycle
    status obligation_status NOT NULL DEFAULT 'pending',
    is_induction BOOLEAN NOT NULL DEFAULT false,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    due_date DATE,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,

    -- Recurrence (NULL = one-time)
    recurrence_months INTEGER,
    recurrence_number INTEGER NOT NULL DEFAULT 1,
    is_recurrence BOOLEAN NOT NULL DEFAULT false,

    -- Evidence links
    session_id UUID REFERENCES training_sessions(id) ON DELETE SET NULL,
    training_record_id UUID REFERENCES training_records(id) ON DELETE SET NULL,
    assessment_attempt_id UUID REFERENCES assessment_attempts(id) ON DELETE SET NULL,
    certificate_id UUID REFERENCES certificates(id) ON DELETE SET NULL,
    completion_esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Waiver / cancellation
    waived_reason TEXT,
    waived_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    waived_esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    cancelled_reason TEXT,
    cancelled_by UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Audit / workflow metadata
    workflow_status workflow_state DEFAULT 'initiated',
    initiated_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    initiated_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT chk_obligation_target_present CHECK (
        course_id IS NOT NULL
        OR document_id IS NOT NULL
        OR ojt_master_id IS NOT NULL
        OR question_paper_id IS NOT NULL
    ),
    UNIQUE(employee_id, item_type, course_id, document_id, ojt_master_id, question_paper_id, recurrence_number)
);

CREATE INDEX IF NOT EXISTS idx_obligations_org ON employee_training_obligations(organization_id);
CREATE INDEX IF NOT EXISTS idx_obligations_employee ON employee_training_obligations(employee_id);
CREATE INDEX IF NOT EXISTS idx_obligations_status ON employee_training_obligations(status);
CREATE INDEX IF NOT EXISTS idx_obligations_due ON employee_training_obligations(due_date);
CREATE INDEX IF NOT EXISTS idx_obligations_item_course ON employee_training_obligations(course_id) WHERE course_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_obligations_item_doc ON employee_training_obligations(document_id) WHERE document_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_obligations_matrix_item ON employee_training_obligations(matrix_item_id) WHERE matrix_item_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_obligations_curriculum ON employee_training_obligations(curriculum_id) WHERE curriculum_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_obligations_audit ON employee_training_obligations;
CREATE TRIGGER trg_obligations_audit AFTER INSERT OR UPDATE OR DELETE ON employee_training_obligations FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Projection hook: allow employee_assignments to reference obligation id (added in separate ALTER below)
-- This file only creates the canonical ledger.

