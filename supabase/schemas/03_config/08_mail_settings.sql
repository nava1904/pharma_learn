-- ===========================================
-- MAIL SETTINGS
-- Configurable email event templates and subscriptions
-- Alfa URS §4.3.6, EE URS §5.1.16
-- ===========================================

-- -------------------------------------------------------
-- MAIL EVENT TEMPLATES
-- One template per event code per organization
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS mail_event_templates (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Event identifier (matches notification_type in notifications table)
    event_code          TEXT NOT NULL,

    -- Scope
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id            UUID REFERENCES plants(id) ON DELETE CASCADE,   -- NULL = org-wide
    language_code       TEXT NOT NULL DEFAULT 'en',

    -- Template content (Handlebars/Mustache format)
    -- Available variables depend on event_code (documented per event)
    subject_template    TEXT NOT NULL,
    body_html_template  TEXT NOT NULL,
    body_text_template  TEXT,        -- Plain text fallback

    -- Trigger conditions
    -- Boolean expression evaluated in application context
    -- e.g. '{{days_overdue}} > 0 && {{is_mandatory}} == true'
    trigger_condition   TEXT,

    -- Sender override (defaults to system_settings.notifications.from_address)
    from_name           TEXT,
    from_address        TEXT,
    reply_to            TEXT,
    cc_addresses        TEXT[],       -- Additional always-cc'd addresses (e.g. compliance@org.com)

    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by          UUID,

    UNIQUE(event_code, organization_id, COALESCE(plant_id, '00000000-0000-0000-0000-000000000000'::UUID), language_code)
);

CREATE INDEX IF NOT EXISTS idx_mail_templates_event ON mail_event_templates(event_code);
CREATE INDEX IF NOT EXISTS idx_mail_templates_org   ON mail_event_templates(organization_id);
CREATE INDEX IF NOT EXISTS idx_mail_templates_active ON mail_event_templates(is_active) WHERE is_active = TRUE;

DROP TRIGGER IF EXISTS trg_mail_templates_updated ON mail_event_templates;
CREATE TRIGGER trg_mail_templates_updated
    BEFORE UPDATE ON mail_event_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------
-- MAIL EVENT SUBSCRIPTIONS
-- Per-employee opt-in/opt-out for specific event types
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS mail_event_subscriptions (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    employee_id         UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    event_code          TEXT NOT NULL,

    -- Delivery preferences
    is_subscribed       BOOLEAN NOT NULL DEFAULT TRUE,
    delivery_method     TEXT NOT NULL DEFAULT 'EMAIL'
                            CHECK (delivery_method IN ('EMAIL', 'IN_APP', 'BOTH', 'NONE')),

    -- Frequency collapsing (for high-volume events like daily reminders)
    digest_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    digest_frequency    TEXT    DEFAULT 'DAILY'
                            CHECK (digest_frequency IN ('IMMEDIATE', 'DAILY', 'WEEKLY')),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE(employee_id, event_code)
);

CREATE INDEX IF NOT EXISTS idx_mail_subscriptions_employee ON mail_event_subscriptions(employee_id);
CREATE INDEX IF NOT EXISTS idx_mail_subscriptions_event    ON mail_event_subscriptions(event_code);
CREATE INDEX IF NOT EXISTS idx_mail_subscriptions_active   ON mail_event_subscriptions(is_subscribed) WHERE is_subscribed = TRUE;

DROP TRIGGER IF EXISTS trg_mail_subscriptions_updated ON mail_event_subscriptions;
CREATE TRIGGER trg_mail_subscriptions_updated
    BEFORE UPDATE ON mail_event_subscriptions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- -------------------------------------------------------
-- MAIL DELIVERY LOG (append-only)
-- Track every email sent; used for SLA and troubleshooting
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS mail_delivery_log (
    id                  UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    event_code          TEXT NOT NULL,
    template_id         UUID REFERENCES mail_event_templates(id) ON DELETE SET NULL,
    recipient_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    recipient_email     TEXT NOT NULL,

    subject             TEXT NOT NULL,
    status              TEXT NOT NULL DEFAULT 'queued'
                            CHECK (status IN ('queued','sent','delivered','bounced','failed','skipped')),
    provider_message_id TEXT,         -- External mail provider message ID
    sent_at             TIMESTAMPTZ,
    delivered_at        TIMESTAMPTZ,
    failure_reason      TEXT,

    -- Entity context
    entity_type         TEXT,
    entity_id           UUID,

    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Append-only enforcement for audit integrity
CREATE OR REPLACE FUNCTION mail_delivery_log_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'mail_delivery_log is append-only and cannot be deleted';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_mail_delivery_log_immutable ON mail_delivery_log;
CREATE TRIGGER trg_mail_delivery_log_immutable
    BEFORE DELETE ON mail_delivery_log
    FOR EACH ROW EXECUTE FUNCTION mail_delivery_log_immutable();

CREATE INDEX IF NOT EXISTS idx_mail_log_event     ON mail_delivery_log(event_code);
CREATE INDEX IF NOT EXISTS idx_mail_log_recipient ON mail_delivery_log(recipient_employee_id);
CREATE INDEX IF NOT EXISTS idx_mail_log_status    ON mail_delivery_log(status);
CREATE INDEX IF NOT EXISTS idx_mail_log_created   ON mail_delivery_log(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mail_log_entity    ON mail_delivery_log(entity_type, entity_id);

-- -------------------------------------------------------
-- SEED: event code registry (event_code values used in templates)
-- -------------------------------------------------------
-- These are the canonical event codes. Templates per org are created
-- by the organization setup wizard.
-- Event codes match notification_type enum where possible.
COMMENT ON TABLE mail_event_templates IS 'Per-organization email templates with Handlebars variable interpolation (Alfa §4.3.6)';
COMMENT ON TABLE mail_event_subscriptions IS 'Employee-level opt-in/opt-out for each notification event type';
COMMENT ON TABLE mail_delivery_log IS 'Append-only delivery audit log for every outgoing email';
COMMENT ON COLUMN mail_event_templates.trigger_condition IS 'Boolean expression (evaluated at send time) — NULL means always send';
COMMENT ON COLUMN mail_event_subscriptions.digest_enabled IS 'When TRUE, emails are batched and sent as a digest instead of immediately';
