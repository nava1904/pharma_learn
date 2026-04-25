-- ===========================================
-- DELEGATION AND PROXY
-- ===========================================

-- Approval Delegations
CREATE TABLE IF NOT EXISTS approval_delegations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    delegator_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    delegate_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    delegation_type TEXT NOT NULL DEFAULT 'all',
    entity_types JSONB DEFAULT '[]',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT NOT NULL,
    status workflow_state DEFAULT 'pending_approval',
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_delegation_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_not_self CHECK (delegator_id != delegate_id)
);

CREATE INDEX IF NOT EXISTS idx_delegations_delegator ON approval_delegations(delegator_id);
CREATE INDEX IF NOT EXISTS idx_delegations_delegate ON approval_delegations(delegate_id);
CREATE INDEX IF NOT EXISTS idx_delegations_active ON approval_delegations(is_active);
CREATE INDEX IF NOT EXISTS idx_delegations_dates ON approval_delegations(start_date, end_date);

DROP TRIGGER IF EXISTS trg_delegations_audit ON approval_delegations;
CREATE TRIGGER trg_delegations_audit AFTER INSERT OR UPDATE OR DELETE ON approval_delegations FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Delegation Actions Log
CREATE TABLE IF NOT EXISTS delegation_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    delegation_id UUID NOT NULL REFERENCES approval_delegations(id) ON DELETE CASCADE,
    workflow_task_id UUID REFERENCES workflow_tasks(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    action_taken TEXT NOT NULL,
    action_at TIMESTAMPTZ DEFAULT NOW(),
    action_by UUID NOT NULL,
    on_behalf_of UUID NOT NULL,
    comments TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_delegation_actions_delegation ON delegation_actions(delegation_id);
CREATE INDEX IF NOT EXISTS idx_delegation_actions_entity ON delegation_actions(entity_type, entity_id);

-- Out of Office Settings
CREATE TABLE IF NOT EXISTS out_of_office (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    start_datetime TIMESTAMPTZ NOT NULL,
    end_datetime TIMESTAMPTZ NOT NULL,
    reason TEXT,
    auto_delegate BOOLEAN DEFAULT false,
    delegate_id UUID REFERENCES employees(id),
    auto_reply_message TEXT,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_ooo_dates CHECK (end_datetime > start_datetime),
    CONSTRAINT chk_ooo_delegate CHECK (auto_delegate = false OR delegate_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_ooo_employee ON out_of_office(employee_id);
CREATE INDEX IF NOT EXISTS idx_ooo_dates ON out_of_office(start_datetime, end_datetime);
CREATE INDEX IF NOT EXISTS idx_ooo_active ON out_of_office(is_active);

-- Parallel Approval Groups
CREATE TABLE IF NOT EXISTS parallel_approval_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    members JSONB NOT NULL,
    min_approvals INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_parallel_groups_org ON parallel_approval_groups(organization_id);
