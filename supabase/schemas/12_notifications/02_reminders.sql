-- ===========================================
-- REMINDERS AND ESCALATIONS
-- ===========================================

-- Reminder Rules
CREATE TABLE IF NOT EXISTS reminder_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    reminder_type TEXT NOT NULL,
    trigger_event TEXT NOT NULL,
    days_before_due JSONB NOT NULL,
    notification_template_id UUID REFERENCES notification_templates(id),
    channels JSONB DEFAULT '["email", "in_app"]',
    recipient_type TEXT NOT NULL,
    include_supervisor BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_reminder_rules_org ON reminder_rules(organization_id);
CREATE INDEX IF NOT EXISTS idx_reminder_rules_type ON reminder_rules(reminder_type);

-- Scheduled Reminders
CREATE TABLE IF NOT EXISTS scheduled_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_id UUID NOT NULL REFERENCES reminder_rules(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    scheduled_date DATE NOT NULL,
    status TEXT DEFAULT 'scheduled',
    sent_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(rule_id, entity_type, entity_id, employee_id, scheduled_date)
);

CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_date ON scheduled_reminders(scheduled_date);
CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_status ON scheduled_reminders(status);
CREATE INDEX IF NOT EXISTS idx_scheduled_reminders_employee ON scheduled_reminders(employee_id);

-- Escalation Rules
CREATE TABLE IF NOT EXISTS escalation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    escalation_type TEXT NOT NULL,
    trigger_event TEXT NOT NULL,
    levels JSONB NOT NULL,
    notification_template_id UUID REFERENCES notification_templates(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_escalation_rules_org ON escalation_rules(organization_id);
CREATE INDEX IF NOT EXISTS idx_escalation_rules_type ON escalation_rules(escalation_type);

-- Active Escalations
CREATE TABLE IF NOT EXISTS active_escalations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_id UUID NOT NULL REFERENCES escalation_rules(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    employee_id UUID REFERENCES employees(id),
    current_level INTEGER DEFAULT 1,
    escalated_to JSONB DEFAULT '[]',
    started_at TIMESTAMPTZ DEFAULT NOW(),
    last_escalation_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    resolution_notes TEXT,
    status TEXT DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_active_escalations_status ON active_escalations(status);
CREATE INDEX IF NOT EXISTS idx_active_escalations_entity ON active_escalations(entity_type, entity_id);

-- Escalation History
CREATE TABLE IF NOT EXISTS escalation_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    escalation_id UUID NOT NULL REFERENCES active_escalations(id) ON DELETE CASCADE,
    level INTEGER NOT NULL,
    escalated_to UUID NOT NULL,
    escalated_at TIMESTAMPTZ DEFAULT NOW(),
    notification_sent BOOLEAN DEFAULT false,
    notification_id UUID REFERENCES notification_log(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_escalation_history_escalation ON escalation_history(escalation_id);
