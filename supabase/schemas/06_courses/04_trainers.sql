-- ===========================================
-- TRAINERS TABLES
-- ===========================================

-- Internal trainers
CREATE TABLE IF NOT EXISTS trainers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    qualification TEXT NOT NULL,
    experience TEXT NOT NULL,
    specialization TEXT,
    cost_per_hour NUMERIC(10,2),
    currency TEXT DEFAULT 'INR',
    requalification_date DATE NOT NULL,
    any_external_training_attended TEXT,
    currently_responsible_for TEXT NOT NULL,
    area_of_exposure TEXT NOT NULL,
    certifications JSONB DEFAULT '[]',
    status trainer_status DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

-- External trainers
CREATE TABLE IF NOT EXISTS external_trainers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    company_name TEXT,
    designation TEXT NOT NULL,
    qualification TEXT NOT NULL,
    experience TEXT NOT NULL,
    cost_per_hour NUMERIC(10,2),
    currency TEXT DEFAULT 'INR',
    expertise TEXT NOT NULL,
    currently_responsible_for TEXT NOT NULL,
    area_of_exposure TEXT NOT NULL,
    address TEXT,
    city TEXT,
    phone TEXT,
    email TEXT,
    status trainer_status DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

-- Trainer courses
CREATE TABLE IF NOT EXISTS trainer_courses (
    trainer_id UUID NOT NULL REFERENCES trainers(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    certified_at TIMESTAMPTZ DEFAULT NOW(),
    certified_until DATE,
    PRIMARY KEY (trainer_id, course_id)
);

CREATE TABLE IF NOT EXISTS external_trainer_courses (
    external_trainer_id UUID NOT NULL REFERENCES external_trainers(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    PRIMARY KEY (external_trainer_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_trainers_org ON trainers(organization_id);
CREATE INDEX IF NOT EXISTS idx_trainers_employee ON trainers(employee_id);
CREATE INDEX IF NOT EXISTS idx_ext_trainers_org ON external_trainers(organization_id);

DROP TRIGGER IF EXISTS trg_trainers_revision ON trainers;
CREATE TRIGGER trg_trainers_revision BEFORE UPDATE ON trainers FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_trainers_audit ON trainers;
CREATE TRIGGER trg_trainers_audit AFTER INSERT OR UPDATE OR DELETE ON trainers FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
DROP TRIGGER IF EXISTS trg_ext_trainers_revision ON external_trainers;
CREATE TRIGGER trg_ext_trainers_revision BEFORE UPDATE ON external_trainers FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_ext_trainers_audit ON external_trainers;
CREATE TRIGGER trg_ext_trainers_audit AFTER INSERT OR UPDATE OR DELETE ON external_trainers FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
