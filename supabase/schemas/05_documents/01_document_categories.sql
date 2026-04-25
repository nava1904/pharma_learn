-- ===========================================
-- DOCUMENT CATEGORIES TABLE
-- ===========================================

CREATE TABLE IF NOT EXISTS document_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    
    -- Hierarchy
    parent_category_id UUID REFERENCES document_categories(id) ON DELETE SET NULL,
    
    -- Display
    icon_name TEXT,
    color_hex TEXT DEFAULT '#6366F1',
    
    -- Workflow
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_doc_categories_org ON document_categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_doc_categories_parent ON document_categories(parent_category_id);

DROP TRIGGER IF EXISTS trg_doc_categories_revision ON document_categories;
CREATE TRIGGER trg_doc_categories_revision
    BEFORE UPDATE ON document_categories
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_doc_categories_audit ON document_categories;
CREATE TRIGGER trg_doc_categories_audit
    AFTER INSERT OR UPDATE OR DELETE ON document_categories
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
