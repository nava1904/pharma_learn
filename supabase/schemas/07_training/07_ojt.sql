-- ===========================================
-- ON-THE-JOB TRAINING (OJT)
-- ===========================================

-- OJT Masters
CREATE TABLE IF NOT EXISTS ojt_masters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    version_number INTEGER DEFAULT 1,
    description TEXT,
    category_id UUID REFERENCES categories(id),
    department_id UUID REFERENCES departments(id),
    duration_hours NUMERIC(6,2) NOT NULL,
    competency_requirements JSONB DEFAULT '[]',
    evaluation_criteria JSONB DEFAULT '[]',
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_ojt_org ON ojt_masters(organization_id);
CREATE INDEX IF NOT EXISTS idx_ojt_dept ON ojt_masters(department_id);
CREATE INDEX IF NOT EXISTS idx_ojt_status ON ojt_masters(status);

DROP TRIGGER IF EXISTS trg_ojt_audit ON ojt_masters;
CREATE TRIGGER trg_ojt_audit AFTER INSERT OR UPDATE OR DELETE ON ojt_masters FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- OJT Tasks
CREATE TABLE IF NOT EXISTS ojt_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ojt_id UUID NOT NULL REFERENCES ojt_masters(id) ON DELETE CASCADE,
    task_number INTEGER NOT NULL,
    task_name TEXT NOT NULL,
    task_description TEXT,
    expected_duration_hours NUMERIC(6,2),
    evaluation_method TEXT,
    passing_criteria TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ojt_id, task_number)
);

CREATE INDEX IF NOT EXISTS idx_ojt_tasks_ojt ON ojt_tasks(ojt_id);

-- Employee OJT Assignments
CREATE TABLE IF NOT EXISTS employee_ojt (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ojt_id UUID NOT NULL REFERENCES ojt_masters(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    supervisor_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    start_date DATE NOT NULL,
    expected_completion_date DATE NOT NULL,
    actual_completion_date DATE,
    status training_completion_status DEFAULT 'not_started',
    completion_percentage NUMERIC(5,2) DEFAULT 0,
    overall_score NUMERIC(5,2),
    supervisor_comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ojt_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_emp_ojt_employee ON employee_ojt(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_ojt_supervisor ON employee_ojt(supervisor_id);
CREATE INDEX IF NOT EXISTS idx_emp_ojt_status ON employee_ojt(status);

-- OJT Task Completion Records
CREATE TABLE IF NOT EXISTS ojt_task_completion (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_ojt_id UUID NOT NULL REFERENCES employee_ojt(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES ojt_tasks(id) ON DELETE CASCADE,
    status training_completion_status DEFAULT 'not_started',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    evaluated_by UUID REFERENCES employees(id),
    evaluated_at TIMESTAMPTZ,
    score NUMERIC(5,2),
    evaluation_comments TEXT,
    evidence_attachments JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_ojt_id, task_id)
);

CREATE INDEX IF NOT EXISTS idx_ojt_task_completion_employee ON ojt_task_completion(employee_ojt_id);
CREATE INDEX IF NOT EXISTS idx_ojt_task_completion_status ON ojt_task_completion(status);

DROP TRIGGER IF EXISTS trg_ojt_task_audit ON ojt_task_completion;
CREATE TRIGGER trg_ojt_task_audit AFTER INSERT OR UPDATE OR DELETE ON ojt_task_completion FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
