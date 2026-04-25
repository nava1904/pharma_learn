-- ===========================================
-- MANDATORY REASON ENFORCEMENT
-- GAP 5: Audit trail completeness (21 CFR Part 11)
-- ===========================================

-- Configuration table: which entity+action combos require a reason
CREATE TABLE IF NOT EXISTS mandatory_reason_actions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,   -- table name or '*' for all
    action TEXT NOT NULL,         -- e.g. 'status_changed', 'returned', '*'
    is_active BOOLEAN DEFAULT true,
    description TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, entity_type, action)
);

CREATE INDEX IF NOT EXISTS idx_mandatory_reason_org ON mandatory_reason_actions(organization_id);
CREATE INDEX IF NOT EXISTS idx_mandatory_reason_entity ON mandatory_reason_actions(entity_type);

-- Global defaults (organization_id NULL applies to all orgs)
INSERT INTO mandatory_reason_actions (organization_id, entity_type, action, description) VALUES
    (NULL, '*',         'status_changed', 'All status changes require a reason'),
    (NULL, '*',         'returned',       'Returned/rejected items require a reason'),
    (NULL, '*',         'dropped',        'Dropped items require a reason'),
    (NULL, 'documents', 'modified',       'Document modifications require a reason')
ON CONFLICT (organization_id, entity_type, action) DO NOTHING;

-- Check whether a given org+entity+action combination requires a reason
CREATE OR REPLACE FUNCTION is_reason_required(
    p_org_id UUID,
    p_entity_type TEXT,
    p_action TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_required BOOLEAN;
BEGIN
    -- 1. Org-specific + specific entity+action
    SELECT true INTO v_required
    FROM mandatory_reason_actions
    WHERE organization_id = p_org_id
      AND entity_type = p_entity_type
      AND action = p_action
      AND is_active = true
    LIMIT 1;
    IF FOUND THEN RETURN true; END IF;

    -- 2. Org-specific + wildcard entity
    SELECT true INTO v_required
    FROM mandatory_reason_actions
    WHERE organization_id = p_org_id
      AND entity_type = '*'
      AND action = p_action
      AND is_active = true
    LIMIT 1;
    IF FOUND THEN RETURN true; END IF;

    -- 3. Global (NULL org) + specific entity+action
    SELECT true INTO v_required
    FROM mandatory_reason_actions
    WHERE organization_id IS NULL
      AND entity_type = p_entity_type
      AND action = p_action
      AND is_active = true
    LIMIT 1;
    IF FOUND THEN RETURN true; END IF;

    -- 4. Global (NULL org) + wildcard entity
    SELECT true INTO v_required
    FROM mandatory_reason_actions
    WHERE organization_id IS NULL
      AND entity_type = '*'
      AND action = p_action
      AND is_active = true
    LIMIT 1;
    IF FOUND THEN RETURN true; END IF;

    -- 5. Fall back to behavioral control setting for status changes
    IF p_action = 'status_changed' THEN
        RETURN get_setting_bool(p_org_id, 'mandatory_reason_on_status_change');
    END IF;

    RETURN false;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Enforce mandatory reason — replaces the no-op stub in 02_revision_tracking.sql
-- Called by track_entity_changes() trigger and can be called directly from API layer
CREATE OR REPLACE FUNCTION enforce_mandatory_reason(
    p_org_id UUID,
    p_entity_type TEXT,
    p_action TEXT,
    p_reason TEXT
) RETURNS VOID AS $$
BEGIN
    IF is_reason_required(p_org_id, p_entity_type, p_action) THEN
        IF p_reason IS NULL OR TRIM(p_reason) = '' THEN
            RAISE EXCEPTION
                'Reason is mandatory for action "%" on "%" (21 CFR Part 11 compliance). '
                'Set app.current_action_reason before performing this operation.',
                p_action, p_entity_type
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE mandatory_reason_actions IS 'Configures which entity+action combinations require a mandatory audit reason (21 CFR Part 11)';
COMMENT ON FUNCTION is_reason_required IS 'Returns true if a reason is required for the given org/entity/action combination';
COMMENT ON FUNCTION enforce_mandatory_reason IS 'Raises check_violation if a required reason is missing; replaces stub in 02_revision_tracking.sql';
