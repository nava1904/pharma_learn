-- ===========================================
-- DETAILED AUDIT TRAIL SCHEMAS
-- ===========================================

-- Login Audit Trail (21 CFR Part 11)
CREATE TABLE IF NOT EXISTS login_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES global_profiles(id),
    employee_id UUID REFERENCES employees(id),
    username TEXT,
    login_type TEXT NOT NULL,
    action TEXT NOT NULL,
    status TEXT NOT NULL,
    failure_reason TEXT,
    ip_address INET,
    user_agent TEXT,
    device_info JSONB,
    geo_location JSONB,
    session_id TEXT,
    mfa_method TEXT,
    mfa_verified BOOLEAN,
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_login_audit_user ON login_audit_trail(user_id);
CREATE INDEX IF NOT EXISTS idx_login_audit_timestamp ON login_audit_trail(timestamp);
CREATE INDEX IF NOT EXISTS idx_login_audit_status ON login_audit_trail(status);
CREATE INDEX IF NOT EXISTS idx_login_audit_ip ON login_audit_trail(ip_address);

-- Security Audit Trail
CREATE TABLE IF NOT EXISTS security_audit_trail (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID,
    action_type TEXT NOT NULL,
    action_description TEXT NOT NULL,
    target_type TEXT,
    target_id UUID,
    target_name TEXT,
    old_value JSONB,
    new_value JSONB,
    ip_address INET,
    user_agent TEXT,
    risk_level TEXT DEFAULT 'low',
    requires_review BOOLEAN DEFAULT false,
    reviewed_by UUID,
    reviewed_at TIMESTAMPTZ,
    review_notes TEXT,
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_security_audit_user ON security_audit_trail(user_id);
CREATE INDEX IF NOT EXISTS idx_security_audit_action ON security_audit_trail(action_type);
CREATE INDEX IF NOT EXISTS idx_security_audit_timestamp ON security_audit_trail(timestamp);
CREATE INDEX IF NOT EXISTS idx_security_audit_risk ON security_audit_trail(risk_level);

-- Data Access Audit Trail
CREATE TABLE IF NOT EXISTS data_access_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL,
    access_type TEXT NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID,
    fields_accessed JSONB,
    query_type TEXT,
    row_count INTEGER,
    purpose TEXT,
    ip_address INET,
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_data_access_user ON data_access_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_data_access_table ON data_access_audit(table_name);
CREATE INDEX IF NOT EXISTS idx_data_access_timestamp ON data_access_audit(timestamp);

-- Permission Change Audit
CREATE TABLE IF NOT EXISTS permission_change_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    changed_by UUID NOT NULL,
    target_user_id UUID NOT NULL,
    target_employee_id UUID,
    change_type TEXT NOT NULL,
    role_id UUID,
    permission_id UUID,
    old_permissions JSONB,
    new_permissions JSONB,
    reason TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_perm_change_target ON permission_change_audit(target_user_id);
CREATE INDEX IF NOT EXISTS idx_perm_change_by ON permission_change_audit(changed_by);
CREATE INDEX IF NOT EXISTS idx_perm_change_timestamp ON permission_change_audit(timestamp);

-- System Configuration Audit
CREATE TABLE IF NOT EXISTS system_config_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    changed_by UUID NOT NULL,
    config_category TEXT NOT NULL,
    config_key TEXT NOT NULL,
    old_value JSONB,
    new_value JSONB,
    change_reason TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_sys_config_category ON system_config_audit(config_category);
CREATE INDEX IF NOT EXISTS idx_sys_config_timestamp ON system_config_audit(timestamp);
