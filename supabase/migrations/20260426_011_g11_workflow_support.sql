-- ===========================================
-- G11: WORKFLOW & LIFECYCLE SUPPORT FUNCTIONS
-- Adds missing RPC + columns for S7 implementation
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. FUNCTION: get_employee_permissions
-- Returns TEXT[] of permissions for JWT embedding in auth-hook
-- Format: ['module.action', 'module.action', ...]
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_employee_permissions(p_employee_id UUID)
RETURNS TEXT[]
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_perms TEXT[];
BEGIN
    SELECT ARRAY_AGG(DISTINCT p.module || '.' || p.action)
    INTO v_perms
    FROM permissions p
    JOIN employee_roles er ON er.role_id = p.role_id
    JOIN roles r ON r.id = er.role_id AND r.is_active = TRUE
    WHERE er.employee_id = p_employee_id
      AND p.is_allowed = TRUE;
    
    RETURN COALESCE(v_perms, ARRAY[]::TEXT[]);
END;
$$;

COMMENT ON FUNCTION get_employee_permissions IS 
    'Returns array of permission strings (module.action) for embedding in JWT claims';

-- ---------------------------------------------------------------------------
-- 2. ALTER approval_steps: Add escalation tracking
-- ---------------------------------------------------------------------------
ALTER TABLE approval_steps
ADD COLUMN IF NOT EXISTS escalation_sent_at TIMESTAMPTZ;

ALTER TABLE approval_steps
ADD COLUMN IF NOT EXISTS escalation_level INTEGER DEFAULT 0;

ALTER TABLE approval_steps
ADD COLUMN IF NOT EXISTS min_approval_tier INTEGER;

COMMENT ON COLUMN approval_steps.escalation_sent_at IS 
    'When escalation notification was sent (NULL = not escalated yet)';
COMMENT ON COLUMN approval_steps.escalation_level IS 
    'How many times this step has been escalated (0 = not escalated)';
COMMENT ON COLUMN approval_steps.min_approval_tier IS 
    'Minimum role tier required to approve this step (from matrix)';

-- ---------------------------------------------------------------------------
-- 3. ALTER events_outbox: Add dead letter alerting
-- ---------------------------------------------------------------------------
ALTER TABLE events_outbox
ADD COLUMN IF NOT EXISTS dead_letter_alerted_at TIMESTAMPTZ;

COMMENT ON COLUMN events_outbox.dead_letter_alerted_at IS 
    'When super_admin was notified about this dead letter event';

-- ---------------------------------------------------------------------------
-- 4. FUNCTION: seed_approval_steps
-- Creates approval_steps rows from approval_matrix_steps template
-- Called by workflow_engine on first submission
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION seed_approval_steps(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_organization_id UUID,
    p_plant_id UUID DEFAULT NULL
)
RETURNS TABLE (
    steps_created INTEGER,
    matrix_id UUID,
    is_serial BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_matrix RECORD;
    v_count INTEGER := 0;
BEGIN
    -- Find applicable approval matrix
    SELECT am.* INTO v_matrix
    FROM approval_matrices am
    WHERE am.organization_id = p_organization_id
      AND am.entity_type = p_entity_type
      AND am.is_active = TRUE
      AND (am.plant_id IS NULL OR am.plant_id = p_plant_id)
    ORDER BY am.plant_id NULLS LAST  -- Plant-specific takes precedence
    LIMIT 1;
    
    -- If no matrix, return 0 (auto-approve case)
    IF v_matrix IS NULL THEN
        RETURN QUERY SELECT 0, NULL::UUID, TRUE;
        RETURN;
    END IF;
    
    -- Check if steps already exist (idempotency)
    IF EXISTS (
        SELECT 1 FROM approval_steps 
        WHERE entity_type = p_entity_type 
        AND entity_id = p_entity_id
    ) THEN
        -- Return existing count
        SELECT COUNT(*) INTO v_count 
        FROM approval_steps 
        WHERE entity_type = p_entity_type 
        AND entity_id = p_entity_id;
        
        RETURN QUERY SELECT v_count, v_matrix.id, v_matrix.is_serial;
        RETURN;
    END IF;
    
    -- Seed steps from matrix template
    INSERT INTO approval_steps (
        organization_id,
        entity_type,
        entity_id,
        step_order,
        step_name,
        required_role,
        min_approval_tier,
        status,
        created_at
    )
    SELECT 
        p_organization_id,
        p_entity_type,
        p_entity_id,
        ams.step_order,
        ams.step_name,
        ams.required_role,
        ams.min_approval_tier,
        'pending',
        NOW()
    FROM approval_matrix_steps ams
    WHERE ams.matrix_id = v_matrix.id
      AND ams.is_active = TRUE
    ORDER BY ams.step_order;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    
    RETURN QUERY SELECT v_count, v_matrix.id, v_matrix.is_serial;
END;
$$;

COMMENT ON FUNCTION seed_approval_steps IS 
    'Creates approval_steps instances from approval_matrix_steps template for a submitted entity';

-- ---------------------------------------------------------------------------
-- 5. FUNCTION: get_next_pending_step
-- Returns the next step requiring approval
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_next_pending_step(
    p_entity_type TEXT,
    p_entity_id UUID
)
RETURNS TABLE (
    step_id UUID,
    step_order INTEGER,
    step_name TEXT,
    required_role TEXT,
    min_approval_tier INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        as_step.id,
        as_step.step_order,
        as_step.step_name,
        as_step.required_role,
        as_step.min_approval_tier,
        as_step.created_at
    FROM approval_steps as_step
    WHERE as_step.entity_type = p_entity_type
      AND as_step.entity_id = p_entity_id
      AND as_step.status = 'pending'
    ORDER BY as_step.step_order
    LIMIT 1;
END;
$$;

COMMENT ON FUNCTION get_next_pending_step IS 
    'Returns the next pending approval step for an entity (lowest step_order)';

-- ---------------------------------------------------------------------------
-- 6. FUNCTION: check_approval_complete
-- Returns TRUE if all steps are approved/skipped
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_approval_complete(
    p_entity_type TEXT,
    p_entity_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_pending_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_pending_count
    FROM approval_steps
    WHERE entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND status = 'pending';
    
    RETURN v_pending_count = 0;
END;
$$;

COMMENT ON FUNCTION check_approval_complete IS 
    'Returns TRUE when all approval steps are approved or skipped';

-- ---------------------------------------------------------------------------
-- 7. FUNCTION: approve_step
-- Marks a step as approved with e-signature
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION approve_step(
    p_step_id UUID,
    p_approved_by UUID,
    p_esignature_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_step RECORD;
BEGIN
    -- Get step details
    SELECT * INTO v_step
    FROM approval_steps
    WHERE id = p_step_id;
    
    IF v_step IS NULL THEN
        RAISE EXCEPTION 'Approval step not found: %', p_step_id;
    END IF;
    
    IF v_step.status != 'pending' THEN
        RAISE EXCEPTION 'Step is not pending: current status = %', v_step.status;
    END IF;
    
    -- Update the step
    UPDATE approval_steps
    SET status = 'approved',
        approved_by = p_approved_by,
        approved_at = NOW(),
        esignature_id = p_esignature_id,
        updated_at = NOW()
    WHERE id = p_step_id;
    
    RETURN TRUE;
END;
$$;

COMMENT ON FUNCTION approve_step IS 
    'Marks an approval step as approved with optional e-signature';

-- ---------------------------------------------------------------------------
-- 8. FUNCTION: reject_step
-- Marks a step as rejected and cancels remaining steps
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reject_step(
    p_step_id UUID,
    p_rejected_by UUID,
    p_reason TEXT,
    p_esignature_id UUID DEFAULT NULL
)
RETURNS TABLE (
    cancelled_steps INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_step RECORD;
    v_cancelled INTEGER;
BEGIN
    -- Get step details
    SELECT * INTO v_step
    FROM approval_steps
    WHERE id = p_step_id;
    
    IF v_step IS NULL THEN
        RAISE EXCEPTION 'Approval step not found: %', p_step_id;
    END IF;
    
    IF v_step.status != 'pending' THEN
        RAISE EXCEPTION 'Step is not pending: current status = %', v_step.status;
    END IF;
    
    -- Reject the step
    UPDATE approval_steps
    SET status = 'rejected',
        approved_by = p_rejected_by,  -- "approved_by" is really "actioned_by"
        approved_at = NOW(),
        rejection_reason = p_reason,
        esignature_id = p_esignature_id,
        updated_at = NOW()
    WHERE id = p_step_id;
    
    -- Cancel all other pending steps for this entity
    UPDATE approval_steps
    SET status = 'skipped',
        updated_at = NOW()
    WHERE entity_type = v_step.entity_type
      AND entity_id = v_step.entity_id
      AND id != p_step_id
      AND status = 'pending';
    
    GET DIAGNOSTICS v_cancelled = ROW_COUNT;
    
    RETURN QUERY SELECT v_cancelled;
END;
$$;

COMMENT ON FUNCTION reject_step IS 
    'Rejects an approval step and cancels remaining pending steps';

-- ---------------------------------------------------------------------------
-- 9. FUNCTION: skip_parallel_steps
-- For parallel approval: skip remaining steps at same step_order when quorum met
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION skip_parallel_steps(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_step_order INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_skipped INTEGER;
BEGIN
    UPDATE approval_steps
    SET status = 'skipped',
        updated_at = NOW()
    WHERE entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND step_order = p_step_order
      AND status = 'pending';
    
    GET DIAGNOSTICS v_skipped = ROW_COUNT;
    RETURN v_skipped;
END;
$$;

COMMENT ON FUNCTION skip_parallel_steps IS 
    'Skips remaining pending steps at a step_order when quorum is satisfied (parallel approval)';

-- ---------------------------------------------------------------------------
-- 10. FUNCTION: get_escalation_candidates
-- Returns approval steps needing escalation
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_escalation_candidates(
    p_escalation_days INTEGER DEFAULT 3
)
RETURNS TABLE (
    step_id UUID,
    entity_type TEXT,
    entity_id UUID,
    organization_id UUID,
    step_name TEXT,
    required_role TEXT,
    days_pending INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        as_step.id,
        as_step.entity_type,
        as_step.entity_id,
        as_step.organization_id,
        as_step.step_name,
        as_step.required_role,
        EXTRACT(DAY FROM NOW() - as_step.created_at)::INTEGER AS days_pending
    FROM approval_steps as_step
    WHERE as_step.status = 'pending'
      AND as_step.escalation_sent_at IS NULL
      AND as_step.created_at < NOW() - (p_escalation_days || ' days')::INTERVAL;
END;
$$;

COMMENT ON FUNCTION get_escalation_candidates IS 
    'Returns pending approval steps older than N days that haven''t been escalated yet';

-- ---------------------------------------------------------------------------
-- 11. INDEX for escalation queries
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_approval_steps_escalation
ON approval_steps(created_at)
WHERE status = 'pending' AND escalation_sent_at IS NULL;

-- ---------------------------------------------------------------------------
-- 12. FUNCTION: get_dead_letter_events
-- Returns dead letter events that haven't been alerted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_dead_letter_events()
RETURNS TABLE (
    event_id UUID,
    event_type TEXT,
    aggregate_type TEXT,
    aggregate_id UUID,
    organization_id UUID,
    error_text TEXT,
    retry_count INTEGER,
    created_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        eo.id,
        eo.event_type,
        eo.aggregate_type,
        eo.aggregate_id,
        eo.organization_id,
        eo.error_text,
        eo.retry_count,
        eo.created_at
    FROM events_outbox eo
    WHERE eo.is_dead_letter = TRUE
      AND eo.dead_letter_alerted_at IS NULL;
END;
$$;

COMMENT ON FUNCTION get_dead_letter_events IS 
    'Returns dead letter events that need admin alerting';

-- ---------------------------------------------------------------------------
-- 13. FUNCTION: mark_dead_letter_alerted
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_dead_letter_alerted(p_event_id UUID)
RETURNS VOID
LANGUAGE SQL
SECURITY DEFINER
AS $$
    UPDATE events_outbox
    SET dead_letter_alerted_at = NOW()
    WHERE id = p_event_id;
$$;

COMMENT ON FUNCTION mark_dead_letter_alerted IS 
    'Marks a dead letter event as having been alerted to admin';
