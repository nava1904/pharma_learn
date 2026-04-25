-- ===========================================
-- COMPLIANCE AUDIT REPORTS
-- ===========================================

-- Training Compliance Reports
CREATE TABLE IF NOT EXISTS compliance_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    report_type compliance_report_type NOT NULL,
    report_name TEXT NOT NULL,
    report_period_start DATE NOT NULL,
    report_period_end DATE NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW(),
    generated_by UUID NOT NULL,
    report_data JSONB NOT NULL,
    summary_stats JSONB,
    pdf_url TEXT,
    excel_url TEXT,
    status TEXT DEFAULT 'generated',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_compliance_reports_org ON compliance_reports(organization_id);
CREATE INDEX IF NOT EXISTS idx_compliance_reports_type ON compliance_reports(report_type);
CREATE INDEX IF NOT EXISTS idx_compliance_reports_period ON compliance_reports(report_period_start, report_period_end);

-- Compliance Snapshots (periodic captures)
CREATE TABLE IF NOT EXISTS compliance_snapshots (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,
    snapshot_type TEXT NOT NULL,
    department_id UUID REFERENCES departments(id),
    total_employees INTEGER NOT NULL,
    compliant_employees INTEGER NOT NULL,
    non_compliant_employees INTEGER NOT NULL,
    compliance_percentage NUMERIC(5,2) NOT NULL,
    overdue_trainings INTEGER DEFAULT 0,
    upcoming_due INTEGER DEFAULT 0,
    expiring_soon INTEGER DEFAULT 0,
    detailed_data JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, snapshot_date, snapshot_type, department_id)
);

CREATE INDEX IF NOT EXISTS idx_compliance_snapshots_org ON compliance_snapshots(organization_id);
CREATE INDEX IF NOT EXISTS idx_compliance_snapshots_date ON compliance_snapshots(snapshot_date);

-- Regulatory Submission Records
CREATE TABLE IF NOT EXISTS regulatory_submissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    submission_number TEXT NOT NULL UNIQUE,
    submission_type TEXT NOT NULL,
    regulatory_body TEXT NOT NULL,
    submission_date DATE NOT NULL,
    due_date DATE,
    description TEXT,
    documents JSONB DEFAULT '[]',
    training_evidence JSONB DEFAULT '[]',
    status TEXT DEFAULT 'draft',
    submitted_by UUID,
    submitted_at TIMESTAMPTZ,
    acknowledgment_number TEXT,
    acknowledgment_date DATE,
    response_received_date DATE,
    response_status TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reg_submissions_org ON regulatory_submissions(organization_id);
CREATE INDEX IF NOT EXISTS idx_reg_submissions_status ON regulatory_submissions(status);
CREATE INDEX IF NOT EXISTS idx_reg_submissions_date ON regulatory_submissions(submission_date);

-- Annual Training Plan
CREATE TABLE IF NOT EXISTS annual_training_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    year INTEGER NOT NULL,
    version_number INTEGER DEFAULT 1,
    name TEXT NOT NULL,
    description TEXT,
    department_id UUID REFERENCES departments(id),
    planned_trainings JSONB NOT NULL,
    budget_allocated NUMERIC(12,2),
    budget_utilized NUMERIC(12,2) DEFAULT 0,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, year, department_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_atp_org ON annual_training_plans(organization_id);
CREATE INDEX IF NOT EXISTS idx_atp_year ON annual_training_plans(year);
CREATE INDEX IF NOT EXISTS idx_atp_status ON annual_training_plans(status);
