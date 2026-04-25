-- ===========================================
-- REMEDIAL TRAININGS (FAILURE DISPOSITION)
-- FAIL does not always imply retraining; QA disposition is required
-- ===========================================

CREATE TABLE IF NOT EXISTS remedial_trainings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- Link to the failed assessment
    assessment_result_id UUID REFERENCES assessment_results(id) ON DELETE SET NULL,
    failed_attempt_id UUID REFERENCES assessment_attempts(id) ON DELETE SET NULL,
    question_paper_id UUID REFERENCES question_papers(id) ON DELETE SET NULL,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    session_id UUID REFERENCES training_sessions(id) ON DELETE SET NULL,

    -- Link to canonical obligation that is being remediated
    obligation_id UUID REFERENCES employee_training_obligations(id) ON DELETE SET NULL,

    -- Disposition / decision
    disposition failure_disposition,
    disposition_decided_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    disposition_decided_at TIMESTAMPTZ,
    disposition_esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Outcome tracking
    remedial_obligation_id UUID REFERENCES employee_training_obligations(id) ON DELETE SET NULL,
    status workflow_state NOT NULL DEFAULT 'initiated',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_remedial_org ON remedial_trainings(organization_id);
CREATE INDEX IF NOT EXISTS idx_remedial_employee ON remedial_trainings(employee_id);
CREATE INDEX IF NOT EXISTS idx_remedial_status ON remedial_trainings(status);
CREATE INDEX IF NOT EXISTS idx_remedial_obligation ON remedial_trainings(obligation_id);

DROP TRIGGER IF EXISTS trg_remedial_audit ON remedial_trainings;
CREATE TRIGGER trg_remedial_audit AFTER INSERT OR UPDATE OR DELETE ON remedial_trainings FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Auto-create remedial record on failed assessment result (pending disposition)
CREATE OR REPLACE FUNCTION create_remedial_on_failure()
RETURNS TRIGGER AS $$
DECLARE
    v_org UUID;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_passed = false THEN
            SELECT organization_id INTO v_org FROM employees WHERE id = NEW.employee_id;

            INSERT INTO remedial_trainings (
                organization_id,
                employee_id,
                assessment_result_id,
                failed_attempt_id,
                question_paper_id,
                course_id,
                status
            ) VALUES (
                v_org,
                NEW.employee_id,
                NEW.id,
                NEW.best_attempt_id,
                NEW.question_paper_id,
                NEW.course_id,
                'initiated'::workflow_state
            )
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_results_remedial ON assessment_results;
CREATE TRIGGER trg_results_remedial
    AFTER INSERT ON assessment_results
    FOR EACH ROW EXECUTE FUNCTION create_remedial_on_failure();

