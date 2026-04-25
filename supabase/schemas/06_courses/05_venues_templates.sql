-- ===========================================
-- TRAINING VENUES TABLE
-- ===========================================

CREATE TABLE IF NOT EXISTS training_venues (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    room_number TEXT NOT NULL,
    room_type venue_type NOT NULL,
    capacity INTEGER NOT NULL,
    contact_person TEXT NOT NULL,
    phone_number TEXT NOT NULL,
    email TEXT,
    address1 TEXT NOT NULL,
    address2 TEXT,
    city TEXT,
    state TEXT,
    pin_zip TEXT,
    room_equipment TEXT,
    amenities JSONB DEFAULT '[]',
    cost_per_hour NUMERIC(10,2),
    additional_info TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_venues_org ON training_venues(organization_id);
CREATE INDEX IF NOT EXISTS idx_venues_plant ON training_venues(plant_id);

DROP TRIGGER IF EXISTS trg_venues_audit ON training_venues;
CREATE TRIGGER trg_venues_audit AFTER INSERT OR UPDATE OR DELETE ON training_venues FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Format numbers
CREATE TABLE IF NOT EXISTS format_numbers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    format_number TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    report_type TEXT NOT NULL,
    template_content TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, report_type)
);

-- Satisfaction scales
CREATE TABLE IF NOT EXISTS satisfaction_scales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    number_of_parameters INTEGER NOT NULL,
    parameters JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

-- Feedback evaluation templates
CREATE TABLE IF NOT EXISTS feedback_evaluation_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    template_type feedback_template_type NOT NULL,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    number_of_parameters INTEGER NOT NULL,
    parameters JSONB NOT NULL,
    satisfaction_scale_id UUID REFERENCES satisfaction_scales(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_feedback_templates_org ON feedback_evaluation_templates(organization_id);
CREATE INDEX IF NOT EXISTS idx_feedback_templates_type ON feedback_evaluation_templates(template_type);
