-- ===========================================
-- BIOMETRIC REGISTRATIONS TABLE
-- For non-login users and attendance verification
-- Learn-IQ: Enroll Fingerprint vs Bio Metrics Initiate
-- ===========================================

CREATE TABLE IF NOT EXISTS biometric_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Biometric type
    biometric_type TEXT NOT NULL DEFAULT 'fingerprint' CHECK (biometric_type IN ('fingerprint', 'face', 'iris', 'palm')),
    
    -- Fingerprint specific (can have multiple fingers)
    finger_index INTEGER CHECK (finger_index BETWEEN 1 AND 10),
    -- 1=Right Thumb, 2=Right Index, 3=Right Middle, 4=Right Ring, 5=Right Little
    -- 6=Left Thumb, 7=Left Index, 8=Left Middle, 9=Left Ring, 10=Left Little
    
    -- Template data (encrypted)
    template_hash TEXT NOT NULL, -- Hash of the biometric template
    template_data BYTEA, -- Encrypted biometric template
    template_quality INTEGER, -- Quality score 0-100
    
    -- Device info
    device_id TEXT,
    device_name TEXT,
    device_ip INET,
    
    -- Registration context
    registration_type TEXT DEFAULT 'admin' CHECK (registration_type IN ('self', 'admin')),
    -- 'self' = Enroll Fingerprint (Personal Settings) - Login users
    -- 'admin' = Bio Metrics Initiate (Admin menu) - Non-login users
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    
    -- Registration tracking
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    registered_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Usage tracking
    last_used_at TIMESTAMPTZ,
    usage_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_biometric_org ON biometric_registrations(organization_id);
CREATE INDEX IF NOT EXISTS idx_biometric_employee ON biometric_registrations(employee_id);
CREATE INDEX IF NOT EXISTS idx_biometric_active ON biometric_registrations(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_biometric_type ON biometric_registrations(biometric_type);
CREATE INDEX IF NOT EXISTS idx_biometric_template_hash ON biometric_registrations(template_hash);

-- Triggers
DROP TRIGGER IF EXISTS trg_biometric_audit ON biometric_registrations;
CREATE TRIGGER trg_biometric_audit
    AFTER INSERT OR UPDATE OR DELETE ON biometric_registrations
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Function to verify biometric
CREATE OR REPLACE FUNCTION verify_biometric(
    p_employee_id UUID,
    p_template_hash TEXT,
    p_biometric_type TEXT DEFAULT 'fingerprint'
) RETURNS BOOLEAN AS $$
DECLARE
    v_valid BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1 FROM biometric_registrations
        WHERE employee_id = p_employee_id
          AND template_hash = p_template_hash
          AND biometric_type = p_biometric_type
          AND is_active = true
          AND is_verified = true
    ) INTO v_valid;
    
    -- Update usage tracking if valid
    IF v_valid THEN
        UPDATE biometric_registrations
        SET last_used_at = NOW(),
            usage_count = usage_count + 1
        WHERE employee_id = p_employee_id
          AND template_hash = p_template_hash;
    END IF;
    
    RETURN v_valid;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get employee biometric registrations
CREATE OR REPLACE FUNCTION get_employee_biometrics(p_employee_id UUID)
RETURNS TABLE (
    id UUID,
    biometric_type TEXT,
    finger_index INTEGER,
    is_active BOOLEAN,
    is_verified BOOLEAN,
    registered_at TIMESTAMPTZ,
    last_used_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        br.id,
        br.biometric_type,
        br.finger_index,
        br.is_active,
        br.is_verified,
        br.registered_at,
        br.last_used_at
    FROM biometric_registrations br
    WHERE br.employee_id = p_employee_id
    ORDER BY br.biometric_type, br.finger_index;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE biometric_registrations IS 'Learn-IQ biometric registrations for identity verification';
COMMENT ON COLUMN biometric_registrations.registration_type IS 'self=Enroll Fingerprint (login users), admin=Bio Metrics Initiate (non-login users)';
