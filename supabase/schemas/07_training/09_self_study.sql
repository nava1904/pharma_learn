-- ===========================================
-- SELF-STUDY COURSES AND ENROLLMENTS
-- Open enrollment courses for employee-driven learning
-- URS Alfa §4.2.1.30 - Self-study mode
-- ===========================================

-- Self-Study Courses (open enrollment catalog)
CREATE TABLE IF NOT EXISTS self_study_courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    
    -- Course metadata
    name TEXT NOT NULL,
    description TEXT,
    course_type TEXT NOT NULL DEFAULT 'e_learning' CHECK (course_type IN (
        'e_learning', 'video', 'document', 'scorm', 'external_link'
    )),
    duration_hours NUMERIC(6,2),
    thumbnail_url TEXT,
    
    -- Category / classification
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    subject_id UUID REFERENCES subjects(id) ON DELETE SET NULL,
    
    -- Enrollment settings
    is_open_enrollment BOOLEAN NOT NULL DEFAULT TRUE,
    max_enrollments INTEGER,  -- NULL = unlimited
    enrollment_start_date DATE,
    enrollment_end_date DATE,
    
    -- Completion settings
    requires_assessment BOOLEAN DEFAULT FALSE,
    passing_score NUMERIC(5,2) DEFAULT 80,
    
    -- State
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES employees(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_self_study_org ON self_study_courses(organization_id);
CREATE INDEX IF NOT EXISTS idx_self_study_category ON self_study_courses(category_id);
CREATE INDEX IF NOT EXISTS idx_self_study_active ON self_study_courses(is_active) WHERE is_active = TRUE;

-- Self-Study Enrollments
CREATE TABLE IF NOT EXISTS self_study_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES self_study_courses(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'enrolled' CHECK (status IN (
        'enrolled', 'in_progress', 'completed', 'dropped'
    )),
    
    -- Progress
    progress_percentage NUMERIC(5,2) DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    dropped_at TIMESTAMPTZ,
    
    -- Assessment (if required)
    assessment_attempts INTEGER DEFAULT 0,
    assessment_score NUMERIC(5,2),
    assessment_passed BOOLEAN,
    
    -- Time tracking
    total_time_minutes INTEGER DEFAULT 0,
    last_access_at TIMESTAMPTZ,
    
    -- Audit
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(course_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_self_enroll_course ON self_study_enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_self_enroll_employee ON self_study_enrollments(employee_id);
CREATE INDEX IF NOT EXISTS idx_self_enroll_status ON self_study_enrollments(status);

DROP TRIGGER IF EXISTS trg_self_study_audit ON self_study_enrollments;
CREATE TRIGGER trg_self_study_audit 
    AFTER INSERT OR UPDATE OR DELETE ON self_study_enrollments 
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

COMMENT ON TABLE self_study_courses IS 'Open enrollment course catalog for employee-driven learning';
COMMENT ON TABLE self_study_enrollments IS 'Employee self-enrollments in open catalog courses';
