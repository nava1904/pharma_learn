-- ===========================================
-- G14: GENERATE_NEXT_NUMBER RPC + WAIVER NUMBERING SCHEME
-- Adds generate_next_number() wrapper used by waiver_create_handler.dart.
-- Also seeds waiver numbering scheme for each org.
-- SCORM column additions are idempotent duplicates (G13 adds same columns).
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. scorm_packages: add status and file_name columns
--
-- status: upload/processing lifecycle state for the SCORM upload handler
-- file_name: original filename of the uploaded .zip
-- error_message: stores processing error if status = 'error'
-- ---------------------------------------------------------------------------
ALTER TABLE scorm_packages
    ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ready'
        CHECK (status IN ('processing', 'ready', 'error')),
    ADD COLUMN IF NOT EXISTS file_name TEXT,
    ADD COLUMN IF NOT EXISTS error_message TEXT;

COMMENT ON COLUMN scorm_packages.status IS 'Upload/processing state: processing (zip being parsed), ready (launch_url available), error (manifest parse failed)';
COMMENT ON COLUMN scorm_packages.file_name IS 'Original filename of the uploaded SCORM zip archive';
COMMENT ON COLUMN scorm_packages.error_message IS 'Stores manifest parse or extraction error when status = error';

-- ---------------------------------------------------------------------------
-- 2. generate_next_number RPC (used by waiver_create_handler.dart)
--
-- Delegates to the existing get_next_number() function after resolving the
-- scheme_id for the given org + entity_type. Falls back to an epoch-based ID
-- if no scheme is configured.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_next_number(
    p_organization_id UUID,
    p_entity_type     TEXT
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_scheme_id UUID;
    v_org_name  TEXT;
BEGIN
    -- Find the default scheme for this org + entity type
    SELECT id INTO v_scheme_id
    FROM numbering_schemes
    WHERE organization_id = p_organization_id
      AND entity_type = p_entity_type
      AND is_active = TRUE
      AND is_default = TRUE
    LIMIT 1;

    IF v_scheme_id IS NULL THEN
        -- Fallback: non-conflicting ID when no scheme configured
        RETURN UPPER(p_entity_type) || '-' || TO_CHAR(NOW(), 'YYYY') || '-'
            || LPAD((EXTRACT(EPOCH FROM NOW()) * 1000)::BIGINT::TEXT, 13, '0');
    END IF;

    -- Resolve org name token for {ORG} placeholder
    SELECT LEFT(REGEXP_REPLACE(UPPER(name), '[^A-Z0-9]', '', 'g'), 4)
    INTO v_org_name
    FROM organizations
    WHERE id = p_organization_id;

    RETURN get_next_number(
        p_scheme_id  => v_scheme_id,
        p_org_code   => COALESCE(v_org_name, 'ORG')
    );
END;
$$;

COMMENT ON FUNCTION generate_next_number(UUID, TEXT) IS
'Resolves the default numbering scheme for p_entity_type in p_organization_id and delegates to get_next_number(). Falls back to epoch-based ID if no scheme found.';

-- Insert default numbering scheme for waivers if not present
INSERT INTO numbering_schemes (
    entity_type,
    format_template,
    sequence_start,
    sequence_step,
    sequence_padding,
    reset_frequency,
    organization_id,
    is_active,
    is_default,
    created_at
)
SELECT
    'waiver',
    '{ORG}-WVR-{YYYY}-{SEQ:5}',
    1,
    1,
    5,
    'YEARLY',
    o.id,
    TRUE,
    TRUE,
    NOW()
FROM organizations o
WHERE NOT EXISTS (
    SELECT 1 FROM numbering_schemes ns
    WHERE ns.organization_id = o.id
      AND ns.entity_type = 'waiver'
      AND ns.is_default = TRUE
);
