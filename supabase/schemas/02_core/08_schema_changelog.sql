-- ===========================================
-- SCHEMA CHANGELOG
-- Validation traceability per 21 CFR §11.10(a)
-- URS: EE §5.7.2 (system validation documentation)
-- Alfa §4.6.2 (IQ/OQ/PQ validation traceability)
-- ===========================================
--
-- Every schema migration file corresponds to one row here.
-- The CI pipeline asserts that every file in supabase/schemas/ has
-- a matching, validated changelog entry before allowing a release tag.
-- ===========================================

CREATE TABLE IF NOT EXISTS schema_changelog (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Unique migration identifier — matches the Supabase migration filename
    -- e.g. '20240115_001_user_credentials' or '02_core/08_schema_changelog'
    migration_id        TEXT UNIQUE NOT NULL,

    -- Who/when applied
    applied_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    applied_by          TEXT NOT NULL,   -- GitHub Actions bot / DBA username

    -- What changed (human-readable for IQ protocol)
    change_summary      TEXT NOT NULL,

    -- URS and regulation traceability
    urs_refs            TEXT[],         -- e.g. ARRAY['Alfa §4.5.5', 'EE §5.9.2']
    regulation_refs     TEXT[],         -- e.g. ARRAY['21 CFR §11.300', 'EU Annex 11 §7.1']
    blocker_id          TEXT,           -- e.g. 'B-02', 'DS-03' from evaluation doc

    -- IQ/OQ/PQ document references
    validation_doc_ref  TEXT,           -- e.g. 'IQ-2026-001, OQ-2026-002'
    is_validated        BOOLEAN NOT NULL DEFAULT FALSE,
    validated_by        TEXT,
    validated_at        TIMESTAMPTZ,

    -- Risk level for change control
    change_risk         TEXT NOT NULL DEFAULT 'LOW'
                            CHECK (change_risk IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),

    -- Optional rollback script reference
    rollback_script     TEXT,

    -- Timestamps
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutability: changelog rows cannot be edited or deleted after creation
-- (Matches the requirement that validation evidence is permanent)
CREATE OR REPLACE FUNCTION schema_changelog_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        -- Allow only validation fields to be updated (is_validated, validated_by, validated_at)
        IF (OLD.migration_id    != NEW.migration_id    OR
            OLD.applied_at      != NEW.applied_at      OR
            OLD.applied_by      != NEW.applied_by      OR
            OLD.change_summary  != NEW.change_summary) THEN
            RAISE EXCEPTION
                'Schema changelog core fields are immutable (21 CFR §11.10(a)). '
                'Only validation fields may be updated.';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'Schema changelog records cannot be deleted (21 CFR §11.10(a))';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_schema_changelog_immutable ON schema_changelog;
CREATE TRIGGER trg_schema_changelog_immutable
    BEFORE UPDATE OR DELETE ON schema_changelog
    FOR EACH ROW EXECUTE FUNCTION schema_changelog_immutable();

-- Indexes
CREATE INDEX IF NOT EXISTS idx_schema_changelog_applied_at    ON schema_changelog(applied_at DESC);
CREATE INDEX IF NOT EXISTS idx_schema_changelog_validated      ON schema_changelog(is_validated);
CREATE INDEX IF NOT EXISTS idx_schema_changelog_risk           ON schema_changelog(change_risk)
    WHERE change_risk IN ('HIGH', 'CRITICAL');

-- -------------------------------------------------------
-- Seed: back-fill existing schema files already in place
-- -------------------------------------------------------
INSERT INTO schema_changelog (migration_id, applied_by, change_summary, change_risk, urs_refs, regulation_refs, is_validated)
VALUES
    ('00_extensions/01_pgcrypto',        'system', 'Enable pgcrypto and uuid-ossp extensions',        'LOW',    NULL, ARRAY['21 CFR §11.70'], false),
    ('01_types/01_enums',                'system', 'All application enum types',                       'LOW',    NULL, NULL, false),
    ('02_core/01_audit_log',             'system', 'Immutable audit trail with hash chain',            'CRITICAL', ARRAY['EE §5.6.4-7','Alfa §3.1.15-32'], ARRAY['21 CFR §11.10(e)'], false),
    ('02_core/02_notifications',         'system', 'Notification queue and templates',                 'LOW',    NULL, NULL, false),
    ('02_core/03_workflow_states',       'system', 'Workflow state machine types',                     'MEDIUM', ARRAY['Alfa §4.3.4'], NULL, false),
    ('02_core/04_approval_engine',       'system', 'Generic approval workflow engine',                 'HIGH',   ARRAY['Alfa §4.3.4','EE §5.1.20'], ARRAY['21 CFR §11.10(g)'], false),
    ('02_core/05_esignature_base',       'system', 'E-signature with integrity hash and session chain','CRITICAL', ARRAY['Alfa §4.5.30','EE §5.13.8'], ARRAY['21 CFR §11.50','21 CFR §11.200'], false),
    ('02_core/06_reason_enforcement',    'system', 'Standard reasons with enforced FK pattern',        'MEDIUM', ARRAY['Alfa §3.1.33-34'], NULL, false),
    ('02_core/07_esig_reauth',           'system', 'E-signature re-authentication middleware',         'HIGH',   ARRAY['Alfa §4.5.30.4'], ARRAY['21 CFR §11.200(a)'], false),
    ('02_core/08_schema_changelog',      'system', 'Schema changelog for IQ/OQ/PQ validation traceability', 'HIGH', ARRAY['EE §5.7.2','Alfa §4.6.2'], ARRAY['21 CFR §11.10(a)'], false),
    ('03_organization/01_organizations', 'system', 'Organizations (top-level tenant entities)',        'LOW',    NULL, NULL, false),
    ('03_organization/02_plants',        'system', 'Plants/sites within organizations',                'LOW',    ARRAY['Alfa §4.2.1.28'], NULL, false),
    ('03_organization/03_departments',   'system', 'Departments within plants',                        'LOW',    NULL, NULL, false),
    ('04_identity/01_role_categories',   'system', 'Role category groupings',                          'LOW',    NULL, NULL, false),
    ('04_identity/02_roles',             'system', 'RBAC roles with approval_tier (DS-03 fix)',        'HIGH',   ARRAY['Alfa §4.3.4'], ARRAY['21 CFR §11.10(g)'], false),
    ('04_identity/03_permissions',       'system', 'Permission definitions',                           'HIGH',   NULL, ARRAY['21 CFR §11.10(d)'], false),
    ('04_identity/04_global_profiles',   'system', 'Global user profile metadata',                     'MEDIUM', NULL, NULL, false),
    ('04_identity/05_employees',         'system', 'Employee master with username + induction gate',   'HIGH',   ARRAY['EE §5.1.27','Alfa §3.1.41'], ARRAY['21 CFR §11.100(b)'], false),
    ('04_identity/06_employee_roles',    'system', 'Employee ↔ role assignments',                      'HIGH',   NULL, ARRAY['21 CFR §11.10(d)'], false),
    ('04_identity/12_biometric_registrations', 'system', 'Biometric device registrations',            'HIGH',   ARRAY['Alfa §4.5.30'], ARRAY['21 CFR §11.10(h)'], false),
    ('04_identity/13_standard_reasons',  'system', 'Configurable standard reasons library',            'MEDIUM', ARRAY['Alfa §3.1.33-34'], NULL, false),
    ('04_identity/15_user_credentials',  'system', 'Password hash storage and no-reuse enforcement',  'CRITICAL', ARRAY['Alfa §3.1.41-44','EE §5.9.2'], ARRAY['21 CFR §11.300'], false),
    ('07_training/03_sessions_batches',  'system', 'Training sessions with session_code auto-gen',     'HIGH',   ARRAY['Alfa §4.2.1.16-21'], NULL, false),
    ('07_training/05_attendance',        'system', 'Session attendance with e-signature FK',           'HIGH',   ARRAY['Alfa §5.1.24'], NULL, false),
    ('07_training/10_employee_training_obligations', 'system', 'Mandatory training obligation tracking', 'HIGH', ARRAY['Alfa §4.2.1.25'], NULL, false),
    ('07_training/11_curricula',         'system', 'Training curricula definitions',                   'MEDIUM', NULL, NULL, false),
    ('08_assessment/06_remedial_trainings', 'system', 'Remedial training after failed assessments',    'HIGH',   ARRAY['Alfa §4.3.14'], NULL, false),
    ('09_compliance/06_training_triggers', 'system', 'Automated triggers for training compliance',     'HIGH',   NULL, NULL, false),
    ('09_compliance/07_certificate_invalidation', 'system', 'Certificate invalidation logic',          'HIGH',   NULL, NULL, false),
    ('11_audit/01_security_audit',       'system', 'Legacy audit tables — replaced by audit_trails event_category', 'CRITICAL', NULL, ARRAY['21 CFR §11.10(e)'], false),
    ('11_audit/02_audit_consolidation',  'system', 'Migration: legacy audit → unified audit_trails; drops legacy tables', 'CRITICAL', ARRAY['Alfa §3.1.15-32'], ARRAY['21 CFR §11.10(e)'], false)
ON CONFLICT (migration_id) DO NOTHING;

COMMENT ON TABLE  schema_changelog IS '21 CFR §11.10(a) validation traceability: every schema migration maps to an IQ/OQ/PQ document';
COMMENT ON COLUMN schema_changelog.migration_id IS 'Matches the supabase/schemas/ relative path (without .sql)';
COMMENT ON COLUMN schema_changelog.is_validated IS 'TRUE once the IQ/OQ/PQ protocols for this change are signed off';
COMMENT ON COLUMN schema_changelog.validation_doc_ref IS 'Reference to IQ/OQ/PQ validation protocol document number';
COMMENT ON COLUMN schema_changelog.urs_refs IS 'URS clause IDs this migration satisfies (from Alfa or EE URS)';
COMMENT ON COLUMN schema_changelog.regulation_refs IS 'Regulatory citations (21 CFR §11.x, EU Annex 11 §x)';
