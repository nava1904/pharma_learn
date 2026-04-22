-- ===========================================
-- G10: MISSING RPC FUNCTIONS CALLED BY HANDLERS
-- These functions are invoked via supabase.rpc() but don't exist
-- ===========================================

-- ---------------------------------------------------------------------------
-- 0a. notifications table - in-app notification store
-- Used by: mark_overdue_reviews, notification_handler.dart
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    type TEXT NOT NULL,           -- e.g. 'training_overdue', 'cert_expiring', 'approval_required'
    title TEXT NOT NULL,
    message TEXT,
    data JSONB DEFAULT '{}'::JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications(employee_id);
CREATE INDEX IF NOT EXISTS idx_notifications_org ON notifications(organization_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(employee_id) WHERE is_read = FALSE;

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
CREATE POLICY notifications_select ON notifications FOR SELECT
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY notifications_insert ON notifications FOR INSERT
    WITH CHECK (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);
CREATE POLICY notifications_update ON notifications FOR UPDATE
    USING (organization_id = (current_setting('app.current_organization_id', TRUE))::UUID);

COMMENT ON TABLE notifications IS 'In-app notifications for employees (training overdue, cert expiry, approvals)';

-- Add last_run_at tracking column to retention_policies
ALTER TABLE retention_policies
    ADD COLUMN IF NOT EXISTS last_run_at TIMESTAMPTZ;

-- ---------------------------------------------------------------------------
-- 0b. ALTER user_credentials: Add login tracking columns used by auth RPCs
-- ---------------------------------------------------------------------------
ALTER TABLE user_credentials
    ADD COLUMN IF NOT EXISTS last_login_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_failed_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS last_failed_ip TEXT;

-- ---------------------------------------------------------------------------
-- 1. check_account_lock - Returns whether a user account is locked
-- Used by: auth handlers before allowing login
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_account_lock(
    p_employee_id UUID
)
RETURNS TABLE (
    is_locked BOOLEAN,
    locked_at TIMESTAMPTZ,
    lock_reason TEXT,
    failed_attempts INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        uc.locked_at IS NOT NULL AS is_locked,
        uc.locked_at,
        CASE 
            WHEN uc.locked_at IS NOT NULL AND uc.failed_attempts >= 5 
            THEN 'Too many failed login attempts'
            WHEN uc.locked_at IS NOT NULL 
            THEN 'Account locked by administrator'
            ELSE NULL
        END AS lock_reason,
        COALESCE(uc.failed_attempts, 0) AS failed_attempts
    FROM user_credentials uc
    WHERE uc.employee_id = p_employee_id;
    
    -- If no record found, return unlocked state
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, NULL::TIMESTAMPTZ, NULL::TEXT, 0;
    END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. cleanup_expired_sessions - Removes expired sessions
-- Used by: session_cleanup_handler.dart (lifecycle_monitor cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS TABLE (
    deleted_count INTEGER,
    revoked_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_deleted INTEGER;
    v_revoked INTEGER;
BEGIN
    -- Delete expired sessions
    WITH deleted AS (
        DELETE FROM user_sessions
        WHERE expires_at < NOW()
        RETURNING id
    )
    SELECT COUNT(*) INTO v_deleted FROM deleted;
    
    -- Revoke sessions that haven't been active in 24 hours (for active session types)
    WITH revoked AS (
        UPDATE user_sessions
        SET revoked_at = NOW(),
            revoked_reason = 'Inactive timeout'
        WHERE revoked_at IS NULL
          AND last_activity_at < NOW() - INTERVAL '24 hours'
        RETURNING id
    )
    SELECT COUNT(*) INTO v_revoked FROM revoked;
    
    -- Also clean up expired SSO auth states
    DELETE FROM sso_auth_states WHERE expires_at < NOW();
    
    -- Clean up expired QR tokens
    UPDATE training_sessions
    SET qr_token = NULL, qr_expires_at = NULL
    WHERE qr_expires_at < NOW();
    
    RETURN QUERY SELECT v_deleted, v_revoked;
END;
$$;

-- ---------------------------------------------------------------------------
-- 3. clear_failed_attempts - Resets failed login counter on success
-- Used by: login success path
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION clear_failed_attempts(
    p_employee_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE user_credentials
    SET failed_attempts = 0,
        locked_at = NULL,
        last_login_at = NOW()
    WHERE employee_id = p_employee_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- 4. record_failed_login - Increments failed counter, locks if threshold reached
-- Used by: login failure path
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION record_failed_login(
    p_employee_id UUID,
    p_ip_address TEXT DEFAULT NULL
)
RETURNS TABLE (
    new_failed_count INTEGER,
    is_now_locked BOOLEAN,
    remaining_attempts INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_failed_attempts INTEGER;
    v_lock_threshold INTEGER := 5;  -- Could be from system_settings
    v_is_locked BOOLEAN;
BEGIN
    -- Increment failed attempts
    UPDATE user_credentials
    SET failed_attempts = COALESCE(failed_attempts, 0) + 1,
        last_failed_at = NOW(),
        last_failed_ip = p_ip_address
    WHERE employee_id = p_employee_id
    RETURNING failed_attempts INTO v_failed_attempts;
    
    -- Lock if threshold reached
    IF v_failed_attempts >= v_lock_threshold THEN
        UPDATE user_credentials
        SET locked_at = NOW()
        WHERE employee_id = p_employee_id
          AND locked_at IS NULL;
        v_is_locked := TRUE;
    ELSE
        v_is_locked := FALSE;
    END IF;
    
    RETURN QUERY SELECT 
        v_failed_attempts,
        v_is_locked,
        GREATEST(0, v_lock_threshold - v_failed_attempts);
END;
$$;

-- ---------------------------------------------------------------------------
-- 5. create_biometric_session - Creates short-lived biometric challenge
-- Used by: biometric_handler.dart
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_biometric_session(
    p_employee_id UUID,
    p_credential_type TEXT
)
RETURNS TABLE (
    session_id UUID,
    challenge TEXT,
    expires_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := uuid_generate_v4();
    v_challenge TEXT;
    v_expires TIMESTAMPTZ := NOW() + INTERVAL '2 minutes';
BEGIN
    -- Generate random challenge
    v_challenge := encode(gen_random_bytes(32), 'base64');
    
    -- Store in temporary table or reuse sso_auth_states
    INSERT INTO sso_auth_states (
        id,
        state,
        nonce,
        employee_id,
        expires_at
    ) VALUES (
        v_session_id,
        'biometric:' || v_session_id::TEXT,
        v_challenge,
        p_employee_id,
        v_expires
    );
    
    RETURN QUERY SELECT v_session_id, v_challenge, v_expires;
END;
$$;

-- ---------------------------------------------------------------------------
-- 6. create_sso_session - Creates SSO auth state and returns session info
-- Used by: sso_handler.dart
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_sso_session(
    p_provider_id UUID,
    p_organization_id UUID,
    p_redirect_uri TEXT DEFAULT NULL,
    p_target_url TEXT DEFAULT NULL
)
RETURNS TABLE (
    session_id UUID,
    state TEXT,
    nonce TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session_id UUID := uuid_generate_v4();
    v_state TEXT;
    v_nonce TEXT;
BEGIN
    -- Generate cryptographic state and nonce
    v_state := encode(gen_random_bytes(32), 'hex');
    v_nonce := encode(gen_random_bytes(16), 'hex');
    
    INSERT INTO sso_auth_states (
        id,
        organization_id,
        provider_id,
        state,
        nonce,
        redirect_uri,
        target_url,
        expires_at
    ) VALUES (
        v_session_id,
        p_organization_id,
        p_provider_id,
        v_state,
        v_nonce,
        p_redirect_uri,
        p_target_url,
        NOW() + INTERVAL '10 minutes'
    );
    
    RETURN QUERY SELECT v_session_id, v_state, v_nonce;
END;
$$;

-- ---------------------------------------------------------------------------
-- 7. get_next_sequence_number - Wrapper for get_next_number by entity type
-- Used by: various handlers that need sequence numbers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_next_sequence_number(
    p_entity_type TEXT,
    p_organization_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_scheme_id UUID;
    v_org_code TEXT;
    v_number TEXT;
BEGIN
    -- Get the default numbering scheme for this entity type
    SELECT id INTO v_scheme_id
    FROM numbering_schemes
    WHERE organization_id = p_organization_id
      AND entity_type = p_entity_type
      AND is_default = TRUE
      AND is_active = TRUE
    LIMIT 1;
    
    IF v_scheme_id IS NULL THEN
        RAISE EXCEPTION 'No default numbering scheme found for entity type: %', p_entity_type;
    END IF;
    
    -- Get org code
    SELECT short_code INTO v_org_code
    FROM organizations
    WHERE id = p_organization_id;
    
    -- Call existing get_next_number function
    SELECT get_next_number(v_scheme_id, v_org_code) INTO v_number;
    
    RETURN v_number;
END;
$$;

-- ---------------------------------------------------------------------------
-- 8a. audit_trails_archive - Archive table for old audit records (21 CFR §11.10)
-- Must exist before process_retention_policies can insert into it
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_trails_archive (
    LIKE audit_trails INCLUDING ALL
);
ALTER TABLE audit_trails_archive ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ DEFAULT NOW();
COMMENT ON TABLE audit_trails_archive IS '21 CFR §11.10 long-term archive of audit trail records past retention window';

-- ---------------------------------------------------------------------------
-- 8. process_retention_policies - Archives records past retention period
-- Used by: archive_job_handler.dart (lifecycle_monitor cron)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION process_retention_policies(
    p_organization_id UUID DEFAULT NULL
)
RETURNS TABLE (
    entity_type TEXT,
    archived_count INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_policy RECORD;
    v_count INTEGER;
BEGIN
    -- Process each active retention policy
    FOR v_policy IN
        SELECT rp.*
        FROM retention_policies rp
        WHERE rp.is_active = TRUE
          AND (p_organization_id IS NULL OR rp.organization_id = p_organization_id)
    LOOP
        v_count := 0;
        
        -- Handle different entity types
        CASE v_policy.entity_type
            WHEN 'audit_trails' THEN
                -- Move old audit trails to archive table
                WITH archived AS (
                    INSERT INTO audit_trails_archive
                    SELECT * FROM audit_trails
                    WHERE organization_id = v_policy.organization_id
                      AND occurred_at < NOW() - (v_policy.retention_years || ' years')::INTERVAL
                    RETURNING id
                )
                SELECT COUNT(*) INTO v_count FROM archived;
                
                -- Delete archived records
                DELETE FROM audit_trails
                WHERE organization_id = v_policy.organization_id
                  AND occurred_at < NOW() - (v_policy.retention_years || ' years')::INTERVAL;
                  
            WHEN 'user_sessions' THEN
                WITH deleted AS (
                    DELETE FROM user_sessions
                    WHERE organization_id = v_policy.organization_id
                      AND (expires_at < NOW() - (v_policy.retention_years || ' years')::INTERVAL
                           OR revoked_at < NOW() - (v_policy.retention_years || ' years')::INTERVAL)
                    RETURNING id
                )
                SELECT COUNT(*) INTO v_count FROM deleted;
                
            WHEN 'notifications' THEN
                WITH deleted AS (
                    DELETE FROM notifications
                    WHERE organization_id = v_policy.organization_id
                      AND read_at IS NOT NULL
                      AND created_at < NOW() - (v_policy.retention_years || ' years')::INTERVAL
                    RETURNING id
                )
                SELECT COUNT(*) INTO v_count FROM deleted;
                
            ELSE
                -- Log unknown entity type but continue
                RAISE NOTICE 'Unknown retention entity type: %', v_policy.entity_type;
        END CASE;
        
        -- Update last_run timestamp
        UPDATE retention_policies
        SET last_run_at = NOW()
        WHERE id = v_policy.id;
        
        -- Return result for this policy
        RETURN QUERY SELECT v_policy.entity_type, v_count;
    END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- 9. verify_audit_hash_chain - Verifies integrity of audit trail
-- Used by: integrity_check_handler.dart (lifecycle_monitor cron)
-- Already referenced in G5, adding if not exists
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION verify_audit_hash_chain(
    p_organization_id UUID DEFAULT NULL
)
RETURNS TABLE (
    is_valid BOOLEAN,
    records_checked INTEGER,
    first_invalid_id UUID,
    error_message TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_count INTEGER := 0;
    v_prev_hash TEXT := NULL;
    v_record RECORD;
    v_computed_hash TEXT;
    v_is_valid BOOLEAN := TRUE;
    v_invalid_id UUID;
    v_error TEXT;
BEGIN
    -- Check each audit record in order
    FOR v_record IN
        SELECT id, previous_hash, hash_value, 
               occurred_at, employee_id, action, entity_type, entity_id
        FROM audit_trails
        WHERE (p_organization_id IS NULL OR organization_id = p_organization_id)
        ORDER BY occurred_at, id
    LOOP
        v_count := v_count + 1;
        
        -- Verify previous_hash matches prior record's hash
        IF v_prev_hash IS NOT NULL AND v_record.previous_hash != v_prev_hash THEN
            v_is_valid := FALSE;
            v_invalid_id := v_record.id;
            v_error := 'Previous hash mismatch at record ' || v_record.id::TEXT;
            EXIT;
        END IF;
        
        -- Compute expected hash (simplified - actual implementation uses full record)
        v_computed_hash := encode(
            sha256(
                (v_record.occurred_at::TEXT || v_record.employee_id::TEXT || 
                 v_record.action || v_record.entity_type || 
                 COALESCE(v_record.entity_id::TEXT, '') ||
                 COALESCE(v_prev_hash, ''))::BYTEA
            ),
            'hex'
        );
        
        -- Verify hash matches (if hash_value is stored)
        IF v_record.hash_value IS NOT NULL AND v_record.hash_value != v_computed_hash THEN
            v_is_valid := FALSE;
            v_invalid_id := v_record.id;
            v_error := 'Hash value mismatch at record ' || v_record.id::TEXT;
            EXIT;
        END IF;
        
        v_prev_hash := COALESCE(v_record.hash_value, v_computed_hash);
    END LOOP;
    
    RETURN QUERY SELECT v_is_valid, v_count, v_invalid_id, v_error;
END;
$$;

-- ---------------------------------------------------------------------------
-- 10. mark_overdue_reviews - Marks training assignments as overdue
-- Used by: overdue_training_handler.dart, periodic_review_handler.dart
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_overdue_reviews()
RETURNS TABLE (
    marked_overdue INTEGER,
    notifications_sent INTEGER
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_marked INTEGER;
    v_notified INTEGER := 0;
    v_assignment RECORD;
BEGIN
    -- Mark assignments as overdue where due_date has passed
    WITH marked AS (
        UPDATE employee_assignments
        SET status = 'overdue',
            updated_at = NOW()
        WHERE status IN ('assigned', 'in_progress', 'pending')
          AND due_date < CURRENT_DATE
        RETURNING id, employee_id, assignment_id
    )
    SELECT COUNT(*) INTO v_marked FROM marked;
    
    -- Also mark periodic review schedules as overdue
    UPDATE periodic_review_schedules
    SET status = 'OVERDUE',
        updated_at = NOW()
    WHERE status IN ('PENDING', 'IN_REVIEW')
      AND next_review_due < NOW();
    
    -- Queue notifications for newly overdue items
    FOR v_assignment IN
        SELECT ea.id, ea.employee_id, ea.due_date, ta.course_id, c.title AS course_title
        FROM employee_assignments ea
        JOIN training_assignments ta ON ea.assignment_id = ta.id
        JOIN courses c ON ta.course_id = c.id
        WHERE ea.status = 'overdue'
          AND ea.updated_at > NOW() - INTERVAL '1 hour'  -- Recently marked
    LOOP
        -- Insert notification
        INSERT INTO notifications (
            organization_id,
            employee_id,
            type,
            title,
            message,
            data,
            created_at
        )
        SELECT 
            e.organization_id,
            v_assignment.employee_id,
            'training_overdue',
            'Training Overdue: ' || v_assignment.course_title,
            'Your training "' || v_assignment.course_title || '" was due on ' || 
                v_assignment.due_date::TEXT || ' and is now overdue.',
            jsonb_build_object(
                'assignment_id', v_assignment.id,
                'course_id', v_assignment.course_id,
                'due_date', v_assignment.due_date
            ),
            NOW()
        FROM employees e
        WHERE e.id = v_assignment.employee_id;
        
        v_notified := v_notified + 1;
    END LOOP;
    
    RETURN QUERY SELECT v_marked, v_notified;
END;
$$;

-- ---------------------------------------------------------------------------
-- 11. get_training_coverage - Training coverage stats for dashboard
-- Used by: audit_readiness report
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_training_coverage(
    p_organization_id UUID
)
RETURNS TABLE (
    total_employees INTEGER,
    employees_with_assignments INTEGER,
    employees_fully_compliant INTEGER,
    coverage_percentage NUMERIC(5,2),
    compliance_percentage NUMERIC(5,2)
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH emp_stats AS (
        SELECT 
            e.id,
            COUNT(ea.id) AS total_assignments,
            COUNT(ea.id) FILTER (WHERE ea.status = 'completed') AS completed,
            COUNT(ea.id) FILTER (WHERE ea.status = 'overdue') AS overdue
        FROM employees e
        LEFT JOIN employee_assignments ea ON e.id = ea.employee_id
        WHERE e.organization_id = p_organization_id
          AND e.is_active = TRUE
        GROUP BY e.id
    )
    SELECT
        COUNT(*)::INTEGER AS total_employees,
        COUNT(*) FILTER (WHERE total_assignments > 0)::INTEGER AS employees_with_assignments,
        COUNT(*) FILTER (WHERE total_assignments > 0 AND completed = total_assignments)::INTEGER AS employees_fully_compliant,
        CASE 
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(
                (COUNT(*) FILTER (WHERE total_assignments > 0)::NUMERIC / COUNT(*)::NUMERIC) * 100, 
                2
            )
        END AS coverage_percentage,
        CASE 
            WHEN COUNT(*) FILTER (WHERE total_assignments > 0) = 0 THEN 100
            ELSE ROUND(
                (COUNT(*) FILTER (WHERE total_assignments > 0 AND overdue = 0)::NUMERIC / 
                 COUNT(*) FILTER (WHERE total_assignments > 0)::NUMERIC) * 100,
                2
            )
        END AS compliance_percentage
    FROM emp_stats;
END;
$$;

-- ---------------------------------------------------------------------------
-- Comments
-- ---------------------------------------------------------------------------
COMMENT ON FUNCTION check_account_lock IS 'Checks if employee account is locked due to failed attempts';
COMMENT ON FUNCTION cleanup_expired_sessions IS 'Removes expired sessions and revokes inactive ones';
COMMENT ON FUNCTION clear_failed_attempts IS 'Resets failed login counter after successful login';
COMMENT ON FUNCTION record_failed_login IS 'Records failed login, locks account if threshold reached';
COMMENT ON FUNCTION create_biometric_session IS 'Creates biometric challenge for 2FA';
COMMENT ON FUNCTION create_sso_session IS 'Initiates SSO OAuth flow with state/nonce';
COMMENT ON FUNCTION get_next_sequence_number IS 'Gets next number from default scheme for entity type';
COMMENT ON FUNCTION process_retention_policies IS 'Archives/deletes records per retention policy';
COMMENT ON FUNCTION verify_audit_hash_chain IS 'Verifies integrity of audit trail hash chain';
COMMENT ON FUNCTION mark_overdue_reviews IS 'Marks past-due assignments as overdue and sends notifications';
COMMENT ON FUNCTION get_training_coverage IS 'Returns training coverage statistics for an organization';
