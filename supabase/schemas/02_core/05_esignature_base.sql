-- ===========================================
-- ELECTRONIC SIGNATURES BASE
-- 21 CFR Part 11 Compliant
-- ===========================================

-- Signature meanings configuration
CREATE TABLE IF NOT EXISTS signature_meanings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meaning TEXT NOT NULL UNIQUE,
    display_text TEXT NOT NULL,
    description TEXT,
    applicable_entities TEXT[] DEFAULT '{}',
    requires_reason BOOLEAN DEFAULT false,
    requires_password_reauth BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default signature meanings per 21 CFR Part 11
INSERT INTO signature_meanings (meaning, display_text, applicable_entities, requires_reason, requires_password_reauth, display_order) VALUES
    ('authored', 'Authored', ARRAY['document', 'question', 'course', 'topic'], false, true, 1),
    ('reviewed', 'Reviewed', ARRAY['document', 'training_record', 'assessment', 'question_paper'], false, true, 2),
    ('approved', 'Approved', ARRAY['document', 'training_record', 'certificate', 'course', 'topic', 'trainer', 'session'], false, true, 3),
    ('acknowledged', 'Acknowledged', ARRAY['training_record', 'document_reading', 'job_responsibility', 'assignment'], false, true, 4),
    ('verified', 'Verified', ARRAY['training_record', 'attendance', 'marks', 'assessment'], false, true, 5),
    ('witnessed', 'Witnessed', ARRAY['training_record', 'ojt', 'biometric'], true, true, 6),
    ('rejected', 'Rejected', ARRAY['document', 'course', 'session', 'pending_approval'], true, true, 7)
ON CONFLICT (meaning) DO NOTHING;

-- Electronic signatures table
CREATE TABLE IF NOT EXISTS electronic_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Signer information
    employee_id UUID NOT NULL,
    employee_name TEXT NOT NULL,
    employee_email TEXT,
    employee_title TEXT,
    employee_id_code TEXT,
    
    -- Signature details
    meaning signature_meaning NOT NULL,
    meaning_display TEXT NOT NULL,
    reason TEXT,
    
    -- Entity reference
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    
    -- Verification context
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    
    -- Integrity verification (21 CFR Part 11)
    integrity_hash TEXT NOT NULL,
    data_snapshot JSONB, -- Snapshot of signed data for verification

    -- Deterministic binding to record state (auditable + reproducible)
    hash_schema_version INTEGER NOT NULL DEFAULT 1,
    canonical_payload JSONB,
    record_hash TEXT,
    
    -- Authentication verification
    password_reauth_verified BOOLEAN DEFAULT false,
    biometric_verified BOOLEAN DEFAULT false,
    mfa_verified BOOLEAN DEFAULT false,

    -- §11.200(a) — First-signing-in-session indicator
    -- TRUE when this is the first e-sig in the current user session
    -- (requires both identifier + authenticator to be verified at this event)
    is_first_in_session BOOLEAN NOT NULL DEFAULT FALSE,

    -- §11.200(b) — Session linkage
    -- SHA-256 hash of the session JWT — never the token itself
    session_token_hash TEXT,

    -- Signature chain — links successive e-sigs in one workflow
    -- NULL on the first signature of a chain; set for all subsequent ones
    prev_signature_id UUID REFERENCES electronic_signatures(id) ON DELETE RESTRICT,

    -- Validity
    is_valid BOOLEAN DEFAULT true,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    revoked_by UUID,

    -- Organization context
    organization_id UUID,
    plant_id UUID
);

-- Indexes for e-signature queries
CREATE INDEX IF NOT EXISTS idx_esig_entity ON electronic_signatures(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_esig_employee ON electronic_signatures(employee_id);
CREATE INDEX IF NOT EXISTS idx_esig_timestamp ON electronic_signatures(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_esig_meaning ON electronic_signatures(meaning);
CREATE INDEX IF NOT EXISTS idx_esig_org ON electronic_signatures(organization_id);
CREATE INDEX IF NOT EXISTS idx_esig_valid ON electronic_signatures(is_valid) WHERE is_valid = true;
CREATE INDEX IF NOT EXISTS idx_esig_record_hash ON electronic_signatures(record_hash) WHERE record_hash IS NOT NULL;
-- §11.200 session chain indexes
CREATE INDEX IF NOT EXISTS idx_esig_prev_sig ON electronic_signatures(prev_signature_id) WHERE prev_signature_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_esig_session_first ON electronic_signatures(session_token_hash, is_first_in_session);

-- -------------------------------------------------------
-- ALTER: idempotent column additions for existing databases
-- -------------------------------------------------------
ALTER TABLE electronic_signatures ADD COLUMN IF NOT EXISTS is_first_in_session BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE electronic_signatures ADD COLUMN IF NOT EXISTS session_token_hash TEXT;
ALTER TABLE electronic_signatures ADD COLUMN IF NOT EXISTS prev_signature_id UUID REFERENCES electronic_signatures(id) ON DELETE RESTRICT;

-- Deterministic canonicalization for JSONB payloads (sorted keys, stable structure)
CREATE OR REPLACE FUNCTION jsonb_canonical(p_input JSONB)
RETURNS TEXT AS $$
DECLARE
    v_type TEXT;
    v_result TEXT;
BEGIN
    v_type := jsonb_typeof(p_input);

    IF v_type IS NULL THEN
        RETURN 'null';
    ELSIF v_type = 'string' OR v_type = 'number' OR v_type = 'boolean' THEN
        RETURN p_input::TEXT;
    ELSIF v_type = 'array' THEN
        SELECT '[' || string_agg(jsonb_canonical(value), ',' ORDER BY ord) || ']'
        INTO v_result
        FROM jsonb_array_elements(p_input) WITH ORDINALITY AS arr(value, ord);
        RETURN COALESCE(v_result, '[]');
    ELSIF v_type = 'object' THEN
        SELECT '{' || string_agg(to_jsonb(key)::TEXT || ':' || jsonb_canonical(value), ',' ORDER BY key) || '}'
        INTO v_result
        FROM jsonb_each(p_input);
        RETURN COALESCE(v_result, '{}');
    ELSE
        RETURN p_input::TEXT;
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to make signatures immutable after creation
CREATE OR REPLACE FUNCTION esignature_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Only allow revoking a signature
        IF OLD.is_valid = true AND NEW.is_valid = false AND 
           NEW.revoked_at IS NOT NULL AND NEW.revoked_reason IS NOT NULL THEN
            -- Allow revocation
            RETURN NEW;
        ELSE
            RAISE EXCEPTION 'Electronic signatures are immutable and cannot be modified (21 CFR Part 11 compliance)';
        END IF;
    END IF;
    
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Electronic signatures cannot be deleted (21 CFR Part 11 compliance)';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_esignature_immutable ON electronic_signatures;
CREATE TRIGGER trg_esignature_immutable
    BEFORE UPDATE OR DELETE ON electronic_signatures
    FOR EACH ROW EXECUTE FUNCTION esignature_immutable();

-- Function to create e-signature with integrity hash
-- §11.200(a)/(b): caller must supply is_first_in_session and session_token_hash
CREATE OR REPLACE FUNCTION create_esignature(
    p_employee_id UUID,
    p_meaning signature_meaning,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_reason TEXT DEFAULT NULL,
    p_password_verified BOOLEAN DEFAULT false,
    p_biometric_verified BOOLEAN DEFAULT false,
    p_data_snapshot JSONB DEFAULT NULL,
    p_hash_schema_version INTEGER DEFAULT 1,
    p_canonical_payload JSONB DEFAULT NULL,
    -- §11.200 session chain parameters
    p_is_first_in_session BOOLEAN DEFAULT TRUE,
    p_session_token_hash TEXT DEFAULT NULL,
    p_prev_signature_id UUID DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_esig_id UUID;
    v_employee RECORD;
    v_meaning_display TEXT;
    v_meaning_record RECORD;
    v_hash TEXT;
    v_record_hash TEXT;
    v_canonical_payload JSONB;
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
    
    -- Check if password re-auth is required
    IF v_meaning_record.requires_password_reauth AND NOT p_password_verified THEN
        RAISE EXCEPTION 'Password re-authentication required for this signature type';
    END IF;
    
    -- Check if reason is required
    IF v_meaning_record.requires_reason AND (p_reason IS NULL OR p_reason = '') THEN
        RAISE EXCEPTION 'Reason is required for this signature type';
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

    -- Canonical payload + deterministic record hash
    v_canonical_payload := COALESCE(p_canonical_payload, p_data_snapshot);
    IF v_canonical_payload IS NOT NULL THEN
        v_record_hash := encode(
            digest(
                COALESCE(p_hash_schema_version::TEXT, '') || '|' || jsonb_canonical(v_canonical_payload),
                'sha256'
            ),
            'hex'
        );
    END IF;
    
    -- §11.200(a): first-in-session signature requires both identifier AND authenticator
    IF p_is_first_in_session AND NOT (p_password_verified OR p_biometric_verified) THEN
        RAISE EXCEPTION 'First e-signature in session requires both identifier and authenticator verification (21 CFR Part 11 §11.200(a))';
    END IF;

    -- Insert signature
    INSERT INTO electronic_signatures (
        employee_id, employee_name, employee_email, employee_title, employee_id_code,
        meaning, meaning_display, reason,
        entity_type, entity_id,
        ip_address, integrity_hash, data_snapshot,
        hash_schema_version, canonical_payload, record_hash,
        password_reauth_verified, biometric_verified,
        is_first_in_session, session_token_hash, prev_signature_id,
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
        v_canonical_payload,
        v_record_hash,
        p_password_verified,
        p_biometric_verified,
        p_is_first_in_session,
        p_session_token_hash,
        p_prev_signature_id,
        v_employee.organization_id,
        v_employee.plant_id
    )
    RETURNING id INTO v_esig_id;
    
    -- Create audit trail for signature
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
            'integrity_hash', v_hash
        ),
        p_employee_id, v_employee.full_name,
        v_employee.organization_id, v_employee.plant_id
    );
    
    RETURN v_esig_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify signature integrity
CREATE OR REPLACE FUNCTION verify_esignature_integrity(p_esig_id UUID)
RETURNS TABLE (
    is_valid BOOLEAN,
    verification_status TEXT,
    signature_details JSONB
) AS $$
DECLARE
    v_esig electronic_signatures%ROWTYPE;
    v_computed_hash TEXT;
    v_status TEXT;
    v_valid BOOLEAN;
BEGIN
    SELECT * INTO v_esig FROM electronic_signatures WHERE id = p_esig_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Signature not found'::TEXT, NULL::JSONB;
        RETURN;
    END IF;
    
    -- Check if revoked
    IF NOT v_esig.is_valid THEN
        RETURN QUERY SELECT FALSE, 'Signature has been revoked'::TEXT, 
            jsonb_build_object(
                'revoked_at', v_esig.revoked_at,
                'revoked_reason', v_esig.revoked_reason
            );
        RETURN;
    END IF;
    
    -- Recompute hash
    v_computed_hash := encode(
        digest(
            COALESCE(v_esig.employee_id::TEXT, '') || 
            COALESCE(v_esig.meaning::TEXT, '') || 
            COALESCE(v_esig.entity_type, '') || 
            COALESCE(v_esig.entity_id::TEXT, '') || 
            COALESCE(v_esig.timestamp::TEXT, '') ||
            COALESCE(v_esig.data_snapshot::TEXT, ''),
            'sha256'
        ),
        'hex'
    );
    
    IF v_computed_hash = v_esig.integrity_hash THEN
        v_valid := TRUE;
        v_status := 'Signature integrity verified';
    ELSE
        v_valid := FALSE;
        v_status := 'Signature integrity check failed - possible tampering';
    END IF;
    
    RETURN QUERY SELECT v_valid, v_status,
        jsonb_build_object(
            'signer', v_esig.employee_name,
            'signed_at', v_esig.timestamp,
            'meaning', v_esig.meaning_display,
            'entity_type', v_esig.entity_type,
            'entity_id', v_esig.entity_id
        );
END;
$$ LANGUAGE plpgsql;

-- Function to get signatures for an entity
CREATE OR REPLACE FUNCTION get_entity_signatures(
    p_entity_type TEXT,
    p_entity_id UUID
) RETURNS TABLE (
    signature_id UUID,
    signer_name TEXT,
    signer_title TEXT,
    meaning TEXT,
    signed_at TIMESTAMPTZ,
    reason TEXT,
    is_valid BOOLEAN
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        es.id,
        es.employee_name,
        es.employee_title,
        es.meaning_display,
        es.timestamp,
        es.reason,
        es.is_valid
    FROM electronic_signatures es
    WHERE es.entity_type = p_entity_type
      AND es.entity_id = p_entity_id
    ORDER BY es.timestamp ASC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE electronic_signatures IS '21 CFR Part 11 compliant electronic signatures with integrity verification';
COMMENT ON TABLE signature_meanings IS '21 CFR Part 11 signature meaning configurations';
COMMENT ON FUNCTION create_esignature IS 'Create an e-signature with integrity hash and audit trail';
COMMENT ON FUNCTION verify_esignature_integrity IS 'Verify signature has not been tampered with';
