-- ===========================================
-- COURSES TABLE
-- ===========================================

CREATE TABLE IF NOT EXISTS courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Course configuration
    course_type course_type DEFAULT 'one_time',
    training_types training_type[] DEFAULT ARRAY['gmp']::training_type[],
    self_study BOOLEAN DEFAULT false,
    frequency_months INTEGER,
    
    -- Access control
    course_open_for_all BOOLEAN DEFAULT true,
    mandatory_subgroup_selection BOOLEAN DEFAULT false,
    
    -- Assessment
    assessment_required BOOLEAN DEFAULT true,
    pass_mark NUMERIC(5,2) DEFAULT 70.00,
    max_attempts INTEGER DEFAULT 3,
    
    -- Approval (Learn-IQ)
    approval_for_candidature approval_requirement DEFAULT 'not_required',
    approval_group_id UUID REFERENCES groups(id),
    
    -- Certificate
    certificate_validity_months INTEGER,
    
    -- Compliance
    sop_number TEXT,
    effective_date DATE,
    
    -- Display
    thumbnail_url TEXT,
    estimated_duration_minutes INTEGER,
    
    -- Workflow
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id),
    
    UNIQUE(organization_id, unique_code)
);

-- Course topics
CREATE TABLE IF NOT EXISTS course_topics (
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL DEFAULT 0,
    is_mandatory BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (course_id, topic_id)
);

-- Course documents
CREATE TABLE IF NOT EXISTS course_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    topic_id UUID REFERENCES topics(id) ON DELETE SET NULL,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version_no TEXT NOT NULL,
    is_mandatory BOOLEAN DEFAULT TRUE
);

-- Course subgroup access
CREATE TABLE IF NOT EXISTS course_subgroup_access (
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    subgroup_id UUID NOT NULL REFERENCES subgroups(id) ON DELETE CASCADE,
    is_mandatory BOOLEAN DEFAULT false,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (course_id, subgroup_id)
);

CREATE INDEX IF NOT EXISTS idx_courses_org ON courses(organization_id);
CREATE INDEX IF NOT EXISTS idx_courses_status ON courses(status);
CREATE INDEX IF NOT EXISTS idx_courses_type ON courses(course_type);

DROP TRIGGER IF EXISTS trg_courses_revision ON courses;
CREATE TRIGGER trg_courses_revision BEFORE UPDATE ON courses FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_courses_audit ON courses;
CREATE TRIGGER trg_courses_audit AFTER INSERT OR UPDATE OR DELETE ON courses FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
