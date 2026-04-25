-- ===========================================
-- COST / BUDGET TRACKING
-- Training cost centers, budgets, actuals
-- ===========================================

CREATE TYPE budget_period_type AS ENUM ('monthly','quarterly','yearly','fiscal_year');
CREATE TYPE cost_category AS ENUM (
    'trainer_fees','venue_rental','materials','travel','accommodation',
    'license_subscription','certification_fees','food_beverage','equipment','miscellaneous'
);

CREATE TABLE IF NOT EXISTS cost_centers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id),
    department_id UUID REFERENCES departments(id),
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    description TEXT,
    owner_employee_id UUID REFERENCES employees(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, code)
);

CREATE TABLE IF NOT EXISTS training_budgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    cost_center_id UUID NOT NULL REFERENCES cost_centers(id),
    period_type budget_period_type NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    allocated_amount NUMERIC(14,2) NOT NULL,
    committed_amount NUMERIC(14,2) DEFAULT 0,
    spent_amount NUMERIC(14,2) DEFAULT 0,
    currency TEXT DEFAULT 'INR',
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS course_costs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    cost_category cost_category NOT NULL,
    per_participant_cost NUMERIC(10,2) DEFAULT 0,
    fixed_cost NUMERIC(12,2) DEFAULT 0,
    currency TEXT DEFAULT 'INR',
    is_active BOOLEAN DEFAULT true,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS training_expenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    cost_center_id UUID REFERENCES cost_centers(id),
    session_id UUID,
    course_id UUID REFERENCES courses(id),
    cost_category cost_category NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    currency TEXT DEFAULT 'INR',
    expense_date DATE NOT NULL,
    vendor TEXT,
    invoice_number TEXT,
    invoice_file_id UUID,
    participant_count INTEGER,
    notes TEXT,
    submitted_by UUID REFERENCES employees(id),
    submitted_at TIMESTAMPTZ DEFAULT NOW(),
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    approval_status TEXT DEFAULT 'pending' CHECK (approval_status IN ('pending','approved','rejected','paid'))
);

CREATE TABLE IF NOT EXISTS budget_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    budget_id UUID NOT NULL REFERENCES training_budgets(id) ON DELETE CASCADE,
    threshold_percent INTEGER NOT NULL CHECK (threshold_percent BETWEEN 1 AND 200),
    alert_recipients UUID[] DEFAULT '{}',
    last_triggered_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT true
);

CREATE INDEX IF NOT EXISTS idx_te_cost_center ON training_expenses(cost_center_id, expense_date DESC);
CREATE INDEX IF NOT EXISTS idx_tb_period ON training_budgets(period_start, period_end);

COMMENT ON TABLE training_budgets IS 'Period-based training budgets allocated to cost centers';
COMMENT ON TABLE training_expenses IS 'Actual training expenditures linked to sessions/courses';
