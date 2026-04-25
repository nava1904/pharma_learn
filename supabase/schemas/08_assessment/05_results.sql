-- ===========================================
-- ASSESSMENT RESULTS AND GRADING
-- ===========================================

-- Assessment Results (final results)
CREATE TABLE IF NOT EXISTS assessment_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    question_paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    schedule_id UUID REFERENCES training_schedules(id),
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    best_attempt_id UUID REFERENCES assessment_attempts(id),
    total_attempts INTEGER DEFAULT 0,
    best_score NUMERIC(6,2) DEFAULT 0,
    best_percentage NUMERIC(5,2) DEFAULT 0,
    is_passed BOOLEAN DEFAULT false,
    first_attempt_date TIMESTAMPTZ,
    last_attempt_date TIMESTAMPTZ,
    passed_date TIMESTAMPTZ,
    result_status result_status DEFAULT 'pending',
    verified_by UUID,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, question_paper_id, schedule_id)
);

CREATE INDEX IF NOT EXISTS idx_results_employee ON assessment_results(employee_id);
CREATE INDEX IF NOT EXISTS idx_results_paper ON assessment_results(question_paper_id);
CREATE INDEX IF NOT EXISTS idx_results_schedule ON assessment_results(schedule_id);
CREATE INDEX IF NOT EXISTS idx_results_status ON assessment_results(result_status);

DROP TRIGGER IF EXISTS trg_results_audit ON assessment_results;
CREATE TRIGGER trg_results_audit AFTER INSERT OR UPDATE OR DELETE ON assessment_results FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Manual Grading Queue
CREATE TABLE IF NOT EXISTS grading_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    attempt_id UUID NOT NULL REFERENCES assessment_attempts(id) ON DELETE CASCADE,
    response_id UUID NOT NULL REFERENCES assessment_responses(id) ON DELETE CASCADE,
    assigned_to UUID REFERENCES employees(id),
    status grading_status DEFAULT 'pending',
    priority INTEGER DEFAULT 5,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_grading_queue_status ON grading_queue(status);
CREATE INDEX IF NOT EXISTS idx_grading_queue_assigned ON grading_queue(assigned_to);

-- Result Appeals
CREATE TABLE IF NOT EXISTS result_appeals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    result_id UUID NOT NULL REFERENCES assessment_results(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    appeal_reason TEXT NOT NULL,
    supporting_documents JSONB DEFAULT '[]',
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    status workflow_state DEFAULT 'pending_approval',
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    review_comments TEXT,
    outcome TEXT,
    marks_adjusted NUMERIC(5,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_appeals_result ON result_appeals(result_id);
CREATE INDEX IF NOT EXISTS idx_appeals_employee ON result_appeals(employee_id);
CREATE INDEX IF NOT EXISTS idx_appeals_status ON result_appeals(status);
