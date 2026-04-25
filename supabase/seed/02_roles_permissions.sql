-- ===========================================
-- SEED DATA: ROLES AND PERMISSIONS
-- ===========================================

-- Role Categories
INSERT INTO role_categories (id, organization_id, name, unique_code, description) VALUES
    ('00000000-0000-0000-0000-000000000031', '00000000-0000-0000-0000-000000000001', 'Executive', 'EXEC', 'C-Suite and senior leadership'),
    ('00000000-0000-0000-0000-000000000032', '00000000-0000-0000-0000-000000000001', 'Management', 'MGMT', 'Department heads and managers'),
    ('00000000-0000-0000-0000-000000000033', '00000000-0000-0000-0000-000000000001', 'Supervisory', 'SUPV', 'Team leads and supervisors'),
    ('00000000-0000-0000-0000-000000000034', '00000000-0000-0000-0000-000000000001', 'Professional', 'PROF', 'Technical and professional staff'),
    ('00000000-0000-0000-0000-000000000035', '00000000-0000-0000-0000-000000000001', 'Operational', 'OPER', 'Operational and production staff'),
    ('00000000-0000-0000-0000-000000000036', '00000000-0000-0000-0000-000000000001', 'Support', 'SUPP', 'Administrative and support staff')
ON CONFLICT DO NOTHING;

-- Roles with Learn-IQ levels (1 = highest authority, 99.99 = lowest)
INSERT INTO roles (id, organization_id, category_id, name, unique_code, level, is_login_role, status, permissions) VALUES
    -- Executive (Level 1-5)
    ('00000000-0000-0000-0000-000000000041', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031', 'Chief Executive Officer', 'CEO', 1, true, 'active', '{"all": true}'),
    ('00000000-0000-0000-0000-000000000042', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031', 'Chief Operating Officer', 'COO', 2, true, 'active', '{"all": true}'),
    ('00000000-0000-0000-0000-000000000043', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031', 'VP Quality', 'VPQ', 3, true, 'active', '{"quality": true, "training": true}'),
    ('00000000-0000-0000-0000-000000000044', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000031', 'VP Operations', 'VPO', 3, true, 'active', '{"operations": true, "training": true}'),
    
    -- Management (Level 10-20)
    ('00000000-0000-0000-0000-000000000045', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000032', 'QA Director', 'QAD', 10, true, 'active', '{"qa": true, "training": true}'),
    ('00000000-0000-0000-0000-000000000046', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000032', 'Production Director', 'PRD', 10, true, 'active', '{"production": true, "training": true}'),
    ('00000000-0000-0000-0000-000000000047', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000032', 'Training Manager', 'TRM', 15, true, 'active', '{"training": true, "courses": true, "assessments": true}'),
    ('00000000-0000-0000-0000-000000000048', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000032', 'QC Manager', 'QCM', 15, true, 'active', '{"qc": true, "training": true}'),
    ('00000000-0000-0000-0000-000000000049', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000032', 'HR Manager', 'HRM', 15, true, 'active', '{"hr": true, "employees": true}'),
    
    -- Supervisory (Level 30-50)
    ('00000000-0000-0000-0000-000000000051', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000033', 'QA Supervisor', 'QAS', 30, true, 'active', '{"qa": "read", "training": "read"}'),
    ('00000000-0000-0000-0000-000000000052', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000033', 'Production Supervisor', 'PRS', 30, true, 'active', '{"production": "read", "training": "read"}'),
    ('00000000-0000-0000-0000-000000000053', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000033', 'QC Supervisor', 'QCS', 30, true, 'active', '{"qc": "read", "training": "read"}'),
    ('00000000-0000-0000-0000-000000000054', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000033', 'Warehouse Supervisor', 'WHS', 30, true, 'active', '{"warehouse": "read", "training": "read"}'),
    
    -- Professional (Level 60-70)
    ('00000000-0000-0000-0000-000000000061', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000034', 'QA Specialist', 'QASP', 60, true, 'active', '{"training": "self"}'),
    ('00000000-0000-0000-0000-000000000062', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000034', 'QC Analyst', 'QCAN', 60, true, 'active', '{"training": "self"}'),
    ('00000000-0000-0000-0000-000000000063', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000034', 'Trainer', 'TRNR', 50, true, 'active', '{"training": true, "courses": "read"}'),
    
    -- Operational (Level 80-90)
    ('00000000-0000-0000-0000-000000000071', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000035', 'Production Operator', 'PROP', 80, true, 'active', '{"training": "self"}'),
    ('00000000-0000-0000-0000-000000000072', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000035', 'Warehouse Associate', 'WHA', 80, true, 'active', '{"training": "self"}'),
    ('00000000-0000-0000-0000-000000000073', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000035', 'Lab Technician', 'LABT', 70, true, 'active', '{"training": "self"}'),
    
    -- Non-login roles
    ('00000000-0000-0000-0000-000000000081', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000035', 'Contract Worker', 'CONT', 90, false, 'active', '{"training": "self"}'),
    ('00000000-0000-0000-0000-000000000082', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000036', 'Visitor', 'VIST', 99, false, 'active', '{}')
ON CONFLICT DO NOTHING;

-- Permissions
INSERT INTO permissions (id, organization_id, name, unique_code, category, actions) VALUES
    ('00000000-0000-0000-0000-000000000091', '00000000-0000-0000-0000-000000000001', 'Manage Courses', 'courses.manage', 'training', '["create", "read", "update", "delete", "approve"]'),
    ('00000000-0000-0000-0000-000000000092', '00000000-0000-0000-0000-000000000001', 'View Courses', 'courses.view', 'training', '["read"]'),
    ('00000000-0000-0000-0000-000000000093', '00000000-0000-0000-0000-000000000001', 'Manage Documents', 'documents.manage', 'documents', '["create", "read", "update", "delete", "approve"]'),
    ('00000000-0000-0000-0000-000000000094', '00000000-0000-0000-0000-000000000001', 'Manage Employees', 'employees.manage', 'identity', '["create", "read", "update", "delete"]'),
    ('00000000-0000-0000-0000-000000000095', '00000000-0000-0000-0000-000000000001', 'View Reports', 'reports.view', 'analytics', '["read"]'),
    ('00000000-0000-0000-0000-000000000096', '00000000-0000-0000-0000-000000000001', 'Manage Assessments', 'assessments.manage', 'assessment', '["create", "read", "update", "delete", "approve"]'),
    ('00000000-0000-0000-0000-000000000097', '00000000-0000-0000-0000-000000000001', 'Approve Training', 'training.approve', 'training', '["approve", "reject"]'),
    ('00000000-0000-0000-0000-000000000098', '00000000-0000-0000-0000-000000000001', 'System Admin', 'system.admin', 'system', '["all"]')
ON CONFLICT DO NOTHING;
