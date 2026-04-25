-- ===========================================
-- NOTIFICATION SYSTEM
-- ===========================================

-- Notification Templates
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    notification_type notification_type NOT NULL,
    channel notification_channel NOT NULL,
    subject_template TEXT,
    body_template TEXT NOT NULL,
    html_template TEXT,
    variables JSONB DEFAULT '[]',
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_notif_templates_org ON notification_templates(organization_id);
CREATE INDEX IF NOT EXISTS idx_notif_templates_type ON notification_templates(notification_type);

-- Notification Queue
CREATE TABLE IF NOT EXISTS notification_queue (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    template_id UUID REFERENCES notification_templates(id),
    notification_type notification_type NOT NULL,
    channel notification_channel NOT NULL,
    recipient_id UUID REFERENCES employees(id),
    recipient_email TEXT,
    recipient_phone TEXT,
    recipient_device_token TEXT,
    subject TEXT,
    body TEXT NOT NULL,
    html_body TEXT,
    variables_data JSONB,
    priority INTEGER DEFAULT 5,
    scheduled_at TIMESTAMPTZ,
    status notification_status DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    last_error TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_queue_status ON notification_queue(status);
CREATE INDEX IF NOT EXISTS idx_notif_queue_scheduled ON notification_queue(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_notif_queue_recipient ON notification_queue(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notif_queue_priority ON notification_queue(priority);

-- Notification Log (sent notifications)
CREATE TABLE IF NOT EXISTS notification_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    queue_id UUID REFERENCES notification_queue(id),
    organization_id UUID NOT NULL,
    template_id UUID,
    notification_type notification_type NOT NULL,
    channel notification_channel NOT NULL,
    recipient_id UUID,
    recipient_address TEXT,
    subject TEXT,
    body_preview TEXT,
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    delivered_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    clicked_at TIMESTAMPTZ,
    status TEXT NOT NULL,
    provider_response JSONB,
    message_id TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notif_log_recipient ON notification_log(recipient_id);
CREATE INDEX IF NOT EXISTS idx_notif_log_type ON notification_log(notification_type);
CREATE INDEX IF NOT EXISTS idx_notif_log_sent ON notification_log(sent_at);
CREATE INDEX IF NOT EXISTS idx_notif_log_status ON notification_log(status);

-- User Notifications (in-app)
CREATE TABLE IF NOT EXISTS user_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES global_profiles(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id),
    notification_type notification_type NOT NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    action_url TEXT,
    action_data JSONB,
    icon TEXT,
    priority INTEGER DEFAULT 5,
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMPTZ,
    is_dismissed BOOLEAN DEFAULT false,
    dismissed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_user_notif_user ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notif_read ON user_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_user_notif_created ON user_notifications(created_at);

-- Notification Preferences
CREATE TABLE IF NOT EXISTS notification_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES global_profiles(id) ON DELETE CASCADE,
    notification_type notification_type NOT NULL,
    email_enabled BOOLEAN DEFAULT true,
    push_enabled BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT false,
    in_app_enabled BOOLEAN DEFAULT true,
    frequency TEXT DEFAULT 'immediate',
    quiet_hours_start TIME,
    quiet_hours_end TIME,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, notification_type)
);

CREATE INDEX IF NOT EXISTS idx_notif_prefs_user ON notification_preferences(user_id);
