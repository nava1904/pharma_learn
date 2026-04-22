-- ===========================================
-- G13: SCORM SUPPORT ENHANCEMENTS
-- Adds missing columns + RPCs for S8 SCORM implementation
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. ALTER scorm_packages: Add missing columns used by handler
-- ---------------------------------------------------------------------------
ALTER TABLE scorm_packages 
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'processing' 
    CHECK (status IN ('processing', 'ready', 'error'));

ALTER TABLE scorm_packages 
ADD COLUMN IF NOT EXISTS file_name TEXT;

ALTER TABLE scorm_packages 
ADD COLUMN IF NOT EXISTS manifest_json JSONB;

ALTER TABLE scorm_packages 
ADD COLUMN IF NOT EXISTS error_message TEXT;

COMMENT ON COLUMN scorm_packages.status IS 
    'Package processing status: processing (being extracted), ready (can launch), error (extraction failed)';
COMMENT ON COLUMN scorm_packages.file_name IS 
    'Original uploaded ZIP file name';
COMMENT ON COLUMN scorm_packages.manifest_json IS 
    'Parsed imsmanifest.xml content: {title, launch_url, mastery_score, sco_list, prerequisites}';
COMMENT ON COLUMN scorm_packages.error_message IS 
    'Error message if status = error';

-- Index for status filtering
CREATE INDEX IF NOT EXISTS idx_scorm_packages_status ON scorm_packages(status);

-- ---------------------------------------------------------------------------
-- 2. FUNCTION: get_scorm_session
-- Returns or creates a SCORM session for an employee+package
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_or_create_scorm_session(
    p_package_id UUID,
    p_employee_id UUID,
    p_training_record_id UUID DEFAULT NULL
)
RETURNS TABLE (
    session_id UUID,
    attempt_number INTEGER,
    status TEXT,
    cmi_data JSONB,
    is_new_session BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_org_id UUID;
    v_max_attempt INTEGER;
BEGIN
    -- Get org_id from package
    SELECT organization_id INTO v_org_id
    FROM scorm_packages WHERE id = p_package_id;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'SCORM package not found: %', p_package_id;
    END IF;
    
    -- Find existing incomplete session
    SELECT * INTO v_session
    FROM scorm_sessions ss
    WHERE ss.package_id = p_package_id
      AND ss.employee_id = p_employee_id
      AND ss.status IN ('not_attempted', 'incomplete')
    ORDER BY ss.attempt_number DESC
    LIMIT 1;
    
    IF v_session IS NOT NULL THEN
        -- Return existing session
        RETURN QUERY SELECT 
            v_session.id,
            v_session.attempt_number,
            v_session.status,
            v_session.cmi_data,
            FALSE;
        RETURN;
    END IF;
    
    -- Get max attempt number for new session
    SELECT COALESCE(MAX(attempt_number), 0) INTO v_max_attempt
    FROM scorm_sessions
    WHERE package_id = p_package_id AND employee_id = p_employee_id;
    
    -- Create new session
    INSERT INTO scorm_sessions (
        organization_id,
        package_id,
        employee_id,
        training_record_id,
        attempt_number,
        status,
        cmi_data,
        created_at
    )
    VALUES (
        v_org_id,
        p_package_id,
        p_employee_id,
        p_training_record_id,
        v_max_attempt + 1,
        'not_attempted',
        '{
            "cmi.core.lesson_status": "not attempted",
            "cmi.core.lesson_location": "",
            "cmi.core.entry": "ab-initio",
            "cmi.core.score.raw": "",
            "cmi.core.score.min": "",
            "cmi.core.score.max": "",
            "cmi.core.total_time": "0000:00:00",
            "cmi.core.session_time": "0000:00:00",
            "cmi.suspend_data": ""
        }'::JSONB,
        NOW()
    )
    RETURNING id, attempt_number, status, cmi_data
    INTO v_session;
    
    RETURN QUERY SELECT 
        v_session.id,
        v_session.attempt_number,
        v_session.status,
        v_session.cmi_data,
        TRUE;
END;
$$;

COMMENT ON FUNCTION get_or_create_scorm_session IS 
    'Returns existing incomplete session or creates new one for SCORM launch';

-- ---------------------------------------------------------------------------
-- 3. FUNCTION: commit_scorm_cmi
-- Updates CMI data and determines status from lesson_status
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION commit_scorm_cmi(
    p_session_id UUID,
    p_employee_id UUID,
    p_cmi_data JSONB
)
RETURNS TABLE (
    status TEXT,
    score_raw NUMERIC,
    is_completed BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_lesson_status TEXT;
    v_new_status TEXT;
    v_score NUMERIC;
    v_is_completed BOOLEAN := FALSE;
BEGIN
    -- Verify session ownership
    SELECT * INTO v_session
    FROM scorm_sessions
    WHERE id = p_session_id AND employee_id = p_employee_id;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'SCORM session not found or access denied';
    END IF;
    
    -- Extract lesson_status from CMI data
    v_lesson_status := COALESCE(
        p_cmi_data->>'cmi.core.lesson_status',
        p_cmi_data->>'cmi.completion_status',
        'incomplete'
    );
    
    -- Map SCORM status to our status
    CASE v_lesson_status
        WHEN 'passed', 'completed' THEN 
            v_new_status := 'completed';
            v_is_completed := TRUE;
        WHEN 'failed' THEN 
            v_new_status := 'failed';
        WHEN 'incomplete' THEN 
            v_new_status := 'incomplete';
        ELSE 
            v_new_status := 'incomplete';
    END CASE;
    
    -- Extract score
    v_score := (p_cmi_data->>'cmi.core.score.raw')::NUMERIC;
    
    -- Update session
    UPDATE scorm_sessions
    SET cmi_data = p_cmi_data,
        status = v_new_status,
        score_raw = v_score,
        total_time = p_cmi_data->>'cmi.core.total_time',
        last_accessed_at = NOW(),
        completed_at = CASE WHEN v_is_completed THEN NOW() ELSE completed_at END,
        updated_at = NOW()
    WHERE id = p_session_id;
    
    RETURN QUERY SELECT v_new_status, v_score, v_is_completed;
END;
$$;

COMMENT ON FUNCTION commit_scorm_cmi IS 
    'Commits CMI data from SCORM player, determines completion status';

-- ---------------------------------------------------------------------------
-- 4. FUNCTION: complete_scorm_training
-- Called when SCORM completes - creates training_record + publishes event
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION complete_scorm_training(
    p_session_id UUID,
    p_employee_id UUID
)
RETURNS TABLE (
    training_record_id UUID,
    certificate_required BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_session RECORD;
    v_package RECORD;
    v_course RECORD;
    v_training_record_id UUID;
    v_cert_required BOOLEAN;
BEGIN
    -- Get session details
    SELECT * INTO v_session
    FROM scorm_sessions
    WHERE id = p_session_id AND employee_id = p_employee_id;
    
    IF v_session IS NULL THEN
        RAISE EXCEPTION 'SCORM session not found';
    END IF;
    
    IF v_session.status != 'completed' THEN
        RAISE EXCEPTION 'Session is not completed: %', v_session.status;
    END IF;
    
    -- Get package + course details
    SELECT * INTO v_package
    FROM scorm_packages WHERE id = v_session.package_id;
    
    IF v_package.course_id IS NOT NULL THEN
        SELECT * INTO v_course
        FROM courses WHERE id = v_package.course_id;
        
        v_cert_required := COALESCE(v_course.assessment_required, FALSE);
    ELSE
        v_cert_required := FALSE;
    END IF;
    
    -- Create/update training_record
    INSERT INTO training_records (
        organization_id,
        employee_id,
        course_id,
        completion_type,
        overall_status,
        score,
        completion_date,
        scorm_session_id,
        created_at
    )
    VALUES (
        v_session.organization_id,
        p_employee_id,
        v_package.course_id,
        'scorm',
        'completed',
        v_session.score_raw,
        NOW(),
        p_session_id,
        NOW()
    )
    ON CONFLICT (employee_id, course_id) 
    DO UPDATE SET
        overall_status = 'completed',
        score = EXCLUDED.score,
        completion_date = EXCLUDED.completion_date,
        scorm_session_id = EXCLUDED.scorm_session_id,
        updated_at = NOW()
    RETURNING id INTO v_training_record_id;
    
    -- Upsert training_completions (denormalized cache)
    INSERT INTO training_completions (
        employee_id,
        course_id,
        completion_type,
        completed_at,
        score,
        created_at
    )
    VALUES (
        p_employee_id,
        v_package.course_id,
        'scorm',
        NOW(),
        v_session.score_raw,
        NOW()
    )
    ON CONFLICT (employee_id, course_id) 
    DO UPDATE SET
        completion_type = 'scorm',
        completed_at = EXCLUDED.completed_at,
        score = EXCLUDED.score,
        updated_at = NOW();
    
    -- Publish training.completed event
    PERFORM publish_event(
        p_aggregate_type := 'training_record',
        p_aggregate_id := v_training_record_id,
        p_event_type := 'training.completed',
        p_payload := jsonb_build_object(
            'employee_id', p_employee_id,
            'course_id', v_package.course_id,
            'scorm_session_id', p_session_id,
            'score', v_session.score_raw,
            'certificate_required', v_cert_required
        ),
        p_source_server := 'api',
        p_org_id := v_session.organization_id
    );
    
    RETURN QUERY SELECT v_training_record_id, v_cert_required;
END;
$$;

COMMENT ON FUNCTION complete_scorm_training IS 
    'Creates training_record on SCORM completion and publishes event';

-- ---------------------------------------------------------------------------
-- 5. FUNCTION: get_scorm_progress
-- Returns progress summary for employee across all packages/courses
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_scorm_progress(
    p_employee_id UUID,
    p_course_id UUID DEFAULT NULL
)
RETURNS TABLE (
    package_id UUID,
    package_name TEXT,
    course_id UUID,
    course_name TEXT,
    session_id UUID,
    attempt_number INTEGER,
    status TEXT,
    score_raw NUMERIC,
    total_time TEXT,
    last_accessed_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sp.id AS package_id,
        sp.title AS package_name,
        sp.course_id,
        c.title AS course_name,
        ss.id AS session_id,
        ss.attempt_number,
        ss.status,
        ss.score_raw,
        ss.total_time,
        ss.last_accessed_at
    FROM scorm_sessions ss
    JOIN scorm_packages sp ON sp.id = ss.package_id
    LEFT JOIN courses c ON c.id = sp.course_id
    WHERE ss.employee_id = p_employee_id
      AND (p_course_id IS NULL OR sp.course_id = p_course_id)
    ORDER BY ss.last_accessed_at DESC NULLS LAST;
END;
$$;

COMMENT ON FUNCTION get_scorm_progress IS 
    'Returns SCORM progress for an employee, optionally filtered by course';

-- ---------------------------------------------------------------------------
-- 6. INDEX for progress queries
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_scorm_sessions_employee_status 
ON scorm_sessions(employee_id, status);

CREATE INDEX IF NOT EXISTS idx_scorm_sessions_last_accessed 
ON scorm_sessions(last_accessed_at DESC);
