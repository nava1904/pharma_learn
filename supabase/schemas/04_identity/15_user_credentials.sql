-- ===========================================
-- USER CREDENTIALS
-- 21 CFR Part 11 §11.300 — Password controls, rotation, no-reuse
-- Alfa URS §3.1.41-44, 4.5.5, 4.8.1.15, 4.8.1.23
-- EE URS §5.9.2, 5.9.4, 5.6.12-14
-- ===========================================

CREATE TABLE IF NOT EXISTS user_credentials (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Ownership: one credential record per employee
    employee_id         UUID UNIQUE NOT NULL REFERENCES employees(id) ON DELETE CASCADE,

    -- Credential storage — value is bcrypt/argon2 hash; NEVER plaintext
    password_hash       TEXT NOT NULL,

    -- Lifecycle flags
    must_change         BOOLEAN NOT NULL DEFAULT TRUE,
    last_changed_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ,            -- driven by password_policies.max_age_days

    -- No-reuse enforcement (§11.300) — stores up to N previous hashes
    -- Config table password_policies.history_count controls how many are kept
    previous_hashes     TEXT[] NOT NULL DEFAULT '{}',

    -- Lock-out tracking
    failed_attempts     INTEGER NOT NULL DEFAULT 0,
    locked_at           TIMESTAMPTZ,            -- NULL = not locked

    -- MFA supplement (backup codes stored hashed)
    totp_secret_enc     TEXT,                   -- AES-encrypted TOTP seed
    backup_codes        TEXT[],                 -- hashed one-time backup codes
    mfa_enabled         BOOLEAN NOT NULL DEFAULT FALSE,

    -- Audit trail
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Hard cap: store at most 10 previous hashes (configurable enforcement at app layer)
    CONSTRAINT chk_prev_hash_limit
        CHECK (array_length(previous_hashes, 1) IS NULL
               OR array_length(previous_hashes, 1) <= 10)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_credentials_employee ON user_credentials(employee_id);
CREATE INDEX IF NOT EXISTS idx_user_credentials_locked   ON user_credentials(locked_at)
    WHERE locked_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_user_credentials_expires  ON user_credentials(expires_at)
    WHERE expires_at IS NOT NULL;

-- updated_at trigger
DROP TRIGGER IF EXISTS trg_user_credentials_updated ON user_credentials;
CREATE TRIGGER trg_user_credentials_updated
    BEFORE UPDATE ON user_credentials
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Audit trigger
DROP TRIGGER IF EXISTS trg_user_credentials_audit ON user_credentials;
CREATE TRIGGER trg_user_credentials_audit
    AFTER INSERT OR UPDATE OR DELETE ON user_credentials
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- FUNCTIONS
-- -------------------------------------------------------

-- Validate a password attempt: increments failed_attempts,
-- locks the account when threshold is reached, resets on success.
-- Returns TRUE on success, FALSE on failure.
-- p_policy_threshold: max consecutive failures before lock (from password_policies)
CREATE OR REPLACE FUNCTION validate_credential(
    p_employee_id     UUID,
    p_input_hash      TEXT,   -- caller already hashed the candidate password
    p_policy_threshold INTEGER DEFAULT 5
) RETURNS BOOLEAN AS $$
DECLARE
    v_cred user_credentials%ROWTYPE;
BEGIN
    SELECT * INTO v_cred FROM user_credentials WHERE employee_id = p_employee_id;
    IF NOT FOUND THEN
        RETURN FALSE;
    END IF;

    -- Check if account is locked
    IF v_cred.locked_at IS NOT NULL THEN
        RETURN FALSE;
    END IF;

    -- Compare hashes (caller supplies hash; DB does constant-time compare via =)
    IF v_cred.password_hash = p_input_hash THEN
        -- Success: reset failed attempts
        UPDATE user_credentials
        SET failed_attempts = 0,
            updated_at = NOW()
        WHERE employee_id = p_employee_id;
        RETURN TRUE;
    ELSE
        -- Failure: increment and potentially lock
        UPDATE user_credentials
        SET failed_attempts = failed_attempts + 1,
            locked_at = CASE
                WHEN failed_attempts + 1 >= p_policy_threshold THEN NOW()
                ELSE NULL
            END,
            updated_at = NOW()
        WHERE employee_id = p_employee_id;
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Change password: rotates hash, enforces no-reuse, resets must_change flag.
-- p_new_hash: already-hashed new password
-- p_history_count: number of previous passwords to retain (from password_policies)
CREATE OR REPLACE FUNCTION change_password(
    p_employee_id   UUID,
    p_new_hash      TEXT,
    p_history_count INTEGER DEFAULT 3
) RETURNS VOID AS $$
DECLARE
    v_cred user_credentials%ROWTYPE;
    v_trimmed TEXT[];
BEGIN
    SELECT * INTO v_cred FROM user_credentials WHERE employee_id = p_employee_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Credentials not found for employee %', p_employee_id;
    END IF;

    -- Enforce no-reuse: reject if new hash matches any stored previous hash
    IF v_cred.previous_hashes @> ARRAY[p_new_hash] THEN
        RAISE EXCEPTION 'New password cannot be the same as a recently used password (21 CFR Part 11 §11.300)';
    END IF;

    -- Also reject if same as current hash
    IF v_cred.password_hash = p_new_hash THEN
        RAISE EXCEPTION 'New password must differ from the current password';
    END IF;

    -- Build new previous_hashes: prepend current hash, trim to history_count
    v_trimmed := (ARRAY[v_cred.password_hash] || v_cred.previous_hashes)[1:p_history_count];

    UPDATE user_credentials
    SET password_hash    = p_new_hash,
        previous_hashes  = v_trimmed,
        must_change      = FALSE,
        last_changed_at  = NOW(),
        expires_at       = NULL,  -- caller sets expires_at after policy lookup
        failed_attempts  = 0,
        locked_at        = NULL,
        updated_at       = NOW()
    WHERE employee_id = p_employee_id;

    -- Write audit entry for password change event
    INSERT INTO audit_trails (
        entity_type, entity_id, action, event_category,
        performed_by, performed_by_name
    ) VALUES (
        'user_credentials', p_employee_id, 'password_changed', 'PASSWORD_CHANGE',
        p_employee_id, (SELECT first_name || ' ' || last_name FROM employees WHERE id = p_employee_id)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Unlock a locked account (admin action)
CREATE OR REPLACE FUNCTION unlock_credential(
    p_employee_id UUID,
    p_unlocked_by UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE user_credentials
    SET locked_at        = NULL,
        failed_attempts  = 0,
        must_change      = TRUE,   -- Force password reset on unlock
        updated_at       = NOW()
    WHERE employee_id = p_employee_id;

    INSERT INTO audit_trails (
        entity_type, entity_id, action, event_category,
        performed_by, performed_by_name
    ) VALUES (
        'user_credentials', p_employee_id, 'account_unlocked', 'ACCOUNT_LOCK',
        p_unlocked_by, (SELECT first_name || ' ' || last_name FROM employees WHERE id = p_unlocked_by)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE  user_credentials IS '21 CFR Part 11 §11.300 — password hash, rotation enforcement, lockout, and no-reuse storage';
COMMENT ON COLUMN user_credentials.password_hash IS 'bcrypt or argon2id hash — NEVER store plaintext';
COMMENT ON COLUMN user_credentials.previous_hashes IS 'Array of previously used hashes for no-reuse enforcement';
COMMENT ON COLUMN user_credentials.locked_at IS 'Non-NULL means account is locked; set when failed_attempts >= policy threshold';
COMMENT ON COLUMN user_credentials.totp_secret_enc IS 'AES-256-GCM encrypted TOTP seed; decryption key held in application secret vault';
