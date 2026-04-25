-- ===========================================
-- BUSINESS CONTINUITY AND DISASTER RECOVERY
-- RTO/RPO tracking per Alfa URS §4.6.1.9-10
-- ===========================================

-- Business Continuity Plans
CREATE TABLE IF NOT EXISTS business_continuity_plans (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,

    -- Plan identification
    plan_code               TEXT NOT NULL,
    plan_name               TEXT NOT NULL,
    description             TEXT,
    plan_type               TEXT NOT NULL CHECK (plan_type IN (
        'DISASTER_RECOVERY', 'BUSINESS_CONTINUITY', 'INCIDENT_RESPONSE', 'BACKUP_RESTORE'
    )),

    -- RTO/RPO targets (Alfa §4.6.1.9 — RTO ≤15 min)
    rto_minutes             INTEGER NOT NULL DEFAULT 15,    -- Recovery Time Objective
    rpo_minutes             INTEGER NOT NULL DEFAULT 5,     -- Recovery Point Objective

    -- Plan details
    document_url            TEXT,                           -- Link to full plan document
    procedures              JSONB DEFAULT '[]',             -- Step-by-step procedures
    contacts                JSONB DEFAULT '[]',             -- Emergency contacts

    -- Ownership
    owner_id                UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    backup_owner_id         UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Review schedule
    review_frequency_months INTEGER DEFAULT 12,
    last_reviewed_at        TIMESTAMPTZ,
    next_review_due         DATE,
    reviewed_by             UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Testing
    last_tested_at          TIMESTAMPTZ,
    last_test_result        TEXT CHECK (last_test_result IN ('PASS', 'FAIL', 'PARTIAL')),
    test_frequency_months   INTEGER DEFAULT 6,
    next_test_due           DATE,

    -- Status
    status                  TEXT NOT NULL DEFAULT 'DRAFT' CHECK (status IN (
        'DRAFT', 'ACTIVE', 'UNDER_REVIEW', 'RETIRED'
    )),
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,

    -- Workflow
    workflow_status         workflow_state DEFAULT 'draft',
    approved_by             UUID REFERENCES employees(id) ON DELETE SET NULL,
    approved_at             TIMESTAMPTZ,
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID,

    UNIQUE(organization_id, plan_code)
);

CREATE INDEX IF NOT EXISTS idx_bcp_org ON business_continuity_plans(organization_id);
CREATE INDEX IF NOT EXISTS idx_bcp_plant ON business_continuity_plans(plant_id) WHERE plant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bcp_status ON business_continuity_plans(status);
CREATE INDEX IF NOT EXISTS idx_bcp_active ON business_continuity_plans(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_bcp_next_review ON business_continuity_plans(next_review_due);
CREATE INDEX IF NOT EXISTS idx_bcp_next_test ON business_continuity_plans(next_test_due);

-- Trigger for audit
DROP TRIGGER IF EXISTS trg_bcp_audit ON business_continuity_plans;
CREATE TRIGGER trg_bcp_audit
    AFTER INSERT OR UPDATE OR DELETE ON business_continuity_plans
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- DISASTER RECOVERY DRILLS
-- Test execution and results tracking
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS disaster_recovery_drills (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    plan_id                 UUID NOT NULL REFERENCES business_continuity_plans(id) ON DELETE CASCADE,
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,

    -- Drill identification
    drill_code              TEXT NOT NULL,
    drill_name              TEXT NOT NULL,
    drill_type              TEXT NOT NULL CHECK (drill_type IN (
        'TABLETOP', 'SIMULATION', 'FULL_SCALE', 'PARTIAL', 'UNANNOUNCED'
    )),

    -- Timing
    scheduled_at            TIMESTAMPTZ NOT NULL,
    started_at              TIMESTAMPTZ,
    completed_at            TIMESTAMPTZ,

    -- Results
    status                  TEXT NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN (
        'SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'POSTPONED'
    )),
    result                  TEXT CHECK (result IN ('PASS', 'FAIL', 'PARTIAL', 'INCONCLUSIVE')),

    -- Metrics
    actual_rto_minutes      INTEGER,                        -- Actual recovery time achieved
    actual_rpo_minutes      INTEGER,                        -- Actual data loss measured
    rto_met                 BOOLEAN,                        -- Did we meet the target RTO?
    rpo_met                 BOOLEAN,

    -- Documentation
    scope_description       TEXT,
    findings                JSONB DEFAULT '[]',
    recommendations         JSONB DEFAULT '[]',
    lessons_learned         TEXT,
    evidence_attachments    JSONB DEFAULT '[]',

    -- Participants
    led_by                  UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    participants            UUID[] DEFAULT '{}',
    observers               UUID[] DEFAULT '{}',

    -- Follow-up
    action_items            JSONB DEFAULT '[]',
    next_drill_date         DATE,

    -- Approval
    reviewed_by             UUID REFERENCES employees(id) ON DELETE SET NULL,
    reviewed_at             TIMESTAMPTZ,
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID
);

CREATE INDEX IF NOT EXISTS idx_drills_plan ON disaster_recovery_drills(plan_id);
CREATE INDEX IF NOT EXISTS idx_drills_org ON disaster_recovery_drills(organization_id);
CREATE INDEX IF NOT EXISTS idx_drills_status ON disaster_recovery_drills(status);
CREATE INDEX IF NOT EXISTS idx_drills_scheduled ON disaster_recovery_drills(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_drills_result ON disaster_recovery_drills(result);

-- Trigger for audit
DROP TRIGGER IF EXISTS trg_drills_audit ON disaster_recovery_drills;
CREATE TRIGGER trg_drills_audit
    AFTER INSERT OR UPDATE OR DELETE ON disaster_recovery_drills
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- SYSTEM HEALTH CHECKS
-- Continuous monitoring for SLA dashboard
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS system_health_checks (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Check identification
    check_name              TEXT NOT NULL,
    check_type              TEXT NOT NULL CHECK (check_type IN (
        'DATABASE', 'API', 'STORAGE', 'AUTH', 'INTEGRATION', 'CRON', 'NETWORK'
    )),
    check_endpoint          TEXT,                           -- URL or connection string being checked

    -- Timing
    last_run_at             TIMESTAMPTZ,
    next_run_at             TIMESTAMPTZ,
    check_interval_seconds  INTEGER NOT NULL DEFAULT 60,

    -- Results
    status                  TEXT NOT NULL DEFAULT 'UNKNOWN' CHECK (status IN (
        'HEALTHY', 'DEGRADED', 'UNHEALTHY', 'UNKNOWN'
    )),
    latency_ms              INTEGER,
    response_code           INTEGER,
    response_body           TEXT,
    error_message           TEXT,
    error_count             INTEGER DEFAULT 0,              -- Consecutive errors

    -- Thresholds
    latency_warning_ms      INTEGER DEFAULT 1000,
    latency_critical_ms     INTEGER DEFAULT 5000,
    error_threshold         INTEGER DEFAULT 3,              -- Consecutive errors before alert

    -- Metadata
    metadata                JSONB DEFAULT '{}',
    tags                    TEXT[] DEFAULT '{}',

    -- Status
    is_active               BOOLEAN NOT NULL DEFAULT TRUE,
    is_critical             BOOLEAN NOT NULL DEFAULT FALSE, -- Critical checks trigger immediate alerts

    -- Audit
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_health_checks_type ON system_health_checks(check_type);
CREATE INDEX IF NOT EXISTS idx_health_checks_status ON system_health_checks(status);
CREATE INDEX IF NOT EXISTS idx_health_checks_active ON system_health_checks(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_health_checks_critical ON system_health_checks(is_critical) WHERE is_critical = TRUE;
CREATE INDEX IF NOT EXISTS idx_health_checks_next ON system_health_checks(next_run_at);

-- -------------------------------------------------------
-- SYSTEM HEALTH HISTORY
-- Time-series storage for trending
-- -------------------------------------------------------

CREATE TABLE IF NOT EXISTS system_health_history (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    check_id                UUID NOT NULL REFERENCES system_health_checks(id) ON DELETE CASCADE,

    -- Metrics
    checked_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    status                  TEXT NOT NULL,
    latency_ms              INTEGER,
    response_code           INTEGER,
    error_message           TEXT,

    -- Partition key for time-series
    partition_key           DATE NOT NULL DEFAULT CURRENT_DATE
);

CREATE INDEX IF NOT EXISTS idx_health_history_check ON system_health_history(check_id);
CREATE INDEX IF NOT EXISTS idx_health_history_time ON system_health_history(checked_at DESC);
CREATE INDEX IF NOT EXISTS idx_health_history_partition ON system_health_history(partition_key);

-- Immutability for health history (append-only)
CREATE OR REPLACE FUNCTION health_history_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'System health history is append-only and cannot be modified';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_health_history_immutable ON system_health_history;
CREATE TRIGGER trg_health_history_immutable
    BEFORE UPDATE OR DELETE ON system_health_history
    FOR EACH ROW EXECUTE FUNCTION health_history_immutable();

-- -------------------------------------------------------
-- SEED: Default health checks
-- -------------------------------------------------------

INSERT INTO system_health_checks
    (check_name, check_type, check_interval_seconds, latency_warning_ms, latency_critical_ms, is_critical)
VALUES
    ('Database Connection', 'DATABASE', 30, 100, 500, TRUE),
    ('Auth Service', 'AUTH', 60, 200, 1000, TRUE),
    ('Storage Service', 'STORAGE', 120, 500, 2000, FALSE),
    ('API Gateway', 'API', 60, 200, 1000, TRUE),
    ('Cron Jobs', 'CRON', 300, 1000, 5000, FALSE)
ON CONFLICT DO NOTHING;

COMMENT ON TABLE business_continuity_plans IS 'BCP/DR plans with RTO/RPO targets per Alfa §4.6.1.9';
COMMENT ON TABLE disaster_recovery_drills IS 'DR drill execution and results tracking';
COMMENT ON TABLE system_health_checks IS 'Continuous health monitoring configuration';
COMMENT ON TABLE system_health_history IS 'Time-series health check results for SLA dashboard';
COMMENT ON COLUMN business_continuity_plans.rto_minutes IS 'Recovery Time Objective — Alfa §4.6.1.9 target is ≤15 min';
