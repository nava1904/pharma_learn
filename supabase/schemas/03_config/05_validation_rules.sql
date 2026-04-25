-- ===========================================
-- VALIDATION RULES
-- Configurable field-level validation per entity type
-- Alfa URS §3.1.33-34: "alert for blank fields before e-signing"
-- EE URS §5.3.5: data completeness before workflow submission
-- ===========================================

CREATE TABLE IF NOT EXISTS validation_rules (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What entity and field this rule applies to
    entity_type         TEXT NOT NULL,       -- e.g. 'training_session', 'document', 'certificate'
    field_name          TEXT NOT NULL,       -- exact DB column name or logical field name
    field_label         TEXT NOT NULL,       -- human-readable label shown in UI (for error messages)

    -- Rule definition
    rule_type           TEXT NOT NULL
                            CHECK (rule_type IN (
                                'REQUIRED',          -- field must not be null/empty
                                'REGEX',             -- value must match a regex pattern
                                'RANGE',             -- numeric/date value must be within min/max
                                'ENUM',              -- value must be in an allowed set
                                'MIN_LENGTH',        -- text must be at least N chars
                                'MAX_LENGTH',        -- text must be at most N chars
                                'CUSTOM_SQL',        -- arbitrary SQL expression returning boolean
                                'CROSS_FIELD'        -- depends on another field's value
                            )),

    -- Rule expression (interpretation depends on rule_type)
    rule_expression     TEXT,
    -- REQUIRED: NULL (no extra data)
    -- REGEX: '^[A-Z0-9\-]+$'
    -- RANGE: '{"min": 0, "max": 100}' (JSONB coerced as TEXT)
    -- ENUM: '["ILT","OJT","WBT"]' (JSON array)
    -- MIN_LENGTH/MAX_LENGTH: '8'
    -- CUSTOM_SQL: 'NEW.end_date > NEW.start_date'
    -- CROSS_FIELD: '{"depends_on":"is_postdated","condition":"true","required_field":"postdated_reason"}'

    -- When this rule fires
    trigger_event       TEXT NOT NULL DEFAULT 'SUBMIT'
                            CHECK (trigger_event IN (
                                'SAVE',     -- on every save (strict)
                                'SUBMIT',   -- before workflow submission
                                'SIGN',     -- before e-signature (Alfa §3.1.33 — blank-field gate)
                                'ANY'       -- all events
                            )),

    -- Error message (supports {field_label} interpolation)
    error_message_key   TEXT NOT NULL,   -- i18n key or literal string
    error_severity      TEXT NOT NULL DEFAULT 'ERROR'
                            CHECK (error_severity IN ('ERROR', 'WARNING', 'INFO')),

    -- Scope
    organization_id     UUID REFERENCES organizations(id) ON DELETE CASCADE,   -- NULL = system-wide
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    display_order       INTEGER NOT NULL DEFAULT 0,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID
);

CREATE INDEX IF NOT EXISTS idx_validation_rules_entity  ON validation_rules(entity_type, field_name);
CREATE INDEX IF NOT EXISTS idx_validation_rules_event   ON validation_rules(trigger_event);
CREATE INDEX IF NOT EXISTS idx_validation_rules_active  ON validation_rules(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_validation_rules_org     ON validation_rules(organization_id);

DROP TRIGGER IF EXISTS trg_validation_rules_updated ON validation_rules;
CREATE TRIGGER trg_validation_rules_updated
    BEFORE UPDATE ON validation_rules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------
-- SEED: required field rules for e-signature gate
-- (Alfa §3.1.33: system must alert for blank fields before allowing e-sig)
-- -------------------------------------------------------
INSERT INTO validation_rules
    (entity_type, field_name, field_label, rule_type, trigger_event, error_message_key, error_severity)
VALUES
    ('training_session', 'session_code',      'Session Code',       'REQUIRED', 'SIGN',   'validation.session_code_required',    'ERROR'),
    ('training_session', 'session_date',      'Session Date',       'REQUIRED', 'SIGN',   'validation.session_date_required',    'ERROR'),
    ('training_session', 'trainer_id',        'Trainer',            'REQUIRED', 'SIGN',   'validation.trainer_required',         'ERROR'),
    ('training_session', 'postdated_reason',  'Post-date Reason',   'CROSS_FIELD', 'SIGN',
        '{"depends_on":"is_postdated","condition":"true","required_field":"postdated_reason"}',
        'validation.postdate_reason_required', 'ERROR'),

    ('document',         'document_number',   'Document Number',    'REQUIRED', 'SIGN',   'validation.doc_number_required',      'ERROR'),
    ('document',         'version',           'Version',            'REQUIRED', 'SIGN',   'validation.version_required',         'ERROR'),
    ('document',         'owner_id',          'Document Owner',     'REQUIRED', 'SIGN',   'validation.owner_required',           'ERROR'),

    ('training_record',  'employee_id',       'Employee',           'REQUIRED', 'SIGN',   'validation.employee_required',        'ERROR'),
    ('training_record',  'completion_date',   'Completion Date',    'REQUIRED', 'SIGN',   'validation.completion_date_required', 'ERROR'),

    ('certificate',      'issued_to',         'Issued To',          'REQUIRED', 'SIGN',   'validation.issued_to_required',       'ERROR'),
    ('certificate',      'valid_until',       'Valid Until',        'REQUIRED', 'SIGN',   'validation.valid_until_required',     'ERROR')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE  validation_rules IS 'Configurable field validation rules per entity; fires on SAVE/SUBMIT/SIGN events (Alfa §3.1.33-34)';
COMMENT ON COLUMN validation_rules.rule_type IS 'REQUIRED|REGEX|RANGE|ENUM|MIN_LENGTH|MAX_LENGTH|CUSTOM_SQL|CROSS_FIELD';
COMMENT ON COLUMN validation_rules.trigger_event IS 'SIGN fires the blank-field gate before e-signature (Alfa §3.1.33)';
COMMENT ON COLUMN validation_rules.rule_expression IS 'Interpretation depends on rule_type: regex string, JSON range/enum, or SQL expression';
