-- ===========================================
-- SEED DATA: COMPLIANCE MODULE
-- training records, certificates, assignments, waivers, matrix, competencies
-- ===========================================

-- Certificate templates
INSERT INTO certificate_templates (id, organization_id, name, description, html_template,
                                   qr_code_enabled, digital_signature_enabled, validity_months,
                                   is_default, created_by, is_active) VALUES
('90000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Standard Training Certificate','Default certificate template',
 '<html><body><h1>Certificate of Training</h1><p>{{employee_name}} has completed {{course_name}}</p></body></html>',
 true,true,12,true,'10000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

-- Training records
INSERT INTO training_records (id, organization_id, employee_id, course_id, session_id,
                              training_type, enrollment_source, start_date, completion_date,
                              training_result, marks_obtained, pass_mark, assessment_attempt_id,
                              duration_hours, supervisor_id) VALUES
('91000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','63000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001',
 'gmp','invitation','2026-02-05','2026-02-05','pass',9,8,'84000000-0000-0000-0000-000000000001',1.5,'10000000-0000-0000-0000-000000000005'),
('91000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007','63000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000001',
 'gmp','invitation','2026-02-05','2026-02-05','fail',6,8,'84000000-0000-0000-0000-000000000002',1.5,'10000000-0000-0000-0000-000000000005'),
('91000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','63000000-0000-0000-0000-000000000003','72000000-0000-0000-0000-000000000002',
 'safety','invitation','2026-02-10','2026-02-10','pass',5,3.5,'84000000-0000-0000-0000-000000000003',1.5,'10000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

-- Certificates
INSERT INTO certificates (id, organization_id, employee_id, training_record_id, certificate_template_id,
                          certificate_number, issued_date, expiry_date, certificate_status, qr_code_data,
                          is_active) VALUES
('92000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','91000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-000000000001',
 'ACME-2026-CR-0001','2026-02-05','2027-02-05','active','https://verify.acmepharma.com/c/ACME-2026-CR-0001',true),
('92000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','91000000-0000-0000-0000-000000000003','90000000-0000-0000-0000-000000000001',
 'ACME-2026-FIRE-0001','2026-02-10','2027-02-10','active','https://verify.acmepharma.com/c/ACME-2026-FIRE-0001',true)
ON CONFLICT DO NOTHING;

-- Training assignments
INSERT INTO training_assignments (id, organization_id, assignment_name, assignment_type, assignment_source,
                                  applicable_roles, applicable_subgroups, courses, due_date, priority,
                                  is_mandatory, auto_enroll, assignment_status, created_by, is_active) VALUES
('93000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Annual GMP Refresher 2026','role','training_matrix',
 ARRAY['00000000-0000-0000-0000-000000000001011']::UUID[],
 ARRAY['21000000-0000-0000-0000-000000000003']::UUID[],
 ARRAY['63000000-0000-0000-0000-000000000001']::UUID[],
 '2026-02-28','high',true,true,'assigned','10000000-0000-0000-0000-000000000001',true),
('93000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','SOP-QA-001 v3.0 Read & Ack','sop_update','sop_update',
 NULL,ARRAY['21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000003']::UUID[],
 ARRAY['63000000-0000-0000-0000-000000000001']::UUID[],
 '2026-02-15','high',true,true,'assigned','10000000-0000-0000-0000-000000000004',true)
ON CONFLICT DO NOTHING;

INSERT INTO employee_assignments (id, organization_id, assignment_id, employee_id, assigned_date,
                                  due_date, status, acknowledged_at, completion_date, priority) VALUES
('93100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006',
 '2026-01-20','2026-02-28','completed','2026-01-21 09:00+05:30','2026-02-05','high'),
('93100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',
 '2026-01-20','2026-02-28','in_progress','2026-01-21 09:30+05:30',NULL,'high'),
('93100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004',
 '2026-01-15','2026-02-15','acknowledged','2026-01-16 10:00+05:30',NULL,'high')
ON CONFLICT DO NOTHING;

-- Training matrix
INSERT INTO training_matrix (id, organization_id, name, unique_code, description, version,
                             effective_date, created_by, is_active) VALUES
('94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Acme 2026 Training Matrix','MTX-2026','Role-based mandatory training requirements',
 '1.0','2026-01-01','10000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

INSERT INTO training_matrix_items (id, training_matrix_id, role_id, course_id, is_mandatory,
                                   frequency_months, valid_from) VALUES
('94100000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001011','63000000-0000-0000-0000-000000000001',true,12,'2026-01-01'),
('94100000-0000-0000-0000-000000000002','94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001011','63000000-0000-0000-0000-000000000003',true,12,'2026-01-01'),
('94100000-0000-0000-0000-000000000003','94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001007','63000000-0000-0000-0000-000000000002',true,NULL,'2026-01-01'),
('94100000-0000-0000-0000-000000000004','94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001007','63000000-0000-0000-0000-000000000004',true,24,'2026-01-01'),
('94100000-0000-0000-0000-000000000005','94000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001010','63000000-0000-0000-0000-000000000005',true,6,'2026-01-01')
ON CONFLICT DO NOTHING;

-- Waivers
INSERT INTO training_waivers (id, organization_id, employee_id, course_id, reason, waiver_type,
                              valid_from, valid_until, waived_by, waived_at, approval_status, is_active) VALUES
('95000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000010','63000000-0000-0000-0000-000000000001',
 'External regulatory expert with 10+ years GMP auditing experience','prior_experience',
 '2026-01-01','2026-12-31','10000000-0000-0000-0000-000000000002','2026-01-05 14:00+05:30','approved',true)
ON CONFLICT DO NOTHING;

INSERT INTO waiver_approval_history (id, training_waiver_id, action, performed_by, performed_at, comments) VALUES
('95100000-0000-0000-0000-000000000001','95000000-0000-0000-0000-000000000001','submitted','10000000-0000-0000-0000-000000000010','2026-01-03 09:00+05:30','Request with CV & evidence'),
('95100000-0000-0000-0000-000000000002','95000000-0000-0000-0000-000000000001','approved','10000000-0000-0000-0000-000000000002','2026-01-05 14:00+05:30','Evidence verified - WAV001 applies')
ON CONFLICT DO NOTHING;

-- Competencies
INSERT INTO competencies (id, organization_id, name, unique_code, description, competency_level,
                          is_mandatory, validation_required, is_active) VALUES
('96000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Aseptic Gowning','COMP-ASG','Ability to gown for Grade A/B','intermediate',true,true,true),
('96000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Deviation Investigation','COMP-DEV','Lead root cause analysis','advanced',true,true,true),
('96000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Data Integrity','COMP-DI','ALCOA+ in practice','foundation',true,true,true)
ON CONFLICT DO NOTHING;

INSERT INTO role_competencies (id, role_id, competency_id, proficiency_level, is_mandatory, validation_method) VALUES
('96100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001010','96000000-0000-0000-0000-000000000001','intermediate',true,'observation'),
('96100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001007','96000000-0000-0000-0000-000000000002','advanced',true,'case_study'),
('96100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001004','96000000-0000-0000-0000-000000000003','foundation',true,'assessment')
ON CONFLICT DO NOTHING;

INSERT INTO employee_competencies (id, organization_id, employee_id, competency_id, proficiency_level,
                                   validated, validated_by, validated_at, expiry_date) VALUES
('96200000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000008','96000000-0000-0000-0000-000000000001','intermediate',
 true,'10000000-0000-0000-0000-000000000002','2025-12-15','2026-12-15'),
('96200000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004','96000000-0000-0000-0000-000000000002','advanced',
 true,'10000000-0000-0000-0000-000000000002','2026-01-20','2028-01-20'),
('96200000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','96000000-0000-0000-0000-000000000003','foundation',
 true,'10000000-0000-0000-0000-000000000004','2026-03-05','2027-03-05')
ON CONFLICT DO NOTHING;

INSERT INTO competency_gaps (id, organization_id, employee_id, competency_id, gap_identified_date,
                             required_proficiency, current_proficiency) VALUES
('96300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007','96000000-0000-0000-0000-000000000001',
 '2026-02-06','intermediate','foundation')
ON CONFLICT DO NOTHING;
