-- ===========================================
-- SEED DATA: KPI DEFINITIONS
-- Standard KPIs for training compliance monitoring
-- ===========================================

-- Insert standard KPI definitions
INSERT INTO kpi_definitions (
    id, 
    organization_id, 
    kpi_code, 
    kpi_name, 
    description,
    calculation_sql,
    target_value,
    warning_threshold,
    critical_threshold,
    unit,
    frequency,
    is_active
) VALUES
    -- Training Compliance Rate
    (
        '00000000-0000-0000-0000-000000000101',
        '00000000-0000-0000-0000-000000000001',
        'TCR001',
        'Training Compliance Rate',
        'Percentage of employees current on all required training',
        'SELECT (COUNT(*) FILTER (WHERE is_compliant) * 100.0 / NULLIF(COUNT(*), 0))::NUMERIC(5,2) FROM v_employee_compliance_status',
        95.00,
        90.00,
        85.00,
        'percent',
        'daily',
        TRUE
    ),
    
    -- On-Time Completion Rate
    (
        '00000000-0000-0000-0000-000000000102',
        '00000000-0000-0000-0000-000000000001',
        'OTC001',
        'On-Time Training Completion',
        'Percentage of trainings completed before due date',
        'SELECT (COUNT(*) FILTER (WHERE completed_at <= due_date) * 100.0 / NULLIF(COUNT(*), 0))::NUMERIC(5,2) FROM training_assignments WHERE completed_at IS NOT NULL',
        90.00,
        85.00,
        80.00,
        'percent',
        'weekly',
        TRUE
    ),
    
    -- Certificate Expiry Risk
    (
        '00000000-0000-0000-0000-000000000103',
        '00000000-0000-0000-0000-000000000001',
        'CER001',
        'Certificates Expiring in 30 Days',
        'Count of active certificates expiring within 30 days',
        'SELECT COUNT(*) FROM certificates WHERE status = ''active'' AND expires_at BETWEEN NOW() AND NOW() + INTERVAL ''30 days''',
        0,
        5,
        10,
        'count',
        'daily',
        TRUE
    ),
    
    -- Overdue Training Count
    (
        '00000000-0000-0000-0000-000000000104',
        '00000000-0000-0000-0000-000000000001',
        'ODT001',
        'Overdue Training Assignments',
        'Count of training assignments past due date',
        'SELECT COUNT(*) FROM training_assignments WHERE status = ''assigned'' AND due_date < NOW()',
        0,
        10,
        25,
        'count',
        'daily',
        TRUE
    ),
    
    -- Average Assessment Score
    (
        '00000000-0000-0000-0000-000000000105',
        '00000000-0000-0000-0000-000000000001',
        'ASS001',
        'Average Assessment Score',
        'Average score across all assessments in period',
        'SELECT AVG(score)::NUMERIC(5,2) FROM assessment_attempts WHERE submitted_at > NOW() - INTERVAL ''30 days''',
        85.00,
        80.00,
        75.00,
        'percent',
        'weekly',
        TRUE
    ),
    
    -- First-Time Pass Rate
    (
        '00000000-0000-0000-0000-000000000106',
        '00000000-0000-0000-0000-000000000001',
        'FTP001',
        'First-Time Pass Rate',
        'Percentage of assessments passed on first attempt',
        'SELECT (COUNT(*) FILTER (WHERE attempt_number = 1 AND passed = TRUE) * 100.0 / NULLIF(COUNT(*) FILTER (WHERE attempt_number = 1), 0))::NUMERIC(5,2) FROM assessment_attempts',
        80.00,
        70.00,
        60.00,
        'percent',
        'monthly',
        TRUE
    ),
    
    -- Session Attendance Rate
    (
        '00000000-0000-0000-0000-000000000107',
        '00000000-0000-0000-0000-000000000001',
        'SAR001',
        'Session Attendance Rate',
        'Percentage of enrolled employees who attended sessions',
        'SELECT (COUNT(*) FILTER (WHERE attended = TRUE) * 100.0 / NULLIF(COUNT(*), 0))::NUMERIC(5,2) FROM session_attendance',
        95.00,
        90.00,
        85.00,
        'percent',
        'weekly',
        TRUE
    ),
    
    -- Induction Completion Time
    (
        '00000000-0000-0000-0000-000000000108',
        '00000000-0000-0000-0000-000000000001',
        'IND001',
        'Average Induction Time (Days)',
        'Average days to complete induction training for new hires',
        'SELECT AVG(EXTRACT(DAY FROM induction_completed_at - created_at))::NUMERIC(5,1) FROM employees WHERE induction_completed_at IS NOT NULL AND created_at > NOW() - INTERVAL ''90 days''',
        14.0,
        21.0,
        30.0,
        'days',
        'monthly',
        TRUE
    ),
    
    -- GxP Training Coverage
    (
        '00000000-0000-0000-0000-000000000109',
        '00000000-0000-0000-0000-000000000001',
        'GXP001',
        'GxP Role Training Coverage',
        'Percentage of GxP roles with current required training',
        'SELECT (COUNT(*) FILTER (WHERE is_gxp_compliant) * 100.0 / NULLIF(COUNT(*), 0))::NUMERIC(5,2) FROM v_employee_gxp_status',
        100.00,
        98.00,
        95.00,
        'percent',
        'daily',
        TRUE
    ),
    
    -- Training Cost per Employee
    (
        '00000000-0000-0000-0000-000000000110',
        '00000000-0000-0000-0000-000000000001',
        'CST001',
        'Training Cost per Employee',
        'Average training cost per employee this quarter',
        'SELECT COALESCE(SUM(total_cost) / NULLIF(COUNT(DISTINCT employee_id), 0), 0)::NUMERIC(10,2) FROM training_costs WHERE created_at > date_trunc(''quarter'', NOW())',
        500.00,
        750.00,
        1000.00,
        'currency',
        'quarterly',
        TRUE
    ),
    
    -- E-Signature Completion Time
    (
        '00000000-0000-0000-0000-000000000111',
        '00000000-0000-0000-0000-000000000001',
        'ESG001',
        'Avg E-Signature Turnaround (Hours)',
        'Average time from signature request to completion',
        'SELECT AVG(EXTRACT(EPOCH FROM (signed_at - requested_at)) / 3600)::NUMERIC(5,1) FROM electronic_signatures WHERE signed_at IS NOT NULL AND requested_at > NOW() - INTERVAL ''30 days''',
        4.0,
        8.0,
        24.0,
        'hours',
        'weekly',
        TRUE
    ),
    
    -- Active Users
    (
        '00000000-0000-0000-0000-000000000112',
        '00000000-0000-0000-0000-000000000001',
        'USR001',
        'Monthly Active Users',
        'Count of unique users with activity in last 30 days',
        'SELECT COUNT(DISTINCT employee_id) FROM audit_trails WHERE performed_at > NOW() - INTERVAL ''30 days''',
        NULL,  -- No target - informational
        NULL,
        NULL,
        'count',
        'monthly',
        TRUE
    )
ON CONFLICT (organization_id, kpi_code) DO NOTHING;
