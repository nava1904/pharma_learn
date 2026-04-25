-- ===========================================
-- TRAINING WAIVERS AND EXEMPTIONS
-- ===========================================

-- Training Waivers
CREATE TABLE IF NOT EXISTS training_waivers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    waiver_type waiver_type NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    assignment_id UUID REFERENCES training_assignments(id),
    waiver_reason TEXT NOT NULL,
    justification TEXT NOT NULL,
    evidence_attachments JSONB DEFAULT '[]',
    requested_by UUID NOT NULL,
    requested_at TIMESTAMPTZ DEFAULT NOW(),
    effective_from DATE NOT NULL,
    effective_to DATE,
    is_permanent BOOLEAN DEFAULT false,
    status workflow_state DEFAULT 'pending_approval',
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    approval_comments TEXT,
    rejection_reason TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_waivers_org ON training_waivers(organization_id);
CREATE INDEX IF NOT EXISTS idx_waivers_employee ON training_waivers(employee_id);
CREATE INDEX IF NOT EXISTS idx_waivers_status ON training_waivers(status);
CREATE INDEX IF NOT EXISTS idx_waivers_course ON training_waivers(course_id);

DROP TRIGGER IF EXISTS trg_waivers_audit ON training_waivers;
CREATE TRIGGER trg_waivers_audit AFTER INSERT OR UPDATE OR DELETE ON training_waivers FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Waiver Approval History
CREATE TABLE IF NOT EXISTS waiver_approval_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    waiver_id UUID NOT NULL REFERENCES training_waivers(id) ON DELETE CASCADE,
    approver_id UUID NOT NULL REFERENCES employees(id),
    approval_level INTEGER NOT NULL,
    action TEXT NOT NULL,
    comments TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    action_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_waiver_history_waiver ON waiver_approval_history(waiver_id);

-- Training Exemptions (bulk exemptions)
CREATE TABLE IF NOT EXISTS training_exemptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    exemption_type TEXT NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    target_department_id UUID REFERENCES departments(id),
    target_role_id UUID REFERENCES roles(id),
    exemption_reason TEXT NOT NULL,
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'pending_approval',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_exemptions_org ON training_exemptions(organization_id);
CREATE INDEX IF NOT EXISTS idx_exemptions_status ON training_exemptions(status);

-- Exempted Employees
CREATE TABLE IF NOT EXISTS exemption_employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exemption_id UUID NOT NULL REFERENCES training_exemptions(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(exemption_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_exemption_employees_exemption ON exemption_employees(exemption_id);
