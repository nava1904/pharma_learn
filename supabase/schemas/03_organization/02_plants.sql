-- ===========================================
-- PLANTS / SITES TABLE
-- Manufacturing sites within an organization
-- One plant is designated as "Master" for global config
-- ===========================================

CREATE TABLE IF NOT EXISTS plants (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    short_name TEXT,
    description TEXT,
    
    -- Type
    is_master BOOLEAN DEFAULT false, -- Master plant holds global config (Learn-IQ)
    plant_type TEXT DEFAULT 'manufacturing' CHECK (plant_type IN ('manufacturing', 'r_and_d', 'warehouse', 'office', 'qa_qc_lab', 'packaging')),
    
    -- Location
    address_line1 TEXT,
    address_line2 TEXT,
    city TEXT,
    state TEXT,
    country TEXT DEFAULT 'India',
    postal_code TEXT,
    timezone TEXT DEFAULT 'Asia/Kolkata',
    
    -- GPS coordinates
    latitude NUMERIC(10,8),
    longitude NUMERIC(11,8),
    
    -- Contact
    contact_person TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    emergency_contact TEXT,
    
    -- Regulatory licenses
    manufacturing_license TEXT,
    manufacturing_license_expiry DATE,
    drug_license TEXT,
    drug_license_expiry DATE,
    gmp_certificate TEXT,
    gmp_certificate_expiry DATE,
    fda_registration TEXT,
    who_gmp_certificate TEXT,
    iso_certification TEXT,
    
    -- Operational info
    operating_hours_start TIME DEFAULT '08:00',
    operating_hours_end TIME DEFAULT '18:00',
    working_days TEXT[] DEFAULT ARRAY['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
    
    -- Capacity
    employee_capacity INTEGER,
    production_capacity TEXT,
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Status
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    -- Constraints
    UNIQUE(organization_id, code)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_plants_org ON plants(organization_id);
CREATE INDEX IF NOT EXISTS idx_plants_status ON plants(status);
CREATE INDEX IF NOT EXISTS idx_plants_active ON plants(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_plants_master ON plants(organization_id, is_master) WHERE is_master = true;

-- Ensure only one master plant per organization
CREATE UNIQUE INDEX IF NOT EXISTS idx_plants_unique_master 
    ON plants(organization_id) 
    WHERE is_master = true;

-- Triggers
DROP TRIGGER IF EXISTS trg_plants_revision ON plants;
CREATE TRIGGER trg_plants_revision
    BEFORE UPDATE ON plants
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_plants_audit ON plants;
CREATE TRIGGER trg_plants_audit
    AFTER INSERT OR UPDATE OR DELETE ON plants
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_plants_created ON plants;
CREATE TRIGGER trg_plants_created
    BEFORE INSERT ON plants
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Function to get master plant for an organization
CREATE OR REPLACE FUNCTION get_master_plant(p_org_id UUID)
RETURNS UUID AS $$
DECLARE
    v_plant_id UUID;
BEGIN
    SELECT id INTO v_plant_id
    FROM plants
    WHERE organization_id = p_org_id
      AND is_master = true
      AND is_active = true
    LIMIT 1;
    
    RETURN v_plant_id;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE plants IS 'Manufacturing plants/sites within an organization';
COMMENT ON COLUMN plants.is_master IS 'Learn-IQ: Master plant holds global configuration data shared across all plants';
