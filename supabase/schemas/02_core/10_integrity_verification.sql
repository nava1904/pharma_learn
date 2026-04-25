-- ===========================================
-- INTEGRITY VERIFICATION
-- Hash chain verification for 21 CFR §11.10(c) defense-in-depth
-- Nightly job walks audit_trail hash chain and flags any broken links
-- ===========================================

CREATE TABLE IF NOT EXISTS integrity_verification_log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What was verified
    run_id              UUID NOT NULL,           -- Groups all checks in one verification run
    entity_type         TEXT NOT NULL,           -- 'audit_trail', 'electronic_signature', 'revision_history'

    -- Scope of this check
    checked_from_id     UUID,                    -- First entity ID in the verified range
    checked_through_id  UUID,                    -- Last entity ID in the verified range
    record_count        INTEGER NOT NULL DEFAULT 0,

    -- Result
    is_valid            BOOLEAN NOT NULL,
    first_broken_id     UUID,                    -- ID of the first record with a hash mismatch
    first_broken_at     TIMESTAMPTZ,             -- Timestamp of the broken record
    broken_count        INTEGER NOT NULL DEFAULT 0,
    verification_notes  TEXT,

    -- Performance
    run_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_ms         INTEGER,

    -- Trigger (who/what initiated this run)
    triggered_by        TEXT NOT NULL DEFAULT 'scheduled'
                            CHECK (triggered_by IN ('scheduled', 'manual', 'incident_response')),
    triggered_by_employee UUID REFERENCES employees(id) ON DELETE SET NULL,

    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL
);

-- Verification log is append-only
CREATE OR REPLACE FUNCTION integrity_log_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'integrity_verification_log cannot be deleted — required as evidence for §11.10(c)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_integrity_log_immutable ON integrity_verification_log;
CREATE TRIGGER trg_integrity_log_immutable
    BEFORE DELETE ON integrity_verification_log
    FOR EACH ROW EXECUTE FUNCTION integrity_log_immutable();

CREATE INDEX IF NOT EXISTS idx_integrity_log_run      ON integrity_verification_log(run_id);
CREATE INDEX IF NOT EXISTS idx_integrity_log_entity   ON integrity_verification_log(entity_type);
CREATE INDEX IF NOT EXISTS idx_integrity_log_valid    ON integrity_verification_log(is_valid);
CREATE INDEX IF NOT EXISTS idx_integrity_log_run_at   ON integrity_verification_log(run_at DESC);
CREATE INDEX IF NOT EXISTS idx_integrity_log_broken   ON integrity_verification_log(first_broken_id)
    WHERE first_broken_id IS NOT NULL;

-- -------------------------------------------------------
-- FUNCTION: verify audit trail hash chain for an entity
-- Walks through all audit_trails rows for entity_type/entity_id
-- and re-computes each row_hash to detect tampering
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION verify_audit_hash_chain(
    p_entity_type       TEXT DEFAULT NULL,   -- NULL = check all entity types
    p_entity_id         UUID DEFAULT NULL,   -- NULL = check all entities
    p_run_id            UUID DEFAULT NULL,
    p_org_id            UUID DEFAULT NULL,
    p_triggered_by      TEXT DEFAULT 'scheduled'
) RETURNS TABLE (
    run_id              UUID,
    entity_type         TEXT,
    record_count        INTEGER,
    is_valid            BOOLEAN,
    first_broken_id     UUID,
    broken_count        INTEGER
) AS $$
DECLARE
    v_run_id        UUID := COALESCE(p_run_id, gen_random_uuid());
    v_start_time    TIMESTAMPTZ := NOW();
    v_count         INTEGER := 0;
    v_broken_count  INTEGER := 0;
    v_first_broken  UUID;
    v_first_broken_at TIMESTAMPTZ;
    v_prev_hash     TEXT;
    v_computed_hash TEXT;
    v_row           audit_trails%ROWTYPE;
    v_duration_ms   INTEGER;
BEGIN
    -- Walk audit_trails in creation order for the given scope
    FOR v_row IN
        SELECT *
        FROM audit_trails
        WHERE (p_entity_type IS NULL OR entity_type = p_entity_type)
          AND (p_entity_id   IS NULL OR entity_id   = p_entity_id)
          AND (p_org_id      IS NULL OR organization_id = p_org_id)
        ORDER BY entity_type, entity_id, created_at ASC
    LOOP
        v_count := v_count + 1;

        -- Recompute the hash
        v_computed_hash := generate_audit_hash(
            v_row.entity_type,
            v_row.entity_id,
            v_row.action,
            v_row.performed_by,
            v_row.created_at,
            v_row.previous_hash
        );

        IF v_computed_hash != v_row.row_hash THEN
            v_broken_count := v_broken_count + 1;
            IF v_first_broken IS NULL THEN
                v_first_broken    := v_row.id;
                v_first_broken_at := v_row.created_at;
            END IF;
        END IF;
    END LOOP;

    v_duration_ms := EXTRACT(MILLISECONDS FROM (NOW() - v_start_time))::INTEGER;

    -- Persist result
    INSERT INTO integrity_verification_log (
        run_id, entity_type, record_count, is_valid,
        first_broken_id, first_broken_at, broken_count,
        run_at, duration_ms, triggered_by, organization_id
    ) VALUES (
        v_run_id, COALESCE(p_entity_type, 'ALL'), v_count, v_broken_count = 0,
        v_first_broken, v_first_broken_at, v_broken_count,
        NOW(), v_duration_ms, p_triggered_by, p_org_id
    );

    -- Return result
    RETURN QUERY
    SELECT
        v_run_id,
        COALESCE(p_entity_type, 'ALL'),
        v_count,
        v_broken_count = 0,
        v_first_broken,
        v_broken_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- VIEW: latest verification result per entity_type
-- -------------------------------------------------------
CREATE OR REPLACE VIEW v_latest_integrity_status AS
SELECT DISTINCT ON (entity_type)
    entity_type,
    run_at,
    record_count,
    is_valid,
    broken_count,
    first_broken_id
FROM integrity_verification_log
ORDER BY entity_type, run_at DESC;

COMMENT ON TABLE  integrity_verification_log IS '21 CFR §11.10(c) — evidence of regular hash chain verification runs';
COMMENT ON FUNCTION verify_audit_hash_chain IS 'Walk audit_trail rows and recompute hashes to detect tampering; persists result to verification log';
COMMENT ON VIEW v_latest_integrity_status IS 'Latest integrity check result per entity type — for compliance dashboard';
