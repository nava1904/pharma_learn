-- ===========================================
-- FILE STORAGE AND MEDIA
-- ===========================================

-- File Storage Records
CREATE TABLE IF NOT EXISTS file_storage (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    bucket_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    file_name TEXT NOT NULL,
    original_name TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    checksum TEXT,
    storage_provider TEXT DEFAULT 'supabase',
    public_url TEXT,
    signed_url_expires_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    uploaded_by UUID NOT NULL,
    uploaded_at TIMESTAMPTZ DEFAULT NOW(),
    is_public BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(bucket_name, file_path)
);

CREATE INDEX IF NOT EXISTS idx_file_storage_org ON file_storage(organization_id);
CREATE INDEX IF NOT EXISTS idx_file_storage_bucket ON file_storage(bucket_name);
CREATE INDEX IF NOT EXISTS idx_file_storage_mime ON file_storage(mime_type);
CREATE INDEX IF NOT EXISTS idx_file_storage_uploaded_by ON file_storage(uploaded_by);

-- File Associations (linking files to entities)
CREATE TABLE IF NOT EXISTS file_associations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_storage(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    association_type TEXT NOT NULL DEFAULT 'attachment',
    display_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_file_assoc_file ON file_associations(file_id);
CREATE INDEX IF NOT EXISTS idx_file_assoc_entity ON file_associations(entity_type, entity_id);

-- Media Transcoding Jobs
CREATE TABLE IF NOT EXISTS media_transcoding_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_file_id UUID NOT NULL REFERENCES file_storage(id) ON DELETE CASCADE,
    output_format TEXT NOT NULL,
    output_quality TEXT,
    output_file_id UUID REFERENCES file_storage(id),
    status TEXT DEFAULT 'pending',
    progress_percentage INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_transcoding_source ON media_transcoding_jobs(source_file_id);
CREATE INDEX IF NOT EXISTS idx_transcoding_status ON media_transcoding_jobs(status);

-- File Versions (for versioned documents)
CREATE TABLE IF NOT EXISTS file_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID NOT NULL REFERENCES file_storage(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    file_size_bytes BIGINT NOT NULL,
    checksum TEXT,
    change_description TEXT,
    created_by UUID NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(file_id, version_number)
);

CREATE INDEX IF NOT EXISTS idx_file_versions_file ON file_versions(file_id);

-- Temporary Files (for cleanup)
CREATE TABLE IF NOT EXISTS temporary_files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_path TEXT NOT NULL,
    purpose TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_temp_files_expires ON temporary_files(expires_at);
