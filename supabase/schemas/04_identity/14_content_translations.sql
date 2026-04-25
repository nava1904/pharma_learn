-- ===========================================
-- MULTILINGUAL CONTENT TRANSLATIONS
-- Supports Marathi/Hindi requirement (and future locales)
-- ===========================================

CREATE TABLE IF NOT EXISTS content_translations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    field_name TEXT NOT NULL,

    locale TEXT NOT NULL, -- 'en', 'hi', 'mr', etc.
    translated_text TEXT NOT NULL,

    translated_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    is_approved BOOLEAN NOT NULL DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(organization_id, entity_type, entity_id, field_name, locale)
);

CREATE INDEX IF NOT EXISTS idx_translations_org ON content_translations(organization_id);
CREATE INDEX IF NOT EXISTS idx_translations_entity ON content_translations(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_translations_locale ON content_translations(locale);

DROP TRIGGER IF EXISTS trg_translations_audit ON content_translations;
CREATE TRIGGER trg_translations_audit AFTER INSERT OR UPDATE OR DELETE ON content_translations FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

