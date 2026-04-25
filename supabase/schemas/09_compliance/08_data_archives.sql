-- ===========================================
-- DATA ARCHIVES
-- Record archival per retention policy
-- EE URS §5.13.5 (archival after retention period)
-- Alfa URS §4.5.14 (archival mechanism)
-- ===========================================

-- -------------------------------------------------------
-- DATA ARCHIVES
-- One row per archived entity record
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS data_archives (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What was archived
    entity_type             TEXT NOT NULL,
    entity_id               UUID NOT NULL,

    -- Archive metadata
    archived_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    archived_by             UUID REFERENCES employees(id) ON DELETE SET NULL,
    archive_reason          TEXT NOT NULL DEFAULT 'RETENTION_POLICY',

    -- Where the archive lives
    archive_location        TEXT NOT NULL,   -- e.g. 's3://pharmalearn-archives/2024/training_records/'
    archive_format          TEXT NOT NULL DEFAULT 'JSON'
                                CHECK (archive_format IN ('JSON', 'PDF', 'XML', 'CSV', 'PARQUET')),
    archive_checksum        TEXT NOT NULL,   -- SHA-256 of archive content for integrity verification
    archive_size_bytes      BIGINT,

    -- Snapshot of the audit trail for this entity at time of archival
    audit_trail_snapshot    JSONB,    -- last N audit events for the entity
    esig_snapshot           JSONB,    -- all e-signatures for the entity

    -- Retrieval tracking
    retrieved_count         INTEGER NOT NULL DEFAULT 0,
    last_retrieved_at       TIMESTAMPTZ,
    last_retrieved_by       UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Retention policy reference
    retention_policy_id     UUID REFERENCES retention_policies(id) ON DELETE SET NULL,

    -- Organization context
    organization_id         UUID REFERENCES organizations(id) ON DELETE SET NULL,
    plant_id                UUID REFERENCES plants(id) ON DELETE SET NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Archives are append-only
CREATE OR REPLACE FUNCTION data_archives_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'data_archives records cannot be deleted — required for §5.13.5 archival compliance';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        -- Allow only retrieval tracking fields to be updated
        IF OLD.entity_id      != NEW.entity_id      OR
           OLD.archived_at    != NEW.archived_at     OR
           OLD.archive_location != NEW.archive_location THEN
            RAISE EXCEPTION 'data_archives core fields are immutable after archival';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_data_archives_immutable ON data_archives;
CREATE TRIGGER trg_data_archives_immutable
    BEFORE UPDATE OR DELETE ON data_archives
    FOR EACH ROW EXECUTE FUNCTION data_archives_immutable();

CREATE INDEX IF NOT EXISTS idx_data_archives_entity  ON data_archives(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_data_archives_date    ON data_archives(archived_at DESC);
CREATE INDEX IF NOT EXISTS idx_data_archives_org     ON data_archives(organization_id);

-- -------------------------------------------------------
-- ARCHIVE JOBS
-- Background jobs executed by lifecycle_monitor
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS archive_jobs (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Job identity
    job_type                TEXT NOT NULL DEFAULT 'ARCHIVE'
                                CHECK (job_type IN ('ARCHIVE', 'RESTORE', 'VERIFY', 'DELETE')),
    entity_type             TEXT NOT NULL,

    -- Status lifecycle
    status                  TEXT NOT NULL DEFAULT 'QUEUED'
                                CHECK (status IN ('QUEUED','RUNNING','COMPLETED','FAILED','CANCELLED')),

    -- Execution context
    triggered_by            UUID REFERENCES employees(id) ON DELETE SET NULL,
    triggered_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,

    -- Results
    records_queued          INTEGER DEFAULT 0,
    records_processed       INTEGER DEFAULT 0,
    records_archived        INTEGER DEFAULT 0,
    records_failed          INTEGER DEFAULT 0,
    error_text              TEXT,
    error_detail            JSONB,

    -- Retention policy that triggered this job
    retention_policy_id     UUID REFERENCES retention_policies(id) ON DELETE SET NULL,

    organization_id         UUID REFERENCES organizations(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_archive_jobs_status  ON archive_jobs(status);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_entity  ON archive_jobs(entity_type);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_org     ON archive_jobs(organization_id);
CREATE INDEX IF NOT EXISTS idx_archive_jobs_date    ON archive_jobs(triggered_at DESC);

DROP TRIGGER IF EXISTS trg_archive_jobs_updated ON archive_jobs;
CREATE TRIGGER trg_archive_jobs_updated
    BEFORE UPDATE ON archive_jobs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE data_archives IS 'Archived entity records per retention policy (EE §5.13.5, Alfa §4.5.14)';
COMMENT ON COLUMN data_archives.archive_checksum IS 'SHA-256 of archive file contents for long-term integrity verification';
COMMENT ON COLUMN data_archives.audit_trail_snapshot IS 'Last N audit events captured at archival time — survives entity deletion';
COMMENT ON TABLE archive_jobs IS 'Background archival/restoration jobs executed by lifecycle_monitor';
