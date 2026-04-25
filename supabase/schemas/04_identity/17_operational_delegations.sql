-- ===========================================
-- OPERATIONAL DELEGATIONS
-- Delegate option for unplanned leave of employee
-- Alfa URS §4.4.6, EE URS §5.1.27 (Site Training Coordinator coverage)
-- Distinct from approval_delegations (which covers workflow approval only)
-- ===========================================

CREATE TABLE IF NOT EXISTS operational_delegations (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Who is delegating
    delegator_id        UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- Who is receiving the delegation
    delegate_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- What authority is being delegated
    -- 'FULL' = all operational authority; 'ROLE_SCOPED' = limited to specific role functions
    delegation_scope    TEXT NOT NULL DEFAULT 'FULL'
                            CHECK (delegation_scope IN ('FULL', 'ROLE_SCOPED', 'FUNCTION_SCOPED')),

    -- For ROLE_SCOPED: which role's functions are delegated
    delegated_role_id   UUID REFERENCES roles(id) ON DELETE SET NULL,

    -- For FUNCTION_SCOPED: which specific functions (as text codes)
    -- e.g. '{"approve_training_records", "sign_attendance"}'
    delegated_functions TEXT[],

    -- Temporal bounds
    starts_at           TIMESTAMPTZ NOT NULL,
    ends_at             TIMESTAMPTZ,            -- NULL = indefinite (requires manual revocation)

    -- Reason (GxP: delegation reason is mandatory for traceability)
    reason_id           UUID REFERENCES standard_reasons(id) ON DELETE SET NULL,
    reason_text         TEXT NOT NULL,          -- Mandatory free text (complements standard reason)

    -- Authorization
    -- Delegation must be e-signed by the delegator
    esignature_id       UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Scope
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,

    -- Status
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    revoked_at          TIMESTAMPTZ,
    revoked_by          UUID REFERENCES employees(id) ON DELETE SET NULL,
    revoked_reason      TEXT,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,

    -- A person cannot delegate to themselves
    CONSTRAINT chk_no_self_delegation CHECK (delegator_id != delegate_id),
    -- ends_at must be after starts_at
    CONSTRAINT chk_delegation_dates CHECK (ends_at IS NULL OR ends_at > starts_at)
);

CREATE INDEX IF NOT EXISTS idx_op_delegations_delegator ON operational_delegations(delegator_id);
CREATE INDEX IF NOT EXISTS idx_op_delegations_delegate  ON operational_delegations(delegate_id);
CREATE INDEX IF NOT EXISTS idx_op_delegations_active    ON operational_delegations(is_active, starts_at, ends_at)
    WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_op_delegations_org       ON operational_delegations(organization_id);

DROP TRIGGER IF EXISTS trg_op_delegations_updated ON operational_delegations;
CREATE TRIGGER trg_op_delegations_updated
    BEFORE UPDATE ON operational_delegations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_op_delegations_audit ON operational_delegations;
CREATE TRIGGER trg_op_delegations_audit
    AFTER INSERT OR UPDATE OR DELETE ON operational_delegations
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- FUNCTION: get the active delegate for an employee at a point in time
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_active_delegate(
    p_delegator_id  UUID,
    p_at_time       TIMESTAMPTZ DEFAULT NOW()
) RETURNS UUID AS $$
DECLARE
    v_delegate_id UUID;
BEGIN
    SELECT delegate_id INTO v_delegate_id
    FROM operational_delegations
    WHERE delegator_id = p_delegator_id
      AND is_active = TRUE
      AND starts_at <= p_at_time
      AND (ends_at IS NULL OR ends_at > p_at_time)
    ORDER BY starts_at DESC
    LIMIT 1;

    RETURN v_delegate_id;  -- NULL if no active delegation
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON TABLE  operational_delegations IS 'Operational delegation covering unplanned leave (Alfa §4.4.6); distinct from approval workflow delegation';
COMMENT ON COLUMN operational_delegations.delegation_scope IS 'FULL=all authority; ROLE_SCOPED=specific role functions; FUNCTION_SCOPED=named function codes';
COMMENT ON COLUMN operational_delegations.esignature_id IS 'Delegation requires delegator e-signature for GxP traceability';
COMMENT ON COLUMN operational_delegations.reason_text IS 'Mandatory free-text delegation reason (e.g. emergency leave, planned leave)';
COMMENT ON FUNCTION get_active_delegate IS 'Returns the active delegate for a given employee at a point in time; NULL if no active delegation';
