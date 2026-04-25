-- ===========================================
-- REVISION TRACKING
-- Auto-increment revision and track changes
-- ===========================================

-- Function to get current user ID from JWT
CREATE OR REPLACE FUNCTION get_current_user_id() 
RETURNS UUID AS $$
BEGIN
    RETURN COALESCE(
        (current_setting('request.jwt.claims', true)::jsonb->>'sub')::UUID,
        '00000000-0000-0000-0000-000000000000'::UUID
    );
EXCEPTION WHEN OTHERS THEN
    RETURN '00000000-0000-0000-0000-000000000000'::UUID;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get current user's name from JWT
CREATE OR REPLACE FUNCTION get_current_user_name() 
RETURNS TEXT AS $$
BEGIN
    RETURN COALESCE(
        current_setting('request.jwt.claims', true)::jsonb->>'name',
        'System'
    );
EXCEPTION WHEN OTHERS THEN
    RETURN 'System';
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get current user's organization ID
CREATE OR REPLACE FUNCTION get_current_org_id() 
RETURNS UUID AS $$
BEGIN
    RETURN (current_setting('request.jwt.claims', true)::jsonb->>'org_id')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to get current user's plant ID
CREATE OR REPLACE FUNCTION get_current_plant_id() 
RETURNS UUID AS $$
BEGIN
    RETURN (current_setting('request.jwt.claims', true)::jsonb->>'plant_id')::UUID;
EXCEPTION WHEN OTHERS THEN
    RETURN NULL;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to increment revision on update
CREATE OR REPLACE FUNCTION increment_revision()
RETURNS TRIGGER AS $$
BEGIN
    NEW.revision_no := COALESCE(OLD.revision_no, 0) + 1;
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to set created_by on insert
CREATE OR REPLACE FUNCTION set_created_by()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.created_by IS NULL THEN
        NEW.created_by := get_current_user_id();
    END IF;
    NEW.created_at := COALESCE(NEW.created_at, NOW());
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Stub: replaced by real implementation in 02_core/06_reason_enforcement.sql
-- Defined here so track_entity_changes() can call it during table creation phase
CREATE OR REPLACE FUNCTION enforce_mandatory_reason(
    p_org_id UUID, p_entity_type TEXT, p_action TEXT, p_reason TEXT
) RETURNS VOID AS $$ BEGIN END; $$ LANGUAGE plpgsql;

-- Function to track changes and create audit entry
CREATE OR REPLACE FUNCTION track_entity_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_changed_fields TEXT[];
    v_old_json JSONB;
    v_new_json JSONB;
    v_key TEXT;
    v_actor_id UUID;
    v_actor_name TEXT;
    v_org_id UUID;
    v_plant_id UUID;
    v_action_reason TEXT;
BEGIN
    -- Get current user info
    v_actor_id := get_current_user_id();
    v_actor_name := get_current_user_name();
    v_org_id := get_current_org_id();
    v_plant_id := get_current_plant_id();
    v_action_reason := current_setting('app.current_action_reason', true);

    IF TG_OP = 'INSERT' THEN
        v_new_json := to_jsonb(NEW);

        INSERT INTO audit_trails (
            entity_type, entity_id, action, action_category,
            new_value, performed_by, performed_by_name,
            reason, organization_id, plant_id
        ) VALUES (
            TG_TABLE_NAME, NEW.id, 'created', 'creation',
            v_new_json, v_actor_id, v_actor_name,
            NULLIF(TRIM(COALESCE(v_action_reason, '')), ''),
            v_org_id, v_plant_id
        );

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_json := to_jsonb(OLD);
        v_new_json := to_jsonb(NEW);

        -- Find changed fields (excluding updated_at and revision_no)
        FOR v_key IN SELECT jsonb_object_keys(v_new_json)
        LOOP
            IF v_key NOT IN ('updated_at', 'revision_no') AND
               v_old_json->v_key IS DISTINCT FROM v_new_json->v_key THEN
                v_changed_fields := array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;

        -- Only audit if something meaningful changed
        IF array_length(v_changed_fields, 1) > 0 THEN
            -- Enforce mandatory reason on status changes (21 CFR Part 11)
            IF 'status' = ANY(v_changed_fields) THEN
                PERFORM enforce_mandatory_reason(
                    v_org_id,
                    TG_TABLE_NAME,
                    'status_changed',
                    v_action_reason
                );
            END IF;

            INSERT INTO audit_trails (
                entity_type, entity_id, action, action_category,
                old_value, new_value, changed_fields,
                performed_by, performed_by_name,
                reason, organization_id, plant_id
            ) VALUES (
                TG_TABLE_NAME, NEW.id, 'modified', 'modification',
                v_old_json, v_new_json, v_changed_fields,
                v_actor_id, v_actor_name,
                NULLIF(TRIM(COALESCE(v_action_reason, '')), ''),
                v_org_id, v_plant_id
            );
        END IF;

    ELSIF TG_OP = 'DELETE' THEN
        v_old_json := to_jsonb(OLD);

        INSERT INTO audit_trails (
            entity_type, entity_id, action, action_category,
            old_value, performed_by, performed_by_name,
            reason, organization_id, plant_id
        ) VALUES (
            TG_TABLE_NAME, OLD.id, 'deleted', 'deletion',
            v_old_json, v_actor_id, v_actor_name,
            NULLIF(TRIM(COALESCE(v_action_reason, '')), ''),
            v_org_id, v_plant_id
        );
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to compare two revisions (Learn-IQ feature)
CREATE OR REPLACE FUNCTION compare_audit_revisions(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_revision_1 INTEGER,
    p_revision_2 INTEGER
) RETURNS TABLE (
    field_name TEXT,
    revision_1_value JSONB,
    revision_2_value JSONB,
    changed BOOLEAN
) AS $$
DECLARE
    v_rev1 JSONB;
    v_rev2 JSONB;
    v_key TEXT;
BEGIN
    -- Get revision 1 data
    SELECT new_value INTO v_rev1
    FROM audit_trails
    WHERE entity_type = p_entity_type 
      AND entity_id = p_entity_id 
      AND revision_number = p_revision_1;
      
    -- Get revision 2 data
    SELECT new_value INTO v_rev2
    FROM audit_trails
    WHERE entity_type = p_entity_type 
      AND entity_id = p_entity_id 
      AND revision_number = p_revision_2;
    
    -- Compare all fields
    FOR v_key IN SELECT DISTINCT jsonb_object_keys(COALESCE(v_rev1, '{}')) 
                 UNION 
                 SELECT DISTINCT jsonb_object_keys(COALESCE(v_rev2, '{}'))
    LOOP
        RETURN QUERY SELECT 
            v_key,
            v_rev1->v_key,
            v_rev2->v_key,
            v_rev1->v_key IS DISTINCT FROM v_rev2->v_key;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to get audit history for an entity
CREATE OR REPLACE FUNCTION get_audit_history(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_limit INTEGER DEFAULT 100
) RETURNS TABLE (
    revision_number INTEGER,
    action TEXT,
    changed_fields TEXT[],
    performed_by_name TEXT,
    performed_at TIMESTAMPTZ,
    reason TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        at.revision_number,
        at.action,
        at.changed_fields,
        at.performed_by_name,
        at.created_at,
        at.reason
    FROM audit_trails at
    WHERE at.entity_type = p_entity_type
      AND at.entity_id = p_entity_id
    ORDER BY at.revision_number DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION compare_audit_revisions IS 'Learn-IQ revision comparison feature for audit trails';
COMMENT ON FUNCTION track_entity_changes IS 'Automatic audit trail generation for entity changes';
