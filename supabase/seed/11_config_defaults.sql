-- ===========================================
-- SEED DATA: CONFIGURATION DEFAULTS
-- Default configuration for system settings
-- ===========================================

-- Password Policy (21 CFR Part 11 compliant defaults)
INSERT INTO password_policies (
    id,
    organization_id,
    policy_name,
    min_length,
    require_uppercase,
    require_lowercase,
    require_number,
    require_special,
    expiry_days,
    history_count,
    lockout_attempts,
    lockout_duration_minutes,
    is_active
) VALUES (
    '00000000-0000-0000-0000-000000000201',
    '00000000-0000-0000-0000-000000000001',
    'Default GxP Policy',
    12,
    TRUE,
    TRUE,
    TRUE,
    TRUE,
    90,
    12,
    5,
    30,
    TRUE
) ON CONFLICT DO NOTHING;

-- System Settings
INSERT INTO system_settings (
    id,
    organization_id,
    setting_key,
    setting_value,
    data_type,
    category,
    description,
    is_sensitive,
    requires_restart
) VALUES
    -- Session Settings
    (
        '00000000-0000-0000-0000-000000000301',
        '00000000-0000-0000-0000-000000000001',
        'session.timeout_minutes',
        '30',
        'integer',
        'security',
        'Session inactivity timeout in minutes',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000302',
        '00000000-0000-0000-0000-000000000001',
        'session.max_concurrent',
        '3',
        'integer',
        'security',
        'Maximum concurrent sessions per user',
        FALSE,
        FALSE
    ),
    
    -- E-Signature Settings
    (
        '00000000-0000-0000-0000-000000000303',
        '00000000-0000-0000-0000-000000000001',
        'esig.require_reason',
        'true',
        'boolean',
        'compliance',
        'Require reason for all e-signatures',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000304',
        '00000000-0000-0000-0000-000000000001',
        'esig.require_password',
        'true',
        'boolean',
        'compliance',
        'Require password re-entry for e-signatures',
        FALSE,
        FALSE
    ),
    
    -- Training Settings
    (
        '00000000-0000-0000-0000-000000000305',
        '00000000-0000-0000-0000-000000000001',
        'training.overdue_grace_days',
        '7',
        'integer',
        'training',
        'Grace period days before training marked critical',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000306',
        '00000000-0000-0000-0000-000000000001',
        'training.reminder_days',
        '[30, 14, 7, 3, 1]',
        'json',
        'training',
        'Days before due date to send reminders',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000307',
        '00000000-0000-0000-0000-000000000001',
        'training.max_assessment_attempts',
        '3',
        'integer',
        'training',
        'Maximum assessment attempts before lockout',
        FALSE,
        FALSE
    ),
    
    -- Certificate Settings
    (
        '00000000-0000-0000-0000-000000000308',
        '00000000-0000-0000-0000-000000000001',
        'certificate.default_validity_months',
        '12',
        'integer',
        'compliance',
        'Default certificate validity period',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000309',
        '00000000-0000-0000-0000-000000000001',
        'certificate.expiry_warning_days',
        '60',
        'integer',
        'compliance',
        'Days before expiry to start warnings',
        FALSE,
        FALSE
    ),
    
    -- Audit Settings
    (
        '00000000-0000-0000-0000-000000000310',
        '00000000-0000-0000-0000-000000000001',
        'audit.retention_years',
        '7',
        'integer',
        'compliance',
        'Years to retain audit trails (GxP minimum)',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000311',
        '00000000-0000-0000-0000-000000000001',
        'audit.hash_algorithm',
        'SHA-256',
        'string',
        'security',
        'Hash algorithm for audit chain',
        FALSE,
        TRUE
    ),
    
    -- Notification Settings
    (
        '00000000-0000-0000-0000-000000000312',
        '00000000-0000-0000-0000-000000000001',
        'notification.email_enabled',
        'true',
        'boolean',
        'notifications',
        'Enable email notifications',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000313',
        '00000000-0000-0000-0000-000000000001',
        'notification.sms_enabled',
        'false',
        'boolean',
        'notifications',
        'Enable SMS notifications',
        FALSE,
        FALSE
    ),
    
    -- Integration Settings
    (
        '00000000-0000-0000-0000-000000000314',
        '00000000-0000-0000-0000-000000000001',
        'integration.hr_sync_enabled',
        'true',
        'boolean',
        'integrations',
        'Enable HR system synchronization',
        FALSE,
        FALSE
    ),
    (
        '00000000-0000-0000-0000-000000000315',
        '00000000-0000-0000-0000-000000000001',
        'integration.qms_enabled',
        'true',
        'boolean',
        'integrations',
        'Enable QMS integration for deviations',
        FALSE,
        FALSE
    )
ON CONFLICT (organization_id, setting_key) DO NOTHING;

-- Feature Flags
INSERT INTO feature_flags (
    id,
    organization_id,
    flag_key,
    flag_value,
    description,
    is_enabled,
    rollout_percentage
) VALUES
    (
        '00000000-0000-0000-0000-000000000401',
        '00000000-0000-0000-0000-000000000001',
        'gamification_enabled',
        'true',
        'Enable gamification features (badges, points, leaderboards)',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000402',
        '00000000-0000-0000-0000-000000000001',
        'knowledge_base_enabled',
        'true',
        'Enable knowledge base articles',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000403',
        '00000000-0000-0000-0000-000000000001',
        'discussions_enabled',
        'true',
        'Enable discussion forums',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000404',
        '00000000-0000-0000-0000-000000000001',
        'social_learning_enabled',
        'true',
        'Enable social learning features',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000405',
        '00000000-0000-0000-0000-000000000001',
        'cost_tracking_enabled',
        'true',
        'Enable training cost tracking',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000406',
        '00000000-0000-0000-0000-000000000001',
        'xapi_lrs_enabled',
        'true',
        'Enable xAPI Learning Record Store',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000407',
        '00000000-0000-0000-0000-000000000001',
        'ai_recommendations_enabled',
        'false',
        'Enable AI-powered training recommendations',
        FALSE,
        0
    ),
    (
        '00000000-0000-0000-0000-000000000408',
        '00000000-0000-0000-0000-000000000001',
        'mobile_app_enabled',
        'true',
        'Enable mobile app access',
        TRUE,
        100
    ),
    (
        '00000000-0000-0000-0000-000000000409',
        '00000000-0000-0000-0000-000000000001',
        'offline_mode_enabled',
        'false',
        'Enable offline training mode',
        FALSE,
        0
    ),
    (
        '00000000-0000-0000-0000-000000000410',
        '00000000-0000-0000-0000-000000000001',
        'two_factor_required',
        'false',
        'Require two-factor authentication for all users',
        FALSE,
        0
    )
ON CONFLICT (organization_id, flag_key) DO NOTHING;

-- Retention Policies (GxP compliant)
INSERT INTO retention_policies (
    id,
    organization_id,
    policy_name,
    entity_type,
    retention_years,
    archive_after_years,
    requires_approval_to_delete,
    is_active,
    regulatory_reference
) VALUES
    (
        '00000000-0000-0000-0000-000000000501',
        '00000000-0000-0000-0000-000000000001',
        'Training Records - GxP',
        'training_records',
        7,
        3,
        TRUE,
        TRUE,
        '21 CFR 211.180, 21 CFR 820.180'
    ),
    (
        '00000000-0000-0000-0000-000000000502',
        '00000000-0000-0000-0000-000000000001',
        'Audit Trails - Permanent',
        'audit_trails',
        99,  -- Effectively permanent
        10,
        TRUE,
        TRUE,
        '21 CFR Part 11 §11.10(e)'
    ),
    (
        '00000000-0000-0000-0000-000000000503',
        '00000000-0000-0000-0000-000000000001',
        'E-Signatures - Permanent',
        'electronic_signatures',
        99,
        10,
        TRUE,
        TRUE,
        '21 CFR Part 11 §11.50'
    ),
    (
        '00000000-0000-0000-0000-000000000504',
        '00000000-0000-0000-0000-000000000001',
        'Certificates',
        'certificates',
        7,
        3,
        TRUE,
        TRUE,
        '21 CFR 211.180'
    ),
    (
        '00000000-0000-0000-0000-000000000505',
        '00000000-0000-0000-0000-000000000001',
        'Assessment Results',
        'assessment_attempts',
        7,
        3,
        TRUE,
        TRUE,
        '21 CFR 211.180'
    ),
    (
        '00000000-0000-0000-0000-000000000506',
        '00000000-0000-0000-0000-000000000001',
        'Session Attendance',
        'session_attendance',
        7,
        3,
        TRUE,
        TRUE,
        '21 CFR 211.180'
    ),
    (
        '00000000-0000-0000-0000-000000000507',
        '00000000-0000-0000-0000-000000000001',
        'User Sessions - Security',
        'user_sessions',
        2,
        1,
        FALSE,
        TRUE,
        'Internal Security Policy'
    ),
    (
        '00000000-0000-0000-0000-000000000508',
        '00000000-0000-0000-0000-000000000001',
        'Survey Responses',
        'survey_responses',
        3,
        2,
        FALSE,
        TRUE,
        'Internal Policy'
    )
ON CONFLICT DO NOTHING;
