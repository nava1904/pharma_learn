-- ===========================================
-- CHANGE CONTROL INTEGRATION
-- ===========================================

-- Change Control Records
CREATE TABLE IF NOT EXISTS change_controls (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL UNIQUE,
    change_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    change_type change_control_type NOT NULL,
    category TEXT,
    department_id UUID REFERENCES departments(id),
    plant_id UUID REFERENCES plants(id),
    affected_areas JSONB DEFAULT '[]',
    impact_assessment TEXT,
    risk_assessment TEXT,
    proposed_date DATE NOT NULL,
    implementation_date DATE,
    status workflow_state DEFAULT 'initiated',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    implemented_by UUID,
    implemented_at TIMESTAMPTZ,
    closed_by UUID,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cc_org ON change_controls(organization_id);
CREATE INDEX IF NOT EXISTS idx_cc_status ON change_controls(status);
CREATE INDEX IF NOT EXISTS idx_cc_type ON change_controls(change_type);
CREATE INDEX IF NOT EXISTS idx_cc_date ON change_controls(proposed_date);

DROP TRIGGER IF EXISTS trg_cc_audit ON change_controls;
CREATE TRIGGER trg_cc_audit AFTER INSERT OR UPDATE OR DELETE ON change_controls FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Change Control Training Requirements
CREATE TABLE IF NOT EXISTS change_control_training (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    change_control_id UUID NOT NULL REFERENCES change_controls(id) ON DELETE CASCADE,
    training_type TEXT NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    target_department_id UUID REFERENCES departments(id),
    target_role_id UUID REFERENCES roles(id),
    target_employees JSONB DEFAULT '[]',
    required_before_implementation BOOLEAN DEFAULT true,
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'pending',
    completion_percentage NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cc_training_cc ON change_control_training(change_control_id);
CREATE INDEX IF NOT EXISTS idx_cc_training_status ON change_control_training(status);

-- Change Control Training Completion
CREATE TABLE IF NOT EXISTS change_control_training_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cc_training_id UUID NOT NULL REFERENCES change_control_training(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    status training_completion_status DEFAULT 'not_started',
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    training_record_id UUID REFERENCES training_records(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(cc_training_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_cc_ts_training ON change_control_training_status(cc_training_id);
CREATE INDEX IF NOT EXISTS idx_cc_ts_employee ON change_control_training_status(employee_id);
