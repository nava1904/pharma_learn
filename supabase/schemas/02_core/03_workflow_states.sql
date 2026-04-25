-- ===========================================
-- WORKFLOW STATE MACHINE
-- Implements Learn-IQ object lifecycle
-- Registration → Initiation → Approval Set → Decision → Active/Inactive
-- ===========================================

-- Valid state transitions configuration
CREATE TABLE IF NOT EXISTS workflow_transitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    from_state workflow_state NOT NULL,
    to_state workflow_state NOT NULL,
    action_name TEXT NOT NULL,
    action_display_name TEXT,
    requires_approval BOOLEAN DEFAULT false,
    requires_reason BOOLEAN DEFAULT false,
    requires_esignature BOOLEAN DEFAULT false,
    allowed_roles TEXT[],
    min_approver_level NUMERIC(5,2),
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(from_state, to_state, action_name)
);

-- Insert Learn-IQ workflow transitions
INSERT INTO workflow_transitions (from_state, to_state, action_name, action_display_name, requires_approval, requires_reason, requires_esignature, description) VALUES
    -- Draft to Initiated
    ('draft', 'initiated', 'initiate', 'Initiate', false, false, false, 'Start the registration process'),
    
    -- Initiated flow (Learn-IQ Approval Set logic)
    ('initiated', 'pending_approval', 'submit_for_approval', 'Submit for Approval', false, false, false, 'Submit for manager approval'),
    ('initiated', 'active', 'submit_direct', 'Submit (No Approval)', false, false, false, 'Directly activate when approval not required'),
    
    -- Pending Approval decisions (Learn-IQ Decision Gate)
    ('pending_approval', 'approved', 'approve', 'Approve', true, false, true, 'Approve the object (Latest Version)'),
    ('pending_approval', 'returned', 'return', 'Return for Correction', true, true, true, 'Return to initiator for corrections'),
    ('pending_approval', 'dropped', 'drop', 'Drop Changes', true, true, true, 'Discard changes (Earlier Version)'),
    
    -- Post-approval activation
    ('approved', 'active', 'activate', 'Activate', false, false, false, 'Move approved object to active list'),
    
    -- Return handling (Re-initiation)
    ('returned', 'initiated', 'reinitiate', 'Re-initiate', false, true, false, 'Restart the submission process'),
    ('returned', 'dropped', 'abandon', 'Abandon', false, true, false, 'Abandon the modification'),
    
    -- Status change workflow
    ('active', 'inactive', 'deactivate', 'Deactivate', true, true, true, 'Move to inactive list'),
    ('inactive', 'active', 'reactivate', 'Reactivate', true, true, true, 'Return to active list'),
    
    -- Modification workflow (active objects)
    ('active', 'initiated', 'modify', 'Modify', false, false, false, 'Start modification of active object')
    
ON CONFLICT (from_state, to_state, action_name) DO NOTHING;

-- Index for faster lookups
CREATE INDEX IF NOT EXISTS idx_workflow_transitions_from ON workflow_transitions(from_state);
CREATE INDEX IF NOT EXISTS idx_workflow_transitions_action ON workflow_transitions(action_name);

-- Function to validate state transition
CREATE OR REPLACE FUNCTION validate_state_transition(
    p_current_state workflow_state,
    p_new_state workflow_state,
    p_action TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_valid BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM workflow_transitions
        WHERE from_state = p_current_state
          AND to_state = p_new_state
          AND action_name = p_action
    ) INTO v_valid;
    
    RETURN v_valid;
END;
$$ LANGUAGE plpgsql;

-- Function to get available actions for current state
CREATE OR REPLACE FUNCTION get_available_actions(
    p_current_state workflow_state
) RETURNS TABLE (
    action_name TEXT,
    action_display_name TEXT,
    target_state workflow_state,
    requires_approval BOOLEAN,
    requires_reason BOOLEAN,
    requires_esignature BOOLEAN,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wt.action_name,
        wt.action_display_name,
        wt.to_state,
        wt.requires_approval,
        wt.requires_reason,
        wt.requires_esignature,
        wt.description
    FROM workflow_transitions wt
    WHERE wt.from_state = p_current_state;
END;
$$ LANGUAGE plpgsql;

-- Function to get transition requirements
CREATE OR REPLACE FUNCTION get_transition_requirements(
    p_current_state workflow_state,
    p_target_state workflow_state
) RETURNS TABLE (
    action_name TEXT,
    requires_approval BOOLEAN,
    requires_reason BOOLEAN,
    requires_esignature BOOLEAN,
    allowed_roles TEXT[],
    min_approver_level NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        wt.action_name,
        wt.requires_approval,
        wt.requires_reason,
        wt.requires_esignature,
        wt.allowed_roles,
        wt.min_approver_level
    FROM workflow_transitions wt
    WHERE wt.from_state = p_current_state
      AND wt.to_state = p_target_state;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to validate state changes
CREATE OR REPLACE FUNCTION validate_workflow_state_change()
RETURNS TRIGGER AS $$
DECLARE
    v_valid BOOLEAN;
BEGIN
    -- Skip validation if status hasn't changed
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;
    
    -- Check if transition is valid
    SELECT EXISTS(
        SELECT 1 FROM workflow_transitions
        WHERE from_state = OLD.status::workflow_state
          AND to_state = NEW.status::workflow_state
    ) INTO v_valid;
    
    IF NOT v_valid THEN
        RAISE EXCEPTION 'Invalid workflow state transition from % to %', OLD.status, NEW.status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE workflow_transitions IS 'Learn-IQ object lifecycle state machine configuration';
COMMENT ON FUNCTION validate_state_transition IS 'Validates if a state transition is allowed per Learn-IQ workflow';
COMMENT ON FUNCTION get_available_actions IS 'Returns available workflow actions for current state';
