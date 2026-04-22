-- ===========================================
-- EXTERNAL TRAINING RECORDS
-- Workflow: Submit → Approve → Creates training_records entry
-- URS Alfa §4.3.18 - External training capture
-- ===========================================

-- External Training Submissions (pre-approval staging)
CREATE TABLE IF NOT EXISTS external_training_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Training details
    course_name TEXT NOT NULL,
    institution_name TEXT NOT NULL,
    completion_date DATE NOT NULL,
    training_hours NUMERIC(6,2),
    training_type TEXT NOT NULL DEFAULT 'external' CHECK (training_type IN (
        'external', 'conference', 'workshop', 'certification', 'webinar', 'self_study'
    )),
    description TEXT,
    skills_acquired JSONB DEFAULT '[]',
    
    -- Evidence
    certificate_attachment_id UUID REFERENCES attachments(id) ON DELETE SET NULL,
    evidence_attachments JSONB DEFAULT '[]',
    
    -- Workflow state
    status TEXT NOT NULL DEFAULT 'pending_approval' CHECK (status IN (
        'draft', 'pending_approval', 'approved', 'rejected'
    )),
    
    -- Submission
    submitted_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    submitted_at TIMESTAMPTZ,
    
    -- Approval
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    
    -- Rejection
    rejected_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    
    -- Link to training_records after approval
    training_record_id UUID REFERENCES training_records(id) ON DELETE SET NULL,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ext_training_org ON external_training_records(organization_id);
CREATE INDEX IF NOT EXISTS idx_ext_training_employee ON external_training_records(employee_id);
CREATE INDEX IF NOT EXISTS idx_ext_training_status ON external_training_records(status);
CREATE INDEX IF NOT EXISTS idx_ext_training_pending ON external_training_records(status) 
    WHERE status = 'pending_approval';

DROP TRIGGER IF EXISTS trg_ext_training_audit ON external_training_records;
CREATE TRIGGER trg_ext_training_audit 
    AFTER INSERT OR UPDATE OR DELETE ON external_training_records 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

COMMENT ON TABLE external_training_records IS 'Pre-approval staging for external training. After approval, creates entry in training_records.';
