-- ===========================================
-- TRAINING SESSIONS AND BATCHES
-- ===========================================

-- Session code sequence — used by generate_session_code() trigger below
-- Format: {PLANT_CODE}-{YYYY}-{SEQ:05}
-- Sequence is global; year is embedded in the code string for readability.
CREATE SEQUENCE IF NOT EXISTS training_session_code_seq START 1;

-- Training Sessions - individual session instances
CREATE TABLE IF NOT EXISTS training_sessions (
    id                    UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id           UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    course_id             UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    question_paper_id     UUID REFERENCES question_papers(id) ON DELETE SET NULL,

    -- Auto-generated code: {PLANT_CODE}-{YYYY}-{00001}  (DS-10)
    session_code          TEXT UNIQUE,

    -- Session classification (URS Alfa §4.2.1.16-21)
    session_type          TEXT NOT NULL DEFAULT 'SCHEDULED'
                              CHECK (session_type IN ('SCHEDULED', 'UNSCHEDULED', 'INTERIM')),
    training_method       TEXT
                              CHECK (training_method IN (
                                  'ILT', 'EXTERNAL', 'BLENDED', 'OJT',
                                  'DOC_READ', 'COMPLETED', 'WBT'
                              )),
    online_offline        TEXT NOT NULL DEFAULT 'OFFLINE'
                              CHECK (online_offline IN ('ONLINE', 'OFFLINE')),

    -- Evaluation (URS Alfa §4.3.14-19)
    evaluation_mode       TEXT CHECK (evaluation_mode IN ('SYSTEM', 'MANUAL')),
    evaluator_id          UUID REFERENCES employees(id) ON DELETE SET NULL,
    missed_q_analysis     BOOLEAN NOT NULL DEFAULT FALSE,

    -- Post-dating (GxP ALCOA+ requirement)
    is_postdated          BOOLEAN NOT NULL DEFAULT FALSE,
    postdated_reason      TEXT,

    -- Plant context (for session_code prefix + RLS)
    plant_id              UUID REFERENCES plants(id) ON DELETE SET NULL,
    organization_id       UUID REFERENCES organizations(id) ON DELETE SET NULL,

    session_number        INTEGER NOT NULL,
    session_date          DATE NOT NULL,
    start_time            TIME NOT NULL,
    end_time              TIME NOT NULL,
    duration_hours        NUMERIC(6,2) NOT NULL,
    venue_id              UUID REFERENCES training_venues(id),
    trainer_id            UUID REFERENCES trainers(id),
    external_trainer_id   UUID REFERENCES external_trainers(id),
    topic_covered         TEXT,
    session_notes         TEXT,
    status                session_status DEFAULT 'scheduled',
    actual_start_time     TIMESTAMPTZ,
    actual_end_time       TIMESTAMPTZ,
    created_at            TIMESTAMPTZ DEFAULT NOW(),
    updated_at            TIMESTAMPTZ DEFAULT NOW(),
    created_by            UUID,
    CONSTRAINT chk_session_time CHECK (end_time > start_time),
    CONSTRAINT chk_postdated_reason CHECK (is_postdated = FALSE OR postdated_reason IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_sessions_schedule     ON training_sessions(schedule_id);
CREATE INDEX IF NOT EXISTS idx_sessions_date         ON training_sessions(session_date);
CREATE INDEX IF NOT EXISTS idx_sessions_status       ON training_sessions(status);
CREATE INDEX IF NOT EXISTS idx_sessions_code         ON training_sessions(session_code);
CREATE INDEX IF NOT EXISTS idx_sessions_type         ON training_sessions(session_type);
CREATE INDEX IF NOT EXISTS idx_sessions_plant        ON training_sessions(plant_id);
CREATE INDEX IF NOT EXISTS idx_sessions_org          ON training_sessions(organization_id);
CREATE INDEX IF NOT EXISTS idx_sessions_evaluator    ON training_sessions(evaluator_id)
    WHERE evaluator_id IS NOT NULL;

DROP TRIGGER IF EXISTS trg_sessions_audit ON training_sessions;
CREATE TRIGGER trg_sessions_audit
    AFTER INSERT OR UPDATE OR DELETE ON training_sessions
    FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- -------------------------------------------------------
-- SESSION CODE AUTO-GENERATION (DS-10)
-- Format: {PLANT_CODE}-{YYYY}-{00001}
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION generate_session_code()
RETURNS TRIGGER AS $$
DECLARE
    v_plant_code TEXT := 'TRN';
    v_year       TEXT := TO_CHAR(NOW(), 'YYYY');
    v_seq        BIGINT;
BEGIN
    -- Look up plant code from plant_id if available
    IF NEW.plant_id IS NOT NULL THEN
        SELECT UPPER(COALESCE(code, 'TRN'))
        INTO v_plant_code
        FROM plants
        WHERE id = NEW.plant_id;
        v_plant_code := COALESCE(v_plant_code, 'TRN');
    ELSIF NEW.organization_id IS NOT NULL THEN
        -- Fall back to abbreviated organization name
        SELECT UPPER(LEFT(REPLACE(name, ' ', ''), 4))
        INTO v_plant_code
        FROM organizations
        WHERE id = NEW.organization_id;
        v_plant_code := COALESCE(v_plant_code, 'TRN');
    END IF;

    v_seq := nextval('training_session_code_seq');
    NEW.session_code := v_plant_code || '-' || v_year || '-' || LPAD(v_seq::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_session_code ON training_sessions;
CREATE TRIGGER trg_session_code
    BEFORE INSERT ON training_sessions
    FOR EACH ROW
    WHEN (NEW.session_code IS NULL)
    EXECUTE FUNCTION generate_session_code();

-- -------------------------------------------------------
-- ALTER: idempotent column additions for existing databases
-- -------------------------------------------------------
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS session_code TEXT;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'SCHEDULED';
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS training_method TEXT;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS online_offline TEXT NOT NULL DEFAULT 'OFFLINE';
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS evaluation_mode TEXT;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS evaluator_id UUID REFERENCES employees(id) ON DELETE SET NULL;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS missed_q_analysis BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS is_postdated BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS postdated_reason TEXT;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS plant_id UUID REFERENCES plants(id) ON DELETE SET NULL;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL;
ALTER TABLE training_sessions ADD COLUMN IF NOT EXISTS created_by UUID;

-- Unique constraint on session_code (idempotent)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints
        WHERE constraint_name = 'training_sessions_session_code_key'
          AND table_name = 'training_sessions'
    ) THEN
        ALTER TABLE training_sessions ADD CONSTRAINT training_sessions_session_code_key UNIQUE (session_code);
    END IF;
END
$$;

COMMENT ON TABLE  training_sessions IS 'Individual training session instances with URS-compliant classification and auto-generated session code';
COMMENT ON COLUMN training_sessions.session_code IS 'Auto-generated code: {PLANT_CODE}-{YYYY}-{SEQ:5} per DS-10';
COMMENT ON COLUMN training_sessions.is_postdated IS 'GxP ALCOA+: session recorded after the actual date — requires postdated_reason';
COMMENT ON COLUMN training_sessions.is_first_in_session IS 'Removed — this belongs to electronic_signatures. See §11.200.';

-- Training Batches - group of trainees
CREATE TABLE IF NOT EXISTS training_batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    max_capacity INTEGER NOT NULL,
    current_count INTEGER DEFAULT 0,
    batch_start_date DATE,
    batch_end_date DATE,
    status TEXT DEFAULT 'open',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_batches_schedule ON training_batches(schedule_id);
CREATE INDEX IF NOT EXISTS idx_batches_status ON training_batches(status);

-- Batch Trainees - employees in a batch
CREATE TABLE IF NOT EXISTS batch_trainees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    batch_id UUID NOT NULL REFERENCES training_batches(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    enrollment_date TIMESTAMPTZ DEFAULT NOW(),
    enrollment_status TEXT DEFAULT 'enrolled',
    completion_status training_completion_status DEFAULT 'not_started',
    completion_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(batch_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_batch_trainees_batch ON batch_trainees(batch_id);
CREATE INDEX IF NOT EXISTS idx_batch_trainees_employee ON batch_trainees(employee_id);
CREATE INDEX IF NOT EXISTS idx_batch_trainees_status ON batch_trainees(completion_status);
