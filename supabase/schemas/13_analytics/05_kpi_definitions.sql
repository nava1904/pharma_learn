-- ===========================================
-- KPI DEFINITIONS AND SNAPSHOTS
-- Named KPIs with time-series tracking
-- EE URS §5.1.7, §5.1.18 — graphical progress representation
-- ===========================================

-- KPI Definitions (master list of trackable metrics)
CREATE TABLE IF NOT EXISTS kpi_definitions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Identification
    kpi_code            TEXT NOT NULL,
    kpi_name            TEXT NOT NULL,
    description         TEXT,

    -- Classification
    kpi_category        TEXT NOT NULL CHECK (kpi_category IN (
        'COMPLIANCE', 'TRAINING', 'ASSESSMENT', 'QUALITY', 'EFFICIENCY', 'ENGAGEMENT', 'COST'
    )),
    kpi_type            TEXT NOT NULL CHECK (kpi_type IN (
        'PERCENTAGE', 'COUNT', 'AVERAGE', 'SUM', 'RATIO', 'DURATION'
    )),

    -- Calculation
    calculation_query   TEXT,                   -- SQL or view name to compute this KPI
    calculation_params  JSONB DEFAULT '{}',     -- Parameters for the query
    aggregation_level   TEXT NOT NULL DEFAULT 'ORGANIZATION' CHECK (aggregation_level IN (
        'ORGANIZATION', 'PLANT', 'DEPARTMENT', 'ROLE', 'EMPLOYEE'
    )),

    -- Thresholds for RAG status
    target_value        NUMERIC(10, 2),
    warning_threshold   NUMERIC(10, 2),         -- Below this = amber
    critical_threshold  NUMERIC(10, 2),         -- Below this = red

    -- Display
    display_format      TEXT DEFAULT '{value}%',
    display_order       INTEGER DEFAULT 100,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,

    -- Refresh schedule (for kpi_snapshots)
    refresh_frequency   TEXT DEFAULT 'DAILY' CHECK (refresh_frequency IN (
        'HOURLY', 'DAILY', 'WEEKLY', 'MONTHLY', 'ON_DEMAND'
    )),
    last_refreshed_at   TIMESTAMPTZ,

    -- Audit
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,

    UNIQUE(organization_id, kpi_code)
);

CREATE INDEX IF NOT EXISTS idx_kpi_defs_org ON kpi_definitions(organization_id);
CREATE INDEX IF NOT EXISTS idx_kpi_defs_category ON kpi_definitions(kpi_category);
CREATE INDEX IF NOT EXISTS idx_kpi_defs_active ON kpi_definitions(is_active) WHERE is_active = TRUE;

-- KPI Snapshots (time-series storage — no UPDATE, append-only)
CREATE TABLE IF NOT EXISTS kpi_snapshots (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kpi_definition_id   UUID NOT NULL REFERENCES kpi_definitions(id) ON DELETE CASCADE,

    -- Scope (which entity this snapshot is for)
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,
    department_id       UUID REFERENCES departments(id) ON DELETE CASCADE,
    role_id             UUID REFERENCES roles(id) ON DELETE CASCADE,
    employee_id         UUID REFERENCES employees(id) ON DELETE CASCADE,

    -- Time dimension
    snapshot_date       DATE NOT NULL,
    snapshot_period     TEXT NOT NULL DEFAULT 'DAY' CHECK (snapshot_period IN (
        'DAY', 'WEEK', 'MONTH', 'QUARTER', 'YEAR'
    )),

    -- Value
    value               NUMERIC(12, 4) NOT NULL,
    numerator           NUMERIC(12, 4),         -- For ratio/percentage KPIs
    denominator         NUMERIC(12, 4),

    -- RAG status
    rag_status          TEXT CHECK (rag_status IN ('GREEN', 'AMBER', 'RED')),
    vs_target_percent   NUMERIC(8, 2),          -- (value / target) * 100

    -- Metadata
    calculation_details JSONB,                  -- Breakdown of how value was computed
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(kpi_definition_id, organization_id, COALESCE(plant_id, '00000000-0000-0000-0000-000000000000'::UUID),
           COALESCE(department_id, '00000000-0000-0000-0000-000000000000'::UUID),
           COALESCE(role_id, '00000000-0000-0000-0000-000000000000'::UUID),
           COALESCE(employee_id, '00000000-0000-0000-0000-000000000000'::UUID),
           snapshot_date, snapshot_period)
);

CREATE INDEX IF NOT EXISTS idx_kpi_snap_def ON kpi_snapshots(kpi_definition_id);
CREATE INDEX IF NOT EXISTS idx_kpi_snap_org ON kpi_snapshots(organization_id);
CREATE INDEX IF NOT EXISTS idx_kpi_snap_plant ON kpi_snapshots(plant_id) WHERE plant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_kpi_snap_date ON kpi_snapshots(snapshot_date DESC);
CREATE INDEX IF NOT EXISTS idx_kpi_snap_period ON kpi_snapshots(snapshot_period, snapshot_date);

-- Immutability rule for snapshots (append-only — no updates or deletes)
CREATE OR REPLACE FUNCTION kpi_snapshot_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'KPI snapshots are append-only and cannot be modified';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'KPI snapshots cannot be deleted';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_kpi_snapshot_immutable ON kpi_snapshots;
CREATE TRIGGER trg_kpi_snapshot_immutable
    BEFORE UPDATE OR DELETE ON kpi_snapshots
    FOR EACH ROW EXECUTE FUNCTION kpi_snapshot_immutable();

-- -------------------------------------------------------
-- SEED: Core compliance and training KPIs
-- -------------------------------------------------------
INSERT INTO kpi_definitions
    (organization_id, kpi_code, kpi_name, description, kpi_category, kpi_type,
     aggregation_level, target_value, warning_threshold, critical_threshold,
     display_format, display_order, refresh_frequency)
VALUES
    -- Use a placeholder org; real seeds should use actual org_id
    ('00000000-0000-0000-0000-000000000001'::UUID,
     'COMPLIANCE_RATE', 'Training Compliance Rate',
     'Percentage of employees with all mandatory training complete and not overdue',
     'COMPLIANCE', 'PERCENTAGE', 'ORGANIZATION', 100.00, 90.00, 80.00, '{value}%', 10, 'DAILY'),

    ('00000000-0000-0000-0000-000000000001'::UUID,
     'OVERDUE_COUNT', 'Overdue Training Count',
     'Number of training obligations past due date',
     'COMPLIANCE', 'COUNT', 'ORGANIZATION', 0, 10, 50, '{value}', 20, 'DAILY'),

    ('00000000-0000-0000-0000-000000000001'::UUID,
     'FIRST_ATTEMPT_PASS', 'First Attempt Pass Rate',
     'Percentage of assessments passed on first attempt',
     'ASSESSMENT', 'PERCENTAGE', 'ORGANIZATION', 95.00, 85.00, 75.00, '{value}%', 30, 'DAILY'),

    ('00000000-0000-0000-0000-000000000001'::UUID,
     'AVG_COMPLETION_DAYS', 'Average Training Completion Days',
     'Average days from assignment to completion',
     'EFFICIENCY', 'AVERAGE', 'ORGANIZATION', 7, 14, 30, '{value} days', 40, 'WEEKLY'),

    ('00000000-0000-0000-0000-000000000001'::UUID,
     'INDUCTION_COMPLETION', 'Induction Completion Rate',
     'Percentage of new hires with completed induction',
     'TRAINING', 'PERCENTAGE', 'ORGANIZATION', 100.00, 95.00, 90.00, '{value}%', 50, 'DAILY')
ON CONFLICT DO NOTHING;

COMMENT ON TABLE kpi_definitions IS 'Named, configurable KPIs for compliance and training analytics per EE §5.1.7';
COMMENT ON TABLE kpi_snapshots IS 'Time-series storage of KPI values — append-only for trend analysis';
COMMENT ON COLUMN kpi_definitions.calculation_query IS 'SQL query or view name used by lifecycle_monitor to compute this KPI';
COMMENT ON COLUMN kpi_snapshots.rag_status IS 'RED/AMBER/GREEN status based on thresholds in kpi_definitions';
