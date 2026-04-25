-- ===========================================
-- KNOWLEDGE BASE / FAQ / WIKI
-- Searchable, versioned knowledge articles
-- ===========================================

CREATE TYPE kb_article_status AS ENUM ('draft','in_review','published','archived','deprecated');
CREATE TYPE kb_visibility     AS ENUM ('organization','plant','role','subgroup','public');

CREATE TABLE IF NOT EXISTS kb_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    parent_category_id UUID REFERENCES kb_categories(id),
    description TEXT,
    icon_name TEXT,
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE TABLE IF NOT EXISTS kb_articles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id),
    category_id UUID REFERENCES kb_categories(id),
    title TEXT NOT NULL,
    slug TEXT NOT NULL,
    summary TEXT,
    body_markdown TEXT NOT NULL,
    tags TEXT[] DEFAULT '{}',
    search_vector TSVECTOR,
    related_course_ids UUID[] DEFAULT '{}',
    related_document_ids UUID[] DEFAULT '{}',
    visibility kb_visibility DEFAULT 'organization',
    visible_to_ids UUID[] DEFAULT '{}',
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    article_status kb_article_status DEFAULT 'draft',
    status workflow_state DEFAULT 'draft',
    current_version INTEGER DEFAULT 1,
    revision_no INTEGER DEFAULT 0,
    published_at TIMESTAMPTZ,
    published_by UUID,
    last_reviewed_at TIMESTAMPTZ,
    next_review_due DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, slug)
);

CREATE TABLE IF NOT EXISTS kb_article_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES kb_articles(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    title TEXT NOT NULL,
    body_markdown TEXT NOT NULL,
    change_summary TEXT,
    edited_by UUID,
    edited_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(article_id, version_number)
);

CREATE TABLE IF NOT EXISTS kb_article_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES kb_articles(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id),
    was_helpful BOOLEAN NOT NULL,
    comment TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS kb_article_views (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    article_id UUID NOT NULL REFERENCES kb_articles(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id),
    viewed_at TIMESTAMPTZ DEFAULT NOW(),
    dwell_seconds INTEGER,
    source TEXT
);

CREATE TABLE IF NOT EXISTS kb_search_queries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id),
    employee_id UUID REFERENCES employees(id),
    query TEXT NOT NULL,
    result_count INTEGER,
    clicked_article_id UUID REFERENCES kb_articles(id),
    searched_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_kb_articles_search ON kb_articles USING GIN(search_vector);
CREATE INDEX IF NOT EXISTS idx_kb_articles_tags ON kb_articles USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_kb_articles_status ON kb_articles(article_status) WHERE article_status = 'published';

CREATE OR REPLACE FUNCTION kb_update_search_vector() RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector := to_tsvector('english',
        COALESCE(NEW.title,'') || ' ' || COALESCE(NEW.summary,'') || ' ' ||
        COALESCE(NEW.body_markdown,'') || ' ' || COALESCE(array_to_string(NEW.tags,' '),''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kb_search ON kb_articles;
CREATE TRIGGER trg_kb_search BEFORE INSERT OR UPDATE ON kb_articles
    FOR EACH ROW EXECUTE FUNCTION kb_update_search_vector();

COMMENT ON TABLE kb_articles IS 'Knowledge-base articles with full-text search and version history';
