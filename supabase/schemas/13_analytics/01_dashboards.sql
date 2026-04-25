-- ===========================================
-- ANALYTICS AND DASHBOARDS
-- ===========================================

-- Dashboard Widgets Configuration
CREATE TABLE IF NOT EXISTS dashboard_widgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    widget_type TEXT NOT NULL,
    data_source TEXT NOT NULL,
    query_config JSONB NOT NULL,
    visualization_config JSONB NOT NULL,
    refresh_interval_seconds INTEGER DEFAULT 300,
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_widgets_org ON dashboard_widgets(organization_id);

-- User Dashboard Layouts
CREATE TABLE IF NOT EXISTS user_dashboards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES global_profiles(id) ON DELETE CASCADE,
    dashboard_name TEXT NOT NULL DEFAULT 'default',
    layout_config JSONB NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, dashboard_name)
);

CREATE INDEX IF NOT EXISTS idx_user_dashboards_user ON user_dashboards(user_id);

-- Training Analytics Aggregates
CREATE TABLE IF NOT EXISTS training_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    analytics_date DATE NOT NULL,
    granularity TEXT NOT NULL DEFAULT 'daily',
    department_id UUID REFERENCES departments(id),
    plant_id UUID REFERENCES plants(id),
    total_employees INTEGER DEFAULT 0,
    active_trainings INTEGER DEFAULT 0,
    completed_trainings INTEGER DEFAULT 0,
    overdue_trainings INTEGER DEFAULT 0,
    compliance_rate NUMERIC(5,2) DEFAULT 0,
    avg_completion_time_hours NUMERIC(6,2),
    total_training_hours NUMERIC(10,2) DEFAULT 0,
    assessment_pass_rate NUMERIC(5,2),
    avg_assessment_score NUMERIC(5,2),
    feedback_avg_rating NUMERIC(3,2),
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, analytics_date, granularity, department_id, plant_id)
);

CREATE INDEX IF NOT EXISTS idx_training_analytics_org ON training_analytics(organization_id);
CREATE INDEX IF NOT EXISTS idx_training_analytics_date ON training_analytics(analytics_date);

-- Course Performance Analytics
CREATE TABLE IF NOT EXISTS course_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
    analytics_period TEXT NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    total_enrollments INTEGER DEFAULT 0,
    total_completions INTEGER DEFAULT 0,
    completion_rate NUMERIC(5,2) DEFAULT 0,
    avg_completion_time_hours NUMERIC(6,2),
    avg_assessment_score NUMERIC(5,2),
    assessment_pass_rate NUMERIC(5,2),
    avg_feedback_rating NUMERIC(3,2),
    drop_off_rate NUMERIC(5,2),
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(course_id, analytics_period, period_start)
);

CREATE INDEX IF NOT EXISTS idx_course_analytics_course ON course_analytics(course_id);
CREATE INDEX IF NOT EXISTS idx_course_analytics_period ON course_analytics(period_start, period_end);

-- Employee Training Analytics
CREATE TABLE IF NOT EXISTS employee_training_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    analytics_year INTEGER NOT NULL,
    analytics_month INTEGER,
    total_assigned INTEGER DEFAULT 0,
    total_completed INTEGER DEFAULT 0,
    total_overdue INTEGER DEFAULT 0,
    total_training_hours NUMERIC(6,2) DEFAULT 0,
    avg_assessment_score NUMERIC(5,2),
    certifications_earned INTEGER DEFAULT 0,
    certifications_expiring INTEGER DEFAULT 0,
    compliance_status TEXT,
    calculated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(employee_id, analytics_year, analytics_month)
);

CREATE INDEX IF NOT EXISTS idx_emp_analytics_employee ON employee_training_analytics(employee_id);
CREATE INDEX IF NOT EXISTS idx_emp_analytics_year ON employee_training_analytics(analytics_year);
