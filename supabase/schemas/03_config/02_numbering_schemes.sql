-- ===========================================
-- NUMBERING SCHEMES
-- Configurable auto-numbering per entity type
-- Alfa URS §4.2.1.28: "{PLANT}-{DEPT}-{TYPE}-{YYYY}-{SEQ}"
-- ===========================================

CREATE TABLE IF NOT EXISTS numbering_schemes (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What entity type this scheme applies to
    entity_type         TEXT NOT NULL,  -- 'training_session', 'document', 'certificate', etc.

    -- Format template — tokens: {PLANT}, {ORG}, {DEPT}, {TYPE}, {YYYY}, {MM}, {DD}, {SEQ:N}
    -- Example: '{PLANT}-SOP-{YYYY}-{SEQ:5}'  → 'GOA-SOP-2026-00001'
    format_template     TEXT NOT NULL,

    -- Sequence configuration
    sequence_start      INTEGER NOT NULL DEFAULT 1,
    sequence_step       INTEGER NOT NULL DEFAULT 1,
    sequence_padding    INTEGER NOT NULL DEFAULT 5,    -- zero-left-pad width for {SEQ}

    -- Reset behavior
    reset_frequency     TEXT NOT NULL DEFAULT 'NEVER'
                            CHECK (reset_frequency IN ('NEVER', 'YEARLY', 'MONTHLY')),
    last_reset_at       TIMESTAMPTZ,
    next_reset_at       TIMESTAMPTZ,    -- computed by trigger

    -- Scope
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,   -- NULL = org-wide
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    is_default          BOOLEAN NOT NULL DEFAULT FALSE,  -- default scheme for entity_type in this org

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID
);

-- Per entity_type, per plant there should be one active default
CREATE UNIQUE INDEX IF NOT EXISTS idx_numbering_default
    ON numbering_schemes(organization_id, entity_type)
    WHERE is_default = TRUE AND plant_id IS NULL AND is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_numbering_entity   ON numbering_schemes(entity_type);
CREATE INDEX IF NOT EXISTS idx_numbering_plant     ON numbering_schemes(plant_id);
CREATE INDEX IF NOT EXISTS idx_numbering_org       ON numbering_schemes(organization_id);

-- -------------------------------------------------------
-- NUMBERING SEQUENCES
-- One row per active scheme; tracks current sequence value.
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS numbering_sequences (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scheme_id           UUID NOT NULL REFERENCES numbering_schemes(id) ON DELETE CASCADE,

    -- Sequence state
    current_value       BIGINT NOT NULL DEFAULT 0,      -- last used value (next = current + step)
    year_partition      INTEGER,                         -- NULL when reset_frequency = NEVER
    month_partition     INTEGER,

    -- Reset history
    reset_count         INTEGER NOT NULL DEFAULT 0,
    last_reset_at       TIMESTAMPTZ,
    last_used_at        TIMESTAMPTZ,

    UNIQUE(scheme_id, year_partition, month_partition)
);

CREATE INDEX IF NOT EXISTS idx_numbering_sequences_scheme ON numbering_sequences(scheme_id);

-- -------------------------------------------------------
-- FUNCTION: get next number in a scheme
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION get_next_number(
    p_scheme_id         UUID,
    p_plant_code        TEXT DEFAULT NULL,
    p_org_code          TEXT DEFAULT NULL,
    p_dept_code         TEXT DEFAULT NULL,
    p_type_code         TEXT DEFAULT NULL
) RETURNS TEXT AS $$
DECLARE
    v_scheme    numbering_schemes%ROWTYPE;
    v_seq       numbering_sequences%ROWTYPE;
    v_year      INTEGER := EXTRACT(YEAR FROM NOW())::INTEGER;
    v_month     INTEGER := EXTRACT(MONTH FROM NOW())::INTEGER;
    v_next_val  BIGINT;
    v_result    TEXT;
    v_year_part INTEGER;
    v_month_part INTEGER;
BEGIN
    SELECT * INTO v_scheme FROM numbering_schemes WHERE id = p_scheme_id AND is_active = TRUE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Numbering scheme not found or inactive: %', p_scheme_id;
    END IF;

    -- Determine partition keys based on reset_frequency
    v_year_part  := CASE WHEN v_scheme.reset_frequency IN ('YEARLY','MONTHLY') THEN v_year ELSE NULL END;
    v_month_part := CASE WHEN v_scheme.reset_frequency = 'MONTHLY' THEN v_month ELSE NULL END;

    -- Upsert sequence row for this partition
    INSERT INTO numbering_sequences (scheme_id, current_value, year_partition, month_partition, last_used_at)
    VALUES (p_scheme_id, v_scheme.sequence_start - v_scheme.sequence_step, v_year_part, v_month_part, NOW())
    ON CONFLICT (scheme_id, year_partition, month_partition)
    DO UPDATE SET
        current_value = numbering_sequences.current_value + v_scheme.sequence_step,
        last_used_at  = NOW()
    RETURNING current_value INTO v_next_val;

    -- Replace tokens in format_template
    v_result := v_scheme.format_template;
    v_result := REPLACE(v_result, '{PLANT}',  COALESCE(p_plant_code, 'XXX'));
    v_result := REPLACE(v_result, '{ORG}',    COALESCE(p_org_code, 'XXX'));
    v_result := REPLACE(v_result, '{DEPT}',   COALESCE(p_dept_code, 'XXX'));
    v_result := REPLACE(v_result, '{TYPE}',   COALESCE(p_type_code, 'XXX'));
    v_result := REPLACE(v_result, '{YYYY}',   v_year::TEXT);
    v_result := REPLACE(v_result, '{MM}',     LPAD(v_month::TEXT, 2, '0'));
    v_result := REPLACE(v_result, '{DD}',     LPAD(EXTRACT(DAY FROM NOW())::TEXT, 2, '0'));
    v_result := REPLACE(v_result, '{SEQ:'  || v_scheme.sequence_padding::TEXT || '}',
                                  LPAD(v_next_val::TEXT, v_scheme.sequence_padding, '0'));

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_numbering_updated ON numbering_schemes;
CREATE TRIGGER trg_numbering_updated
    BEFORE UPDATE ON numbering_schemes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

COMMENT ON TABLE  numbering_schemes IS 'Configurable auto-numbering templates per entity type (Alfa §4.2.1.28)';
COMMENT ON COLUMN numbering_schemes.format_template IS 'Token pattern e.g. {PLANT}-SOP-{YYYY}-{SEQ:5}';
COMMENT ON COLUMN numbering_schemes.reset_frequency IS 'NEVER=global sequence; YEARLY=resets Jan 1; MONTHLY=resets 1st of month';
COMMENT ON TABLE  numbering_sequences IS 'Running sequence counters per scheme per partition (year/month)';
COMMENT ON FUNCTION get_next_number IS 'Atomically increments sequence and returns formatted number string';
