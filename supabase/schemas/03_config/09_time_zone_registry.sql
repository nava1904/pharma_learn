-- ===========================================
-- TIME ZONE REGISTRY
-- Per-plant timezone configuration
-- Alfa URS §4.5.31.5: EBR timestamp reconstruction
-- Required for multi-site orgs spanning multiple time zones
-- (Goa, Indore, Mumbai R&D are all IST but global orgs may span UTC offsets)
-- ===========================================

CREATE TABLE IF NOT EXISTS time_zone_registry (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Scope
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID UNIQUE REFERENCES plants(id) ON DELETE CASCADE,  -- NULL = org-wide default

    -- IANA timezone identifier (used with AT TIME ZONE in SQL)
    iana_tz             TEXT NOT NULL,          -- e.g. 'Asia/Kolkata', 'America/New_York'
    display_name        TEXT NOT NULL,          -- e.g. 'India Standard Time (IST, UTC+5:30)'
    utc_offset_hours    NUMERIC(4,2) NOT NULL,  -- e.g. 5.5 for IST, -5.0 for EST

    is_default          BOOLEAN NOT NULL DEFAULT FALSE,
    is_dst_observed     BOOLEAN NOT NULL DEFAULT FALSE,   -- Does this zone observe Daylight Saving Time?
    dst_offset_hours    NUMERIC(4,2),                    -- Additional offset during DST (NULL if no DST)

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_tz_registry_default
    ON time_zone_registry(organization_id)
    WHERE is_default = TRUE AND plant_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_tz_registry_org   ON time_zone_registry(organization_id);
CREATE INDEX IF NOT EXISTS idx_tz_registry_plant ON time_zone_registry(plant_id);

DROP TRIGGER IF EXISTS trg_tz_registry_updated ON time_zone_registry;
CREATE TRIGGER trg_tz_registry_updated
    BEFORE UPDATE ON time_zone_registry
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------
-- FUNCTION: convert a TIMESTAMPTZ to the plant's local time
-- Used for EBR (Electronic Batch Record) timestamp display
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION to_plant_local_time(
    p_timestamp     TIMESTAMPTZ,
    p_plant_id      UUID
) RETURNS TIMESTAMPTZ AS $$
DECLARE
    v_iana_tz TEXT;
BEGIN
    SELECT iana_tz INTO v_iana_tz
    FROM time_zone_registry
    WHERE plant_id = p_plant_id;

    IF NOT FOUND OR v_iana_tz IS NULL THEN
        -- Fall back to UTC
        RETURN p_timestamp AT TIME ZONE 'UTC';
    END IF;

    RETURN p_timestamp AT TIME ZONE v_iana_tz;
END;
$$ LANGUAGE plpgsql STABLE;

-- -------------------------------------------------------
-- SEED: common timezones for pharma sites in India
-- -------------------------------------------------------
-- Note: plant associations are set during plant setup wizard.
-- These rows provide named zone references.
-- For Indian pharma (Alfa: Goa, Indore, Mumbai R&D — all IST)
INSERT INTO time_zone_registry
    (organization_id, plant_id, iana_tz, display_name, utc_offset_hours, is_default, is_dst_observed)
SELECT
    id,
    NULL,
    'Asia/Kolkata',
    'India Standard Time (IST, UTC+5:30)',
    5.5,
    TRUE,
    FALSE
FROM organizations
ON CONFLICT DO NOTHING;

COMMENT ON TABLE  time_zone_registry IS 'Per-plant IANA timezone for EBR timestamp reconstruction (Alfa §4.5.31.5)';
COMMENT ON COLUMN time_zone_registry.iana_tz IS 'IANA tz database key (e.g. Asia/Kolkata) — use with AT TIME ZONE in SQL';
COMMENT ON COLUMN time_zone_registry.utc_offset_hours IS 'UTC offset in fractional hours (e.g. 5.5 = UTC+05:30 for IST)';
COMMENT ON FUNCTION to_plant_local_time IS 'Convert UTC timestamp to plant local time for EBR display';
