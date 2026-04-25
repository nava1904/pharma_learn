-- ===========================================
-- TRAINING MATRIX → CURRICULUM BRIDGE
-- Generates a regulated curriculum from a training matrix (no parallel targeting logic)
-- ===========================================

CREATE OR REPLACE FUNCTION generate_curriculum_from_training_matrix(
    p_matrix_id UUID,
    p_unique_code TEXT,
    p_title TEXT,
    p_effective_from DATE,
    p_created_by UUID
) RETURNS UUID AS $$
DECLARE
    v_curriculum_id UUID;
    v_matrix training_matrix%ROWTYPE;
BEGIN
    SELECT * INTO v_matrix FROM training_matrix WHERE id = p_matrix_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Training matrix not found: %', p_matrix_id;
    END IF;

    INSERT INTO curricula (
        organization_id,
        matrix_id,
        unique_code,
        title,
        description,
        effective_from,
        status,
        created_by
    ) VALUES (
        v_matrix.organization_id,
        v_matrix.id,
        p_unique_code,
        p_title,
        v_matrix.description,
        p_effective_from,
        'draft'::workflow_state,
        p_created_by
    )
    RETURNING id INTO v_curriculum_id;

    -- Roles targeted by the matrix
    INSERT INTO curriculum_job_roles (curriculum_id, role_id)
    SELECT DISTINCT v_curriculum_id, tmi.role_id
    FROM training_matrix_items tmi
    WHERE tmi.matrix_id = v_matrix.id
      AND tmi.role_id IS NOT NULL
    ON CONFLICT DO NOTHING;

    -- Items from the matrix
    INSERT INTO curriculum_items (
        curriculum_id,
        item_type,
        source_matrix_item_id,
        course_id,
        document_id,
        due_days,
        recurrence_months,
        display_order
    )
    SELECT
        v_curriculum_id,
        CASE
            WHEN tmi.course_id IS NOT NULL THEN 'course'::obligation_item_type
            WHEN tmi.document_id IS NOT NULL THEN 'document_read'::obligation_item_type
            ELSE 'course'::obligation_item_type
        END,
        tmi.id,
        tmi.course_id,
        tmi.document_id,
        tmi.due_days,
        CASE
            WHEN tmi.frequency_type = 'recurring' THEN tmi.frequency_value
            ELSE NULL
        END,
        ROW_NUMBER() OVER (ORDER BY tmi.created_at)
    FROM training_matrix_items tmi
    WHERE tmi.matrix_id = v_matrix.id
      AND (tmi.course_id IS NOT NULL OR tmi.document_id IS NOT NULL);

    RETURN v_curriculum_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

