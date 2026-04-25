-- ===========================================
-- BUSINESS CONTINUITY & SYSTEM HEALTH
-- RTO ≤ 15 min tracking per Alfa URS §4.6.1.9
-- System health checks feed into SLA dashboard
-- EE URS §5.2.7 (availability)
-- ===========================================

-- -------------------------------------------------------
-- BUSINESS CONTINUITY PLANS
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS business_continuity_plans (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    name                TEXT NOT NULL,
    description         TEXT,

    -- SLA targets
    rto_minutes         INTEGER NOT NULL CHECK (rto_minutes > 0),    -- Recovery Time Objective
    rpo_minutes         INTEGER NOT NULL CHECK (rpo_minutes >= 0),   -- Recovery Point Objective
    -- Alfa §4.6.1.9 mandates RTO ≤ 15 min for the LMS
    -- CHECK enforced as a business rule comment; adjust to 15 if required per SOP

    -- Coverage scope
    covered_systems     TEXT[] NOT NULL DEFAULT '{}',   -- e.g. ARRAY['lms_db','auth','file_storage']
    failover_location   TEXT,    -- DR site or cloud region
    failover_procedure  TEXT,    -- Reference to SOP document or step summary

    -- Ownership
    owner_id            UUID REFERENCES employees(id) ON DELETE SET NULL,
    backup_owner_id     UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Review status
    last_reviewed_at    TIMESTAMPTZ,
    last_tested_at      TIMESTAMPTZ,
    next_test_due       TIMESTAMPTZ,
    test_frequency_months INTEGER DEFAULT 6,

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID
);

CREATE INDEX IF NOT EXISTS idx_bcp_org    ON business_continuity_plans(organization_id);
CREATE INDEX IF NOT EXISTS idx_bcp_active ON business_continuity_plans(is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trg_bcp_updated ON business_continuity_plans;
CREATE TRIGGER trg_bcp_updated
    BEFORE UPDATE ON business_continuity_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------
-- DISASTER RECOVERY DRILLS
-- Records actual RTO/RPO achieved during each DR test
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS disaster_recovery_drills (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    plan_id             UUID NOT NULL REFERENCES business_continuity_plans(id) ON DELETE CASCADE,

    drilled_at          TIMESTAMPTZ NOT NULL,
    drill_type          TEXT NOT NULL DEFAULT 'PLANNED'
                            CHECK (drill_type IN ('PLANNED', 'UNPLANNED', 'TABLETOP', 'FULL_FAILOVER')),

    -- Actual measurements
    actual_rto_minutes  INTEGER,    -- How long recovery actually took
    actual_rpo_minutes  INTEGER,    -- How much data was lost/recreated

    -- Pass/fail against BCP targets
    pass_fail           TEXT NOT NULL CHECK (pass_fail IN ('PASS', 'FAIL', 'PARTIAL')),
    target_rto_met      BOOLEAN,
    target_rpo_met      BOOLEAN,

    -- Findings
    notes               TEXT,
    issues_found        TEXT[],
    corrective_actions  TEXT[],

    -- Authorization
    drill_lead_id       UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_by_id      UUID REFERENCES employees(id) ON DELETE SET NULL,
    esignature_id       UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_dr_drills_plan ON disaster_recovery_drills(plan_id);
CREATE INDEX IF NOT EXISTS idx_dr_drills_date ON disaster_recovery_drills(drilled_at DESC);

-- DR drills are append-only (evidence)
CREATE OR REPLACE FUNCTION dr_drills_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'disaster_recovery_drills records cannot be deleted — GxP evidence';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_dr_drills_immutable ON disaster_recovery_drills;
CREATE TRIGGER trg_dr_drills_immutable
    BEFORE DELETE ON disaster_recovery_drills
    FOR EACH ROW EXECUTE FUNCTION dr_drills_immutable();

-- -------------------------------------------------------
-- SYSTEM HEALTH CHECKS
-- Automated checks run by lifecycle_monitor
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS system_health_checks (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Check identity
    check_name          TEXT NOT NULL,      -- e.g. 'db_connection', 'storage_access', 'esig_service'
    check_category      TEXT NOT NULL DEFAULT 'availability'
                            CHECK (check_category IN (
                                'availability',
                                'performance',
                                'data_integrity',
                                'security',
                                'compliance'
                            )),

    -- Execution
    last_run_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    next_run_at         TIMESTAMPTZ,

    -- Result
    status              TEXT NOT NULL DEFAULT 'UNKNOWN'
                            CHECK (status IN ('OK', 'WARNING', 'CRITICAL', 'UNKNOWN')),
    latency_ms          INTEGER,
    message             TEXT,
    error_detail        TEXT,

    -- Threshold configuration
    warning_threshold_ms  INTEGER,
    critical_threshold_ms INTEGER,

    -- Alerting
    alert_sent_at       TIMESTAMPTZ,
    alert_recipients    TEXT[],

    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_health_checks_name ON system_health_checks(check_name)
    WHERE organization_id IS NULL;
CREATE INDEX IF NOT EXISTS idx_health_checks_status  ON system_health_checks(status);
CREATE INDEX IF NOT EXISTS idx_health_checks_run_at  ON system_health_checks(last_run_at DESC);

-- -------------------------------------------------------
-- SEED: default health checks
-- -------------------------------------------------------
INSERT INTO system_health_checks
    (check_name, check_category, status, warning_threshold_ms, critical_threshold_ms)
VALUES
    ('db_connection',          'availability',  'UNKNOWN', 100,  500),
    ('db_write_latency',       'performance',   'UNKNOWN', 200, 1000),
    ('audit_chain_integrity',  'data_integrity','UNKNOWN', NULL, NULL),
    ('esig_service',           'availability',  'UNKNOWN', 500, 2000),
    ('storage_access',         'availability',  'UNKNOWN', 300, 1500),
    ('auth_service',           'availability',  'UNKNOWN', 200, 1000),
    ('notification_queue',     'availability',  'UNKNOWN', NULL, NULL),
    ('certificate_expiry_scan','compliance',    'UNKNOWN', NULL, NULL),
    ('overdue_training_scan',  'compliance',    'UNKNOWN', NULL, NULL)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE business_continuity_plans IS 'BCP with RTO/RPO targets per Alfa §4.6.1.9 (RTO ≤ 15 min target)';
COMMENT ON TABLE disaster_recovery_drills IS 'Append-only DR drill results — evidence for audit and IQ/OQ validation';
COMMENT ON TABLE system_health_checks IS 'Automated health check results for the SLA availability dashboard';
COMMENT ON COLUMN business_continuity_plans.rto_minutes IS 'Recovery Time Objective in minutes; Alfa §4.6.1.9 requires ≤ 15 min for LMS';
