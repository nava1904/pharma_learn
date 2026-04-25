-- ===========================================
-- ARCHIVE JOBS
-- Manages lifecycle_monitor archival operations
-- EE URS §5.13.5 — Archival mechanism
-- ===========================================

CREATE TABLE IF NOT EXISTS archive_jobs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID REFERENCES organizations(id) ON DELETE SET NULL,

    -- Job identification
    job_type                TEXT NOT NULL CHECK (job_type IN ('ARCHIVE', 'RESTORE', 'DELETE', 'LEGAL_HOLD')),
    entity_type             TEXT NOT NULL,
    batch_id                TEXT NOT NULL,          -- Unique identifier for this batch of records

    -- Scope
    retention_policy_id     UUID REFERENCES retention_policies(id) ON DELETE SET NULL,
    plant_id                UUID REFERENCES plants(id) ON DELETE SET NULL,
    date_range_start        DATE,
    date_range_end          DATE,

    -- Progress tracking
    status                  TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN (
        'PENDING', 'IN_PROGRESS', 'COMPLETED', 'FAILED', 'CANCELLED', 'PARTIAL'
    )),
    total_records           INTEGER DEFAULT 0,
    processed_records       INTEGER DEFAULT 0,
    archived_records        INTEGER DEFAULT 0,
    failed_records          INTEGER DEFAULT 0,

    -- Timing
    scheduled_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,
    estimated_completion    TIMESTAMPTZ,

    -- Output
    archive_location        TEXT,                   -- S3 bucket, file path, etc.
    archive_format          TEXT DEFAULT 'JSON' CHECK (archive_format IN ('JSON', 'PDF', 'XML', 'CSV')),
    archive_checksum        TEXT,                   -- SHA-256 of the archive file

    -- Error handling
    error_message           TEXT,
    error_details           JSONB,
    retry_count             INTEGER DEFAULT 0,
    max_retries             INTEGER DEFAULT 3,

    -- Audit
    triggered_by            UUID REFERENCES employees(id) ON DELETE SET NULL,
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_archive_jobs_org ON archive_jobs(organization_id);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_status ON archive_jobs(status);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_type ON archive_jobs(job_type, entity_type);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_scheduled ON archive_jobs(scheduled_at) WHERE status = 'PENDING';
CREATE INDEX IF NOT EXISTS idx_archive_jobs_batch ON archive_jobs(batch_id);

-- Trigger for audit
DROP TRIGGER IF EXISTS trg_archive_jobs_audit ON archive_jobs;
CREATE TRIGGER trg_archive_jobs_audit
    AFTER INSERT OR UPDATE OR DELETE ON archive_jobs
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- ARCHIVE MANIFEST
-- Tracks individual records within an archive batch
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS archive_manifest (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    archive_job_id          UUID NOT NULL REFERENCES archive_jobs(id) ON DELETE CASCADE,

    -- Record identification
    entity_type             TEXT NOT NULL,
    entity_id               UUID NOT NULL,
    original_created_at     TIMESTAMPTZ NOT NULL,

    -- Archive details
    archive_path            TEXT NOT NULL,          -- Path within archive file/storage
    record_checksum         TEXT NOT NULL,          -- SHA-256 of the individual record
    record_size_bytes       BIGINT,

    -- Status
    status                  TEXT NOT NULL DEFAULT 'ARCHIVED' CHECK (status IN (
        'ARCHIVED', 'RESTORED', 'DELETED', 'LEGAL_HOLD'
    )),
    restored_at             TIMESTAMPTZ,
    deleted_at              TIMESTAMPTZ,

    -- Metadata
    metadata                JSONB,                  -- Additional info (original IDs, relationships, etc.)
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(archive_job_id, entity_type, entity_id)
);

CREATE INDEX IF NOT EXISTS idx_archive_manifest_job ON archive_manifest(archive_job_id);
CREATE INDEX IF NOT EXISTS idx_archive_manifest_entity ON archive_manifest(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_archive_manifest_status ON archive_manifest(status);

-- -------------------------------------------------------
-- LEGAL HOLDS
-- Prevents archival/deletion of specific records
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS legal_holds (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Hold identification
    hold_name               TEXT NOT NULL,
    hold_reason             TEXT NOT NULL,
    legal_matter_ref        TEXT,                   -- External legal case reference

    -- Scope
    entity_type             TEXT,                   -- NULL = all entity types
    entity_ids              UUID[],                 -- Specific entities; NULL = all matching type
    date_range_start        DATE,
    date_range_end          DATE,

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at              TIMESTAMPTZ,            -- Auto-release date (NULL = indefinite)

    -- Authorization
    authorized_by           UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    authorized_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Release
    released_by             UUID REFERENCES employees(id) ON DELETE SET NULL,
    released_at             TIMESTAMPTZ,
    release_reason          TEXT,
    release_esignature_id   UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_legal_holds_org ON legal_holds(organization_id);
CREATE INDEX IF NOT EXISTS idx_legal_holds_active ON legal_holds(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_legal_holds_entity ON legal_holds(entity_type) WHERE entity_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_legal_holds_expires ON legal_holds(expires_at) WHERE expires_at IS NOT NULL;

-- Trigger for audit
DROP TRIGGER IF EXISTS trg_legal_holds_audit ON legal_holds;
CREATE TRIGGER trg_legal_holds_audit
    AFTER INSERT OR UPDATE OR DELETE ON legal_holds
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- Function to check if a record is under legal hold
-- -------------------------------------------------------

CREATE OR REPLACE FUNCTION is_under_legal_hold(
    p_entity_type TEXT,
    p_entity_id UUID,
    p_record_date DATE DEFAULT CURRENT_DATE
) RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM legal_holds lh
        WHERE lh.is_active = TRUE
          AND (lh.expires_at IS NULL OR lh.expires_at > NOW())
          AND (lh.entity_type IS NULL OR lh.entity_type = p_entity_type)
          AND (lh.entity_ids IS NULL OR p_entity_id = ANY(lh.entity_ids))
          AND (lh.date_range_start IS NULL OR p_record_date >= lh.date_range_start)
          AND (lh.date_range_end IS NULL OR p_record_date <= lh.date_range_end)
    );
END;
$$ LANGUAGE plpgsql STABLE;

COMMENT ON TABLE archive_jobs IS 'Archival batch jobs managed by lifecycle_monitor';
COMMENT ON TABLE archive_manifest IS 'Individual record tracking within archive batches';
COMMENT ON TABLE legal_holds IS 'Legal holds preventing archival/deletion of specific records';
COMMENT ON FUNCTION is_under_legal_hold IS 'Check if a specific record is currently under any active legal hold';
