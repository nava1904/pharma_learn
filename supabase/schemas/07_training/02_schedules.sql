-- ===========================================
-- TRAINING SCHEDULES
-- ===========================================

-- Training Schedules - master schedule planning
CREATE TABLE IF NOT EXISTS training_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    gtp_id UUID REFERENCES gtp_masters(id) ON DELETE SET NULL,
    course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
    schedule_category schedule_type NOT NULL DEFAULT 'planned',
    training_type training_type NOT NULL DEFAULT 'initial',
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    total_duration_hours NUMERIC(6,2),
    max_participants INTEGER,
    venue_id UUID REFERENCES training_venues(id),
    status workflow_state DEFAULT 'draft',
    initiated_by UUID,
    initiated_at TIMESTAMPTZ,
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    created_by UUID,
    UNIQUE(organization_id, unique_code),
    CONSTRAINT chk_schedule_dates CHECK (end_date >= start_date),
    CONSTRAINT chk_schedule_type CHECK (gtp_id IS NOT NULL OR course_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_schedules_org ON training_schedules(organization_id);
CREATE INDEX IF NOT EXISTS idx_schedules_gtp ON training_schedules(gtp_id);
CREATE INDEX IF NOT EXISTS idx_schedules_course ON training_schedules(course_id);
CREATE INDEX IF NOT EXISTS idx_schedules_dates ON training_schedules(start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_schedules_status ON training_schedules(status);

DROP TRIGGER IF EXISTS trg_schedules_audit ON training_schedules;
CREATE TRIGGER trg_schedules_audit AFTER INSERT OR UPDATE OR DELETE ON training_schedules FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Schedule Trainers
CREATE TABLE IF NOT EXISTS schedule_trainers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES trainers(id) ON DELETE SET NULL,
    external_trainer_id UUID REFERENCES external_trainers(id) ON DELETE SET NULL,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT chk_trainer_type CHECK (trainer_id IS NOT NULL OR external_trainer_id IS NOT NULL)
);

-- Schedule Courses (for GTP-based schedules)
CREATE TABLE IF NOT EXISTS schedule_courses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    sequence_number INTEGER DEFAULT 1,
    scheduled_date DATE,
    duration_hours NUMERIC(6,2),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, course_id)
);
