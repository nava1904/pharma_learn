-- ===========================================
-- G12: NOTIFICATIONS & NOTIFICATION SETTINGS TABLES
-- Required by notification_handler.dart in API server
-- ===========================================

-- ---------------------------------------------------------------------------
-- 1. notifications - Stores in-app notifications for employees
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Notification content
    template_key TEXT NOT NULL,  -- Key for notification template
    title TEXT,                   -- Rendered title (can be generated from template)
    body TEXT,                    -- Rendered body (can be generated from template)
    data JSONB DEFAULT '{}'::JSONB,  -- Template variables / additional data
    
    -- Categorization
    category TEXT DEFAULT 'general' 
        CHECK (category IN ('general', 'approval', 'training', 'compliance', 'system', 'alert')),
    priority TEXT DEFAULT 'normal'
        CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
    
    -- Links
    action_url TEXT,              -- URL to navigate when clicked
    entity_type TEXT,             -- Related entity type (document, course, etc.)
    entity_id UUID,               -- Related entity ID
    
    -- State
    status TEXT DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
    read_at TIMESTAMPTZ,          -- When user read the notification
    deleted_at TIMESTAMPTZ,       -- Soft delete for audit
    
    -- Delivery tracking
    email_sent_at TIMESTAMPTZ,
    push_sent_at TIMESTAMPTZ,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_employee ON notifications(employee_id);
CREATE INDEX IF NOT EXISTS idx_notifications_unread ON notifications(employee_id, read_at) 
    WHERE read_at IS NULL AND deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications(category);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_entity ON notifications(entity_type, entity_id)
    WHERE entity_type IS NOT NULL;

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY notifications_select ON notifications FOR SELECT
    USING (employee_id = (current_setting('app.current_employee_id', TRUE))::UUID);

CREATE POLICY notifications_update ON notifications FOR UPDATE
    USING (employee_id = (current_setting('app.current_employee_id', TRUE))::UUID)
    WITH CHECK (employee_id = (current_setting('app.current_employee_id', TRUE))::UUID);

-- Service role can insert for all employees
CREATE POLICY notifications_insert_service ON notifications FOR INSERT
    WITH CHECK (TRUE);

COMMENT ON TABLE notifications IS 'In-app notifications for employees with delivery tracking';

-- ---------------------------------------------------------------------------
-- 2. notification_settings - Per-employee notification preferences
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    
    -- Channel preferences
    email_enabled BOOLEAN DEFAULT TRUE,
    push_enabled BOOLEAN DEFAULT TRUE,
    sms_enabled BOOLEAN DEFAULT FALSE,
    
    -- Category preferences
    approval_notifications BOOLEAN DEFAULT TRUE,
    training_reminders BOOLEAN DEFAULT TRUE,
    cert_expiry_warnings BOOLEAN DEFAULT TRUE,
    compliance_alerts BOOLEAN DEFAULT TRUE,
    system_notifications BOOLEAN DEFAULT TRUE,
    
    -- Timing preferences
    digest_frequency TEXT DEFAULT 'instant'
        CHECK (digest_frequency IN ('instant', 'hourly', 'daily', 'weekly')),
    quiet_hours_start TIME,       -- Don't send during quiet hours
    quiet_hours_end TIME,
    timezone TEXT DEFAULT 'UTC',
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notification_settings_employee ON notification_settings(employee_id);

-- RLS
ALTER TABLE notification_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY notification_settings_own ON notification_settings FOR ALL
    USING (employee_id = (current_setting('app.current_employee_id', TRUE))::UUID)
    WITH CHECK (employee_id = (current_setting('app.current_employee_id', TRUE))::UUID);

COMMENT ON TABLE notification_settings IS 'Per-employee notification preferences and delivery settings';

-- ---------------------------------------------------------------------------
-- 3. notification_templates - Reusable notification templates
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notification_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,  -- NULL = system template
    
    -- Template identification
    template_key TEXT NOT NULL,
    locale TEXT DEFAULT 'en',
    
    -- Content templates (supports {{variable}} interpolation)
    title_template TEXT NOT NULL,
    body_template TEXT NOT NULL,
    email_subject_template TEXT,
    email_body_template TEXT,       -- HTML or plain text
    push_body_template TEXT,        -- Shorter for push notifications
    
    -- Metadata
    category TEXT DEFAULT 'general',
    default_priority TEXT DEFAULT 'normal',
    
    -- State
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    CONSTRAINT notification_templates_unique UNIQUE (organization_id, template_key, locale)
);

CREATE INDEX IF NOT EXISTS idx_notification_templates_key ON notification_templates(template_key);
CREATE INDEX IF NOT EXISTS idx_notification_templates_org ON notification_templates(organization_id);

COMMENT ON TABLE notification_templates IS 'Reusable notification templates with localization support';

-- ---------------------------------------------------------------------------
-- 4. Insert default system templates
-- ---------------------------------------------------------------------------
INSERT INTO notification_templates (template_key, title_template, body_template, category, default_priority)
VALUES
    ('approval_required', 
     'Approval Required: {{entity_type}}', 
     'A {{entity_type}} "{{entity_title}}" requires your approval for step "{{step_name}}".',
     'approval', 'high'),
    
    ('approval_step_approved',
     'Approval Progress: {{entity_type}}',
     'Step "{{step_name}}" has been approved for {{entity_type}} "{{entity_title}}".',
     'approval', 'normal'),
    
    ('document_approved',
     'Document Approved',
     'Your document "{{entity_title}}" has been fully approved and is now effective.',
     'approval', 'normal'),
    
    ('document_rejected',
     'Document Rejected',
     'Your document "{{entity_title}}" has been rejected. Reason: {{reason}}',
     'approval', 'high'),
    
    ('course_approved',
     'Course Approved',
     'Your course "{{entity_title}}" has been fully approved and is now effective.',
     'approval', 'normal'),
    
    ('course_rejected',
     'Course Rejected',
     'Your course "{{entity_title}}" has been rejected. Reason: {{reason}}',
     'approval', 'high'),
    
    ('training_assigned',
     'New Training Assignment',
     'You have been assigned new training: "{{training_plan_title}}". Due date: {{due_date}}.',
     'training', 'normal'),
    
    ('training_completed',
     'Training Completed',
     'Congratulations! You have completed the training.',
     'training', 'normal'),
    
    ('training_overdue',
     'Training Overdue',
     'Your training "{{training_title}}" is overdue. Please complete it as soon as possible.',
     'training', 'urgent'),
    
    ('cert_expiry_30d',
     'Certificate Expiring Soon',
     'Your certificate will expire in 30 days on {{valid_until}}. Please renew before expiration.',
     'compliance', 'high'),
    
    ('cert_expiry_7d',
     'Certificate Expiring This Week',
     'Your certificate will expire in 7 days on {{valid_until}}. Immediate action required.',
     'compliance', 'urgent'),
    
    ('certificate_expired',
     'Certificate Expired',
     'Your certificate has expired on {{expired_at}}. Please complete retraining.',
     'compliance', 'urgent'),
    
    ('password_expiry_warning',
     'Password Expiring Soon',
     'Your password will expire on {{expires_at}}. Please change it before expiration.',
     'system', 'high'),
    
    ('approval_escalation',
     'Escalation: Pending Approval',
     'An approval for {{entity_type}} has been pending for {{days_pending}} days and requires attention.',
     'approval', 'urgent'),
    
    ('dead_letter_alert',
     'System Alert: Failed Events',
     '{{count}} events have failed processing and require manual intervention.',
     'system', 'urgent')
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. FUNCTION: get_unread_notification_count
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_employee_id UUID)
RETURNS INTEGER
LANGUAGE SQL
SECURITY DEFINER
AS $$
    SELECT COUNT(*)::INTEGER
    FROM notifications
    WHERE employee_id = p_employee_id
      AND read_at IS NULL
      AND deleted_at IS NULL;
$$;

COMMENT ON FUNCTION get_unread_notification_count IS 
    'Returns count of unread notifications for an employee';

-- ---------------------------------------------------------------------------
-- 6. FUNCTION: render_notification
-- Renders a notification from template with variable substitution
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION render_notification(
    p_template_key TEXT,
    p_data JSONB,
    p_locale TEXT DEFAULT 'en',
    p_organization_id UUID DEFAULT NULL
)
RETURNS TABLE (
    title TEXT,
    body TEXT,
    category TEXT,
    priority TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_template RECORD;
    v_title TEXT;
    v_body TEXT;
    v_key TEXT;
    v_value TEXT;
BEGIN
    -- Find template (org-specific first, then system)
    SELECT nt.* INTO v_template
    FROM notification_templates nt
    WHERE nt.template_key = p_template_key
      AND nt.locale = p_locale
      AND nt.is_active = TRUE
      AND (nt.organization_id = p_organization_id OR nt.organization_id IS NULL)
    ORDER BY nt.organization_id NULLS LAST
    LIMIT 1;
    
    IF v_template IS NULL THEN
        RETURN QUERY SELECT 
            p_template_key::TEXT, 
            'Notification'::TEXT,
            'general'::TEXT,
            'normal'::TEXT;
        RETURN;
    END IF;
    
    v_title := v_template.title_template;
    v_body := v_template.body_template;
    
    -- Simple variable substitution: replace {{key}} with value
    FOR v_key, v_value IN SELECT * FROM jsonb_each_text(p_data)
    LOOP
        v_title := REPLACE(v_title, '{{' || v_key || '}}', COALESCE(v_value, ''));
        v_body := REPLACE(v_body, '{{' || v_key || '}}', COALESCE(v_value, ''));
    END LOOP;
    
    RETURN QUERY SELECT 
        v_title, 
        v_body, 
        v_template.category, 
        v_template.default_priority;
END;
$$;

COMMENT ON FUNCTION render_notification IS 
    'Renders a notification using template with variable substitution';

-- ---------------------------------------------------------------------------
-- 7. FUNCTION: create_notification
-- Creates a notification and renders it from template
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_notification(
    p_employee_id UUID,
    p_template_key TEXT,
    p_data JSONB DEFAULT '{}',
    p_entity_type TEXT DEFAULT NULL,
    p_entity_id UUID DEFAULT NULL,
    p_action_url TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_notification_id UUID;
    v_employee RECORD;
    v_rendered RECORD;
BEGIN
    -- Get employee's org
    SELECT organization_id INTO v_employee
    FROM employees
    WHERE id = p_employee_id;
    
    IF v_employee IS NULL THEN
        RAISE EXCEPTION 'Employee not found: %', p_employee_id;
    END IF;
    
    -- Render notification from template
    SELECT * INTO v_rendered
    FROM render_notification(p_template_key, p_data, 'en', v_employee.organization_id);
    
    -- Insert notification
    INSERT INTO notifications (
        organization_id,
        employee_id,
        template_key,
        title,
        body,
        data,
        category,
        priority,
        entity_type,
        entity_id,
        action_url
    )
    VALUES (
        v_employee.organization_id,
        p_employee_id,
        p_template_key,
        v_rendered.title,
        v_rendered.body,
        p_data,
        v_rendered.category,
        v_rendered.priority,
        p_entity_type,
        p_entity_id,
        p_action_url
    )
    RETURNING id INTO v_notification_id;
    
    RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION create_notification IS 
    'Creates a notification for an employee, rendering from template';
