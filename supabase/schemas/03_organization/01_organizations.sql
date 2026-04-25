-- ===========================================
-- ORGANIZATIONS TABLE
-- Multi-tenant root entity
-- ===========================================

CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Basic info
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    legal_name TEXT,
    description TEXT,
    
    -- Branding
    logo_url TEXT,
    primary_color TEXT DEFAULT '#1a73e8',
    secondary_color TEXT DEFAULT '#4285f4',
    
    -- Contact
    website TEXT,
    email TEXT,
    phone TEXT,
    fax TEXT,
    
    -- Address
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    country TEXT DEFAULT 'India',
    postal_code TEXT,
    
    -- Regional settings
    timezone TEXT DEFAULT 'Asia/Kolkata',
    date_format TEXT DEFAULT 'DD/MM/YYYY',
    time_format TEXT DEFAULT 'HH:mm',
    currency TEXT DEFAULT 'INR',
    language TEXT DEFAULT 'en',
    fiscal_year_start INTEGER DEFAULT 4, -- Month (1-12), April for India
    
    -- Regulatory/License info
    gst_number TEXT,
    pan_number TEXT,
    cin_number TEXT,
    drug_license TEXT,
    manufacturing_license TEXT,
    
    -- Compliance framework settings
    compliance_frameworks TEXT[] DEFAULT ARRAY['FDA_21CFR_PART11', 'EU_ANNEXURE_11', 'WHO_GMP'],
    
    -- Security settings (Learn-IQ)
    audit_retention_years INTEGER DEFAULT 7,
    session_timeout_minutes INTEGER DEFAULT 30,
    max_login_attempts INTEGER DEFAULT 5,
    lockout_duration_minutes INTEGER DEFAULT 30,
    password_expiry_days INTEGER DEFAULT 90,
    password_min_length INTEGER DEFAULT 8,
    password_require_special BOOLEAN DEFAULT true,
    password_require_numbers BOOLEAN DEFAULT true,
    password_require_uppercase BOOLEAN DEFAULT true,
    mfa_required BOOLEAN DEFAULT false,
    mfa_methods TEXT[] DEFAULT ARRAY['totp', 'email'],
    
    -- Training settings
    default_pass_mark NUMERIC(5,2) DEFAULT 70.00,
    max_assessment_attempts INTEGER DEFAULT 3,
    certificate_validity_months INTEGER DEFAULT 12,
    training_reminder_days INTEGER[] DEFAULT ARRAY[30, 14, 7, 1],
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    subscription_plan TEXT DEFAULT 'enterprise',
    subscription_valid_until DATE,
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'active',
    revision_no INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_organizations_code ON organizations(code);
CREATE INDEX IF NOT EXISTS idx_organizations_status ON organizations(status);
CREATE INDEX IF NOT EXISTS idx_organizations_active ON organizations(is_active) WHERE is_active = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_organizations_revision ON organizations;
CREATE TRIGGER trg_organizations_revision
    BEFORE UPDATE ON organizations
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_organizations_audit ON organizations;
CREATE TRIGGER trg_organizations_audit
    AFTER INSERT OR UPDATE OR DELETE ON organizations
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_organizations_created ON organizations;
CREATE TRIGGER trg_organizations_created
    BEFORE INSERT ON organizations
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

COMMENT ON TABLE organizations IS 'Multi-tenant root entity for pharma organizations';
COMMENT ON COLUMN organizations.compliance_frameworks IS 'Applicable regulatory frameworks (FDA 21CFR11, EU Annexure 11, WHO GMP)';
COMMENT ON COLUMN organizations.audit_retention_years IS '21 CFR Part 11: Minimum 7 years retention for GxP records';
