-- ===========================================
-- APPROVAL ENGINE
-- Implements Learn-IQ hierarchical approval
-- Level 1 = highest seniority, 99.99 = lowest
-- Approvers must have LOWER level number than initiators
-- ===========================================

-- Pending approvals queue
CREATE TABLE IF NOT EXISTS pending_approvals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Entity being approved
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_display_name TEXT,
    
    -- Workflow context
    requested_action TEXT NOT NULL,
    current_state workflow_state NOT NULL,
    target_state workflow_state NOT NULL,
    
    -- Initiator info (person who submitted)
    initiated_by UUID NOT NULL,
    initiator_name TEXT,
    initiator_role_level NUMERIC(5,2) NOT NULL,
    initiated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Approval requirements
    requires_approval BOOLEAN DEFAULT true,
    approval_type approval_requirement DEFAULT 'by_approval_group',
    min_approver_level NUMERIC(5,2), -- Must be LOWER than initiator_role_level
    approval_group_id UUID,
    assigned_approver_id UUID,
    
    -- Due date for approval
    due_date TIMESTAMPTZ,
    reminder_sent_at TIMESTAMPTZ,
    
    -- Resolution
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'returned', 'dropped', 'expired', 'cancelled')),
    resolved_by UUID,
    resolver_name TEXT,
    resolver_role_level NUMERIC(5,2),
    resolved_at TIMESTAMPTZ,
    resolution_reason TEXT,
    standard_reason_id UUID,
    esignature_id UUID,
    
    -- Metadata
    plant_id UUID,
    organization_id UUID,
    comments TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pending_approvals_status ON pending_approvals(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_pending_approvals_entity ON pending_approvals(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_pending_approvals_initiated_by ON pending_approvals(initiated_by);
CREATE INDEX IF NOT EXISTS idx_pending_approvals_org ON pending_approvals(organization_id);
CREATE INDEX IF NOT EXISTS idx_pending_approvals_due ON pending_approvals(due_date) WHERE status = 'pending';

-- Approval history (for multiple approval levels if needed)
CREATE TABLE IF NOT EXISTS approval_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pending_approval_id UUID NOT NULL REFERENCES pending_approvals(id),
    
    -- Action taken
    action TEXT NOT NULL CHECK (action IN ('viewed', 'commented', 'approved', 'returned', 'dropped', 'reassigned', 'escalated')),
    
    -- Actor
    performed_by UUID NOT NULL,
    performer_name TEXT,
    performer_role_level NUMERIC(5,2),
    
    -- Details
    comments TEXT,
    esignature_id UUID,
    
    -- Timestamp
    performed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_approval_history_pending ON approval_history(pending_approval_id);

-- Function to check if user can approve (Learn-IQ level system)
-- CRITICAL: Level 1 = highest authority, Level 99.99 = lowest
-- Approvers must have LOWER level number than initiators
CREATE OR REPLACE FUNCTION can_user_approve(
    p_approval_id UUID,
    p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_approval pending_approvals%ROWTYPE;
    v_user_level NUMERIC(5,2);
BEGIN
    -- Get approval details
    SELECT * INTO v_approval FROM pending_approvals WHERE id = p_approval_id;
    
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;
    
    -- Already resolved
    IF v_approval.status != 'pending' THEN
        RETURN FALSE;
    END IF;
    
    -- User cannot approve their own submission
    IF v_approval.initiated_by = p_user_id THEN
        RETURN FALSE;
    END IF;
    
    -- Get user's role level (lowest level value = highest authority)
    -- We use MIN because if user has multiple roles, their highest authority applies
    SELECT MIN(r.level) INTO v_user_level
    FROM employee_roles er
    JOIN roles r ON r.id = er.role_id
    WHERE er.employee_id = p_user_id
      AND r.is_active = true;
    
    IF v_user_level IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- ===========================================
    -- LEARN-IQ CORE RULE:
    -- Approver must have LOWER level number (higher authority)
    -- Example: Level 5 user CANNOT approve Level 10 user's work
    --          Level 5 user CAN approve Level 10 user's work (5 < 10)
    -- ===========================================
    IF v_user_level >= v_approval.initiator_role_level THEN
        RETURN FALSE;
    END IF;
    
    -- Check minimum approver level if specified
    IF v_approval.min_approver_level IS NOT NULL AND v_user_level > v_approval.min_approver_level THEN
        RETURN FALSE;
    END IF;
    
    -- Check if specific approver is assigned
    IF v_approval.assigned_approver_id IS NOT NULL AND v_approval.assigned_approver_id != p_user_id THEN
        RETURN FALSE;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get pending approvals for a user
CREATE OR REPLACE FUNCTION get_pending_approvals_for_user(
    p_user_id UUID
) RETURNS TABLE (
    approval_id UUID,
    entity_type TEXT,
    entity_id UUID,
    entity_display_name TEXT,
    requested_action TEXT,
    initiator_name TEXT,
    initiated_at TIMESTAMPTZ,
    due_date TIMESTAMPTZ,
    is_overdue BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pa.id,
        pa.entity_type,
        pa.entity_id,
        pa.entity_display_name,
        pa.requested_action,
        pa.initiator_name,
        pa.initiated_at,
        pa.due_date,
        CASE WHEN pa.due_date < NOW() THEN TRUE ELSE FALSE END
    FROM pending_approvals pa
    WHERE pa.status = 'pending'
      AND can_user_approve(pa.id, p_user_id)
    ORDER BY 
        CASE WHEN pa.due_date < NOW() THEN 0 ELSE 1 END,
        pa.initiated_at ASC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to submit entity for approval
CREATE OR REPLACE FUNCTION submit_for_approval(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_entity_display_name TEXT,
    p_action TEXT,
    p_requires_approval BOOLEAN DEFAULT true,
    p_approval_type approval_requirement DEFAULT 'by_approval_group',
    p_approval_group_id UUID DEFAULT NULL,
    p_due_date TIMESTAMPTZ DEFAULT NULL,
    p_comments TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_approval_id UUID;
    v_user_id UUID;
    v_user_name TEXT;
    v_user_level NUMERIC(5,2);
    v_current_state workflow_state;
    v_target_state workflow_state;
    v_org_id UUID;
    v_plant_id UUID;
BEGIN
    -- Get current user
    v_user_id := get_current_user_id();
    v_org_id := get_current_org_id();
    v_plant_id := get_current_plant_id();
    
    -- Get user's name and lowest role level
    SELECT 
        e.first_name || ' ' || e.last_name,
        MIN(r.level)
    INTO v_user_name, v_user_level
    FROM employees e
    LEFT JOIN employee_roles er ON er.employee_id = e.id
    LEFT JOIN roles r ON r.id = er.role_id AND r.is_active = true
    WHERE e.id = v_user_id
    GROUP BY e.id, e.first_name, e.last_name;
    
    IF v_user_level IS NULL THEN
        v_user_level := 99.99; -- Default to lowest level if no role assigned
    END IF;
    
    -- Get current state from entity (assumes 'status' column)
    EXECUTE format(
        'SELECT status FROM %I WHERE id = $1',
        p_entity_type
    ) INTO v_current_state USING p_entity_id;
    
    -- Get target state from workflow transitions
    SELECT to_state INTO v_target_state
    FROM workflow_transitions
    WHERE from_state = v_current_state 
      AND action_name = p_action
    LIMIT 1;
    
    -- If no approval required, set target to active
    IF NOT p_requires_approval AND v_target_state = 'pending_approval' THEN
        v_target_state := 'active';
    END IF;
    
    -- Create pending approval record
    INSERT INTO pending_approvals (
        entity_type, entity_id, entity_display_name,
        requested_action, current_state, target_state,
        initiated_by, initiator_name, initiator_role_level,
        requires_approval, approval_type, approval_group_id,
        due_date, comments,
        status, organization_id, plant_id
    ) VALUES (
        p_entity_type, p_entity_id, p_entity_display_name,
        p_action, COALESCE(v_current_state, 'initiated'), COALESCE(v_target_state, 'pending_approval'),
        v_user_id, v_user_name, v_user_level,
        p_requires_approval, p_approval_type, p_approval_group_id,
        COALESCE(p_due_date, NOW() + INTERVAL '7 days'), p_comments,
        CASE WHEN p_requires_approval THEN 'pending' ELSE 'approved' END,
        v_org_id, v_plant_id
    )
    RETURNING id INTO v_approval_id;
    
    -- Update entity state to pending_approval (if requires approval)
    IF p_requires_approval THEN
        EXECUTE format(
            'UPDATE %I SET status = $1, updated_at = NOW() WHERE id = $2',
            p_entity_type
        ) USING 'pending_approval', p_entity_id;
    ELSE
        -- Auto-approve and activate
        EXECUTE format(
            'UPDATE %I SET status = $1, updated_at = NOW() WHERE id = $2',
            p_entity_type
        ) USING 'active', p_entity_id;
        
        -- Mark approval as resolved
        UPDATE pending_approvals SET
            status = 'approved',
            resolved_by = v_user_id,
            resolver_name = 'System (Auto-approved)',
            resolved_at = NOW()
        WHERE id = v_approval_id;
    END IF;
    
    RETURN v_approval_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to resolve approval (approve/return/drop)
CREATE OR REPLACE FUNCTION resolve_approval(
    p_approval_id UUID,
    p_decision approval_decision,
    p_reason TEXT DEFAULT NULL,
    p_standard_reason_id UUID DEFAULT NULL,
    p_esignature_id UUID DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_approval pending_approvals%ROWTYPE;
    v_user_id UUID;
    v_user_name TEXT;
    v_user_level NUMERIC(5,2);
    v_new_status TEXT;
    v_new_state workflow_state;
BEGIN
    v_user_id := get_current_user_id();
    
    -- Check authorization using Learn-IQ level rules
    IF NOT can_user_approve(p_approval_id, v_user_id) THEN
        RAISE EXCEPTION 'User not authorized to approve this request. Approver must have lower role level than initiator.';
    END IF;
    
    -- Get approval record
    SELECT * INTO v_approval FROM pending_approvals WHERE id = p_approval_id AND status = 'pending';
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pending approval not found or already resolved';
    END IF;
    
    -- Get resolver info
    SELECT 
        e.first_name || ' ' || e.last_name,
        MIN(r.level)
    INTO v_user_name, v_user_level
    FROM employees e
    LEFT JOIN employee_roles er ON er.employee_id = e.id
    LEFT JOIN roles r ON r.id = er.role_id AND r.is_active = true
    WHERE e.id = v_user_id
    GROUP BY e.id, e.first_name, e.last_name;
    
    -- Determine new status and entity state based on decision
    CASE p_decision
        WHEN 'approve' THEN
            v_new_status := 'approved';
            v_new_state := v_approval.target_state;
            -- If target is 'approved', move to 'active' automatically
            IF v_new_state = 'approved' THEN
                v_new_state := 'active';
            END IF;
        WHEN 'return' THEN
            v_new_status := 'returned';
            v_new_state := 'returned';
        WHEN 'drop' THEN
            v_new_status := 'dropped';
            v_new_state := 'dropped';
    END CASE;
    
    -- Update approval record
    UPDATE pending_approvals SET
        status = v_new_status,
        resolved_by = v_user_id,
        resolver_name = v_user_name,
        resolver_role_level = v_user_level,
        resolved_at = NOW(),
        resolution_reason = p_reason,
        standard_reason_id = p_standard_reason_id,
        esignature_id = p_esignature_id,
        updated_at = NOW()
    WHERE id = p_approval_id;
    
    -- Update entity state
    EXECUTE format(
        'UPDATE %I SET status = $1, updated_at = NOW() WHERE id = $2',
        v_approval.entity_type
    ) USING v_new_state::TEXT, v_approval.entity_id;
    
    -- Record in approval history
    INSERT INTO approval_history (
        pending_approval_id, action, performed_by, performer_name,
        performer_role_level, comments, esignature_id
    ) VALUES (
        p_approval_id, p_decision::TEXT, v_user_id, v_user_name,
        v_user_level, p_reason, p_esignature_id
    );
    
    -- Create audit trail entry
    INSERT INTO audit_trails (
        entity_type, entity_id, action, action_category,
        new_value, performed_by, performed_by_name, reason,
        organization_id, plant_id
    ) VALUES (
        v_approval.entity_type, v_approval.entity_id, 
        'approval_' || p_decision::TEXT, 'approval',
        jsonb_build_object(
            'decision', p_decision,
            'previous_state', v_approval.current_state,
            'new_state', v_new_state,
            'resolver_level', v_user_level,
            'initiator_level', v_approval.initiator_role_level
        ),
        v_user_id, v_user_name, p_reason,
        v_approval.organization_id, v_approval.plant_id
    );
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get approval status summary for dashboard
CREATE OR REPLACE FUNCTION get_approval_dashboard_summary(
    p_user_id UUID DEFAULT NULL
) RETURNS TABLE (
    pending_count BIGINT,
    overdue_count BIGINT,
    approved_today BIGINT,
    returned_today BIGINT
) AS $$
DECLARE
    v_user_id UUID;
BEGIN
    v_user_id := COALESCE(p_user_id, get_current_user_id());
    
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM pending_approvals pa WHERE pa.status = 'pending' AND can_user_approve(pa.id, v_user_id)),
        (SELECT COUNT(*) FROM pending_approvals pa WHERE pa.status = 'pending' AND pa.due_date < NOW() AND can_user_approve(pa.id, v_user_id)),
        (SELECT COUNT(*) FROM pending_approvals WHERE status = 'approved' AND resolved_at::DATE = CURRENT_DATE AND resolved_by = v_user_id),
        (SELECT COUNT(*) FROM pending_approvals WHERE status = 'returned' AND resolved_at::DATE = CURRENT_DATE AND resolved_by = v_user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE pending_approvals IS 'Learn-IQ approval queue with hierarchical level-based authorization';
COMMENT ON FUNCTION can_user_approve IS 'Enforces Learn-IQ rule: approver must have LOWER level number (higher authority) than initiator';
COMMENT ON FUNCTION resolve_approval IS 'Process approval decisions: approve (latest version), return (reinitiate), drop (earlier version)';
