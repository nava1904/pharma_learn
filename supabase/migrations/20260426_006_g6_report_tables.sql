-- ===========================================
-- G6: REPORT SYSTEM ENHANCEMENTS
-- Extends report_executions (from 13_analytics) for pharma job queue pattern
-- Extends scheduled_reports for pharma-grade recurring delivery
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. CREATE ENUM: compliance_report_type
-- This enum was referenced in compliance_reports but never defined
-- ---------------------------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE compliance_report_type AS ENUM (
        'employee_training_dossier',
        'department_compliance_summary',
        'overdue_training_report',
        'certificate_expiry_report',
        'sop_acknowledgment_report',
        'assessment_performance_report',
        'esignature_audit_report',
        'system_access_log_report',
        'integrity_verification_report',
        'audit_readiness_report'
    );
EXCEPTION
    WHEN duplicate_object THEN NULL;
END $$;

-- ---------------------------------------------------------------------------
-- 2. ALTER report_executions: Add pharma job queue columns
-- Using existing table from 13_analytics/02_reports.sql instead of new table
-- ---------------------------------------------------------------------------

-- template_id: Which pharma report template was used (string key from Dart enum)
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS template_id TEXT;

-- parameters: JSON filter parameters passed to the report
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS parameters JSONB DEFAULT '{}'::JSONB;

-- progress_percent: Job progress (0-100) for UI polling
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS progress_percent INTEGER DEFAULT 0 
    CHECK (progress_percent >= 0 AND progress_percent <= 100);

-- report_number: Auto-generated via numbering_schemes (e.g., ALFA-RPT-2026-00142)
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS report_number TEXT;

-- audit_trail_id: Links to audit_trails row for 21 CFR §11.10(e) compliance
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS audit_trail_id UUID REFERENCES audit_trails(id);

-- priority: Job queue priority (1 = highest, 10 = lowest)
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 5 
    CHECK (priority >= 1 AND priority <= 10);

-- organization_id: For multi-tenant RLS (existing table references global_profiles, not orgs)
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);

-- storage_path_csv: CSV export path (separate from file_url for PDF)
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS storage_path_csv TEXT;

-- report_name: Human-readable name for the generated report
ALTER TABLE report_executions 
ADD COLUMN IF NOT EXISTS report_name TEXT;

-- Index for job polling: queued jobs ordered by priority and request time
CREATE INDEX IF NOT EXISTS idx_report_executions_job_queue 
ON report_executions(status, priority, started_at) 
WHERE status = 'running';

-- Index for report number lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_report_executions_number 
ON report_executions(report_number) 
WHERE report_number IS NOT NULL;

-- Index for org-based queries
CREATE INDEX IF NOT EXISTS idx_report_executions_org 
ON report_executions(organization_id);

-- ---------------------------------------------------------------------------
-- 3. ALTER scheduled_reports: Add pharma-grade columns
-- Using existing table from 13_analytics/02_reports.sql instead of new table
-- ---------------------------------------------------------------------------

-- template_id: Which pharma report template to run
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS template_id TEXT;

-- parameters: Default filter parameters for the scheduled report
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS parameters JSONB DEFAULT '{}'::JSONB;

-- timezone: For cron execution context
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS timezone TEXT DEFAULT 'Asia/Kolkata';

-- cron_expression: Alternative to frequency+schedule_config for precise scheduling
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS cron_expression TEXT;

-- delivery_method: How to deliver the report
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS delivery_method TEXT DEFAULT 'email' 
    CHECK (delivery_method IN ('email', 'storage', 'both'));

-- run_count: Track number of successful executions
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS run_count INTEGER DEFAULT 0;

-- last_run_report_id: Link to most recent execution
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS last_run_report_id UUID REFERENCES report_executions(id);

-- organization_id: For multi-tenant access (join through report_definition works, but direct is faster)
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id);

-- created_by: Track who created the schedule
ALTER TABLE scheduled_reports 
ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES employees(id);

-- Index for next run polling
CREATE INDEX IF NOT EXISTS idx_scheduled_reports_org 
ON scheduled_reports(organization_id) 
WHERE is_active = TRUE;

-- ---------------------------------------------------------------------------
-- 4. ALTER compliance_reports: Add missing columns for legacy compatibility
-- Some handlers may still use this table directly
-- ---------------------------------------------------------------------------

-- template_id: Which report template was used
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS template_id TEXT;

-- parameters: JSON filter parameters
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS parameters JSONB DEFAULT '{}'::JSONB;

-- progress_percent: Job progress (0-100)
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS progress_percent INTEGER DEFAULT 0 
    CHECK (progress_percent >= 0 AND progress_percent <= 100);

-- completed_at: When the job finished
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;

-- report_number: Auto-generated number
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS report_number TEXT;

-- audit_trail_id: Links to audit_trails
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS audit_trail_id UUID REFERENCES audit_trails(id);

-- error_message: Error details if failed
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS error_message TEXT;

-- file_size_bytes: Size of generated PDF
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;

-- storage_path_csv: CSV export path
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS storage_path_csv TEXT;

-- priority: Job queue priority
ALTER TABLE compliance_reports 
ADD COLUMN IF NOT EXISTS priority INTEGER DEFAULT 5 
    CHECK (priority >= 1 AND priority <= 10);

-- Update status CHECK constraint to include job states
DO $$ BEGIN
    ALTER TABLE compliance_reports 
    DROP CONSTRAINT IF EXISTS compliance_reports_status_check;
EXCEPTION
    WHEN undefined_object THEN NULL;
END $$;

ALTER TABLE compliance_reports 
ADD CONSTRAINT compliance_reports_status_check 
CHECK (status IN ('queued', 'processing', 'ready', 'failed', 'generated', 'archived'));

-- Index for job polling
CREATE INDEX IF NOT EXISTS idx_compliance_reports_job_queue 
ON compliance_reports(status, priority, generated_at) 
WHERE status = 'queued';

-- Index for report number lookup
CREATE UNIQUE INDEX IF NOT EXISTS idx_compliance_reports_number 
ON compliance_reports(report_number) 
WHERE report_number IS NOT NULL;

-- ---------------------------------------------------------------------------
-- 5. INSERT: Default numbering scheme for reports
-- Format: {ORG}-RPT-{YYYY}-{SEQ:5} → ALFA-RPT-2026-00142
-- ---------------------------------------------------------------------------
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
    'report',
    '{ORG}-RPT-{YYYY}-{SEQ:5}',
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
    AND ns.entity_type = 'report'
    AND ns.is_default = TRUE
);

-- ---------------------------------------------------------------------------
-- 6. RLS POLICIES for report_executions (existing table may lack org-based RLS)
-- ---------------------------------------------------------------------------
ALTER TABLE report_executions ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if any (to avoid conflicts)
DROP POLICY IF EXISTS report_executions_select ON report_executions;
DROP POLICY IF EXISTS report_executions_insert ON report_executions;
DROP POLICY IF EXISTS report_executions_update ON report_executions;

-- Select: users see their own org's reports
CREATE POLICY report_executions_select ON report_executions
    FOR SELECT
    USING (
        organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
        OR organization_id IS NULL  -- Allow legacy rows without org_id
    );

-- Insert: users can create reports for their org
CREATE POLICY report_executions_insert ON report_executions
    FOR INSERT
    WITH CHECK (
        organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
        OR organization_id IS NULL
    );

-- Update: service role only (for job processor)
CREATE POLICY report_executions_update ON report_executions
    FOR UPDATE
    USING (
        organization_id = (current_setting('app.current_organization_id', TRUE))::UUID
        OR current_setting('app.is_service_role', TRUE) = 'true'
    );

-- ---------------------------------------------------------------------------
-- 7. COMMENTS
-- ---------------------------------------------------------------------------
COMMENT ON COLUMN report_executions.template_id IS 'Pharma report template identifier from ReportTemplate enum';
COMMENT ON COLUMN report_executions.parameters IS 'Filter parameters passed to report generator';
COMMENT ON COLUMN report_executions.progress_percent IS 'Job progress for polling: 0=queued, 30=data fetched, 80=PDF done, 100=uploaded';
COMMENT ON COLUMN report_executions.priority IS 'Queue priority: 1=urgent (dossier requests), 5=normal, 10=scheduled';
COMMENT ON COLUMN report_executions.report_number IS 'Unique report number from numbering_schemes: ALFA-RPT-2026-00142';
COMMENT ON COLUMN report_executions.audit_trail_id IS '21 CFR Part 11 audit trail link';
COMMENT ON COLUMN scheduled_reports.template_id IS 'Pharma report template to execute on schedule';
COMMENT ON COLUMN scheduled_reports.cron_expression IS 'Standard cron format: minute hour day-of-month month day-of-week';
