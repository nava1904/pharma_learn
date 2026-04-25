-- ===========================================
-- CERTIFICATE INVALIDATION / OBSOLESCENCE CHAIN
-- ===========================================

-- Mark certificates obsolete for a given course (called by regulated workflows)
CREATE OR REPLACE FUNCTION obsolete_active_certificates_for_course(
    p_course_id UUID,
    p_reason TEXT DEFAULT 'Course updated; retraining required',
    p_obsoleted_by UUID DEFAULT NULL,
    p_esignature_id UUID DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_count INTEGER := 0;
BEGIN
    UPDATE certificates
    SET status = 'obsolete'::certificate_status,
        obsolete_at = NOW(),
        obsolete_by = p_obsoleted_by,
        obsolescence_reason = p_reason,
        obsoleted_via_esignature_id = p_esignature_id,
        updated_at = NOW()
    WHERE course_id = p_course_id
      AND status = 'active'::certificate_status;

    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Course revision approval → obsolete prior certificates (conservative default)
CREATE OR REPLACE FUNCTION auto_obsolete_certificates_on_course_revision()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.revision_no IS NOT NULL
           AND OLD.revision_no IS NOT NULL
           AND NEW.revision_no > OLD.revision_no
           AND NEW.status = 'active'::workflow_state
           AND NEW.approved_at IS NOT NULL
        THEN
            PERFORM obsolete_active_certificates_for_course(
                NEW.id,
                'Course revision approved; prior certificates marked obsolete',
                NEW.approved_by,
                NULL
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_courses_obsolete_certs ON courses;
CREATE TRIGGER trg_courses_obsolete_certs
    AFTER UPDATE ON courses
    FOR EACH ROW EXECUTE FUNCTION auto_obsolete_certificates_on_course_revision();

