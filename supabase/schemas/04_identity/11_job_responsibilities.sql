-- ===========================================
-- JOB RESPONSIBILITIES TABLE
-- Per employee, versioned document (Learn-IQ)
-- ===========================================

CREATE TABLE IF NOT EXISTS job_responsibilities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Position details
    designation TEXT NOT NULL,
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    date_of_joining DATE NOT NULL,
    
    -- Reporting structure
    reporting_to_name TEXT,
    reporting_to_designation TEXT,
    authorized_deputy_name TEXT,
    authorized_deputy_designation TEXT,
    
    -- Job responsibility content
    job_responsibility TEXT NOT NULL,
    key_result_areas TEXT,
    competencies_required TEXT,
    
    -- Qualifications
    qualification TEXT NOT NULL,
    previous_experience TEXT NOT NULL,
    relevant_training TEXT,
    
    -- External certificates (array of objects)
    external_certificates JSONB DEFAULT '[]', -- [{name, issuer, issue_date, expiry_date, file_url}]
    
    -- Workflow (Learn-IQ)
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    -- Approval workflow
    approver_subgroup_id UUID REFERENCES subgroups(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    accepted_by UUID REFERENCES employees(id) ON DELETE SET NULL, -- Employee acceptance
    accepted_at TIMESTAMPTZ,
    
    -- E-signatures
    initiator_esignature_id UUID REFERENCES electronic_signatures(id),
    approver_esignature_id UUID REFERENCES electronic_signatures(id),
    employee_esignature_id UUID REFERENCES electronic_signatures(id),
    
    -- Document info
    document_url TEXT,
    format_number TEXT, -- Reference to format_numbers table
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    effective_from DATE,
    effective_until DATE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_job_resp_org ON job_responsibilities(organization_id);
CREATE INDEX IF NOT EXISTS idx_job_resp_employee ON job_responsibilities(employee_id);
CREATE INDEX IF NOT EXISTS idx_job_resp_department ON job_responsibilities(department_id);
CREATE INDEX IF NOT EXISTS idx_job_resp_status ON job_responsibilities(status);
CREATE INDEX IF NOT EXISTS idx_job_resp_active ON job_responsibilities(employee_id, status) 
    WHERE status = 'active';

-- Triggers
DROP TRIGGER IF EXISTS trg_job_resp_revision ON job_responsibilities;
CREATE TRIGGER trg_job_resp_revision
    BEFORE UPDATE ON job_responsibilities
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_job_resp_audit ON job_responsibilities;
CREATE TRIGGER trg_job_resp_audit
    AFTER INSERT OR UPDATE OR DELETE ON job_responsibilities
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_job_resp_created ON job_responsibilities;
CREATE TRIGGER trg_job_resp_created
    BEFORE INSERT ON job_responsibilities
    FOR EACH ROW EXECUTE FUNCTION set_created_by();

-- Function to get current job responsibility for an employee
CREATE OR REPLACE FUNCTION get_current_job_responsibility(p_employee_id UUID)
RETURNS job_responsibilities AS $$
DECLARE
    v_record job_responsibilities%ROWTYPE;
BEGIN
    SELECT * INTO v_record
    FROM job_responsibilities
    WHERE employee_id = p_employee_id
      AND status = 'active'
    ORDER BY revision_no DESC
    LIMIT 1;
    
    RETURN v_record;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE job_responsibilities IS 'Learn-IQ: Versioned job responsibility document per employee';
COMMENT ON COLUMN job_responsibilities.approver_subgroup_id IS 'Subgroup whose member should approve this document';
COMMENT ON COLUMN job_responsibilities.accepted_at IS 'Timestamp when employee acknowledged and accepted';
