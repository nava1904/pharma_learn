-- ===========================================
-- COMPETENCY MANAGEMENT
-- ===========================================

-- Competency Definitions
CREATE TABLE IF NOT EXISTS competencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    competency_type competency_type NOT NULL,
    proficiency_levels JSONB NOT NULL,
    assessment_criteria JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_competencies_org ON competencies(organization_id);
CREATE INDEX IF NOT EXISTS idx_competencies_type ON competencies(competency_type);

-- Role Competency Requirements
CREATE TABLE IF NOT EXISTS role_competencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE CASCADE,
    required_level INTEGER NOT NULL,
    is_mandatory BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(role_id, competency_id)
);

CREATE INDEX IF NOT EXISTS idx_role_competencies_role ON role_competencies(role_id);

-- Employee Competency Records
CREATE TABLE IF NOT EXISTS employee_competencies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE CASCADE,
    current_level INTEGER NOT NULL,
    assessed_date DATE NOT NULL,
    assessed_by UUID REFERENCES employees(id),
    assessment_method TEXT,
    evidence_attachments JSONB DEFAULT '[]',
    expiry_date DATE,
    status competency_status DEFAULT 'current',
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, competency_id)
);

CREATE INDEX IF NOT EXISTS idx_emp_competencies_employee ON employee_competencies(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_competencies_status ON employee_competencies(status);
CREATE INDEX IF NOT EXISTS idx_emp_competencies_expiry ON employee_competencies(expiry_date);

DROP TRIGGER IF EXISTS trg_emp_competencies_audit ON employee_competencies;
CREATE TRIGGER trg_emp_competencies_audit AFTER INSERT OR UPDATE OR DELETE ON employee_competencies FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Competency History
CREATE TABLE IF NOT EXISTS competency_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_competency_id UUID NOT NULL REFERENCES employee_competencies(id) ON DELETE CASCADE,
    previous_level INTEGER,
    new_level INTEGER NOT NULL,
    change_reason TEXT,
    changed_by UUID,
    changed_at TIMESTAMPTZ DEFAULT NOW(),
    training_record_id UUID REFERENCES training_records(id)
);

CREATE INDEX IF NOT EXISTS idx_comp_history_emp_comp ON competency_history(employee_competency_id);

-- Competency Gaps
CREATE TABLE IF NOT EXISTS competency_gaps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id) ON DELETE CASCADE,
    required_level INTEGER NOT NULL,
    current_level INTEGER NOT NULL,
    gap_level INTEGER GENERATED ALWAYS AS (required_level - current_level) STORED,
    identified_date DATE NOT NULL,
    target_closure_date DATE,
    remediation_plan TEXT,
    status TEXT DEFAULT 'open',
    closed_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, competency_id)
);

CREATE INDEX IF NOT EXISTS idx_comp_gaps_employee ON competency_gaps(employee_id);
CREATE INDEX IF NOT EXISTS idx_comp_gaps_status ON competency_gaps(status);
