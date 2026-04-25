-- ===========================================
-- GROUP TRAINING PROGRAM (GTP) SCHEMAS
-- ===========================================

-- GTP Masters - Group Training Programs
CREATE TABLE IF NOT EXISTS gtp_masters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    version_number INTEGER DEFAULT 1,
    short_description TEXT NOT NULL,
    schedule_category schedule_type NOT NULL DEFAULT 'planned',
    schedule_type TEXT NOT NULL,
    training_type training_type NOT NULL DEFAULT 'initial',
    is_qualification_gtp BOOLEAN DEFAULT false,
    gtp_category_id UUID REFERENCES categories(id),
    prerequisite_course_ids JSONB DEFAULT '[]',
    prerequisite_gtp_ids JSONB DEFAULT '[]',
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    initiated_comments TEXT,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    approved_comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_gtp_org ON gtp_masters(organization_id);
CREATE INDEX IF NOT EXISTS idx_gtp_status ON gtp_masters(status);
CREATE INDEX IF NOT EXISTS idx_gtp_training_type ON gtp_masters(training_type);

DROP TRIGGER IF EXISTS trg_gtp_audit ON gtp_masters;
CREATE TRIGGER trg_gtp_audit AFTER INSERT OR UPDATE OR DELETE ON gtp_masters FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- GTP Courses - junction between GTP and courses
CREATE TABLE IF NOT EXISTS gtp_courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gtp_id UUID NOT NULL REFERENCES gtp_masters(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    sequence_number INTEGER DEFAULT 1,
    is_mandatory BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(gtp_id, course_id)
);

CREATE INDEX IF NOT EXISTS idx_gtp_courses_gtp ON gtp_courses(gtp_id);
CREATE INDEX IF NOT EXISTS idx_gtp_courses_course ON gtp_courses(course_id);

-- Sprint 3 ALTER: add DS-09 columns missing from gtp_courses
-- Alfa URS §4.2.1.25 (recurrence), §4.2.1.5 (completion window)
ALTER TABLE gtp_courses ADD COLUMN IF NOT EXISTS
    -- How many months between required repetitions (NULL = one-time, no recurrence)
    recurrence_months INTEGER CHECK (recurrence_months IS NULL OR recurrence_months > 0);

ALTER TABLE gtp_courses ADD COLUMN IF NOT EXISTS
    -- Days within which employee must complete this course after assignment
    completion_days INTEGER DEFAULT 30 CHECK (completion_days > 0);

ALTER TABLE gtp_courses ADD COLUMN IF NOT EXISTS
    -- Display/print order within the GTP (for certificate layout)
    display_order INTEGER DEFAULT 1;

COMMENT ON COLUMN gtp_courses.recurrence_months IS 'DS-09: NULL = one-time; set = re-enrollment triggered every N months after completion';
COMMENT ON COLUMN gtp_courses.completion_days IS 'Days allowed to complete this course after it becomes due (Alfa §4.2.1.25)';
COMMENT ON COLUMN gtp_courses.display_order IS 'Ordering of courses within a GTP for UI presentation and certificate';

-- GTP Documents - associated documents
CREATE TABLE IF NOT EXISTS gtp_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gtp_id UUID NOT NULL REFERENCES gtp_masters(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    is_mandatory BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(gtp_id, document_id)
);

-- GTP Subgroup Access - which subgroups can access this GTP
CREATE TABLE IF NOT EXISTS gtp_subgroup_access (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gtp_id UUID NOT NULL REFERENCES gtp_masters(id) ON DELETE CASCADE,
    subgroup_id UUID NOT NULL REFERENCES subgroups(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(gtp_id, subgroup_id)
);
