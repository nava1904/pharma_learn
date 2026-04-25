-- ===========================================
-- TRAINING FEEDBACK AND EVALUATION
-- ===========================================

-- Training Feedback
CREATE TABLE IF NOT EXISTS training_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    feedback_type feedback_template_type NOT NULL,
    template_id UUID REFERENCES feedback_evaluation_templates(id),
    responses JSONB NOT NULL,
    overall_rating NUMERIC(3,1),
    comments TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id, feedback_type)
);

CREATE INDEX IF NOT EXISTS idx_feedback_schedule ON training_feedback(schedule_id);
CREATE INDEX IF NOT EXISTS idx_feedback_employee ON training_feedback(employee_id);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON training_feedback(feedback_type);

DROP TRIGGER IF EXISTS trg_feedback_audit ON training_feedback;
CREATE TRIGGER trg_feedback_audit AFTER INSERT OR UPDATE OR DELETE ON training_feedback FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Trainer Feedback
CREATE TABLE IF NOT EXISTS trainer_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES trainers(id),
    external_trainer_id UUID REFERENCES external_trainers(id),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    template_id UUID REFERENCES feedback_evaluation_templates(id),
    responses JSONB NOT NULL,
    overall_rating NUMERIC(3,1),
    comments TEXT,
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    is_anonymous BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_trainer_feedback CHECK (trainer_id IS NOT NULL OR external_trainer_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_trainer_feedback_schedule ON trainer_feedback(schedule_id);
CREATE INDEX IF NOT EXISTS idx_trainer_feedback_trainer ON trainer_feedback(trainer_id);

-- Training Effectiveness Evaluation
CREATE TABLE IF NOT EXISTS training_effectiveness (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    evaluation_period INTEGER NOT NULL,
    evaluation_date DATE NOT NULL,
    evaluated_by UUID NOT NULL REFERENCES employees(id),
    template_id UUID REFERENCES feedback_evaluation_templates(id),
    responses JSONB NOT NULL,
    effectiveness_score NUMERIC(5,2),
    observations TEXT,
    improvement_areas TEXT,
    recommendations TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id, evaluation_period)
);

CREATE INDEX IF NOT EXISTS idx_effectiveness_schedule ON training_effectiveness(schedule_id);
CREATE INDEX IF NOT EXISTS idx_effectiveness_employee ON training_effectiveness(employee_id);

-- Feedback Summary (aggregated)
CREATE TABLE IF NOT EXISTS feedback_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    feedback_type feedback_template_type NOT NULL,
    total_responses INTEGER DEFAULT 0,
    average_rating NUMERIC(3,2),
    parameter_averages JSONB,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, feedback_type)
);

CREATE INDEX IF NOT EXISTS idx_feedback_summary_schedule ON feedback_summary(schedule_id);
