-- ===========================================
-- CRON JOBS AND BACKGROUND TASKS
-- ===========================================

-- Cron Job Definitions
CREATE TABLE IF NOT EXISTS cron_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_name TEXT NOT NULL UNIQUE,
    job_description TEXT,
    cron_expression TEXT NOT NULL,
    function_name TEXT NOT NULL,
    function_params JSONB DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_run_at TIMESTAMPTZ,
    last_run_status TEXT,
    last_run_duration_ms INTEGER,
    last_error TEXT,
    next_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cron_jobs_active ON cron_jobs(is_active);
CREATE INDEX IF NOT EXISTS idx_cron_jobs_next_run ON cron_jobs(next_run_at);

-- Cron Job Execution History
CREATE TABLE IF NOT EXISTS cron_job_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_id UUID NOT NULL REFERENCES cron_jobs(id) ON DELETE CASCADE,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL,
    duration_ms INTEGER,
    records_processed INTEGER,
    error_message TEXT,
    execution_log JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cron_history_job ON cron_job_history(job_id);
CREATE INDEX IF NOT EXISTS idx_cron_history_started ON cron_job_history(started_at);

-- Background Tasks Queue
CREATE TABLE IF NOT EXISTS background_tasks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_type TEXT NOT NULL,
    task_name TEXT NOT NULL,
    payload JSONB NOT NULL,
    priority INTEGER DEFAULT 5,
    scheduled_at TIMESTAMPTZ DEFAULT NOW(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    status TEXT DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 3,
    error_message TEXT,
    result JSONB,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bg_tasks_status ON background_tasks(status);
CREATE INDEX IF NOT EXISTS idx_bg_tasks_scheduled ON background_tasks(scheduled_at);
CREATE INDEX IF NOT EXISTS idx_bg_tasks_type ON background_tasks(task_type);
CREATE INDEX IF NOT EXISTS idx_bg_tasks_priority ON background_tasks(priority);

-- Insert default cron jobs
INSERT INTO cron_jobs (job_name, job_description, cron_expression, function_name, is_active) VALUES
    ('process_training_reminders', 'Send training reminders', '0 8 * * *', 'process_training_reminders', true),
    ('process_escalations', 'Process overdue escalations', '0 9 * * *', 'process_escalations', true),
    ('update_compliance_status', 'Update training compliance status', '0 1 * * *', 'update_compliance_status', true),
    ('expire_certificates', 'Mark expired certificates', '0 0 * * *', 'expire_certificates', true),
    ('generate_daily_analytics', 'Generate daily analytics', '0 2 * * *', 'generate_daily_analytics', true),
    ('cleanup_expired_sessions', 'Clean up expired sessions', '0 3 * * *', 'cleanup_expired_sessions', true),
    ('archive_old_audit_logs', 'Archive audit logs older than retention period', '0 4 * * 0', 'archive_audit_logs', true),
    ('sync_employee_data', 'Sync employee data from HR system', '0 6 * * *', 'sync_employee_data', false),
    ('process_notification_queue', 'Process pending notifications', '*/5 * * * *', 'process_notification_queue', true),
    ('update_training_analytics', 'Update training analytics aggregates', '0 5 * * *', 'update_training_analytics', true)
ON CONFLICT (job_name) DO NOTHING;
