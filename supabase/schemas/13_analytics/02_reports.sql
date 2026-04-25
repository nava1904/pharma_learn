-- ===========================================
-- REPORTS AND EXPORTS
-- ===========================================

-- Report Definitions
CREATE TABLE IF NOT EXISTS report_definitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    unique_code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    report_category TEXT NOT NULL,
    report_type TEXT NOT NULL,
    query_config JSONB NOT NULL,
    filter_config JSONB,
    column_config JSONB NOT NULL,
    sort_config JSONB,
    grouping_config JSONB,
    chart_config JSONB,
    export_formats JSONB DEFAULT '["pdf", "excel", "csv"]',
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(organization_id, unique_code)
);

CREATE INDEX IF NOT EXISTS idx_report_defs_org ON report_definitions(organization_id);
CREATE INDEX IF NOT EXISTS idx_report_defs_category ON report_definitions(report_category);

-- Scheduled Reports
CREATE TABLE IF NOT EXISTS scheduled_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_definition_id UUID NOT NULL REFERENCES report_definitions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES global_profiles(id) ON DELETE CASCADE,
    schedule_name TEXT NOT NULL,
    frequency TEXT NOT NULL,
    schedule_config JSONB NOT NULL,
    filter_values JSONB,
    export_format TEXT DEFAULT 'pdf',
    recipients JSONB NOT NULL,
    is_active BOOLEAN DEFAULT true,
    last_run_at TIMESTAMPTZ,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_scheduled_reports_user ON scheduled_reports(user_id);
CREATE INDEX IF NOT EXISTS idx_scheduled_reports_next_run ON scheduled_reports(next_run_at);

-- Report Execution History
CREATE TABLE IF NOT EXISTS report_executions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_definition_id UUID REFERENCES report_definitions(id),
    scheduled_report_id UUID REFERENCES scheduled_reports(id),
    executed_by UUID REFERENCES global_profiles(id),
    execution_type TEXT NOT NULL,
    filter_values JSONB,
    started_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'running',
    row_count INTEGER,
    file_url TEXT,
    file_size_bytes BIGINT,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_report_exec_report ON report_executions(report_definition_id);
CREATE INDEX IF NOT EXISTS idx_report_exec_user ON report_executions(executed_by);
CREATE INDEX IF NOT EXISTS idx_report_exec_status ON report_executions(status);

-- Saved Filters
CREATE TABLE IF NOT EXISTS saved_report_filters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    report_definition_id UUID NOT NULL REFERENCES report_definitions(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES global_profiles(id) ON DELETE CASCADE,
    filter_name TEXT NOT NULL,
    filter_values JSONB NOT NULL,
    is_default BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(report_definition_id, user_id, filter_name)
);

CREATE INDEX IF NOT EXISTS idx_saved_filters_user ON saved_report_filters(user_id);

-- Data Exports
CREATE TABLE IF NOT EXISTS data_exports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    requested_by UUID NOT NULL REFERENCES global_profiles(id),
    export_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    filter_criteria JSONB,
    export_format TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    file_url TEXT,
    file_size_bytes BIGINT,
    row_count INTEGER,
    expires_at TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_data_exports_org ON data_exports(organization_id);
CREATE INDEX IF NOT EXISTS idx_data_exports_user ON data_exports(requested_by);
CREATE INDEX IF NOT EXISTS idx_data_exports_status ON data_exports(status);
