-- ===========================================
-- ASSESSMENT ATTEMPTS AND RESULTS
-- ===========================================

-- Assessment Attempts
CREATE TABLE IF NOT EXISTS assessment_attempts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    session_id UUID REFERENCES training_sessions(id) ON DELETE SET NULL,
    schedule_id UUID REFERENCES training_schedules(id) ON DELETE SET NULL,
    assignment_id UUID REFERENCES self_learning_assignments(id) ON DELETE SET NULL,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    time_taken_seconds INTEGER,
    status assessment_status DEFAULT 'in_progress',
    total_questions INTEGER NOT NULL,
    attempted_questions INTEGER DEFAULT 0,
    correct_answers INTEGER DEFAULT 0,
    wrong_answers INTEGER DEFAULT 0,
    skipped_questions INTEGER DEFAULT 0,
    total_marks NUMERIC(6,2) NOT NULL,
    obtained_marks NUMERIC(6,2) DEFAULT 0,
    percentage NUMERIC(5,2) DEFAULT 0,
    is_passed BOOLEAN,
    ip_address INET,
    user_agent TEXT,
    proctoring_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_attempts_paper ON assessment_attempts(question_paper_id);
CREATE INDEX IF NOT EXISTS idx_attempts_employee ON assessment_attempts(employee_id);
CREATE INDEX IF NOT EXISTS idx_attempts_session ON assessment_attempts(session_id);
CREATE INDEX IF NOT EXISTS idx_attempts_schedule ON assessment_attempts(schedule_id);
CREATE INDEX IF NOT EXISTS idx_attempts_status ON assessment_attempts(status);

DROP TRIGGER IF EXISTS trg_attempts_audit ON assessment_attempts;
CREATE TRIGGER trg_attempts_audit AFTER INSERT OR UPDATE OR DELETE ON assessment_attempts FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Assessment Responses (individual question answers)
CREATE TABLE IF NOT EXISTS assessment_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    question_number INTEGER NOT NULL,
    response_data JSONB,
    is_answered BOOLEAN DEFAULT false,
    is_marked_for_review BOOLEAN DEFAULT false,
    time_spent_seconds INTEGER DEFAULT 0,
    is_correct BOOLEAN,
    marks_obtained NUMERIC(5,2) DEFAULT 0,
    auto_graded BOOLEAN DEFAULT true,
    graded_by UUID,
    graded_at TIMESTAMPTZ,
    grading_comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(attempt_id, question_id)
);

CREATE INDEX IF NOT EXISTS idx_responses_attempt ON assessment_responses(attempt_id);
CREATE INDEX IF NOT EXISTS idx_responses_question ON assessment_responses(question_id);

-- Assessment Activity Log (for proctoring/audit)
CREATE TABLE IF NOT EXISTS assessment_activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL,
    activity_data JSONB,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activity_attempt ON assessment_activity_log(attempt_id);
CREATE INDEX IF NOT EXISTS idx_activity_timestamp ON assessment_activity_log(timestamp);
