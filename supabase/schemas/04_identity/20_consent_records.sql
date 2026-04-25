-- ===========================================
-- CONSENT RECORDS
-- User acceptance for job responsibilities, policies, training material use
-- Alfa URS §4.3.9: "user acceptance for job responsibilities"
-- Supports GxP consent audit trail (ALCOA+ attributable)
-- ===========================================

CREATE TABLE IF NOT EXISTS consent_records (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    employee_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- What the employee is consenting to
    consent_type        TEXT NOT NULL
                            CHECK (consent_type IN (
                                'JOB_RESPONSIBILITY',    -- Acknowledging assigned job responsibilities
                                'POLICY',                -- Accepting an organizational policy
                                'TRAINING_MATERIAL_USE', -- Consent to use training materials
                                'DATA_PROCESSING',       -- GDPR/data privacy consent
                                'SYSTEM_USAGE',          -- Computer system usage agreement (21 CFR §11)
                                'TRAINING_RECORD',       -- Acknowledging a training record
                                'ASSESSMENT_RESULT'      -- Acknowledging assessment results
                            )),

    -- Reference to the entity being consented to
    entity_type         TEXT NOT NULL,   -- 'job_responsibility', 'policy', 'document', etc.
    entity_id           UUID NOT NULL,

    -- Versioning (consent to specific version)
    entity_version      TEXT,           -- document version, policy version, etc.
    consent_version     INTEGER NOT NULL DEFAULT 1,

    -- Acceptance
    accepted_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- E-signature (required for job responsibility and policy consent per §4.3.9)
    esignature_id       UUID REFERENCES electronic_signatures(id) ON DELETE RESTRICT,

    -- Withdrawal support (e.g. for GDPR data processing consent)
    withdrawn_at        TIMESTAMPTZ,
    withdrawal_reason   TEXT,
    withdrawal_esig_id  UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Audit context
    ip_address          INET,
    user_agent          TEXT,

    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,
    plant_id            UUID REFERENCES plants(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Consent records are append-only; withdrawals add a new record type
-- Existing consent rows are never modified — withdrawal is a state, not an edit
CREATE OR REPLACE FUNCTION consent_records_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Only allow withdrawal fields to be set
        IF OLD.employee_id    != NEW.employee_id    OR
           OLD.consent_type   != NEW.consent_type   OR
           OLD.entity_type    != NEW.entity_type    OR
           OLD.entity_id      != NEW.entity_id      OR
           OLD.accepted_at    != NEW.accepted_at    THEN
            RAISE EXCEPTION 'Consent records are immutable after creation (ALCOA+ — attributable, traceable)';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Consent records cannot be deleted (GxP requirement — ALCOA+ legibility/endurance)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_consent_records_immutable ON consent_records;
CREATE TRIGGER trg_consent_records_immutable
    BEFORE UPDATE OR DELETE ON consent_records
    FOR EACH ROW EXECUTE FUNCTION consent_records_immutable();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_consent_employee   ON consent_records(employee_id);
CREATE INDEX IF NOT EXISTS idx_consent_type       ON consent_records(consent_type);
CREATE INDEX IF NOT EXISTS idx_consent_entity     ON consent_records(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_consent_accepted   ON consent_records(accepted_at DESC);
CREATE INDEX IF NOT EXISTS idx_consent_active     ON consent_records(employee_id, consent_type)
    WHERE withdrawn_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_consent_org        ON consent_records(organization_id);

-- -------------------------------------------------------
-- FUNCTION: check if an employee has active consent for an entity
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION has_active_consent(
    p_employee_id   UUID,
    p_consent_type  TEXT,
    p_entity_id     UUID
) RETURNS BOOLEAN AS $$
    SELECT EXISTS (
        SELECT 1
        FROM consent_records
        WHERE employee_id   = p_employee_id
          AND consent_type  = p_consent_type
          AND entity_id     = p_entity_id
          AND withdrawn_at IS NULL
        ORDER BY accepted_at DESC
        LIMIT 1
    );
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

COMMENT ON TABLE  consent_records IS 'GxP consent audit trail for job responsibilities, policies, and training (Alfa §4.3.9)';
COMMENT ON COLUMN consent_records.esignature_id IS 'E-signature required for JOB_RESPONSIBILITY and POLICY consent types';
COMMENT ON COLUMN consent_records.consent_version IS 'Version of the consent document at time of acceptance — needed when policy is updated';
COMMENT ON COLUMN consent_records.withdrawn_at IS 'When withdrawn — withdrawal is tracked here, not by deleting the record (ALCOA+)';
