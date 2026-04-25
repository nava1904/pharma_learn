-- ===========================================
-- CERTIFICATES
-- ===========================================

-- Certificate Templates
CREATE TABLE IF NOT EXISTS certificate_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    certificate_type certificate_type NOT NULL,
    template_content TEXT NOT NULL,
    template_html TEXT,
    header_image_url TEXT,
    footer_image_url TEXT,
    signature_positions JSONB DEFAULT '[]',
    custom_fields JSONB DEFAULT '[]',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_cert_templates_org ON certificate_templates(organization_id);
CREATE INDEX IF NOT EXISTS idx_cert_templates_type ON certificate_templates(certificate_type);

-- Certificates
CREATE TABLE IF NOT EXISTS certificates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    certificate_number TEXT NOT NULL UNIQUE,
    template_id UUID NOT NULL REFERENCES certificate_templates(id),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    training_record_id UUID REFERENCES training_records(id),
    schedule_id UUID REFERENCES training_schedules(id),
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    certificate_type certificate_type NOT NULL,
    title TEXT NOT NULL,
    description TEXT,
    issue_date DATE NOT NULL,
    expiry_date DATE,
    validity_months INTEGER,
    score NUMERIC(5,2),
    grade TEXT,
    certificate_data JSONB NOT NULL,
    pdf_url TEXT,
    qr_code_data TEXT,
    verification_hash TEXT,
    issued_by UUID NOT NULL,
    issued_at TIMESTAMPTZ DEFAULT NOW(),
    esignature_id UUID REFERENCES electronic_signatures(id),
    status certificate_status DEFAULT 'active',
    revoked_at TIMESTAMPTZ,
    revoked_by UUID,
    revocation_reason TEXT,
    obsolete_at TIMESTAMPTZ,
    obsolete_by UUID,
    obsolescence_reason TEXT,
    obsoleted_via_esignature_id UUID REFERENCES electronic_signatures(id),

    -- Two-person certificate revocation (M-06, cGMP ALCOA+ two-person integrity)
    -- Revocation requires sign-off from both a primary and a secondary authorized person
    -- This prevents unilateral certificate invalidation
    revoked_by_primary          UUID REFERENCES employees(id) ON DELETE SET NULL,
    revoked_by_secondary        UUID REFERENCES employees(id) ON DELETE SET NULL,
    revoke_esig_primary         UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    revoke_esig_secondary       UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    revocation_reason_id        UUID REFERENCES standard_reasons(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Enforce two-person rule: if status is REVOKED, both primary and secondary must be set
    CONSTRAINT chk_two_person_revocation
        CHECK (
            status != 'revoked'
            OR (revoked_by_primary IS NOT NULL AND revoked_by_secondary IS NOT NULL
                AND revoke_esig_primary IS NOT NULL AND revoke_esig_secondary IS NOT NULL)
        ),
    -- Primary and secondary revocers must be different people
    CONSTRAINT chk_revoke_different_persons
        CHECK (revoked_by_primary IS NULL OR revoked_by_secondary IS NULL
               OR revoked_by_primary != revoked_by_secondary)
);

-- ALTER: idempotent column additions for existing databases
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS revoked_by_primary    UUID REFERENCES employees(id) ON DELETE SET NULL;
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS revoked_by_secondary  UUID REFERENCES employees(id) ON DELETE SET NULL;
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS revoke_esig_primary   UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL;
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS revoke_esig_secondary UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL;
ALTER TABLE certificates ADD COLUMN IF NOT EXISTS revocation_reason_id  UUID REFERENCES standard_reasons(id) ON DELETE SET NULL;

-- Add two-person CHECK constraint (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.check_constraints
        WHERE constraint_name = 'chk_two_person_revocation'
          AND constraint_schema = 'public'
    ) THEN
        ALTER TABLE certificates ADD CONSTRAINT chk_two_person_revocation
            CHECK (
                status != 'revoked'
                OR (revoked_by_primary IS NOT NULL AND revoked_by_secondary IS NOT NULL
                    AND revoke_esig_primary IS NOT NULL AND revoke_esig_secondary IS NOT NULL)
            );
        ALTER TABLE certificates ADD CONSTRAINT chk_revoke_different_persons
            CHECK (revoked_by_primary IS NULL OR revoked_by_secondary IS NULL
                   OR revoked_by_primary != revoked_by_secondary);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_certificates_org ON certificates(organization_id);
CREATE INDEX IF NOT EXISTS idx_certificates_employee ON certificates(employee_id);
CREATE INDEX IF NOT EXISTS idx_certificates_number ON certificates(certificate_number);
CREATE INDEX IF NOT EXISTS idx_certificates_status ON certificates(status);
CREATE INDEX IF NOT EXISTS idx_certificates_expiry ON certificates(expiry_date);

DROP TRIGGER IF EXISTS trg_certificates_audit ON certificates;
CREATE TRIGGER trg_certificates_audit AFTER INSERT OR UPDATE OR DELETE ON certificates FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Certificate Signatures
CREATE TABLE IF NOT EXISTS certificate_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    certificate_id UUID NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
    signer_id UUID NOT NULL REFERENCES employees(id),
    signer_role TEXT NOT NULL,
    signature_position INTEGER NOT NULL,
    signed_at TIMESTAMPTZ,
    esignature_id UUID REFERENCES electronic_signatures(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(certificate_id, signature_position)
);

CREATE INDEX IF NOT EXISTS idx_cert_signatures_cert ON certificate_signatures(certificate_id);

-- Certificate Verification Log
CREATE TABLE IF NOT EXISTS certificate_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    certificate_id UUID NOT NULL REFERENCES certificates(id) ON DELETE CASCADE,
    verified_at TIMESTAMPTZ DEFAULT NOW(),
    verified_by TEXT,
    verification_method TEXT,
    ip_address INET,
    is_valid BOOLEAN NOT NULL,
    verification_notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_cert_verifications_cert ON certificate_verifications(certificate_id);
