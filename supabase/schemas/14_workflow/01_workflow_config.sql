-- ===========================================
-- WORKFLOW CONFIGURATION
-- ===========================================

-- Workflow Definitions
CREATE TABLE IF NOT EXISTS workflow_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    entity_type TEXT NOT NULL,
    workflow_type TEXT NOT NULL DEFAULT 'approval',
    states JSONB NOT NULL,
    transitions JSONB NOT NULL,
    default_approvers JSONB,
    sla_config JSONB,
    notification_config JSONB,
    is_active BOOLEAN DEFAULT true,
    version_number INTEGER DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_workflow_defs_org ON workflow_definitions(organization_id);
CREATE INDEX IF NOT EXISTS idx_workflow_defs_entity ON workflow_definitions(entity_type);

-- Workflow Approval Rules
CREATE TABLE IF NOT EXISTS workflow_approval_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_definition_id UUID NOT NULL REFERENCES workflow_definitions(id) ON DELETE CASCADE,
    rule_name TEXT NOT NULL,
    rule_priority INTEGER DEFAULT 1,
    conditions JSONB NOT NULL,
    required_approvers JSONB NOT NULL,
    approval_type TEXT NOT NULL DEFAULT 'sequential',
    min_approvals INTEGER DEFAULT 1,
    sla_hours INTEGER,
    auto_approve_conditions JSONB,
    auto_reject_conditions JSONB,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approval_rules_workflow ON workflow_approval_rules(workflow_definition_id);

-- Workflow Instances (running workflows)
CREATE TABLE IF NOT EXISTS workflow_instances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_definition_id UUID NOT NULL REFERENCES workflow_definitions(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    current_state workflow_state NOT NULL,
    initiated_by UUID NOT NULL,
    initiated_at TIMESTAMPTZ DEFAULT NOW(),
    current_approver_level INTEGER,
    pending_approvers JSONB DEFAULT '[]',
    completed_approvers JSONB DEFAULT '[]',
    sla_deadline TIMESTAMPTZ,
    is_overdue BOOLEAN DEFAULT false,
    completed_at TIMESTAMPTZ,
    final_status TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_workflow_instances_entity ON workflow_instances(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_workflow_instances_state ON workflow_instances(current_state);
CREATE INDEX IF NOT EXISTS idx_workflow_instances_sla ON workflow_instances(sla_deadline);

-- Workflow Tasks (approval tasks)
CREATE TABLE IF NOT EXISTS workflow_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
    task_type TEXT NOT NULL DEFAULT 'approval',
    assigned_to UUID NOT NULL,
    assigned_at TIMESTAMPTZ DEFAULT NOW(),
    due_at TIMESTAMPTZ,
    priority INTEGER DEFAULT 5,
    status TEXT DEFAULT 'pending',
    action_taken TEXT,
    action_at TIMESTAMPTZ,
    comments TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    delegated_to UUID,
    delegated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflow_tasks_instance ON workflow_tasks(workflow_instance_id);
CREATE INDEX IF NOT EXISTS idx_workflow_tasks_assigned ON workflow_tasks(assigned_to);
CREATE INDEX IF NOT EXISTS idx_workflow_tasks_status ON workflow_tasks(status);
CREATE INDEX IF NOT EXISTS idx_workflow_tasks_due ON workflow_tasks(due_at);

-- Workflow History
CREATE TABLE IF NOT EXISTS workflow_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
    from_state workflow_state,
    to_state workflow_state NOT NULL,
    action TEXT NOT NULL,
    action_by UUID NOT NULL,
    action_at TIMESTAMPTZ DEFAULT NOW(),
    comments TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workflow_history_instance ON workflow_history(workflow_instance_id);
CREATE INDEX IF NOT EXISTS idx_workflow_history_action_at ON workflow_history(action_at);

-- ===========================================
-- GAP 2 + 7: Phase support columns + transition enforcement
-- ===========================================

ALTER TABLE workflow_definitions
    ADD COLUMN IF NOT EXISTS max_rejection_count INTEGER DEFAULT 3,
    ADD COLUMN IF NOT EXISTS has_phases BOOLEAN DEFAULT false;

-- Enforce valid state transitions on workflow_instances (GAP 7)
CREATE OR REPLACE FUNCTION enforce_workflow_transition()
RETURNS TRIGGER AS $$
DECLARE
    v_max_rejections INTEGER;
    v_rejection_count INTEGER;
BEGIN
    -- No state change — nothing to enforce
    IF OLD.current_state = NEW.current_state THEN
        RETURN NEW;
    END IF;

    -- Validate transition exists in workflow_transitions state machine
    IF NOT EXISTS (
        SELECT 1 FROM workflow_transitions
        WHERE from_state = OLD.current_state
          AND to_state = NEW.current_state
    ) THEN
        RAISE EXCEPTION
            'Invalid workflow state transition: "%" → "%" is not a permitted transition for instance %',
            OLD.current_state, NEW.current_state, OLD.id
            USING ERRCODE = 'check_violation';
    END IF;

    -- Rejection loop limit: returned → initiated
    IF OLD.current_state = 'returned' AND NEW.current_state = 'initiated' THEN
        SELECT wd.max_rejection_count INTO v_max_rejections
        FROM workflow_definitions wd WHERE wd.id = NEW.workflow_definition_id;

        SELECT COUNT(*) INTO v_rejection_count
        FROM workflow_history
        WHERE workflow_instance_id = OLD.id
          AND from_state = 'returned'
          AND to_state = 'initiated';

        IF v_rejection_count >= COALESCE(v_max_rejections, 3) THEN
            RAISE EXCEPTION
                'Maximum rejection loops (%) reached for workflow instance %. '
                'Further re-initiation is not permitted.',
                COALESCE(v_max_rejections, 3), OLD.id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_workflow_instance_transition ON workflow_instances;
CREATE TRIGGER trg_workflow_instance_transition
    BEFORE UPDATE ON workflow_instances
    FOR EACH ROW EXECUTE FUNCTION enforce_workflow_transition();

-- View: track rejection loop counts per workflow instance (GAP 7)
CREATE OR REPLACE VIEW workflow_rejection_loops AS
SELECT
    wi.id                                               AS instance_id,
    wi.entity_type,
    wi.entity_id,
    COUNT(wh.id)                                        AS rejection_count,
    COALESCE(wd.max_rejection_count, 3)                 AS max_allowed,
    COUNT(wh.id) >= COALESCE(wd.max_rejection_count, 3) AS is_at_limit
FROM workflow_instances wi
JOIN workflow_definitions wd ON wd.id = wi.workflow_definition_id
LEFT JOIN workflow_history wh
    ON wh.workflow_instance_id = wi.id
    AND wh.from_state = 'returned'
    AND wh.to_state = 'initiated'
GROUP BY wi.id, wi.entity_type, wi.entity_id, wd.max_rejection_count;

COMMENT ON VIEW workflow_rejection_loops IS 'Shows rejection loop counts per instance; is_at_limit=true blocks further re-initiation';
