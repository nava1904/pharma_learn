-- ===========================================
-- AUDIT TRAIL TABLE
-- 21 CFR Part 11 Compliant - Immutable, Append-Only
-- Supports Learn-IQ revision comparison feature
-- ===========================================

CREATE TABLE IF NOT EXISTS audit_trails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Entity reference
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,

    -- Action details
    action TEXT NOT NULL,
    action_category TEXT NOT NULL DEFAULT 'modification',
    action_description TEXT,

    -- 21 CFR Part 11 §11.10(e) — unified event classification
    -- Single query surface replaces 5 legacy tables (login_audit_trail,
    -- security_audit_trail, data_access_audit, permission_change_audit, system_config_audit)
    event_category TEXT NOT NULL DEFAULT 'DATA_CHANGE'
        CHECK (event_category IN (
            'DATA_CHANGE',
            'LOGIN',
            'LOGOUT',
            'PERMISSION_CHANGE',
            'CONFIG_CHANGE',
            'DATA_ACCESS',
            'ESIGNATURE',
            'PASSWORD_CHANGE',
            'SESSION_TIMEOUT',
            'FAILED_LOGIN',
            'ACCOUNT_LOCK'
        )),

    -- Change tracking (supports revision comparison)
    old_value JSONB,
    new_value JSONB,
    changed_fields TEXT[],

    -- Single-field delta for granular diffs (complements old_value/new_value for array updates)
    field_name TEXT,

    -- Actor information
    performed_by UUID,
    performed_by_name TEXT NOT NULL DEFAULT 'System',
    performed_by_role TEXT,
    performed_by_email TEXT,

    -- Reason tracking (Standard Reasons from Learn-IQ)
    reason TEXT,
    reason_code TEXT,
    standard_reason_id UUID,

    -- Context
    plant_id UUID,
    organization_id UUID,
    ip_address INET,
    user_agent TEXT,
    session_id UUID,

    -- Security context (for LOGIN/FAILED_LOGIN/ACCOUNT_LOCK events)
    failure_reason TEXT,
    mfa_verified BOOLEAN,
    device_info JSONB,

    -- Timestamp (immutable)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Integrity verification (21 CFR Part 11 tamper detection)
    row_hash TEXT NOT NULL,
    previous_hash TEXT,

    -- Revision tracking for Learn-IQ comparison feature
    revision_number INTEGER NOT NULL DEFAULT 1
);

-- Indexes for audit queries
CREATE INDEX IF NOT EXISTS idx_audit_trails_entity ON audit_trails(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_trails_performed_by ON audit_trails(performed_by);
CREATE INDEX IF NOT EXISTS idx_audit_trails_created_at ON audit_trails(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_trails_action ON audit_trails(action);
CREATE INDEX IF NOT EXISTS idx_audit_trails_revision ON audit_trails(entity_type, entity_id, revision_number);
CREATE INDEX IF NOT EXISTS idx_audit_trails_org ON audit_trails(organization_id);
CREATE INDEX IF NOT EXISTS idx_audit_trails_plant ON audit_trails(plant_id);

-- Function to generate row hash for tamper detection
CREATE OR REPLACE FUNCTION generate_audit_hash(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_action TEXT,
    p_performed_by UUID,
    p_created_at TIMESTAMPTZ,
    p_previous_hash TEXT
) RETURNS TEXT AS $$
BEGIN
    RETURN encode(
        digest(
            COALESCE(p_entity_type, '') || 
            COALESCE(p_entity_id::TEXT, '') || 
            COALESCE(p_action, '') || 
            COALESCE(p_performed_by::TEXT, '') || 
            COALESCE(p_created_at::TEXT, '') ||
            COALESCE(p_previous_hash, ''),
            'sha256'
        ),
        'hex'
    );
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to auto-generate hash and prevent updates/deletes
CREATE OR REPLACE FUNCTION audit_trail_immutable()
RETURNS TRIGGER AS $$
DECLARE
    v_previous_hash TEXT;
    v_revision INTEGER;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'Audit trail records are immutable and cannot be modified (21 CFR Part 11 compliance)';
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Audit trail records cannot be deleted (21 CFR Part 11 compliance)';
    END IF;
    
    IF TG_OP = 'INSERT' THEN
        -- Get previous hash for chain integrity
        SELECT row_hash, revision_number INTO v_previous_hash, v_revision
        FROM audit_trails
        WHERE entity_type = NEW.entity_type 
          AND entity_id = NEW.entity_id
        ORDER BY created_at DESC
        LIMIT 1;
        
        NEW.previous_hash := v_previous_hash;
        NEW.revision_number := COALESCE(v_revision, 0) + 1;
        NEW.row_hash := generate_audit_hash(
            NEW.entity_type,
            NEW.entity_id,
            NEW.action,
            NEW.performed_by,
            NEW.created_at,
            NEW.previous_hash
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_trail_immutable ON audit_trails;
CREATE TRIGGER trg_audit_trail_immutable
    BEFORE INSERT OR UPDATE OR DELETE ON audit_trails
    FOR EACH ROW EXECUTE FUNCTION audit_trail_immutable();

COMMENT ON TABLE audit_trails IS '21 CFR Part 11 compliant immutable audit trail with hash chain verification';
COMMENT ON COLUMN audit_trails.row_hash IS 'SHA-256 hash of record data for tamper detection';
COMMENT ON COLUMN audit_trails.previous_hash IS 'Hash chain link to previous record for integrity verification';
COMMENT ON COLUMN audit_trails.revision_number IS 'Learn-IQ revision number for comparison feature';
COMMENT ON COLUMN audit_trails.event_category IS '21 CFR §11.10(e): unified event classifier replacing legacy audit tables';
COMMENT ON COLUMN audit_trails.field_name IS 'Name of the specific field changed (for granular single-field delta auditing)';
COMMENT ON COLUMN audit_trails.failure_reason IS 'For LOGIN/FAILED_LOGIN/ACCOUNT_LOCK events: human-readable reason for failure';

-- -------------------------------------------------------
-- ALTER: idempotent column additions for existing databases
-- Fresh deployments get these columns via the CREATE TABLE above.
-- -------------------------------------------------------
ALTER TABLE audit_trails ADD COLUMN IF NOT EXISTS event_category TEXT NOT NULL DEFAULT 'DATA_CHANGE';
ALTER TABLE audit_trails ADD COLUMN IF NOT EXISTS field_name TEXT;
ALTER TABLE audit_trails ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE audit_trails ADD COLUMN IF NOT EXISTS mfa_verified BOOLEAN;
ALTER TABLE audit_trails ADD COLUMN IF NOT EXISTS device_info JSONB;

-- Add CHECK constraint on event_category for existing databases (idempotent via DO block)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'audit_trails_event_category_check'
          AND constraint_schema = 'public'
    ) THEN
        ALTER TABLE audit_trails
            ADD CONSTRAINT audit_trails_event_category_check
            CHECK (event_category IN (
                'DATA_CHANGE','LOGIN','LOGOUT','PERMISSION_CHANGE',
                'CONFIG_CHANGE','DATA_ACCESS','ESIGNATURE','PASSWORD_CHANGE',
                'SESSION_TIMEOUT','FAILED_LOGIN','ACCOUNT_LOCK'
            ));
    END IF;
END
$$;

-- Additional indexes for the new classification column
CREATE INDEX IF NOT EXISTS idx_audit_trails_event_category ON audit_trails(event_category);
CREATE INDEX IF NOT EXISTS idx_audit_trails_login_events   ON audit_trails(performed_by, created_at DESC)
    WHERE event_category IN ('LOGIN','LOGOUT','FAILED_LOGIN','SESSION_TIMEOUT');
CREATE INDEX IF NOT EXISTS idx_audit_trails_security       ON audit_trails(event_category, organization_id)
    WHERE event_category IN ('PERMISSION_CHANGE','CONFIG_CHANGE','ACCOUNT_LOCK');
