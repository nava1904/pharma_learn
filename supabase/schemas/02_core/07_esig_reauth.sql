-- ===========================================
-- E-SIGNATURE RE-AUTHENTICATION SESSIONS
-- GAP 6: Session binding + 15-min reauth validity (21 CFR Part 11)
-- ===========================================

-- Re-authentication session table
-- Each password re-auth produces a short-lived token (15 min max, configurable)
-- Once consumed by a signature, it cannot be reused
CREATE TABLE IF NOT EXISTS esignature_reauth_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    session_token TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL
        GENERATED ALWAYS AS (created_at + INTERVAL '15 minutes') STORED,
    used_at TIMESTAMPTZ,
    used_for_esig_id UUID,                          -- set when consumed (no FK to avoid circular dep)
    ip_address INET,
    user_agent TEXT,
    is_consumed BOOLEAN NOT NULL DEFAULT false,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_esig_reauth_employee ON esignature_reauth_sessions(employee_id);
CREATE INDEX IF NOT EXISTS idx_esig_reauth_token ON esignature_reauth_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_esig_reauth_expires ON esignature_reauth_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_esig_reauth_active ON esignature_reauth_sessions(is_consumed, expires_at)
    WHERE is_consumed = false;

-- Append-only guard: only allow the is_consumed false→true transition
CREATE OR REPLACE FUNCTION esig_reauth_session_guard()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION '21 CFR Part 11: Re-auth sessions are append-only and cannot be deleted';
    END IF;

    IF TG_OP = 'UPDATE' THEN
        -- Only allow marking as consumed
        IF OLD.is_consumed = false AND NEW.is_consumed = true
           AND NEW.used_at IS NOT NULL THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION '21 CFR Part 11: Re-auth sessions are immutable after creation (only consumption allowed)';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_esig_reauth_guard ON esignature_reauth_sessions;
CREATE TRIGGER trg_esig_reauth_guard
    BEFORE UPDATE OR DELETE ON esignature_reauth_sessions
    FOR EACH ROW EXECUTE FUNCTION esig_reauth_session_guard();

-- Create a re-authentication session after password verification
-- The caller (API layer / Edge Function) is responsible for verifying the password
-- before calling this function
CREATE OR REPLACE FUNCTION create_reauth_session(
    p_employee_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
    v_token TEXT;
    v_org_id UUID;
BEGIN
    SELECT organization_id INTO v_org_id FROM employees WHERE id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee not found: %', p_employee_id;
    END IF;

    -- Generate a cryptographically secure session token
    v_token := encode(gen_random_bytes(32), 'hex');

    INSERT INTO esignature_reauth_sessions (
        employee_id, session_token, ip_address, user_agent, organization_id
    ) VALUES (
        p_employee_id, v_token, p_ip_address, p_user_agent, v_org_id
    )
    RETURNING id INTO v_session_id;

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Validate that a re-auth session is still usable
CREATE OR REPLACE FUNCTION validate_reauth_session(
    p_session_id UUID,
    p_employee_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_session esignature_reauth_sessions%ROWTYPE;
    v_validity_minutes INTEGER;
    v_effective_expiry TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_session
    FROM esignature_reauth_sessions
    WHERE id = p_session_id AND employee_id = p_employee_id;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    IF v_session.is_consumed THEN
        RETURN false;
    END IF;

    -- Respect org-level override of validity window
    v_validity_minutes := COALESCE(
        get_setting_text(v_session.organization_id, 'esig_reauth_validity_minutes')::INTEGER,
        15
    );
    v_effective_expiry := v_session.created_at + (v_validity_minutes || ' minutes')::INTERVAL;

    IF NOW() > v_effective_expiry THEN
        RETURN false;
    END IF;

    RETURN true;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Mark session as consumed after a successful signature
CREATE OR REPLACE FUNCTION consume_reauth_session(
    p_session_id UUID,
    p_esig_id UUID
) RETURNS VOID AS $$
BEGIN
    UPDATE esignature_reauth_sessions
    SET is_consumed = true,
        used_at = NOW(),
        used_for_esig_id = p_esig_id
    WHERE id = p_session_id AND is_consumed = false;

    IF NOT FOUND THEN
        RAISE EXCEPTION '21 CFR Part 11: Re-auth session % not found or already consumed', p_session_id;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ===========================================
-- ENHANCED create_esignature() WITH SESSION BINDING
-- Replaces the version in 02_core/05_esignature_base.sql
-- Adds p_reauth_session_id parameter for 21 CFR Part 11 session binding
-- ===========================================
CREATE OR REPLACE FUNCTION create_esignature(
    p_employee_id UUID,
    p_meaning signature_meaning,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_password_verified BOOLEAN DEFAULT false,
    p_biometric_verified BOOLEAN DEFAULT false,
    p_data_snapshot JSONB DEFAULT NULL,
    p_reauth_session_id UUID DEFAULT NULL,
    p_hash_schema_version INTEGER DEFAULT 1,
    p_canonical_payload JSONB DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_esig_id UUID;
    v_employee RECORD;
    v_meaning_display TEXT;
    v_meaning_record RECORD;
    v_hash TEXT;
    v_org_id UUID;
    v_plant_id UUID;
BEGIN
    -- Get employee details
    SELECT
        e.id,
        e.first_name || ' ' || e.last_name as full_name,
        e.email,
        e.designation,
        e.employee_id as emp_code,
        e.organization_id,
        e.plant_id
    INTO v_employee
    FROM employees e
    WHERE e.id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee not found: %', p_employee_id;
    END IF;

    -- Get meaning configuration
    SELECT * INTO v_meaning_record
    FROM signature_meanings
    WHERE meaning = p_meaning::TEXT;

    IF NOT FOUND OR NOT v_meaning_record.is_active THEN
        RAISE EXCEPTION 'Invalid or inactive signature meaning: %', p_meaning;
    END IF;

    -- 21 CFR Part 11: enforce re-authentication
    IF v_meaning_record.requires_password_reauth THEN
        IF p_reauth_session_id IS NOT NULL THEN
            -- Session-based reauth (preferred — carries timing + binding)
            IF NOT validate_reauth_session(p_reauth_session_id, p_employee_id) THEN
                RAISE EXCEPTION '21 CFR Part 11: Re-authentication session is invalid or expired (max % minutes). '
                    'Please re-authenticate.',
                    COALESCE(
                        get_setting_text(v_employee.organization_id, 'esig_reauth_validity_minutes'),
                        '15'
                    );
            END IF;
        ELSIF NOT p_password_verified THEN
            RAISE EXCEPTION 'Password re-authentication required for signature type "%"', p_meaning;
        END IF;
    END IF;

    -- 21 CFR Part 11: enforce reason where required
    IF v_meaning_record.requires_reason AND (p_reason IS NULL OR TRIM(p_reason) = '') THEN
        RAISE EXCEPTION 'Reason is required for signature type "%"', p_meaning;
    END IF;

    -- Generate integrity hash
    v_hash := encode(
        digest(
            COALESCE(p_employee_id::TEXT, '') ||
            COALESCE(p_meaning::TEXT, '') ||
            COALESCE(p_entity_type, '') ||
            COALESCE(p_entity_id::TEXT, '') ||
            COALESCE(NOW()::TEXT, '') ||
            COALESCE(p_data_snapshot::TEXT, ''),
            'sha256'
        ),
        'hex'
    );

    -- Insert signature
    INSERT INTO electronic_signatures (
        employee_id, employee_name, employee_email, employee_title, employee_id_code,
        meaning, meaning_display, reason,
        entity_type, entity_id,
        ip_address, integrity_hash, data_snapshot,
        hash_schema_version, canonical_payload, record_hash,
        password_reauth_verified, biometric_verified,
        organization_id, plant_id
    ) VALUES (
        p_employee_id,
        v_employee.full_name,
        v_employee.email,
        v_employee.designation,
        v_employee.emp_code,
        p_meaning,
        v_meaning_record.display_text,
        p_reason,
        p_entity_type,
        p_entity_id,
        inet_client_addr(),
        v_hash,
        p_data_snapshot,
        p_hash_schema_version,
        COALESCE(p_canonical_payload, p_data_snapshot),
        CASE
            WHEN COALESCE(p_canonical_payload, p_data_snapshot) IS NULL THEN NULL
            ELSE encode(
                digest(
                    COALESCE(p_hash_schema_version::TEXT, '') || '|' || jsonb_canonical(COALESCE(p_canonical_payload, p_data_snapshot)),
                    'sha256'
                ),
                'hex'
            )
        END,
        p_password_verified OR (p_reauth_session_id IS NOT NULL),
        p_biometric_verified,
        v_employee.organization_id,
        v_employee.plant_id
    )
    RETURNING id INTO v_esig_id;

    -- Consume the reauth session after successful signature creation
    IF p_reauth_session_id IS NOT NULL THEN
        PERFORM consume_reauth_session(p_reauth_session_id, v_esig_id);
    END IF;

    -- Create audit trail
    INSERT INTO audit_trails (
        entity_type, entity_id, action, action_category,
        new_value, performed_by, performed_by_name,
        organization_id, plant_id
    ) VALUES (
        p_entity_type, p_entity_id,
        'signed_' || p_meaning::TEXT, 'esignature',
        jsonb_build_object(
            'esignature_id', v_esig_id,
            'meaning', p_meaning,
            'reason', p_reason,
            'integrity_hash', v_hash,
            'session_bound', p_reauth_session_id IS NOT NULL
        ),
        p_employee_id, v_employee.full_name,
        v_employee.organization_id, v_employee.plant_id
    );

    RETURN v_esig_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE esignature_reauth_sessions IS '21 CFR Part 11: Short-lived re-authentication tokens (15 min max) consumed on first signature use';
COMMENT ON FUNCTION create_reauth_session IS 'Create a re-auth session after password verification. Returns session UUID to pass to create_esignature()';
COMMENT ON FUNCTION validate_reauth_session IS 'Returns true if session exists, is not consumed, and has not exceeded validity window';
COMMENT ON FUNCTION consume_reauth_session IS 'Mark session consumed after signature — prevents session reuse';
COMMENT ON FUNCTION create_esignature IS 'Enhanced 21 CFR Part 11 e-signature with session binding. Pass p_reauth_session_id from create_reauth_session().';
