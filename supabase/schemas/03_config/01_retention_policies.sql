-- ===========================================
-- RETENTION POLICIES
-- Configurable per-entity record retention
-- EE URS §5.13.4-5, Alfa URS §4.4.5, §4.5.14
-- ===========================================

CREATE TABLE IF NOT EXISTS retention_policies (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Scope: which entity class this policy applies to
    entity_type             TEXT NOT NULL,          -- e.g. 'training_record', 'audit_trail', 'certificate'

    -- Retention windows (in years)
    retention_years         INTEGER NOT NULL DEFAULT 10,    -- Active record retention (GxP: 10 yr typical)
    archive_after_years     INTEGER,                        -- Move to archive after N years (NULL = never auto-archive)
    delete_after_years      INTEGER,                        -- Hard delete after N years (NULL = never auto-delete)

    -- Legal hold support (prevents archival/deletion regardless of age)
    legal_hold_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    legal_hold_reason       TEXT,
    legal_hold_set_by       UUID REFERENCES employees(id) ON DELETE SET NULL,
    legal_hold_set_at       TIMESTAMPTZ,

    -- Applicability
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,   -- NULL = all plants
    organization_id         UUID REFERENCES organizations(id) ON DELETE CASCADE,
    is_default              BOOLEAN NOT NULL DEFAULT FALSE,  -- Default policy for this entity_type if plant_id IS NULL
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    CONSTRAINT chk_retention_window
        CHECK (archive_after_years IS NULL OR archive_after_years >= retention_years
               OR archive_after_years >= 0),
    CONSTRAINT chk_delete_window
        CHECK (delete_after_years IS NULL OR delete_after_years >= COALESCE(archive_after_years, retention_years))
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_retention_policies_default
    ON retention_policies(entity_type)
    WHERE is_default = TRUE AND plant_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_retention_policies_entity ON retention_policies(entity_type);
CREATE INDEX IF NOT EXISTS idx_retention_policies_plant  ON retention_policies(plant_id);
CREATE INDEX IF NOT EXISTS idx_retention_policies_active ON retention_policies(is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trg_retention_policies_updated ON retention_policies;
CREATE TRIGGER trg_retention_policies_updated
    BEFORE UPDATE ON retention_policies
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_retention_policies_audit ON retention_policies;
CREATE TRIGGER trg_retention_policies_audit
    AFTER INSERT OR UPDATE OR DELETE ON retention_policies
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- SEED: GxP-appropriate defaults (10-year retention, never auto-delete)
-- -------------------------------------------------------
INSERT INTO retention_policies
    (entity_type, retention_years, archive_after_years, delete_after_years, is_default, is_active)
VALUES
    ('training_record',          10, 12, NULL, TRUE, TRUE),
    ('audit_trail',              10, 12, NULL, TRUE, TRUE),
    ('electronic_signature',     10, 12, NULL, TRUE, TRUE),
    ('certificate',              10, 12, NULL, TRUE, TRUE),
    ('assessment_attempt',        5,  7, NULL, TRUE, TRUE),
    ('document',                 10, 12, NULL, TRUE, TRUE),
    ('document_version',         10, 12, NULL, TRUE, TRUE),
    ('employee',                 10, 12, NULL, TRUE, TRUE),
    ('user_credential',           7,  9, NULL, TRUE, TRUE),
    ('session_attendance',        7, 10, NULL, TRUE, TRUE),
    ('schema_changelog',         15, 20, NULL, TRUE, TRUE)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE  retention_policies IS 'Configurable per-entity retention windows per EE §5.13.4-5 and Alfa §4.4.5';
COMMENT ON COLUMN retention_policies.retention_years IS 'Minimum years record must be kept in active store (GxP baseline: 10 yrs)';
COMMENT ON COLUMN retention_policies.archive_after_years IS 'After N years, lifecycle_monitor moves record to data_archives';
COMMENT ON COLUMN retention_policies.delete_after_years IS 'After N years, hard deletion is permitted (NULL = permanent retention)';
COMMENT ON COLUMN retention_policies.legal_hold_enabled IS 'When TRUE, overrides all age-based archival/deletion triggers';
