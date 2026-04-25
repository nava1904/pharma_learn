-- ===========================================
-- QUESTION PAPERS / ASSESSMENTS
-- ===========================================

-- Question Papers (Assessment Templates)
CREATE TABLE IF NOT EXISTS question_papers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    version_number INTEGER DEFAULT 1,
    description TEXT,
    assessment_type assessment_type NOT NULL DEFAULT 'post_assessment',
    course_id UUID REFERENCES courses(id),
    gtp_id UUID REFERENCES gtp_masters(id),
    total_questions INTEGER NOT NULL,
    total_marks NUMERIC(6,2) NOT NULL,
    passing_marks NUMERIC(6,2) NOT NULL,
    passing_percentage NUMERIC(5,2) NOT NULL,
    time_limit_minutes INTEGER,
    max_attempts INTEGER DEFAULT 3,
    randomize_questions BOOLEAN DEFAULT true,
    randomize_options BOOLEAN DEFAULT true,
    show_results_immediately BOOLEAN DEFAULT true,
    show_correct_answers BOOLEAN DEFAULT false,
    allow_review BOOLEAN DEFAULT true,
    negative_marking BOOLEAN DEFAULT false,
    effective_from DATE NOT NULL,
    effective_to DATE,
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code, version_number)
);

CREATE INDEX IF NOT EXISTS idx_qpapers_org ON question_papers(organization_id);
CREATE INDEX IF NOT EXISTS idx_qpapers_course ON question_papers(course_id);
CREATE INDEX IF NOT EXISTS idx_qpapers_gtp ON question_papers(gtp_id);
CREATE INDEX IF NOT EXISTS idx_qpapers_status ON question_papers(status);

DROP TRIGGER IF EXISTS trg_qpapers_audit ON question_papers;
CREATE TRIGGER trg_qpapers_audit AFTER INSERT OR UPDATE OR DELETE ON question_papers FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Question Paper Sections
CREATE TABLE IF NOT EXISTS question_paper_sections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    section_number INTEGER NOT NULL,
    section_name TEXT NOT NULL,
    description TEXT,
    total_questions INTEGER NOT NULL,
    marks_per_question NUMERIC(5,2),
    mandatory_questions INTEGER,
    time_limit_minutes INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(question_paper_id, section_number)
);

CREATE INDEX IF NOT EXISTS idx_qp_sections_paper ON question_paper_sections(question_paper_id);

-- Question Paper Questions (questions included in paper)
CREATE TABLE IF NOT EXISTS question_paper_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question_paper_id UUID NOT NULL REFERENCES question_papers(id) ON DELETE CASCADE,
    section_id UUID REFERENCES question_paper_sections(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES questions(id) ON DELETE CASCADE,
    question_number INTEGER NOT NULL,
    marks NUMERIC(5,2) NOT NULL,
    is_mandatory BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(question_paper_id, question_number)
);

CREATE INDEX IF NOT EXISTS idx_qpq_paper ON question_paper_questions(question_paper_id);
CREATE INDEX IF NOT EXISTS idx_qpq_question ON question_paper_questions(question_id);
