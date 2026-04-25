-- ===========================================
-- REGULATORY AUDIT MANAGEMENT
-- ===========================================

-- Regulatory Audits
CREATE TABLE IF NOT EXISTS regulatory_audits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL UNIQUE,
    audit_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT,
    audit_type audit_type NOT NULL,
    regulatory_body TEXT NOT NULL,
    plant_id UUID REFERENCES plants(id),
    department_ids JSONB DEFAULT '[]',
    scheduled_start_date DATE NOT NULL,
    scheduled_end_date DATE NOT NULL,
    actual_start_date DATE,
    actual_end_date DATE,
    lead_auditor TEXT,
    audit_team JSONB DEFAULT '[]',
    scope TEXT,
    status audit_status DEFAULT 'scheduled',
    final_report_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reg_audits_org ON regulatory_audits(organization_id);
CREATE INDEX IF NOT EXISTS idx_reg_audits_status ON regulatory_audits(status);
CREATE INDEX IF NOT EXISTS idx_reg_audits_type ON regulatory_audits(audit_type);
CREATE INDEX IF NOT EXISTS idx_reg_audits_dates ON regulatory_audits(scheduled_start_date, scheduled_end_date);

DROP TRIGGER IF EXISTS trg_reg_audits_audit ON regulatory_audits;
CREATE TRIGGER trg_reg_audits_audit AFTER INSERT OR UPDATE OR DELETE ON regulatory_audits FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Audit Findings
CREATE TABLE IF NOT EXISTS audit_findings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    audit_id UUID NOT NULL REFERENCES regulatory_audits(id) ON DELETE CASCADE,
    finding_number TEXT NOT NULL,
    finding_type finding_type NOT NULL,
    severity finding_severity NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    area_affected TEXT,
    department_id UUID REFERENCES departments(id),
    root_cause TEXT,
    response_due_date DATE,
    response_submitted_date DATE,
    status TEXT DEFAULT 'open',
    closed_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(audit_id, finding_number)
);

CREATE INDEX IF NOT EXISTS idx_findings_audit ON audit_findings(audit_id);
CREATE INDEX IF NOT EXISTS idx_findings_status ON audit_findings(status);
CREATE INDEX IF NOT EXISTS idx_findings_severity ON audit_findings(severity);

-- Audit Finding Training Requirements
CREATE TABLE IF NOT EXISTS audit_finding_training (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    finding_id UUID NOT NULL REFERENCES audit_findings(id) ON DELETE CASCADE,
    training_type TEXT NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    target_employees JSONB NOT NULL,
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_finding_training_finding ON audit_finding_training(finding_id);

-- Audit Preparation Checklist
CREATE TABLE IF NOT EXISTS audit_preparation_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    audit_id UUID NOT NULL REFERENCES regulatory_audits(id) ON DELETE CASCADE,
    item_number INTEGER NOT NULL,
    description TEXT NOT NULL,
    responsible_id UUID REFERENCES employees(id),
    due_date DATE,
    status TEXT DEFAULT 'pending',
    completed_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(audit_id, item_number)
);

CREATE INDEX IF NOT EXISTS idx_audit_prep_audit ON audit_preparation_items(audit_id);
