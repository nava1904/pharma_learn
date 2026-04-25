-- ===========================================
-- PASSWORD POLICIES
-- 21 CFR Part 11 §11.300 — procedural/device controls for passwords
-- Alfa URS §3.1.41-47, §4.8.1.15-26
-- EE URS §5.6.10-14
-- ===========================================

CREATE TABLE IF NOT EXISTS password_policies (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Scope: NULL = organization-wide default; set = plant-specific override
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,

    -- Identity
    name                    TEXT NOT NULL DEFAULT 'Default Policy',
    description             TEXT,
    is_default              BOOLEAN NOT NULL DEFAULT FALSE,
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    -- Complexity rules (§11.300)
    min_length              INTEGER NOT NULL DEFAULT 8 CHECK (min_length >= 6),
    max_length              INTEGER DEFAULT 128,
    require_uppercase       BOOLEAN NOT NULL DEFAULT TRUE,
    require_lowercase       BOOLEAN NOT NULL DEFAULT TRUE,
    require_numeric         BOOLEAN NOT NULL DEFAULT TRUE,
    require_special         BOOLEAN NOT NULL DEFAULT TRUE,
    special_chars_allowed   TEXT DEFAULT '!@#$%^&*()_+-=[]{}|;:,.<>?',

    -- Cannot contain username or employee name
    disallow_username       BOOLEAN NOT NULL DEFAULT TRUE,
    disallow_employee_name  BOOLEAN NOT NULL DEFAULT TRUE,

    -- Rotation (§11.300)
    max_age_days            INTEGER DEFAULT 90 CHECK (max_age_days IS NULL OR max_age_days > 0),
    min_age_days            INTEGER DEFAULT 1  CHECK (min_age_days IS NULL OR min_age_days >= 0),
    warn_before_expiry_days INTEGER DEFAULT 14 CHECK (warn_before_expiry_days >= 0),

    -- No-reuse history
    history_count           INTEGER NOT NULL DEFAULT 5 CHECK (history_count BETWEEN 0 AND 24),

    -- Lockout policy
    lockout_threshold       INTEGER NOT NULL DEFAULT 5 CHECK (lockout_threshold BETWEEN 1 AND 20),
    lockout_duration_minutes INTEGER NOT NULL DEFAULT 30 CHECK (lockout_duration_minutes >= 0),
    -- 0 = manual unlock only (recommended for GxP systems)
    auto_unlock             BOOLEAN NOT NULL DEFAULT FALSE,

    -- Session / idle timeout
    session_timeout_seconds INTEGER NOT NULL DEFAULT 900  CHECK (session_timeout_seconds > 0),  -- 15 min default
    idle_timeout_seconds    INTEGER NOT NULL DEFAULT 600  CHECK (idle_timeout_seconds > 0),     -- 10 min default
    max_concurrent_sessions INTEGER NOT NULL DEFAULT 1    CHECK (max_concurrent_sessions >= 1),

    -- First-login force change
    force_change_on_first_login BOOLEAN NOT NULL DEFAULT TRUE,
    force_change_after_reset    BOOLEAN NOT NULL DEFAULT TRUE,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    CONSTRAINT chk_age_order
        CHECK (min_age_days IS NULL OR max_age_days IS NULL OR min_age_days < max_age_days)
);

-- One default policy per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_password_policies_default
    ON password_policies(organization_id)
    WHERE is_default = TRUE AND plant_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_password_policies_org   ON password_policies(organization_id);
CREATE INDEX IF NOT EXISTS idx_password_policies_plant ON password_policies(plant_id);
CREATE INDEX IF NOT EXISTS idx_password_policies_active ON password_policies(is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trg_password_policies_updated ON password_policies;
CREATE TRIGGER trg_password_policies_updated
    BEFORE UPDATE ON password_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_password_policies_audit ON password_policies;
CREATE TRIGGER trg_password_policies_audit
    AFTER INSERT OR UPDATE OR DELETE ON password_policies
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- FUNCTION: get the active policy for an employee
-- Returns plant-specific policy if it exists, else org-default
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_password_policy(p_employee_id UUID)
RETURNS password_policies AS $$
DECLARE
    v_emp RECORD;
    v_policy password_policies%ROWTYPE;
BEGIN
    SELECT organization_id, plant_id INTO v_emp
    FROM employees WHERE id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee not found: %', p_employee_id;
    END IF;

    -- Try plant-specific first
    IF v_emp.plant_id IS NOT NULL THEN
        SELECT * INTO v_policy
        FROM password_policies
        WHERE organization_id = v_emp.organization_id
          AND plant_id        = v_emp.plant_id
          AND is_active       = TRUE
        ORDER BY is_default DESC
        LIMIT 1;
    END IF;

    -- Fall back to org default
    IF v_policy IS NULL OR v_policy.id IS NULL THEN
        SELECT * INTO v_policy
        FROM password_policies
        WHERE organization_id = v_emp.organization_id
          AND plant_id IS NULL
          AND is_default = TRUE
          AND is_active  = TRUE
        LIMIT 1;
    END IF;

    RETURN v_policy;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

COMMENT ON TABLE  password_policies IS '21 CFR §11.300 — configurable password complexity, rotation, lockout, and session timeout';
COMMENT ON COLUMN password_policies.history_count IS 'Number of previous passwords to remember for no-reuse enforcement';
COMMENT ON COLUMN password_policies.lockout_threshold IS 'Max consecutive failures before account is locked (21 CFR §11.300)';
COMMENT ON COLUMN password_policies.auto_unlock IS 'FALSE (recommended GxP): locked accounts require manual admin unlock';
COMMENT ON COLUMN password_policies.idle_timeout_seconds IS 'Inactivity timeout before session requires re-authentication (Alfa §3.1.47)';
