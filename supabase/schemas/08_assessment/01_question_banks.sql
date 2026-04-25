-- ===========================================
-- QUESTION BANKS
-- ===========================================

-- Question Bank Categories
CREATE TABLE IF NOT EXISTS question_bank_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    parent_id UUID REFERENCES question_bank_categories(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_qb_categories_org ON question_bank_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_qb_categories_parent ON question_bank_categories(parent_id);

-- Question Banks
CREATE TABLE IF NOT EXISTS question_banks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    version_number INTEGER DEFAULT 1,
    description TEXT,
    category_id UUID REFERENCES question_bank_categories(id),
    subject_id UUID REFERENCES subjects(id),
    topic_id UUID REFERENCES topics(id),
    course_id UUID REFERENCES courses(id),
    difficulty_level difficulty_level DEFAULT 'medium',
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

CREATE INDEX IF NOT EXISTS idx_qbanks_org ON question_banks(organization_id);
CREATE INDEX IF NOT EXISTS idx_qbanks_category ON question_banks(category_id);
CREATE INDEX IF NOT EXISTS idx_qbanks_course ON question_banks(course_id);
CREATE INDEX IF NOT EXISTS idx_qbanks_status ON question_banks(status);

DROP TRIGGER IF EXISTS trg_qbanks_audit ON question_banks;
CREATE TRIGGER trg_qbanks_audit AFTER INSERT OR UPDATE OR DELETE ON question_banks FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
