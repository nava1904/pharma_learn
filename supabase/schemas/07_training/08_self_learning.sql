-- ===========================================
-- SELF-LEARNING AND E-LEARNING
-- ===========================================

-- Self-Learning Assignments
CREATE TABLE IF NOT EXISTS self_learning_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    gtp_id UUID REFERENCES gtp_masters(id) ON DELETE SET NULL,
    assignment_type TEXT NOT NULL,
    assigned_by UUID,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    due_date DATE,
    status training_completion_status DEFAULT 'not_started',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    time_spent_minutes INTEGER DEFAULT 0,
    progress_percentage NUMERIC(5,2) DEFAULT 0,
    score NUMERIC(5,2),
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_assignment_content CHECK (course_id IS NOT NULL OR document_id IS NOT NULL OR gtp_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_self_learning_employee ON self_learning_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_self_learning_status ON self_learning_assignments(status);
CREATE INDEX IF NOT EXISTS idx_self_learning_due ON self_learning_assignments(due_date);

DROP TRIGGER IF EXISTS trg_self_learning_audit ON self_learning_assignments;
CREATE TRIGGER trg_self_learning_audit AFTER INSERT OR UPDATE OR DELETE ON self_learning_assignments FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Learning Progress Tracking
CREATE TABLE IF NOT EXISTS learning_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignment_id UUID NOT NULL REFERENCES self_learning_assignments(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    last_position TEXT,
    progress_percentage NUMERIC(5,2) DEFAULT 0,
    time_spent_minutes INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(assignment_id, content_type, content_id)
);

CREATE INDEX IF NOT EXISTS idx_learning_progress_assignment ON learning_progress(assignment_id);
CREATE INDEX IF NOT EXISTS idx_learning_progress_employee ON learning_progress(employee_id);

-- Video/Content Tracking
CREATE TABLE IF NOT EXISTS content_view_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    content_type TEXT NOT NULL,
    content_id UUID NOT NULL,
    view_started_at TIMESTAMPTZ NOT NULL,
    view_ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    percentage_viewed NUMERIC(5,2),
    view_count INTEGER DEFAULT 1,
    device_info JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_content_view_employee ON content_view_tracking(employee_id);
CREATE INDEX IF NOT EXISTS idx_content_view_content ON content_view_tracking(content_type, content_id);
