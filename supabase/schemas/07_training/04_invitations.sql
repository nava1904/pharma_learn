-- ===========================================
-- TRAINING INVITATIONS AND NOMINATIONS
-- ===========================================

-- Training Invitations - sent to employees
CREATE TABLE IF NOT EXISTS training_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    batch_id UUID REFERENCES training_batches(id) ON DELETE SET NULL,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    invited_by UUID NOT NULL,
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    invitation_type TEXT DEFAULT 'manual',
    response_status invitation_response DEFAULT 'pending',
    responded_at TIMESTAMPTZ,
    response_comments TEXT,
    reminder_sent_count INTEGER DEFAULT 0,
    last_reminder_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_invitations_schedule ON training_invitations(schedule_id);
CREATE INDEX IF NOT EXISTS idx_invitations_employee ON training_invitations(employee_id);
CREATE INDEX IF NOT EXISTS idx_invitations_status ON training_invitations(response_status);

DROP TRIGGER IF EXISTS trg_invitations_audit ON training_invitations;
CREATE TRIGGER trg_invitations_audit AFTER INSERT OR UPDATE OR DELETE ON training_invitations FOR EACH ROW EXECUTE FUNCTION track_entity_changes();

-- Training Nominations - supervisor nominations
CREATE TABLE IF NOT EXISTS training_nominations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    nominated_by UUID NOT NULL,
    nominated_at TIMESTAMPTZ DEFAULT NOW(),
    nomination_reason TEXT,
    approval_status workflow_state DEFAULT 'pending_approval',
    approved_by UUID,
    approved_at TIMESTAMPTZ,
    approval_comments TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(schedule_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_nominations_schedule ON training_nominations(schedule_id);
CREATE INDEX IF NOT EXISTS idx_nominations_employee ON training_nominations(employee_id);
CREATE INDEX IF NOT EXISTS idx_nominations_status ON training_nominations(approval_status);

-- Waitlist entries
CREATE TABLE IF NOT EXISTS training_waitlist (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES training_schedules(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ DEFAULT NOW(),
    position INTEGER NOT NULL,
    auto_enroll BOOLEAN DEFAULT true,
    notified_at TIMESTAMPTZ,
    status TEXT DEFAULT 'waiting',
    UNIQUE(schedule_id, employee_id)
);

CREATE INDEX IF NOT EXISTS idx_waitlist_schedule ON training_waitlist(schedule_id);
CREATE INDEX IF NOT EXISTS idx_waitlist_position ON training_waitlist(schedule_id, position);
