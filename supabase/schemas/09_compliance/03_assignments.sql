-- ===========================================
-- TRAINING ASSIGNMENTS AND MATRICES
-- ===========================================

-- Training Assignments (mandatory training)
CREATE TABLE IF NOT EXISTS training_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    assignment_type TEXT NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    target_type TEXT NOT NULL,
    target_department_id UUID REFERENCES departments(id),
    target_role_id UUID REFERENCES roles(id),
    target_subgroup_id UUID REFERENCES subgroups(id),
    target_employee_ids JSONB DEFAULT '[]',
    frequency_type frequency_type NOT NULL DEFAULT 'one_time',
    frequency_value INTEGER,
    due_days INTEGER NOT NULL,
    reminder_days JSONB DEFAULT '[7, 3, 1]',
    escalation_days JSONB DEFAULT '[1, 3]',
    is_mandatory BOOLEAN DEFAULT true,
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_assignments_org ON training_assignments(organization_id);
CREATE INDEX IF NOT EXISTS idx_assignments_course ON training_assignments(course_id);
CREATE INDEX IF NOT EXISTS idx_assignments_status ON training_assignments(status);
CREATE INDEX IF NOT EXISTS idx_assignments_frequency ON training_assignments(frequency_type);

DROP TRIGGER IF EXISTS trg_assignments_audit ON training_assignments;
CREATE TRIGGER trg_assignments_audit AFTER INSERT OR UPDATE OR DELETE ON training_assignments FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Employee Assignment Instances
CREATE TABLE IF NOT EXISTS employee_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    obligation_id UUID REFERENCES employee_training_obligations(id) ON DELETE SET NULL,
    assignment_id UUID NOT NULL REFERENCES training_assignments(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    due_date DATE NOT NULL,
    status assignment_status DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    completion_source TEXT,
    training_record_id UUID REFERENCES training_records(id),
    reminder_sent_count INTEGER DEFAULT 0,
    last_reminder_at TIMESTAMPTZ,
    escalation_level INTEGER DEFAULT 0,
    last_escalation_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emp_assignments_assignment ON employee_assignments(assignment_id);
CREATE INDEX IF NOT EXISTS idx_emp_assignments_employee ON employee_assignments(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_assignments_status ON employee_assignments(status);
CREATE INDEX IF NOT EXISTS idx_emp_assignments_due ON employee_assignments(due_date);
CREATE INDEX IF NOT EXISTS idx_emp_assignments_obligation ON employee_assignments(obligation_id);

-- Training Matrix
CREATE TABLE IF NOT EXISTS training_matrix (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    matrix_type TEXT NOT NULL DEFAULT 'role_based',
    department_id UUID REFERENCES departments(id),
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_matrix_org ON training_matrix(organization_id);
CREATE INDEX IF NOT EXISTS idx_matrix_dept ON training_matrix(department_id);
CREATE INDEX IF NOT EXISTS idx_matrix_status ON training_matrix(status);

-- Training Matrix Items
CREATE TABLE IF NOT EXISTS training_matrix_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    matrix_id UUID NOT NULL REFERENCES training_matrix(id) ON DELETE CASCADE,
    role_id UUID REFERENCES roles(id),
    job_responsibility_id UUID REFERENCES job_responsibilities(id),
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    is_mandatory BOOLEAN DEFAULT true,
    frequency_type frequency_type NOT NULL DEFAULT 'one_time',
    frequency_value INTEGER,
    due_days INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_matrix_items_matrix ON training_matrix_items(matrix_id);
CREATE INDEX IF NOT EXISTS idx_matrix_items_role ON training_matrix_items(role_id);
