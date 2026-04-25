-- ===========================================
-- TRAINING RECORDS (COMPLIANCE)
-- ===========================================

-- Employee Training Records - master training history
CREATE TABLE IF NOT EXISTS training_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    training_type training_type NOT NULL,
    training_source TEXT NOT NULL,
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    schedule_id UUID REFERENCES training_schedules(id),
    induction_id UUID REFERENCES induction_programs(id),
    ojt_id UUID REFERENCES ojt_masters(id),
    document_id UUID REFERENCES documents(id),
    external_training_name TEXT,
    external_training_provider TEXT,
    training_date DATE NOT NULL,
    completion_date DATE,
    expiry_date DATE,
    duration_hours NUMERIC(6,2),
    attendance_percentage NUMERIC(5,2),
    assessment_score NUMERIC(5,2),
    assessment_passed BOOLEAN,
    overall_status training_completion_status NOT NULL,
    certificate_id UUID,
    trainer_names TEXT,
    venue_name TEXT,
    remarks TEXT,
    evidence_attachments JSONB DEFAULT '[]',
    esignature_id UUID REFERENCES electronic_signatures(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_records_org ON training_records(organization_id);
CREATE INDEX IF NOT EXISTS idx_training_records_employee ON training_records(employee_id);
CREATE INDEX IF NOT EXISTS idx_training_records_course ON training_records(course_id);
CREATE INDEX IF NOT EXISTS idx_training_records_date ON training_records(training_date);
CREATE INDEX IF NOT EXISTS idx_training_records_status ON training_records(overall_status);
CREATE INDEX IF NOT EXISTS idx_training_records_expiry ON training_records(expiry_date);

DROP TRIGGER IF EXISTS trg_training_records_audit ON training_records;
CREATE TRIGGER trg_training_records_audit AFTER INSERT OR UPDATE OR DELETE ON training_records FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Training Record Line Items (detailed breakdown)
CREATE TABLE IF NOT EXISTS training_record_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    training_record_id UUID NOT NULL REFERENCES training_records(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    item_id UUID NOT NULL,
    item_name TEXT NOT NULL,
    completion_status training_completion_status NOT NULL,
    completion_date TIMESTAMPTZ,
    score NUMERIC(5,2),
    time_spent_minutes INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tr_items_record ON training_record_items(training_record_id);

-- -------------------------------------------------------
-- Sprint 3 ALTER: add GxP-required columns to training_records
-- Alfa URS §4.3.19, §4.2.1.34
-- -------------------------------------------------------
ALTER TABLE training_records ADD COLUMN IF NOT EXISTS training_method TEXT
    CHECK (training_method IN ('ILT','EXTERNAL','BLENDED','OJT','DOC_READ','COMPLETED','WBT'));

ALTER TABLE training_records ADD COLUMN IF NOT EXISTS is_postdated BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE training_records ADD COLUMN IF NOT EXISTS postdated_reason_id UUID
    REFERENCES standard_reasons(id) ON DELETE SET NULL;

ALTER TABLE training_records ADD COLUMN IF NOT EXISTS postdated_reason_text TEXT;

COMMENT ON COLUMN training_records.training_method IS 'Delivery mode: ILT/EXTERNAL/BLENDED/OJT/DOC_READ/COMPLETED/WBT (Alfa §4.2.1.34)';
COMMENT ON COLUMN training_records.is_postdated IS 'GxP ALCOA+: TRUE when record entered after actual training date';
COMMENT ON COLUMN training_records.postdated_reason_id IS 'Mandatory standard reason when is_postdated = TRUE (Alfa §4.3.19)';
