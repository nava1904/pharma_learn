-- ===========================================
-- DOCUMENTS TABLE
-- ===========================================

CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    
    -- Basic info
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    version_no TEXT NOT NULL DEFAULT '1.0',
    description TEXT,
    document_type document_type NOT NULL,
    
    -- Dates
    effective_from DATE,
    effective_until DATE,
    next_review DATE,
    
    -- File info
    storage_url TEXT,
    file_name TEXT,
    file_size_bytes BIGINT,
    file_hash TEXT,
    mime_type TEXT,
    
    -- Ownership
    department_id UUID REFERENCES departments(id) ON DELETE SET NULL,
    owner_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Compliance
    sop_number TEXT,
    
    -- Workflow
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    
    -- Approval
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_documents_org ON documents(organization_id);
CREATE INDEX IF NOT EXISTS idx_documents_plant ON documents(plant_id);
CREATE INDEX IF NOT EXISTS idx_documents_status ON documents(status);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(document_type);

DROP TRIGGER IF EXISTS trg_documents_revision ON documents;
CREATE TRIGGER trg_documents_revision
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION increment_revision();

DROP TRIGGER IF EXISTS trg_documents_audit ON documents;
CREATE TRIGGER trg_documents_audit
    AFTER INSERT OR UPDATE OR DELETE ON documents
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Document versions table
CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version_no TEXT NOT NULL,
    storage_url TEXT NOT NULL,
    file_hash TEXT,
    file_size_bytes BIGINT,
    change_summary TEXT,
    is_current BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at TIMESTAMPTZ,
    approved_by UUID REFERENCES employees(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_doc_versions_document ON document_versions(document_id);

-- Document category tags
CREATE TABLE IF NOT EXISTS document_category_tags (
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES document_categories(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (document_id, category_id)
);
