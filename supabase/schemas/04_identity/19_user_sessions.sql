-- ===========================================
-- USER SESSIONS
-- JWT session tracking for idle timeout enforcement and §11.200 audit
-- Alfa URS §3.1.47 (idle timeout)
-- EE URS §5.6.10, §5.9.7 (session security)
-- 21 CFR Part 11 §11.200 (session-based signature chain)
-- ===========================================

CREATE TABLE IF NOT EXISTS user_sessions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identity
    employee_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    auth_user_id        UUID,           -- Supabase auth.users UID

    -- JWT tracking (we store hash of JWT, never the token itself)
    jwt_id              TEXT UNIQUE,    -- jti claim from JWT (unique per token)
    jwt_hash            TEXT,           -- SHA-256 hash of the raw JWT string

    -- Lifecycle
    issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ NOT NULL,
    last_activity_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at          TIMESTAMPTZ,
    revocation_reason   TEXT
                            CHECK (revocation_reason IS NULL OR revocation_reason IN (
                                'LOGOUT',
                                'IDLE_TIMEOUT',
                                'SESSION_TIMEOUT',
                                'ADMIN_REVOKE',
                                'PASSWORD_CHANGE',
                                'ACCOUNT_LOCK',
                                'DUPLICATE_SESSION'
                            )),

    -- Context
    ip_address          INET,
    user_agent          TEXT,
    device_fingerprint  TEXT,   -- browser fingerprint hash for anomaly detection
    sso_config_id       UUID REFERENCES sso_configurations(id) ON DELETE SET NULL,

    -- Organization context
    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,
    plant_id            UUID REFERENCES plants(id) ON DELETE SET NULL,

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Sessions are append-only after revocation — never hard-delete
CREATE OR REPLACE FUNCTION user_sessions_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'user_sessions cannot be deleted — mark as revoked instead (21 CFR Part 11 §11.200)';
    END IF;
    -- Allow updates only to revocation fields
    IF TG_OP = 'UPDATE' THEN
        IF OLD.employee_id != NEW.employee_id OR
           OLD.jwt_id      != NEW.jwt_id      OR
           OLD.issued_at   != NEW.issued_at   THEN
            RAISE EXCEPTION 'user_sessions core identity fields are immutable after creation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_sessions_immutable ON user_sessions;
CREATE TRIGGER trg_user_sessions_immutable
    BEFORE UPDATE OR DELETE ON user_sessions
    FOR EACH ROW EXECUTE FUNCTION user_sessions_immutable();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_sessions_employee   ON user_sessions(employee_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_jwt_id     ON user_sessions(jwt_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_active     ON user_sessions(employee_id, expires_at)
    WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_user_sessions_ip         ON user_sessions(ip_address);
CREATE INDEX IF NOT EXISTS idx_user_sessions_issued     ON user_sessions(issued_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_sessions_org        ON user_sessions(organization_id);

-- -------------------------------------------------------
-- FUNCTION: revoke a session (marks as revoked, audits event)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION revoke_user_session(
    p_session_id    UUID,
    p_reason        TEXT DEFAULT 'LOGOUT',
    p_revoked_by    UUID DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
    v_session user_sessions%ROWTYPE;
BEGIN
    SELECT * INTO v_session FROM user_sessions WHERE id = p_session_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session not found: %', p_session_id;
    END IF;

    IF v_session.revoked_at IS NOT NULL THEN
        RETURN;  -- Already revoked — idempotent
    END IF;

    UPDATE user_sessions
    SET revoked_at       = NOW(),
        revocation_reason = p_reason
    WHERE id = p_session_id;

    -- Write audit entry
    INSERT INTO audit_trails (
        entity_type, entity_id, action, event_category,
        performed_by, performed_by_name,
        organization_id
    ) VALUES (
        'user_session', p_session_id,
        'session_revoked', CASE p_reason
            WHEN 'LOGOUT'          THEN 'LOGOUT'
            WHEN 'IDLE_TIMEOUT'    THEN 'SESSION_TIMEOUT'
            WHEN 'SESSION_TIMEOUT' THEN 'SESSION_TIMEOUT'
            ELSE 'LOGIN'
        END,
        COALESCE(p_revoked_by, v_session.employee_id),
        (SELECT first_name || ' ' || last_name FROM employees WHERE id = v_session.employee_id),
        v_session.organization_id
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- FUNCTION: get active session count for an employee
-- Used to enforce max_concurrent_sessions policy
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_active_session_count(p_employee_id UUID)
RETURNS INTEGER AS $$
    SELECT COUNT(*)::INTEGER
    FROM user_sessions
    WHERE employee_id = p_employee_id
      AND revoked_at IS NULL
      AND expires_at > NOW();
$$ LANGUAGE SQL STABLE;

COMMENT ON TABLE  user_sessions IS 'JWT session registry for idle-timeout enforcement and §11.200 session chain tracking';
COMMENT ON COLUMN user_sessions.jwt_id IS 'JWT jti claim — unique per token; used to revoke a specific session';
COMMENT ON COLUMN user_sessions.jwt_hash IS 'SHA-256 hash of raw JWT — NEVER store the token itself';
COMMENT ON COLUMN user_sessions.device_fingerprint IS 'Browser/device fingerprint hash for multi-device anomaly detection';
COMMENT ON COLUMN user_sessions.revocation_reason IS 'Why session was terminated — critical for 21 CFR §11.200 session audit';
