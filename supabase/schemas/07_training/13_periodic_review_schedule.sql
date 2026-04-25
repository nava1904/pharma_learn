-- ===========================================
-- PERIODIC REVIEW SCHEDULE
-- Periodic review of training materials
-- Alfa URS §4.4.8: "periodic review of training materials"
-- EE URS §5.1.18 (content currency), §5.4.4 (document version review)
-- ===========================================

CREATE TABLE IF NOT EXISTS periodic_review_schedules (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- What needs to be periodically reviewed
    entity_type             TEXT NOT NULL
                                CHECK (entity_type IN (
                                    'course',
                                    'document',
                                    'gtp',
                                    'training_matrix',
                                    'curriculum',
                                    'assessment_question_paper',
                                    'job_responsibility'
                                )),
    entity_id               UUID NOT NULL,
    entity_name             TEXT NOT NULL,   -- denormalized for display without joins

    -- Review cadence
    review_interval_months  INTEGER NOT NULL DEFAULT 12 CHECK (review_interval_months > 0),

    -- Review history
    last_reviewed_at        TIMESTAMPTZ,
    last_reviewed_by        UUID REFERENCES employees(id) ON DELETE SET NULL,
    last_review_outcome     TEXT
                                CHECK (last_review_outcome IN (
                                    'NO_CHANGE',        -- Content reviewed; no updates needed
                                    'MINOR_UPDATE',     -- Reviewed and minor corrections made
                                    'MAJOR_REVISION',   -- Reviewed and significant revision initiated
                                    'WITHDRAWN',        -- Content withdrawn from active use
                                    'DEFERRED'          -- Review deferred with reason
                                )),
    last_review_notes       TEXT,

    -- Next review due
    next_review_due         TIMESTAMPTZ NOT NULL,

    -- Review assignment
    reviewer_role_id        UUID REFERENCES roles(id) ON DELETE SET NULL,
    assigned_reviewer_id    UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Status
    status                  TEXT NOT NULL DEFAULT 'PENDING'
                                CHECK (status IN (
                                    'PENDING',    -- Due for review but not yet started
                                    'IN_REVIEW',  -- Review in progress
                                    'COMPLETED',  -- Review completed
                                    'OVERDUE'     -- Past due date; escalation triggered
                                )),

    -- Overdue escalation
    escalation_sent_at      TIMESTAMPTZ,   -- When the overdue notification was sent
    escalation_sent_to      UUID REFERENCES employees(id) ON DELETE SET NULL,

    -- Scope
    organization_id         UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id                UUID REFERENCES plants(id) ON DELETE CASCADE,

    -- Timestamps
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by              UUID
);

CREATE INDEX IF NOT EXISTS idx_periodic_review_entity  ON periodic_review_schedules(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_periodic_review_due     ON periodic_review_schedules(next_review_due ASC);
CREATE INDEX IF NOT EXISTS idx_periodic_review_status  ON periodic_review_schedules(status);
CREATE INDEX IF NOT EXISTS idx_periodic_review_org     ON periodic_review_schedules(organization_id);
CREATE INDEX IF NOT EXISTS idx_periodic_review_overdue ON periodic_review_schedules(next_review_due)
    WHERE status IN ('PENDING', 'OVERDUE');

DROP TRIGGER IF EXISTS trg_periodic_review_updated ON periodic_review_schedules;
CREATE TRIGGER trg_periodic_review_updated
    BEFORE UPDATE ON periodic_review_schedules
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS trg_periodic_review_audit ON periodic_review_schedules;
CREATE TRIGGER trg_periodic_review_audit
    AFTER INSERT OR UPDATE OR DELETE ON periodic_review_schedules
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- PERIODIC REVIEW LOG
-- Immutable record of each completed review event
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS periodic_review_log (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    schedule_id             UUID NOT NULL REFERENCES periodic_review_schedules(id) ON DELETE CASCADE,
    reviewed_by             UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    reviewed_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    outcome                 TEXT NOT NULL
                                CHECK (outcome IN (
                                    'NO_CHANGE','MINOR_UPDATE','MAJOR_REVISION','WITHDRAWN','DEFERRED'
                                )),
    notes                   TEXT,
    action_taken            TEXT,   -- Specific actions taken as result of review

    -- E-signature (review must be signed per GxP)
    esignature_id           UUID REFERENCES electronic_signatures(id) ON DELETE RESTRICT,

    -- The next review date set by THIS review (may differ from the standard cadence)
    next_review_due         TIMESTAMPTZ NOT NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Review log is append-only
CREATE OR REPLACE FUNCTION periodic_review_log_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'periodic_review_log is append-only — GxP ALCOA+ endurance requirement';
    END IF;
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'periodic_review_log records are immutable after creation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_review_log_immutable ON periodic_review_log;
CREATE TRIGGER trg_review_log_immutable
    BEFORE UPDATE OR DELETE ON periodic_review_log
    FOR EACH ROW EXECUTE FUNCTION periodic_review_log_immutable();

CREATE INDEX IF NOT EXISTS idx_review_log_schedule ON periodic_review_log(schedule_id);
CREATE INDEX IF NOT EXISTS idx_review_log_reviewed  ON periodic_review_log(reviewed_at DESC);

-- -------------------------------------------------------
-- FUNCTION: mark a review complete and advance the schedule
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION complete_periodic_review(
    p_schedule_id   UUID,
    p_reviewer_id   UUID,
    p_outcome       TEXT,
    p_notes         TEXT DEFAULT NULL,
    p_esig_id       UUID DEFAULT NULL,
    p_next_due_override TIMESTAMPTZ DEFAULT NULL   -- Override calculated next due date
) RETURNS UUID AS $$
DECLARE
    v_schedule  periodic_review_schedules%ROWTYPE;
    v_log_id    UUID;
    v_next_due  TIMESTAMPTZ;
BEGIN
    SELECT * INTO v_schedule FROM periodic_review_schedules WHERE id = p_schedule_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Periodic review schedule not found: %', p_schedule_id;
    END IF;

    -- Calculate next review date
    v_next_due := COALESCE(
        p_next_due_override,
        NOW() + (v_schedule.review_interval_months || ' months')::INTERVAL
    );

    -- Insert log entry
    INSERT INTO periodic_review_log
        (schedule_id, reviewed_by, outcome, notes, esignature_id, next_review_due)
    VALUES
        (p_schedule_id, p_reviewer_id, p_outcome, p_notes, p_esig_id, v_next_due)
    RETURNING id INTO v_log_id;

    -- Advance the schedule
    UPDATE periodic_review_schedules
    SET status             = 'COMPLETED',
        last_reviewed_at   = NOW(),
        last_reviewed_by   = p_reviewer_id,
        last_review_outcome = p_outcome,
        last_review_notes  = p_notes,
        next_review_due    = v_next_due,
        updated_at         = NOW()
    WHERE id = p_schedule_id;

    RETURN v_log_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- -------------------------------------------------------
-- FUNCTION: mark overdue reviews (called by lifecycle_monitor cron)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION mark_overdue_reviews() RETURNS INTEGER AS $$
DECLARE
    v_updated INTEGER;
BEGIN
    UPDATE periodic_review_schedules
    SET status     = 'OVERDUE',
        updated_at = NOW()
    WHERE status          = 'PENDING'
      AND next_review_due < NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE  periodic_review_schedules IS 'Periodic review scheduling per entity type (Alfa §4.4.8)';
COMMENT ON TABLE  periodic_review_log IS 'Immutable record of every completed periodic review with e-signature';
COMMENT ON COLUMN periodic_review_schedules.review_interval_months IS 'How often this content must be reviewed (typical GMP: 12-24 months)';
COMMENT ON COLUMN periodic_review_log.esignature_id IS 'GxP: review completion must be e-signed by the reviewer';
COMMENT ON FUNCTION complete_periodic_review IS 'Mark a review complete, log the outcome, and advance next_review_due';
COMMENT ON FUNCTION mark_overdue_reviews IS 'Called by lifecycle_monitor cron to flag reviews past their due date';
