-- ===========================================
-- SEED DATA: COURSES MODULE
-- categories / subjects / topics / courses / trainers / venues / feedback templates
-- ===========================================

INSERT INTO categories (id, organization_id, name, unique_code, description, is_active, status) VALUES
('60000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','GMP','GMP','Good Manufacturing Practice',true,'active'),
('60000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Safety','SAFETY','Workplace & process safety',true,'active'),
('60000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Quality','QUALITY','Quality systems',true,'active'),
('60000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Regulatory','REG','Regulatory affairs',true,'active'),
('60000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','Soft Skills','SOFT','Behavioral / soft skills',true,'active')
ON CONFLICT DO NOTHING;

INSERT INTO subjects (id, organization_id, category_id, name, unique_code, description, is_active, status) VALUES
('61000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','Cleanroom Behavior','CLEAN','Behavior in Grade A/B/C/D areas',true,'active'),
('61000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000001','Documentation Practices','DOC','GMP documentation & data integrity',true,'active'),
('61000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','Fire Safety','FIRE','Fire prevention & response',true,'active'),
('61000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000002','Chemical Handling','CHEM','Hazardous chemical handling',true,'active'),
('61000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','60000000-0000-0000-0000-000000000003','Deviation Management','DEV','Deviation investigation',true,'active')
ON CONFLICT DO NOTHING;

INSERT INTO topics (id, organization_id, name, unique_code, description, estimated_duration_minutes,
                    is_active, status) VALUES
('62000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Cleanroom Entry','TOP-CR-ENTRY','Entering Grade A/B cleanroom',30,true,'active'),
('62000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','ALCOA+ Principles','TOP-ALCOA','Data integrity principles',45,true,'active'),
('62000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Fire Extinguisher Use','TOP-FIRE-EXT','Hands-on extinguisher drill',20,true,'active'),
('62000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Deviation Reporting','TOP-DEV-RPT','Reporting deviations in eQMS',30,true,'active'),
('62000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','MSDS Reading','TOP-MSDS','Reading & interpreting MSDS',25,true,'active')
ON CONFLICT DO NOTHING;

INSERT INTO topic_subject_tags (topic_id, subject_id) VALUES
('62000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-000000000001'),
('62000000-0000-0000-0000-000000000002','61000000-0000-0000-0000-000000000002'),
('62000000-0000-0000-0000-000000000003','61000000-0000-0000-0000-000000000003'),
('62000000-0000-0000-0000-000000000004','61000000-0000-0000-0000-000000000005'),
('62000000-0000-0000-0000-000000000005','61000000-0000-0000-0000-000000000004')
ON CONFLICT DO NOTHING;

INSERT INTO topic_document_links (topic_id, document_id, sequence_number) VALUES
('62000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000001',1),
('62000000-0000-0000-0000-000000000002','51000000-0000-0000-0000-000000000003',1)
ON CONFLICT DO NOTHING;

INSERT INTO courses (id, organization_id, plant_id, name, unique_code, description,
                     course_type, training_types, self_study, frequency_months,
                     assessment_required, pass_mark, max_attempts,
                     certificate_validity_months, sop_number, effective_date,
                     estimated_duration_minutes, status, approved_at, approved_by) VALUES
('63000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',NULL,
 'Cleanroom Entry Training','CRSE-CR-001','Gowning & behavior in cleanrooms',
 'recurring',ARRAY['gmp']::training_type[],false,12,
 true,80.00,3,12,'QA-SOP-001','2026-01-15',45,'active','2026-01-10','10000000-0000-0000-0000-000000000002'),
('63000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',NULL,
 'Data Integrity Fundamentals','CRSE-DI-001','ALCOA+ & 21 CFR Part 11',
 'one_time',ARRAY['gmp','regulatory']::training_type[],true,NULL,
 true,85.00,3,NULL,'POL-DI-001','2026-01-01',60,'active','2025-12-20','10000000-0000-0000-0000-000000000002'),
('63000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',NULL,
 'Fire Safety & Emergency Response','CRSE-FIRE-001','Annual fire drill training',
 'recurring',ARRAY['safety']::training_type[],false,12,
 true,70.00,2,12,NULL,'2026-02-01',30,'active','2026-01-25','10000000-0000-0000-0000-000000000002'),
('63000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001',NULL,
 'Deviation & CAPA Handling','CRSE-DEV-001','Quality event lifecycle',
 'refresher',ARRAY['quality']::training_type[],false,24,
 true,75.00,3,24,NULL,'2026-03-01',90,'active','2026-02-15','10000000-0000-0000-0000-000000000002'),
('63000000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000013',
 'Aseptic Techniques','CRSE-ASEP-001','Aseptic behavior in sterile mfg',
 'recurring',ARRAY['gmp','technical']::training_type[],false,6,
 true,90.00,2,6,'WI-STR-010','2026-03-01',120,'active','2026-02-20','10000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

INSERT INTO course_topics (course_id, topic_id, order_index, is_mandatory) VALUES
('63000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',1,true),
('63000000-0000-0000-0000-000000000002','62000000-0000-0000-0000-000000000002',1,true),
('63000000-0000-0000-0000-000000000003','62000000-0000-0000-0000-000000000003',1,true),
('63000000-0000-0000-0000-000000000004','62000000-0000-0000-0000-000000000004',1,true),
('63000000-0000-0000-0000-000000000005','62000000-0000-0000-0000-000000000001',1,true)
ON CONFLICT DO NOTHING;

INSERT INTO course_subgroup_access (course_id, subgroup_id, is_mandatory) VALUES
('63000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000003',true),
('63000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000004',true),
('63000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000001',true),
('63000000-0000-0000-0000-000000000002','21000000-0000-0000-0000-000000000002',true),
('63000000-0000-0000-0000-000000000005','21000000-0000-0000-0000-000000000004',true)
ON CONFLICT DO NOTHING;

INSERT INTO trainers (id, organization_id, employee_id, expertise, experience_years,
                      is_internal, status, is_active) VALUES
('64000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000009',
 ARRAY['GMP','Cleanroom','Aseptic'],8,true,'active',true),
('64000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004',
 ARRAY['QA','Deviation','Data Integrity'],5,true,'active',true)
ON CONFLICT DO NOTHING;

INSERT INTO external_trainers (id, organization_id, name, email, phone, organization, expertise,
                               experience_years, contract_type, contract_valid_until, status, is_active) VALUES
('64100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
 'Dr. Sanjeev Kulkarni','sanjeev@pharmaconsult.example','+91-98-1234-5678',
 'PharmaConsult India',ARRAY['Sterile Mfg','FDA Inspections'],20,'per_session','2026-12-31','active',true)
ON CONFLICT DO NOTHING;

INSERT INTO trainer_courses (trainer_id, course_id, is_primary_trainer) VALUES
('64000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001',true),
('64000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000005',true),
('64000000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000002',true),
('64000000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000004',true)
ON CONFLICT DO NOTHING;

INSERT INTO training_venues (id, organization_id, plant_id, name, unique_code, venue_type,
                             address_line1, capacity_inperson, capacity_virtual, is_active) VALUES
('65000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','Training Room A','VEN-HQ-A','classroom','HQ Bldg 1',30,0,true),
('65000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','Shop-Floor Training Hall','VEN-P1-1','classroom','Plant 1 Admin Bldg',50,0,true),
('65000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',NULL,'Virtual Meeting Room 1','VEN-VIRT-1','virtual','MS Teams',0,100,true)
ON CONFLICT DO NOTHING;

INSERT INTO satisfaction_scales (id, organization_id, scale_name, scale_points, scale_labels, is_default) VALUES
('66000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','5-pt Likert',5,
 '[{"value":1,"label":"Strongly Disagree"},{"value":2,"label":"Disagree"},{"value":3,"label":"Neutral"},{"value":4,"label":"Agree"},{"value":5,"label":"Strongly Agree"}]',true)
ON CONFLICT DO NOTHING;

INSERT INTO feedback_evaluation_templates (id, organization_id, name, description, template_type,
                                           questions, is_active) VALUES
('67000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Post-Training Feedback',
 'Standard feedback after every session','feedback',
 '[
   {"q":"The training objectives were clearly stated","type":"likert","scale_id":"66000000-0000-0000-0000-000000000001"},
   {"q":"The trainer was knowledgeable","type":"likert","scale_id":"66000000-0000-0000-0000-000000000001"},
   {"q":"Content was relevant to my job","type":"likert","scale_id":"66000000-0000-0000-0000-000000000001"},
   {"q":"What would you improve?","type":"text"}
 ]',true),
('67000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Long-Term Training Effectiveness',
 '3-month post-training evaluation','long_term_evaluation',
 '[
   {"q":"Are you applying the learning on the job?","type":"likert","scale_id":"66000000-0000-0000-0000-000000000001"},
   {"q":"Describe one real-world example","type":"text"}
 ]',true)
ON CONFLICT DO NOTHING;
