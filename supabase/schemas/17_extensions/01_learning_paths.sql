-- ===========================================
-- LEARNING PATHS & CURRICULUM SEQUENCING
-- Structured multi-course journeys with prerequisites
-- ===========================================

CREATE TYPE learning_path_status AS ENUM ('draft','active','deprecated','archived');
CREATE TYPE prerequisite_kind  AS ENUM ('course','gtp','competency','role','learning_path');
CREATE TYPE enrollment_status  AS ENUM ('not_started','in_progress','completed','dropped','suspended');

CREATE TABLE IF NOT EXISTS learning_paths (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id),
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    target_role_ids UUID[] DEFAULT '{}',
    target_subgroup_ids UUID[] DEFAULT '{}',
    estimated_hours NUMERIC(6,2),
    certification_on_completion BOOLEAN DEFAULT false,
    certificate_template_id UUID,
    version INTEGER DEFAULT 1,
    path_status learning_path_status DEFAULT 'draft',
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

CREATE TABLE IF NOT EXISTS learning_path_steps (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    learning_path_id UUID NOT NULL REFERENCES learning_paths(id) ON DELETE CASCADE,
    step_order INTEGER NOT NULL,
    step_type TEXT NOT NULL CHECK (step_type IN ('course','gtp','document','assessment','ojt','induction','checkpoint')),
    referenced_id UUID NOT NULL,
    is_mandatory BOOLEAN DEFAULT true,
    unlock_delay_days INTEGER DEFAULT 0,
    passing_criteria JSONB,
    UNIQUE(learning_path_id, step_order)
);

CREATE TABLE IF NOT EXISTS course_prerequisites (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    prerequisite_kind prerequisite_kind NOT NULL,
    prerequisite_id UUID NOT NULL,
    is_hard_block BOOLEAN DEFAULT true,
    UNIQUE(course_id, prerequisite_kind, prerequisite_id)
);

CREATE TABLE IF NOT EXISTS learning_path_enrollments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    learning_path_id UUID NOT NULL REFERENCES learning_paths(id),
    employee_id UUID NOT NULL REFERENCES employees(id),
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    target_completion_date DATE,
    actual_completion_date DATE,
    current_step_id UUID REFERENCES learning_path_steps(id),
    progress_percent NUMERIC(5,2) DEFAULT 0,
    enrollment_status enrollment_status DEFAULT 'not_started',
    completion_certificate_id UUID,
    UNIQUE(learning_path_id, employee_id)
);

CREATE TABLE IF NOT EXISTS learning_path_step_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    enrollment_id UUID NOT NULL REFERENCES learning_path_enrollments(id) ON DELETE CASCADE,
    step_id UUID NOT NULL REFERENCES learning_path_steps(id),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    score NUMERIC(5,2),
    attempt_count INTEGER DEFAULT 0,
    UNIQUE(enrollment_id, step_id)
);

CREATE INDEX IF NOT EXISTS idx_lp_org ON learning_paths(organization_id);
CREATE INDEX IF NOT EXISTS idx_lpe_employee ON learning_path_enrollments(employee_id);
CREATE INDEX IF NOT EXISTS idx_lpsp_enrollment ON learning_path_step_progress(enrollment_id);

COMMENT ON TABLE learning_paths IS 'Curated multi-step journeys combining courses, GTPs, OJT, documents';
COMMENT ON TABLE course_prerequisites IS 'Prerequisites gating course enrollment (course/GTP/competency/role/path)';
