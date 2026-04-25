-- ===========================================
-- TRAINING TRIGGER ENGINE
-- GAP 4: Event-driven auto-assignment of training
-- ===========================================

-- -------------------------------------------------------
-- EVENT LOG: captures every trigger-worthy event
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS training_trigger_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    event_source TEXT NOT NULL CHECK (event_source IN (
        'sop_update', 'deviation', 'capa', 'role_change', 'new_hire',
        'certification_expiry', 'document_update', 'audit_finding'
    )),
    entity_type TEXT NOT NULL,      -- e.g. 'documents', 'capa_records', 'employees'
    entity_id UUID NOT NULL,
    event_metadata JSONB,           -- e.g. {old_version, new_version, role_id}
    triggered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed BOOLEAN NOT NULL DEFAULT false,
    processed_at TIMESTAMPTZ,
    assignments_created INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trigger_events_org ON training_trigger_events(organization_id);
CREATE INDEX IF NOT EXISTS idx_trigger_events_source ON training_trigger_events(event_source);
CREATE INDEX IF NOT EXISTS idx_trigger_events_entity ON training_trigger_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_trigger_events_unprocessed ON training_trigger_events(processed)
    WHERE processed = false;

-- -------------------------------------------------------
-- TRIGGER RULES: defines what assignments to create on each event
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS training_trigger_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    rule_name TEXT NOT NULL,
    event_source TEXT NOT NULL CHECK (event_source IN (
        'sop_update', 'deviation', 'capa', 'role_change', 'new_hire',
        'certification_expiry', 'document_update', 'audit_finding'
    )),
    entity_type_filter TEXT,            -- optional: only fire for this entity_type
    conditions JSONB,                   -- JSON rules: e.g. {"severity": ["critical","major"]}
    training_assignment_template_id UUID REFERENCES training_assignments(id) ON DELETE SET NULL,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    document_id UUID REFERENCES documents(id) ON DELETE SET NULL,
    target_scope TEXT NOT NULL DEFAULT 'involved_employees' CHECK (target_scope IN (
        'involved_employees', 'affected_department', 'all_role', 'all_plant', 'specific_employees'
    )),
    target_roles JSONB DEFAULT '[]',    -- role IDs for target_scope = 'all_role'
    target_employee_ids JSONB DEFAULT '[]', -- for target_scope = 'specific_employees'
    due_days_from_trigger INTEGER NOT NULL DEFAULT 7,
    priority TEXT NOT NULL DEFAULT 'high' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trigger_rules_org ON training_trigger_rules(organization_id);
CREATE INDEX IF NOT EXISTS idx_trigger_rules_source ON training_trigger_rules(event_source);
CREATE INDEX IF NOT EXISTS idx_trigger_rules_active ON training_trigger_rules(is_active);

-- -------------------------------------------------------
-- CORE ENGINE FUNCTION
-- -------------------------------------------------------

-- Process a training trigger event: log it, match rules, create assignments
CREATE OR REPLACE FUNCTION process_training_trigger(
    p_event_source TEXT,
    p_entity_id UUID,
    p_org_id UUID,
    p_entity_type TEXT DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_event_id UUID;
    v_rule training_trigger_rules%ROWTYPE;
    v_emp_ids UUID[];
    v_emp_id UUID;
    v_total_count INTEGER := 0;
    v_rule_count INTEGER;
    v_due_date DATE;
    v_error_msg TEXT;
    v_resolved_entity_type TEXT;
BEGIN
    -- Check behavioral control
    IF NOT get_setting_bool(p_org_id, 'training_trigger_auto_assign') THEN
        RETURN 0;
    END IF;

    v_resolved_entity_type := COALESCE(p_entity_type,
        CASE p_event_source
            WHEN 'sop_update'      THEN 'documents'
            WHEN 'document_update' THEN 'documents'
            WHEN 'capa'            THEN 'capa_records'
            WHEN 'deviation'       THEN 'deviations'
            WHEN 'audit_finding'   THEN 'audit_findings'
            WHEN 'role_change'     THEN 'employees'
            WHEN 'new_hire'        THEN 'employees'
            ELSE 'unknown'
        END
    );

    -- Log the event
    INSERT INTO training_trigger_events (
        organization_id, event_source, entity_type, entity_id, event_metadata
    ) VALUES (
        p_org_id, p_event_source, v_resolved_entity_type, p_entity_id, p_metadata
    )
    RETURNING id INTO v_event_id;

    BEGIN
        -- Process each matching active rule
        FOR v_rule IN
            SELECT * FROM training_trigger_rules
            WHERE organization_id = p_org_id
              AND event_source = p_event_source
              AND is_active = true
              AND (entity_type_filter IS NULL OR entity_type_filter = v_resolved_entity_type)
            ORDER BY priority DESC, created_at ASC
        LOOP
            v_emp_ids := ARRAY[]::UUID[];
            v_due_date := CURRENT_DATE + v_rule.due_days_from_trigger;

            -- Resolve target employees based on scope
            CASE v_rule.target_scope
                WHEN 'involved_employees' THEN
                    -- Employees directly associated with the entity
                    CASE v_resolved_entity_type
                        WHEN 'documents' THEN
                            SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                            FROM employees e
                            WHERE e.organization_id = p_org_id AND e.status = 'active';
                        WHEN 'capa_records' THEN
                            SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                            FROM employees e
                            WHERE e.organization_id = p_org_id
                              AND e.department_id = (
                                  SELECT department_id FROM capa_records WHERE id = p_entity_id
                              );
                        WHEN 'deviations' THEN
                            SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                            FROM employees e
                            WHERE e.organization_id = p_org_id
                              AND e.department_id = (
                                  SELECT department_id FROM deviations WHERE id = p_entity_id
                              );
                        ELSE
                            SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                            FROM employees e
                            WHERE e.organization_id = p_org_id AND e.status = 'active';
                    END CASE;

                WHEN 'affected_department' THEN
                    SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                    FROM employees e
                    WHERE e.organization_id = p_org_id
                      AND e.status = 'active'
                      AND e.department_id IN (
                          SELECT id FROM departments WHERE organization_id = p_org_id
                      );

                WHEN 'all_role' THEN
                    SELECT ARRAY_AGG(DISTINCT er.employee_id) INTO v_emp_ids
                    FROM employee_roles er
                    JOIN employees e ON e.id = er.employee_id
                    WHERE e.organization_id = p_org_id
                      AND e.status = 'active'
                      AND er.role_id = ANY(
                          SELECT (jsonb_array_elements_text(v_rule.target_roles))::UUID
                      );

                WHEN 'all_plant' THEN
                    SELECT ARRAY_AGG(DISTINCT e.id) INTO v_emp_ids
                    FROM employees e
                    WHERE e.organization_id = p_org_id AND e.status = 'active';

                WHEN 'specific_employees' THEN
                    SELECT ARRAY_AGG(DISTINCT (jsonb_array_elements_text(v_rule.target_employee_ids))::UUID)
                    INTO v_emp_ids;

                ELSE
                    v_emp_ids := ARRAY[]::UUID[];
            END CASE;

            -- Bulk insert employee_assignments, skipping duplicates
            IF v_emp_ids IS NOT NULL AND array_length(v_emp_ids, 1) > 0 THEN
                IF v_rule.training_assignment_template_id IS NOT NULL THEN
                    FOREACH v_emp_id IN ARRAY v_emp_ids LOOP
                        INSERT INTO employee_assignments (
                            assignment_id, employee_id, due_date, status
                        ) VALUES (
                            v_rule.training_assignment_template_id,
                            v_emp_id,
                            v_due_date,
                            'assigned'
                        )
                        ON CONFLICT DO NOTHING;
                    END LOOP;

                    GET DIAGNOSTICS v_rule_count = ROW_COUNT;
                    v_total_count := v_total_count + COALESCE(array_length(v_emp_ids, 1), 0);
                END IF;
            END IF;
        END LOOP;

        -- Mark event processed
        UPDATE training_trigger_events
        SET processed = true,
            processed_at = NOW(),
            assignments_created = v_total_count
        WHERE id = v_event_id;

    EXCEPTION WHEN OTHERS THEN
        GET STACKED DIAGNOSTICS v_error_msg = MESSAGE_TEXT;
        UPDATE training_trigger_events
        SET error_message = v_error_msg
        WHERE id = v_event_id;
        -- Re-raise so the caller knows something failed
        RAISE;
    END;

    RETURN v_total_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- TRIGGER HANDLER FUNCTIONS (called by DB triggers)
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION trigger_process_sop_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Only fire on SOP/document activation with revision > 1 (i.e. re-approved)
    IF OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'active' AND NEW.revision_no > 1 THEN
        PERFORM process_training_trigger(
            'sop_update',
            NEW.id,
            NEW.organization_id,
            'documents',
            jsonb_build_object(
                'document_name', NEW.name,
                'version_no', NEW.version_no,
                'sop_number', NEW.sop_number
            )
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION trigger_process_capa()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM process_training_trigger(
        'capa',
        NEW.id,
        NEW.organization_id,
        'capa_records',
        jsonb_build_object(
            'capa_number', NEW.unique_code,
            'severity', NEW.severity
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION trigger_process_role_change()
RETURNS TRIGGER AS $$
DECLARE
    v_org_id UUID;
BEGIN
    SELECT organization_id INTO v_org_id FROM employees WHERE id = NEW.employee_id;

    PERFORM process_training_trigger(
        'role_change',
        NEW.employee_id,
        v_org_id,
        'employees',
        jsonb_build_object('role_id', NEW.role_id, 'effective_from', NEW.effective_from)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- ATTACH TRIGGER HOOKS TO EXISTING TABLES
-- -------------------------------------------------------

DROP TRIGGER IF EXISTS trg_doc_sop_update_training ON documents;
CREATE TRIGGER trg_doc_sop_update_training
    AFTER UPDATE ON documents
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status AND NEW.status = 'active' AND NEW.revision_no > 1)
    EXECUTE FUNCTION trigger_process_sop_update();

DROP TRIGGER IF EXISTS trg_capa_training_trigger ON capa_records;
CREATE TRIGGER trg_capa_training_trigger
    AFTER INSERT ON capa_records
    FOR EACH ROW EXECUTE FUNCTION trigger_process_capa();

DROP TRIGGER IF EXISTS trg_role_change_training ON employee_roles;
CREATE TRIGGER trg_role_change_training
    AFTER INSERT OR UPDATE ON employee_roles
    FOR EACH ROW EXECUTE FUNCTION trigger_process_role_change();

COMMENT ON TABLE training_trigger_events IS 'Log of all events that triggered training assignment checks';
COMMENT ON TABLE training_trigger_rules IS 'Rules mapping event types to training assignment templates and target employee scopes';
COMMENT ON FUNCTION process_training_trigger IS 'Core engine: log event, match rules, bulk-create employee_assignments. Returns count of assignments created.';
