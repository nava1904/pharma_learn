-- ===========================================
-- TOPICS TABLE
-- ===========================================

CREATE TABLE IF NOT EXISTS topics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    objectives TEXT,
    duration_minutes INTEGER,
    content_html TEXT,
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES employees(id),
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id),
    UNIQUE(organization_id, unique_code)
);

-- Topic tags
CREATE TABLE IF NOT EXISTS topic_category_tags (
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (topic_id, category_id)
);

CREATE TABLE IF NOT EXISTS topic_subject_tags (
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
    PRIMARY KEY (topic_id, subject_id)
);

CREATE TABLE IF NOT EXISTS topic_document_links (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    is_mandatory BOOLEAN DEFAULT TRUE,
    linked_at TIMESTAMPTZ DEFAULT NOW(),
    linked_by UUID REFERENCES employees(id),
    UNIQUE(topic_id, document_id)
);

CREATE INDEX IF NOT EXISTS idx_topics_org ON topics(organization_id);
CREATE INDEX IF NOT EXISTS idx_topics_status ON topics(status);

DROP TRIGGER IF EXISTS trg_topics_revision ON topics;
CREATE TRIGGER trg_topics_revision BEFORE UPDATE ON topics FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_topics_audit ON topics;
CREATE TRIGGER trg_topics_audit AFTER INSERT OR UPDATE OR DELETE ON topics FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
