-- ===========================================
-- INDUCTION TRAINING
-- ===========================================

-- Induction Programs
CREATE TABLE IF NOT EXISTS induction_programs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    version_number INTEGER DEFAULT 1,
    description TEXT,
    duration_days INTEGER NOT NULL,
    department_id UUID REFERENCES departments(id),
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
    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_induction_org ON induction_programs(organization_id);
CREATE INDEX IF NOT EXISTS idx_induction_dept ON induction_programs(department_id);
CREATE INDEX IF NOT EXISTS idx_induction_status ON induction_programs(status);

DROP TRIGGER IF EXISTS trg_induction_audit ON induction_programs;
CREATE TRIGGER trg_induction_audit AFTER INSERT OR UPDATE OR DELETE ON induction_programs FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Induction Modules
CREATE TABLE IF NOT EXISTS induction_modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    induction_id UUID NOT NULL REFERENCES induction_programs(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    gtp_id UUID REFERENCES gtp_masters(id) ON DELETE SET NULL,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    module_type TEXT NOT NULL,
    sequence_number INTEGER DEFAULT 1,
    is_mandatory BOOLEAN DEFAULT true,
    expected_duration_hours NUMERIC(6,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_module_type CHECK (course_id IS NOT NULL OR gtp_id IS NOT NULL OR document_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_induction_modules_program ON induction_modules(induction_id);

-- Employee Induction Records
CREATE TABLE IF NOT EXISTS employee_induction (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    induction_id UUID NOT NULL REFERENCES induction_programs(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    start_date DATE NOT NULL,
    expected_completion_date DATE NOT NULL,
    actual_completion_date DATE,
    status training_completion_status DEFAULT 'not_started',
    completion_percentage NUMERIC(5,2) DEFAULT 0,
    mentor_id UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(induction_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_emp_induction_employee ON employee_induction(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_induction_status ON employee_induction(status);

-- Employee Induction Module Progress
CREATE TABLE IF NOT EXISTS employee_induction_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_induction_id UUID NOT NULL REFERENCES employee_induction(id) ON DELETE CASCADE,
    module_id UUID NOT NULL REFERENCES induction_modules(id) ON DELETE CASCADE,
    status training_completion_status DEFAULT 'not_started',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    score NUMERIC(5,2),
    attempts INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_induction_id, module_id)
);

CREATE INDEX IF NOT EXISTS idx_induction_progress_employee ON employee_induction_progress(employee_induction_id);
CREATE INDEX IF NOT EXISTS idx_induction_progress_status ON employee_induction_progress(status);
