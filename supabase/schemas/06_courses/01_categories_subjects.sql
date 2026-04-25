-- ===========================================
-- CATEGORIES & SUBJECTS (Course Manager)
-- ===========================================

CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    color_hex TEXT DEFAULT '#6366F1',
    icon_name TEXT,
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

CREATE TABLE IF NOT EXISTS subjects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_categories_org ON categories(organization_id);
CREATE INDEX IF NOT EXISTS idx_subjects_org ON subjects(organization_id);
CREATE INDEX IF NOT EXISTS idx_subjects_category ON subjects(category_id);

DROP TRIGGER IF EXISTS trg_categories_revision ON categories;
CREATE TRIGGER trg_categories_revision BEFORE UPDATE ON categories FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_categories_audit ON categories;
CREATE TRIGGER trg_categories_audit AFTER INSERT OR UPDATE OR DELETE ON categories FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

DROP TRIGGER IF EXISTS trg_subjects_revision ON subjects;
CREATE TRIGGER trg_subjects_revision BEFORE UPDATE ON subjects FOR EACH ROW EXECUTE FUNCTION increment_revision();
DROP TRIGGER IF EXISTS trg_subjects_audit ON subjects;
CREATE TRIGGER trg_subjects_audit AFTER INSERT OR UPDATE OR DELETE ON subjects FOR EACH ROW EXECUTE FUNCTION track_entity_changes();
