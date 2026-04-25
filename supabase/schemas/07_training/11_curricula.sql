-- ===========================================
-- CURRICULA / TNI (REGULATED BUNDLES)
-- Publishing curricula creates employee_training_obligations (canonical)
-- ===========================================

CREATE TABLE IF NOT EXISTS curricula (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    matrix_id UUID REFERENCES training_matrix(id) ON DELETE SET NULL,
    unique_code TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    version_number INTEGER NOT NULL DEFAULT 1,
    status workflow_state DEFAULT 'draft',

    effective_from DATE NOT NULL,
    effective_to DATE,

    published_at TIMESTAMPTZ,
    published_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    published_esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES employees(id) ON DELETE SET NULL,

    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_curricula_org ON curricula(organization_id);
CREATE INDEX IF NOT EXISTS idx_curricula_status ON curricula(status);

DROP TRIGGER IF EXISTS trg_curricula_audit ON curricula;
CREATE TRIGGER trg_curricula_audit AFTER INSERT OR UPDATE OR DELETE ON curricula FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Which roles a curriculum applies to
CREATE TABLE IF NOT EXISTS curriculum_job_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    curriculum_id UUID NOT NULL REFERENCES curricula(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(curriculum_id, role_id)
);

CREATE INDEX IF NOT EXISTS idx_curriculum_roles_curriculum ON curriculum_job_roles(curriculum_id);

-- What is inside the curriculum
CREATE TABLE IF NOT EXISTS curriculum_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    curriculum_id UUID NOT NULL REFERENCES curricula(id) ON DELETE CASCADE,
    item_type obligation_item_type NOT NULL,
    source_matrix_item_id UUID REFERENCES training_matrix_items(id) ON DELETE SET NULL,

    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    ojt_master_id UUID REFERENCES ojt_masters(id) ON DELETE SET NULL,
    question_paper_id UUID REFERENCES question_papers(id) ON DELETE SET NULL,

    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    due_days INTEGER NOT NULL DEFAULT 30,
    recurrence_months INTEGER,
    display_order INTEGER NOT NULL DEFAULT 1,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(curriculum_id, item_type, course_id, document_id, ojt_master_id, question_paper_id),
    CONSTRAINT chk_curriculum_item_target CHECK (
        course_id IS NOT NULL
        OR document_id IS NOT NULL
        OR ojt_master_id IS NOT NULL
        OR question_paper_id IS NOT NULL
    )
);

CREATE INDEX IF NOT EXISTS idx_curriculum_items_curriculum ON curriculum_items(curriculum_id);

-- Backfill canonical obligations when publishing
CREATE OR REPLACE FUNCTION publish_curriculum_create_obligations(p_curriculum_id UUID)
RETURNS INTEGER AS $$
DECLARE
    v_curr curricula%ROWTYPE;
    v_created INTEGER := 0;
BEGIN
    SELECT * INTO v_curr FROM curricula WHERE id = p_curriculum_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Curriculum not found: %', p_curriculum_id;
    END IF;

    -- For each employee who has at least one matching role, create obligations for each curriculum item.
    INSERT INTO employee_training_obligations (
        organization_id, plant_id, department_id,
        employee_id,
        item_type, course_id, document_id, ojt_master_id, question_paper_id,
        curriculum_id, curriculum_item_id,
        matrix_id, matrix_item_id,
        status, assigned_at, due_date,
        recurrence_months, is_recurrence, recurrence_number,
        workflow_status, initiated_by, initiated_at
    )
    SELECT
        e.organization_id, e.plant_id, e.department_id,
        e.id,
        ci.item_type, ci.course_id, ci.document_id, ci.ojt_master_id, ci.question_paper_id,
        v_curr.id, ci.id,
        v_curr.matrix_id, ci.source_matrix_item_id,
        'pending'::obligation_status,
        NOW(),
        (CURRENT_DATE + (ci.due_days || ' days')::INTERVAL)::DATE,
        ci.recurrence_months,
        (ci.recurrence_months IS NOT NULL),
        1,
        'initiated'::workflow_state,
        v_curr.published_by,
        NOW()
    FROM employees e
    JOIN employee_roles er ON er.employee_id = e.id
    JOIN curriculum_job_roles cjr ON cjr.role_id = er.role_id AND cjr.curriculum_id = v_curr.id
    JOIN curriculum_items ci ON ci.curriculum_id = v_curr.id
    WHERE e.organization_id = v_curr.organization_id
      AND e.status = 'active'
    ON CONFLICT DO NOTHING;

    GET DIAGNOSTICS v_created = ROW_COUNT;
    RETURN v_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

