-- ===========================================
-- G8: ATTENDANCE CORRECTION & IMMUTABILITY
-- 21 CFR §11.10 compliant immutable attendance records
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. CREATE TABLE: attendance_corrections
-- Immutable correction pattern - never UPDATE session_attendance after finalization
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS attendance_corrections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Link to original attendance record being corrected
    original_attendance_id UUID NOT NULL REFERENCES session_attendance(id),
    
    -- Session context (denormalized for query performance)
    session_id UUID NOT NULL REFERENCES training_sessions(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    
    -- Corrected values (only populated fields are being corrected)
    corrected_attendance_status attendance_status,
    corrected_check_in_time TIMESTAMPTZ,
    corrected_check_out_time TIMESTAMPTZ,
    corrected_attendance_hours NUMERIC(6,2),
    
    -- Correction metadata (required by 21 CFR §11.10(e))
    correction_reason TEXT NOT NULL,
    corrected_by UUID NOT NULL REFERENCES employees(id),
    corrected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- E-signature for regulatory compliance
    esignature_id UUID REFERENCES electronic_signatures(id),
    
    -- Audit trail link
    audit_trail_id UUID REFERENCES audit_trails(id),
    
    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Organization for RLS (denormalized from session)
    organization_id UUID REFERENCES organizations(id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_attendance_corrections_original 
ON attendance_corrections(original_attendance_id);

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_session 
ON attendance_corrections(session_id);

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_employee 
ON attendance_corrections(employee_id);

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_corrected_by 
ON attendance_corrections(corrected_by);

CREATE INDEX IF NOT EXISTS idx_attendance_corrections_org 
ON attendance_corrections(organization_id);

-- Audit trigger
DROP TRIGGER IF EXISTS trg_attendance_corrections_audit ON attendance_corrections;
CREATE TRIGGER trg_attendance_corrections_audit 
    AFTER INSERT OR UPDATE OR DELETE ON attendance_corrections 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- ---------------------------------------------------------------------------
-- 2. IMMUTABILITY TRIGGER: session_attendance
-- Block UPDATE/DELETE after attendance has been marked (status != NULL)
-- Force use of attendance_corrections table for corrections
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION session_attendance_immutable() 
RETURNS TRIGGER AS $$
BEGIN
    -- Only block if the original record has been finalized (has a status)
    IF TG_OP = 'DELETE' THEN
        IF OLD.attendance_status IS NOT NULL THEN
            RAISE EXCEPTION 'session_attendance records are immutable after check-in. Record id: %. Use attendance_corrections table instead.', OLD.id
                USING HINT = '21 CFR Part 11 requires immutable audit trails. Insert a correction record instead of modifying the original.';
        END IF;
        RETURN OLD;
    END IF;
    
    IF TG_OP = 'UPDATE' THEN
        -- Allow updates if original had no status (not yet checked in)
        IF OLD.attendance_status IS NULL THEN
            RETURN NEW;
        END IF;
        
        -- Allow updates that only modify allowed fields (reminder tracking)
        IF OLD.attendance_status = NEW.attendance_status 
           AND OLD.check_in_time IS NOT DISTINCT FROM NEW.check_in_time
           AND OLD.check_out_time IS NOT DISTINCT FROM NEW.check_out_time
           AND OLD.attendance_hours IS NOT DISTINCT FROM NEW.attendance_hours THEN
            -- Only metadata fields changed, allow it
            RETURN NEW;
        END IF;
        
        -- Block changes to core attendance data
        RAISE EXCEPTION 'session_attendance records are immutable after check-in. Record id: %. Use attendance_corrections table instead.', OLD.id
            USING HINT = '21 CFR Part 11 requires immutable audit trails. Insert a correction record instead of modifying the original.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_session_attendance_immutable ON session_attendance;
CREATE TRIGGER trg_session_attendance_immutable
    BEFORE UPDATE OR DELETE ON session_attendance
    FOR EACH ROW EXECUTE FUNCTION session_attendance_immutable();

-- ---------------------------------------------------------------------------
-- 3. VIEW: attendance_with_corrections
-- Latest effective attendance status considering corrections
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW attendance_with_corrections AS
SELECT 
    sa.id AS original_id,
    sa.session_id,
    sa.employee_id,
    -- Use corrected values if any corrections exist, otherwise original
    COALESCE(
        (SELECT ac.corrected_attendance_status 
         FROM attendance_corrections ac 
         WHERE ac.original_attendance_id = sa.id 
         ORDER BY ac.corrected_at DESC 
         LIMIT 1),
        sa.attendance_status
    ) AS effective_status,
    COALESCE(
        (SELECT ac.corrected_check_in_time 
         FROM attendance_corrections ac 
         WHERE ac.original_attendance_id = sa.id 
           AND ac.corrected_check_in_time IS NOT NULL
         ORDER BY ac.corrected_at DESC 
         LIMIT 1),
        sa.check_in_time
    ) AS effective_check_in,
    COALESCE(
        (SELECT ac.corrected_check_out_time 
         FROM attendance_corrections ac 
         WHERE ac.original_attendance_id = sa.id 
           AND ac.corrected_check_out_time IS NOT NULL
         ORDER BY ac.corrected_at DESC 
         LIMIT 1),
        sa.check_out_time
    ) AS effective_check_out,
    -- Original values for audit purposes
    sa.attendance_status AS original_status,
    sa.check_in_time AS original_check_in,
    sa.check_out_time AS original_check_out,
    sa.marked_by AS original_marked_by,
    sa.marked_at AS original_marked_at,
    -- Correction info
    (SELECT COUNT(*) FROM attendance_corrections ac WHERE ac.original_attendance_id = sa.id) AS correction_count,
    (SELECT ac.corrected_by 
     FROM attendance_corrections ac 
     WHERE ac.original_attendance_id = sa.id 
     ORDER BY ac.corrected_at DESC 
     LIMIT 1) AS last_corrected_by,
    (SELECT ac.corrected_at 
     FROM attendance_corrections ac 
     WHERE ac.original_attendance_id = sa.id 
     ORDER BY ac.corrected_at DESC 
     LIMIT 1) AS last_corrected_at
FROM session_attendance sa;

-- ---------------------------------------------------------------------------
-- 4. RLS POLICIES: attendance_corrections
-- ---------------------------------------------------------------------------
ALTER TABLE attendance_corrections ENABLE ROW LEVEL SECURITY;

-- Select: org members can view their org's corrections
CREATE POLICY attendance_corrections_select ON attendance_corrections
    FOR SELECT
    USING (
        organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
    );

-- Insert: trainers and coordinators can create corrections
CREATE POLICY attendance_corrections_insert ON attendance_corrections
    FOR INSERT
    WITH CHECK (
        organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
    );

-- Update: corrections are immutable, no updates allowed
CREATE POLICY attendance_corrections_update ON attendance_corrections
    FOR UPDATE
    USING (FALSE);  -- Never allow updates

-- Delete: corrections are immutable, no deletes allowed
CREATE POLICY attendance_corrections_delete ON attendance_corrections
    FOR DELETE
    USING (FALSE);  -- Never allow deletes

-- ---------------------------------------------------------------------------
-- 5. FUNCTION: apply_attendance_correction
-- Helper function to create a correction with proper audit trail
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION apply_attendance_correction(
    p_original_attendance_id UUID,
    p_corrected_status attendance_status DEFAULT NULL,
    p_corrected_check_in TIMESTAMPTZ DEFAULT NULL,
    p_corrected_check_out TIMESTAMPTZ DEFAULT NULL,
    p_correction_reason TEXT DEFAULT NULL,
    p_corrected_by UUID DEFAULT NULL,
    p_esignature_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
    v_employee_id UUID;
    v_org_id UUID;
    v_correction_id UUID;
    v_audit_id UUID;
    v_corrected_hours NUMERIC(6,2);
BEGIN
    -- Get original attendance details
    SELECT sa.session_id, sa.employee_id, ts.organization_id
    INTO v_session_id, v_employee_id, v_org_id
    FROM session_attendance sa
    JOIN training_sessions ts ON sa.session_id = ts.id
    WHERE sa.id = p_original_attendance_id;
    
    IF v_session_id IS NULL THEN
        RAISE EXCEPTION 'Original attendance record not found: %', p_original_attendance_id;
    END IF;
    
    -- Calculate corrected hours if both times provided
    IF p_corrected_check_in IS NOT NULL AND p_corrected_check_out IS NOT NULL THEN
        v_corrected_hours := EXTRACT(EPOCH FROM (p_corrected_check_out - p_corrected_check_in)) / 3600;
    END IF;
    
    -- Create audit trail entry first
    INSERT INTO audit_trails (
        organization_id,
        employee_id,
        action,
        entity_type,
        entity_id,
        event_category,
        old_values,
        new_values
    )
    SELECT 
        v_org_id,
        p_corrected_by,
        'ATTENDANCE_CORRECTED',
        'session_attendance',
        p_original_attendance_id,
        'TRAINING',
        jsonb_build_object(
            'attendance_status', sa.attendance_status,
            'check_in_time', sa.check_in_time,
            'check_out_time', sa.check_out_time
        ),
        jsonb_build_object(
            'corrected_status', p_corrected_status,
            'corrected_check_in', p_corrected_check_in,
            'corrected_check_out', p_corrected_check_out,
            'reason', p_correction_reason
        )
    FROM session_attendance sa
    WHERE sa.id = p_original_attendance_id
    RETURNING id INTO v_audit_id;
    
    -- Create correction record
    INSERT INTO attendance_corrections (
        original_attendance_id,
        session_id,
        employee_id,
        organization_id,
        corrected_attendance_status,
        corrected_check_in_time,
        corrected_check_out_time,
        corrected_attendance_hours,
        correction_reason,
        corrected_by,
        esignature_id,
        audit_trail_id
    ) VALUES (
        p_original_attendance_id,
        v_session_id,
        v_employee_id,
        v_org_id,
        p_corrected_status,
        p_corrected_check_in,
        p_corrected_check_out,
        v_corrected_hours,
        p_correction_reason,
        p_corrected_by,
        p_esignature_id,
        v_audit_id
    ) RETURNING id INTO v_correction_id;
    
    RETURN v_correction_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ---------------------------------------------------------------------------
-- 6. COMMENTS
-- ---------------------------------------------------------------------------
COMMENT ON TABLE attendance_corrections IS '21 CFR Part 11 compliant attendance correction records - immutable';
COMMENT ON COLUMN attendance_corrections.correction_reason IS 'Required explanation for the correction per 21 CFR §11.10(e)';
COMMENT ON COLUMN attendance_corrections.esignature_id IS 'E-signature for regulatory compliance on corrections';
COMMENT ON FUNCTION session_attendance_immutable() IS 'Enforces immutability of session_attendance after check-in';
COMMENT ON VIEW attendance_with_corrections IS 'Latest effective attendance values considering all corrections';
COMMENT ON FUNCTION apply_attendance_correction IS 'Helper to create attendance corrections with proper audit trail';
