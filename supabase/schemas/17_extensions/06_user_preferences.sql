-- ===========================================
-- USER PREFERENCES & PERSONALIZATION
-- Theme, language, accessibility, dashboards
-- ===========================================

CREATE TABLE IF NOT EXISTS user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL UNIQUE REFERENCES employees(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    theme TEXT DEFAULT 'system' CHECK (theme IN ('system','light','dark','high_contrast')),
    language TEXT DEFAULT 'en',
    timezone TEXT DEFAULT 'Asia/Kolkata',
    date_format TEXT DEFAULT 'DD/MM/YYYY',
    time_format TEXT DEFAULT 'HH:mm',
    number_format TEXT DEFAULT 'en_IN',
    font_size TEXT DEFAULT 'medium' CHECK (font_size IN ('small','medium','large','x_large')),
    reduce_motion BOOLEAN DEFAULT false,
    screen_reader_optimized BOOLEAN DEFAULT false,
    keyboard_shortcuts_enabled BOOLEAN DEFAULT true,
    default_landing_page TEXT DEFAULT '/dashboard',
    sidebar_collapsed BOOLEAN DEFAULT false,
    email_digest_frequency TEXT DEFAULT 'daily' CHECK (email_digest_frequency IN ('off','daily','weekly','instant')),
    marketing_emails_opt_in BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_accessibility_needs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    need_type TEXT NOT NULL CHECK (need_type IN ('visual','auditory','motor','cognitive')),
    accommodation_notes TEXT,
    requires_captions BOOLEAN DEFAULT false,
    requires_transcript BOOLEAN DEFAULT false,
    requires_extended_time BOOLEAN DEFAULT false,
    extended_time_multiplier NUMERIC(3,1) DEFAULT 1.5,
    verified_by UUID,
    verified_at TIMESTAMPTZ,
    valid_until DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS saved_filters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    scope_module TEXT NOT NULL,
    name TEXT NOT NULL,
    filter_json JSONB NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, scope_module, name)
);

CREATE TABLE IF NOT EXISTS ui_shortcuts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    action TEXT NOT NULL,
    key_combo TEXT NOT NULL,
    is_enabled BOOLEAN DEFAULT true,
    UNIQUE(employee_id, action)
);

CREATE TABLE IF NOT EXISTS recent_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    item_type TEXT NOT NULL,
    item_id UUID NOT NULL,
    item_label TEXT,
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_recent_employee ON recent_items(employee_id, accessed_at DESC);

COMMENT ON TABLE user_preferences IS 'Per-user UI & personalization settings';
COMMENT ON TABLE user_accessibility_needs IS 'Accommodations (extended time, captions, transcripts) for assessments & content';
