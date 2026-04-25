-- ===========================================
-- SURVEYS, POLLS & PULSE CHECKS
-- Beyond training feedback: org-wide surveys, sentiment
-- ===========================================

CREATE TYPE survey_status AS ENUM ('draft','scheduled','active','closed','archived');
CREATE TYPE survey_question_kind AS ENUM (
    'single_choice','multi_choice','likert','nps','rating','text_short',
    'text_long','yes_no','ranking','matrix','date','numeric'
);

CREATE TABLE IF NOT EXISTS surveys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    unique_code TEXT NOT NULL,
    description TEXT,
    survey_purpose TEXT CHECK (survey_purpose IN ('training_effectiveness','culture','pulse','exit','onboarding','custom','nps')),
    is_anonymous BOOLEAN DEFAULT false,
    target_roles UUID[] DEFAULT '{}',
    target_subgroups UUID[] DEFAULT '{}',
    target_employees UUID[] DEFAULT '{}',
    open_from TIMESTAMPTZ,
    open_until TIMESTAMPTZ,
    survey_status survey_status DEFAULT 'draft',
    status workflow_state DEFAULT 'draft',
    revision_no INTEGER DEFAULT 0,
    created_by UUID,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE TABLE IF NOT EXISTS survey_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    section_name TEXT,
    question_order INTEGER NOT NULL,
    question_text TEXT NOT NULL,
    question_kind survey_question_kind NOT NULL,
    options_json JSONB,
    scale_min INTEGER,
    scale_max INTEGER,
    is_required BOOLEAN DEFAULT true,
    conditional_logic JSONB,
    UNIQUE(survey_id, question_order)
);

CREATE TABLE IF NOT EXISTS survey_invitations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id),
    invited_at TIMESTAMPTZ DEFAULT NOW(),
    reminder_count INTEGER DEFAULT 0,
    last_reminded_at TIMESTAMPTZ,
    response_token TEXT UNIQUE,
    UNIQUE(survey_id, employee_id)
);

CREATE TABLE IF NOT EXISTS survey_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    invitation_id UUID REFERENCES survey_invitations(id),
    employee_id UUID REFERENCES employees(id),
    is_anonymous BOOLEAN DEFAULT false,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    submitted_at TIMESTAMPTZ,
    completion_percent NUMERIC(5,2) DEFAULT 0,
    device_info JSONB,
    ip_address INET
);

CREATE TABLE IF NOT EXISTS survey_answers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    response_id UUID NOT NULL REFERENCES survey_responses(id) ON DELETE CASCADE,
    question_id UUID NOT NULL REFERENCES survey_questions(id),
    answer_text TEXT,
    answer_numeric NUMERIC(12,4),
    answer_options JSONB,
    answered_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(response_id, question_id)
);

CREATE TABLE IF NOT EXISTS survey_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    survey_id UUID NOT NULL REFERENCES surveys(id) ON DELETE CASCADE,
    question_id UUID REFERENCES survey_questions(id),
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(12,4),
    segment_label TEXT,
    distribution_json JSONB,
    calculated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sr_survey ON survey_responses(survey_id);
CREATE INDEX IF NOT EXISTS idx_sa_response ON survey_answers(response_id);

COMMENT ON TABLE surveys IS 'Org-wide surveys, pulse checks, NPS — distinct from per-training feedback';
