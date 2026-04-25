-- ===========================================
-- DEVIATION AND CAPA INTEGRATION
-- ===========================================

-- Deviation Records
CREATE TABLE IF NOT EXISTS deviations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL UNIQUE,
    deviation_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    deviation_type TEXT NOT NULL,
    severity deviation_severity NOT NULL,
    department_id UUID REFERENCES departments(id),
    plant_id UUID REFERENCES plants(id),
    identified_date DATE NOT NULL,
    identified_by UUID NOT NULL REFERENCES employees(id),
    root_cause TEXT,
    immediate_action TEXT,
    status workflow_state DEFAULT 'initiated',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    closed_by UUID,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_deviations_org ON deviations(organization_id);
CREATE INDEX IF NOT EXISTS idx_deviations_status ON deviations(status);
CREATE INDEX IF NOT EXISTS idx_deviations_severity ON deviations(severity);
CREATE INDEX IF NOT EXISTS idx_deviations_date ON deviations(identified_date);

DROP TRIGGER IF EXISTS trg_deviations_audit ON deviations;
CREATE TRIGGER trg_deviations_audit AFTER INSERT OR UPDATE OR DELETE ON deviations FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- CAPA Records
CREATE TABLE IF NOT EXISTS capa_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL UNIQUE,
    capa_number TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    capa_type capa_type NOT NULL,
    source_type TEXT NOT NULL,
    source_id UUID,
    deviation_id UUID REFERENCES deviations(id),
    department_id UUID REFERENCES departments(id),
    root_cause_analysis TEXT,
    corrective_action TEXT,
    preventive_action TEXT,
    target_completion_date DATE,
    actual_completion_date DATE,
    effectiveness_check_date DATE,
    status workflow_state DEFAULT 'initiated',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    closed_by UUID,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_capa_org ON capa_records(organization_id);
CREATE INDEX IF NOT EXISTS idx_capa_status ON capa_records(status);
CREATE INDEX IF NOT EXISTS idx_capa_type ON capa_records(capa_type);
CREATE INDEX IF NOT EXISTS idx_capa_deviation ON capa_records(deviation_id);

DROP TRIGGER IF EXISTS trg_capa_audit ON capa_records;
CREATE TRIGGER trg_capa_audit AFTER INSERT OR UPDATE OR DELETE ON capa_records FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Training linked to Deviations/CAPA
CREATE TABLE IF NOT EXISTS deviation_training_requirements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deviation_id UUID REFERENCES deviations(id) ON DELETE CASCADE,
    capa_id UUID REFERENCES capa_records(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    document_id UUID REFERENCES documents(id),
    training_type TEXT NOT NULL,
    target_employees JSONB NOT NULL,
    due_date DATE NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_source CHECK (deviation_id IS NOT NULL OR capa_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_dev_training_deviation ON deviation_training_requirements(deviation_id);
CREATE INDEX IF NOT EXISTS idx_dev_training_capa ON deviation_training_requirements(capa_id);
