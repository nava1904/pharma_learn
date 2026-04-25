-- ===========================================
-- TRAINING ATTENDANCE
-- ===========================================

-- Session Attendance - detailed attendance per session
CREATE TABLE IF NOT EXISTS session_attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES training_sessions(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    esignature_id UUID REFERENCES electronic_signatures(id) ON DELETE SET NULL,
    attendance_status attendance_status NOT NULL DEFAULT 'present',
    check_in_time TIMESTAMPTZ,
    check_out_time TIMESTAMPTZ,
    attendance_hours NUMERIC(6,2),
    marked_by UUID,
    marked_at TIMESTAMPTZ DEFAULT NOW(),
    biometric_verified BOOLEAN DEFAULT false,
    biometric_reference TEXT,
    remarks TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_session ON session_attendance(session_id);
CREATE INDEX IF NOT EXISTS idx_attendance_employee ON session_attendance(employee_id);
CREATE INDEX IF NOT EXISTS idx_attendance_status ON session_attendance(attendance_status);

DROP TRIGGER IF EXISTS trg_attendance_audit ON session_attendance;
CREATE TRIGGER trg_attendance_audit AFTER INSERT OR UPDATE OR DELETE ON session_attendance FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Daily Attendance Summary
CREATE TABLE IF NOT EXISTS daily_attendance_summary (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    attendance_date DATE NOT NULL,
    total_sessions INTEGER DEFAULT 0,
    attended_sessions INTEGER DEFAULT 0,
    total_hours NUMERIC(6,2) DEFAULT 0,
    attended_hours NUMERIC(6,2) DEFAULT 0,
    attendance_percentage NUMERIC(5,2) DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id, attendance_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_attendance_schedule ON daily_attendance_summary(schedule_id);
CREATE INDEX IF NOT EXISTS idx_daily_attendance_date ON daily_attendance_summary(attendance_date);

-- Training Attendance Percentage
CREATE TABLE IF NOT EXISTS training_attendance_totals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    total_sessions INTEGER DEFAULT 0,
    attended_sessions INTEGER DEFAULT 0,
    total_hours NUMERIC(6,2) DEFAULT 0,
    attended_hours NUMERIC(6,2) DEFAULT 0,
    attendance_percentage NUMERIC(5,2) DEFAULT 0,
    meets_minimum_requirement BOOLEAN DEFAULT false,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_attendance_totals_schedule ON training_attendance_totals(schedule_id);
CREATE INDEX IF NOT EXISTS idx_attendance_totals_employee ON training_attendance_totals(employee_id);
