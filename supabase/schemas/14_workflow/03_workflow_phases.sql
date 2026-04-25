-- ===========================================
-- WORKFLOW PHASES + ETD (Extension of Target Date)
-- GAP 2: Phase-based workflow modeling for CAPA / audit workflows
-- ===========================================

-- Phase definitions attached to a workflow_definition
CREATE TABLE IF NOT EXISTS workflow_phases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_definition_id UUID NOT NULL REFERENCES workflow_definitions(id) ON DELETE CASCADE,
    phase_name TEXT NOT NULL,
    phase_code TEXT NOT NULL,
    phase_order INTEGER NOT NULL,
    description TEXT,
    is_mandatory BOOLEAN NOT NULL DEFAULT true,
    default_duration_days INTEGER,              -- used to auto-compute ETD
    sla_config JSONB,                           -- e.g. {warning_days: 2, critical_days: 0}
    entry_conditions JSONB,                     -- JSON rules to auto-enter phase
    exit_conditions JSONB,                      -- JSON rules to auto-exit phase
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(workflow_definition_id, phase_code)
);

CREATE INDEX IF NOT EXISTS idx_workflow_phases_def ON workflow_phases(workflow_definition_id);
CREATE INDEX IF NOT EXISTS idx_workflow_phases_order ON workflow_phases(workflow_definition_id, phase_order);

-- Phase instance: tracks progress through each phase for a running workflow
CREATE TABLE IF NOT EXISTS workflow_instance_phases (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_instance_id UUID NOT NULL REFERENCES workflow_instances(id) ON DELETE CASCADE,
    phase_id UUID NOT NULL REFERENCES workflow_phases(id) ON DELETE RESTRICT,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'completed', 'skipped', 'extended')),
    entered_at TIMESTAMPTZ,
    target_completion_date DATE,                -- ETD
    actual_completion_date DATE,
    entered_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    completed_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wf_instance_phases_instance ON workflow_instance_phases(workflow_instance_id);
CREATE INDEX IF NOT EXISTS idx_wf_instance_phases_phase ON workflow_instance_phases(phase_id);
CREATE INDEX IF NOT EXISTS idx_wf_instance_phases_status ON workflow_instance_phases(status);

-- Phase extension requests (ETD — Extension of Target Date)
CREATE TABLE IF NOT EXISTS phase_extensions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workflow_instance_phase_id UUID NOT NULL
        REFERENCES workflow_instance_phases(id) ON DELETE RESTRICT,
    original_target_date DATE NOT NULL,
    extended_target_date DATE NOT NULL,
    extension_reason TEXT NOT NULL,             -- mandatory per pharma compliance
    requested_by UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    etd_days INTEGER NOT NULL
        GENERATED ALWAYS AS (extended_target_date - original_target_date) STORED,
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_phase_extensions_phase ON phase_extensions(workflow_instance_phase_id);
CREATE INDEX IF NOT EXISTS idx_phase_extensions_status ON phase_extensions(status);

-- -------------------------------------------------------
-- FUNCTIONS
-- -------------------------------------------------------

-- Enter a workflow phase; auto-computes ETD if etd_required setting is true
CREATE OR REPLACE FUNCTION enter_workflow_phase(
    p_instance_id UUID,
    p_phase_id UUID,
    p_target_date DATE DEFAULT NULL,
    p_entered_by UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_instance_phase_id UUID;
    v_phase workflow_phases%ROWTYPE;
    v_org_id UUID;
    v_target DATE;
BEGIN
    SELECT * INTO v_phase FROM workflow_phases WHERE id = p_phase_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workflow phase not found: %', p_phase_id;
    END IF;

    SELECT wd.workflow_definition_id, o.id
    INTO v_org_id
    FROM workflow_instances wi
    JOIN workflow_definitions wd ON wd.id = wi.workflow_definition_id
    JOIN organizations o ON o.id = (
        SELECT organization_id FROM workflow_definitions WHERE id = wi.workflow_definition_id LIMIT 1
    )
    WHERE wi.id = p_instance_id;

    v_org_id := get_current_org_id();

    -- Auto-compute ETD when required
    v_target := p_target_date;
    IF v_target IS NULL AND get_setting_bool(v_org_id, 'etd_required') THEN
        v_target := CURRENT_DATE + COALESCE(v_phase.default_duration_days, 7);
    END IF;

    -- Mark any previous active phase for this instance as left
    UPDATE workflow_instance_phases
    SET status = 'completed', actual_completion_date = CURRENT_DATE, updated_at = NOW()
    WHERE workflow_instance_id = p_instance_id
      AND status = 'active';

    INSERT INTO workflow_instance_phases (
        workflow_instance_id, phase_id, status,
        entered_at, target_completion_date, entered_by
    ) VALUES (
        p_instance_id, p_phase_id, 'active',
        NOW(), v_target, COALESCE(p_entered_by, get_current_user_id())
    )
    RETURNING id INTO v_instance_phase_id;

    RETURN v_instance_phase_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Request an extension of target date for the current active phase
CREATE OR REPLACE FUNCTION request_phase_extension(
    p_instance_phase_id UUID,
    p_new_target_date DATE,
    p_reason TEXT
) RETURNS UUID AS $$
DECLARE
    v_ext_id UUID;
    v_phase workflow_instance_phases%ROWTYPE;
BEGIN
    SELECT * INTO v_phase FROM workflow_instance_phases WHERE id = p_instance_phase_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Workflow instance phase not found: %', p_instance_phase_id;
    END IF;

    IF v_phase.status NOT IN ('active', 'extended') THEN
        RAISE EXCEPTION 'Can only extend an active phase (current status: %)', v_phase.status;
    END IF;

    IF p_new_target_date <= COALESCE(v_phase.target_completion_date, CURRENT_DATE) THEN
        RAISE EXCEPTION 'Extended target date must be later than the current target date';
    END IF;

    IF TRIM(COALESCE(p_reason, '')) = '' THEN
        RAISE EXCEPTION 'Extension reason is mandatory (GMP requirement)';
    END IF;

    -- Check etd_required setting
    IF NOT get_setting_bool(get_current_org_id(), 'etd_required') THEN
        RAISE EXCEPTION 'Phase extensions (ETD) are not enabled for this organization';
    END IF;

    INSERT INTO phase_extensions (
        workflow_instance_phase_id,
        original_target_date, extended_target_date,
        extension_reason, requested_by, status
    ) VALUES (
        p_instance_phase_id,
        COALESCE(v_phase.target_completion_date, CURRENT_DATE),
        p_new_target_date,
        p_reason,
        get_current_user_id(),
        'pending'
    )
    RETURNING id INTO v_ext_id;

    -- Update phase status to 'extended'
    UPDATE workflow_instance_phases
    SET status = 'extended', updated_at = NOW()
    WHERE id = p_instance_phase_id;

    RETURN v_ext_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE workflow_phases IS 'Phase definitions for a workflow — e.g. RCA, Action Planning, Implementation, Effectiveness Check';
COMMENT ON TABLE workflow_instance_phases IS 'Per-instance phase progress tracking with ETD';
COMMENT ON TABLE phase_extensions IS 'ETD (Extension of Target Date) requests per phase — requires reason and approval';
COMMENT ON FUNCTION enter_workflow_phase IS 'Activate a phase for a workflow instance; auto-computes target date when etd_required setting is true';
COMMENT ON FUNCTION request_phase_extension IS 'Submit an ETD request; raises if reason is missing or extensions not enabled';
