-- ===========================================
-- SEED DATA: IDENTITY (role categories, roles, employees, groups, biometrics)
-- All tables are in `public` schema.
-- ===========================================

-- Role Categories (login / non_login)
INSERT INTO role_categories (id, name, category, description, is_system, is_active) VALUES
('00000000-0000-0000-0000-000000000101','Executive','login','C-suite / board roles',true,true),
('00000000-0000-0000-0000-000000000102','Senior Management','login','Plant heads, directors',true,true),
('00000000-0000-0000-0000-000000000103','Manager','login','Functional managers',true,true),
('00000000-0000-0000-0000-000000000104','Supervisor','login','Shop floor supervisors',true,true),
('00000000-0000-0000-0000-000000000105','Operator','non_login','Shop-floor operators (biometric)',true,true),
('00000000-0000-0000-0000-000000000106','Technician','login','Technicians',true,true),
('00000000-0000-0000-0000-000000000107','Auditor','login','Internal / external auditors',true,true),
('00000000-0000-0000-0000-000000000108','Trainer','login','Designated trainers',true,true),
('00000000-0000-0000-0000-000000000109','Guest','login','Visitor / contractor',true,true)
ON CONFLICT DO NOTHING;

-- Roles (Learn-IQ levels: 1 = highest authority, 99.99 = lowest)
INSERT INTO roles (id, organization_id, name, display_name, description, level, category, role_category_id,
                   is_global, can_approve, max_approval_level, is_system_role, is_admin_role, is_active, status) VALUES
('00000000-0000-0000-0000-000000001001','00000000-0000-0000-0000-000000000001','super_admin','Super Admin','Platform super admin',1.00,'login','00000000-0000-0000-0000-000000000101',true,true,1.00,true,true,true,'active'),
('00000000-0000-0000-0000-000000001002','00000000-0000-0000-0000-000000000001','org_admin','Organization Admin','Org-level admin',2.00,'login','00000000-0000-0000-0000-000000000101',true,true,2.00,true,true,true,'active'),
('00000000-0000-0000-0000-000000001003','00000000-0000-0000-0000-000000000001','plant_head','Plant Head','Site head',3.00,'login','00000000-0000-0000-0000-000000000102',false,true,3.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001004','00000000-0000-0000-0000-000000000001','qa_head','QA Head','Quality Assurance head',4.00,'login','00000000-0000-0000-0000-000000000102',false,true,4.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001005','00000000-0000-0000-0000-000000000001','training_manager','Training Manager','L&D manager',5.00,'login','00000000-0000-0000-0000-000000000103',false,true,5.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001006','00000000-0000-0000-0000-000000000001','production_manager','Production Manager','Production manager',5.00,'login','00000000-0000-0000-0000-000000000103',false,true,5.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001007','00000000-0000-0000-0000-000000000001','qa_manager','QA Manager','QA manager',5.00,'login','00000000-0000-0000-0000-000000000103',false,true,5.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001008','00000000-0000-0000-0000-000000000001','supervisor','Supervisor','Shop-floor supervisor',7.00,'login','00000000-0000-0000-0000-000000000104',false,true,7.00,true,false,true,'active'),
('00000000-0000-0000-0000-000000001009','00000000-0000-0000-0000-000000000001','trainer','Trainer','Designated trainer',6.00,'login','00000000-0000-0000-0000-000000000108',false,false,NULL,true,false,true,'active'),
('00000000-0000-0000-0000-000000001010','00000000-0000-0000-0000-000000000001','technician','Technician','Technician',8.00,'login','00000000-0000-0000-0000-000000000106',false,false,NULL,true,false,true,'active'),
('00000000-0000-0000-0000-000000001011','00000000-0000-0000-0000-000000000001','operator','Operator','Shop-floor operator',9.00,'non_login','00000000-0000-0000-0000-000000000105',false,false,NULL,true,false,true,'active'),
('00000000-0000-0000-0000-000000001012','00000000-0000-0000-0000-000000000001','auditor','Auditor','Internal auditor',4.50,'login','00000000-0000-0000-0000-000000000107',false,true,4.50,true,false,true,'active'),
('00000000-0000-0000-0000-000000001013','00000000-0000-0000-0000-000000000001','visitor','Visitor / Contractor','Visitor/contractor',99.00,'login','00000000-0000-0000-0000-000000000109',false,false,NULL,true,false,true,'active')
ON CONFLICT DO NOTHING;

-- Employees (mix of login & non-login / biometric-only)
INSERT INTO employees (id, organization_id, plant_id, department_id, employee_id,
                       first_name, last_name, email, designation, job_title,
                       hire_date, employee_type, reporting_to, status) VALUES
('10000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000027','EMP001','Alice','Smith','alice.smith@acmepharma.com','Training Manager','Head of L&D','2023-04-01','permanent',NULL,'active'),
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000022','EMP002','Rajesh','Menon','rajesh.menon@acmepharma.com','QA Head','Head Quality Assurance','2022-06-15','permanent',NULL,'active'),
('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000023','EMP003','Kavita','Rao','kavita.rao@acmepharma.com','Production Manager','P1 Production Manager','2022-09-01','permanent','10000000-0000-0000-0000-000000000002','active'),
('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000024','EMP004','Priya','Sharma','priya.sharma@acmepharma.com','QA Manager','P1 QA Manager','2023-01-10','permanent','10000000-0000-0000-0000-000000000002','active'),
('10000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000023','EMP005','Vikram','Iyer','vikram.iyer@acmepharma.com','Supervisor','Production Supervisor','2023-03-20','permanent','10000000-0000-0000-0000-000000000003','active'),
('10000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000023','EMP006','Ramesh','Kumar','ramesh.kumar@acmepharma.com','Operator','Packing Operator','2024-02-01','contract','10000000-0000-0000-0000-000000000005','active'),
('10000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000023','EMP007','Suresh','Babu','suresh.babu@acmepharma.com','Operator','Granulation Operator','2024-02-05','contract','10000000-0000-0000-0000-000000000005','active'),
('10000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000025','EMP008','Anita','Desai','anita.desai@acmepharma.com','Technician','Sterile Technician','2023-11-11','permanent','10000000-0000-0000-0000-000000000002','active'),
('10000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000027','EMP009','Mohit','Joshi','mohit.joshi@acmepharma.com','Trainer','Lead Trainer','2022-12-01','permanent','10000000-0000-0000-0000-000000000002','active'),
('10000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000026','EMP010','Neha','Kapoor','neha.kapoor@acmepharma.com','Regulatory Officer','Regulatory Affairs Lead','2023-07-20','permanent','10000000-0000-0000-0000-000000000002','active')
ON CONFLICT DO NOTHING;

-- Employee role assignments
INSERT INTO employee_roles (employee_id, role_id, is_primary, valid_from, is_active) VALUES
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001004',true,'2022-06-15',true),
('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001006',true,'2022-09-01',true),
('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001007',true,'2023-01-10',true),
('10000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001008',true,'2023-03-20',true),
('10000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000001011',true,'2024-02-01',true),
('10000000-0000-0000-0000-000000000007','00000000-0000-0000-0000-000000000001011',true,'2024-02-05',true),
('10000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000001010',true,'2023-11-11',true),
('10000000-0000-0000-0000-000000000009','00000000-0000-0000-0000-000000000001009',true,'2022-12-01',true),
('10000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000001012',true,'2023-07-20',true)
ON CONFLICT DO NOTHING;

-- Groups / Subgroups
INSERT INTO groups (id, organization_id, name, unique_code, description, is_active, status) VALUES
('20000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Quality','QUALITY','Quality function group',true,'active'),
('20000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Production','PRODUCTION','Production function group',true,'active'),
('20000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Regulatory','REGULATORY','Regulatory / compliance group',true,'active')
ON CONFLICT DO NOTHING;

INSERT INTO subgroups (id, organization_id, name, unique_code, description, is_active, status) VALUES
('21000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','QA Team','QA-TEAM','Quality Assurance personnel',true,'active'),
('21000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','QC Analysts','QC-ANALYSTS','Quality Control analysts',true,'active'),
('21000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Shop-Floor Operators','OPERATORS','Production operators',true,'active'),
('21000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Sterile Techs','STERILE-TECH','Sterile manufacturing techs',true,'active')
ON CONFLICT DO NOTHING;

INSERT INTO group_subgroups (group_id, subgroup_id, display_order) VALUES
('20000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000001',1),
('20000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000002',2),
('20000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000003',1),
('20000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000004',2)
ON CONFLICT DO NOTHING;

INSERT INTO employee_subgroups (employee_id, subgroup_id, is_primary, valid_from, is_active) VALUES
('10000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001',true,'2022-06-15',true),
('10000000-0000-0000-0000-000000000004','21000000-0000-0000-0000-000000000001',true,'2023-01-10',true),
('10000000-0000-0000-0000-000000000006','21000000-0000-0000-0000-000000000003',true,'2024-02-01',true),
('10000000-0000-0000-0000-000000000007','21000000-0000-0000-0000-000000000003',true,'2024-02-05',true),
('10000000-0000-0000-0000-000000000008','21000000-0000-0000-0000-000000000004',true,'2023-11-11',true)
ON CONFLICT DO NOTHING;

-- Job Responsibilities
INSERT INTO job_responsibilities (id, organization_id, employee_id, designation, department_id,
                                  date_of_joining, reporting_to_name, reporting_to_designation,
                                  job_responsibility, is_active, status) VALUES
('30000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','QA Manager','00000000-0000-0000-0000-000000000024',
 '2023-01-10','Rajesh Menon','QA Head','Ensure GMP compliance in P1. Review & approve batch records. Host regulatory audits.',true,'active'),
('30000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000005','Supervisor','00000000-0000-0000-0000-000000000023',
 '2023-03-20','Kavita Rao','Production Manager','Supervise granulation & compression shifts. Validate operator training before task assignment.',true,'active')
ON CONFLICT DO NOTHING;

-- Biometric registrations (for non-login operators)
INSERT INTO biometric_registrations (id, organization_id, employee_id, biometric_type, finger_index,
                                     template_hash, template_quality, device_id, registration_type,
                                     is_active, is_verified) VALUES
('40000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','fingerprint',1,
 encode(digest('demo-op-006-finger-1','sha256'),'hex'),92,'BIO-P1-01','admin',true,true),
('40000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007','fingerprint',1,
 encode(digest('demo-op-007-finger-1','sha256'),'hex'),88,'BIO-P1-01','admin',true,true)
ON CONFLICT DO NOTHING;
