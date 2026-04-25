-- ===========================================
-- SEED DATA: EXTENSIONS
-- Learning paths, gamification, KB, discussions, costs, prefs, content, surveys
-- ===========================================

-- LEARNING PATHS ----------------------------------------------------------
INSERT INTO learning_paths (id, organization_id, name, unique_code, description,
                            target_role_ids, estimated_hours, certification_on_completion,
                            path_status, status, is_active) VALUES
('12100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001',
 'New QA Analyst Onboarding Path','LP-QA-NEW','12-week structured onboarding',
 ARRAY['00000000-0000-0000-0000-000000000001007']::UUID[],40.0,true,'active','active',true),
('12100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',
 'Aseptic Operator Certification','LP-ASEP','Sterile facility certification path',
 ARRAY['00000000-0000-0000-0000-000000000001010']::UUID[],30.0,true,'active','active',true)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_steps (id, learning_path_id, step_order, step_type, referenced_id,
                                 is_mandatory, unlock_delay_days) VALUES
('12110000-0000-0000-0000-000000000001','12100000-0000-0000-0000-000000000001',1,'induction','77000000-0000-0000-0000-000000000001',true,0),
('12110000-0000-0000-0000-000000000002','12100000-0000-0000-0000-000000000001',2,'course','63000000-0000-0000-0000-000000000001',true,0),
('12110000-0000-0000-0000-000000000003','12100000-0000-0000-0000-000000000001',3,'course','63000000-0000-0000-0000-000000000002',true,7),
('12110000-0000-0000-0000-000000000004','12100000-0000-0000-0000-000000000001',4,'course','63000000-0000-0000-0000-000000000004',true,14),
('12110000-0000-0000-0000-000000000005','12100000-0000-0000-0000-000000000002',1,'course','63000000-0000-0000-0000-000000000001',true,0),
('12110000-0000-0000-0000-000000000006','12100000-0000-0000-0000-000000000002',2,'course','63000000-0000-0000-0000-000000000005',true,7),
('12110000-0000-0000-0000-000000000007','12100000-0000-0000-0000-000000000002',3,'ojt','78000000-0000-0000-0000-000000000001',true,14)
ON CONFLICT DO NOTHING;

INSERT INTO course_prerequisites (id, course_id, prerequisite_kind, prerequisite_id, is_hard_block) VALUES
('12120000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000005','course','63000000-0000-0000-0000-000000000001',true),
('12120000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000004','course','63000000-0000-0000-0000-000000000002',false)
ON CONFLICT DO NOTHING;

INSERT INTO learning_path_enrollments (id, organization_id, learning_path_id, employee_id,
                                       enrolled_at, target_completion_date, progress_percent,
                                       enrollment_status) VALUES
('12130000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','12100000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000008',
 '2026-02-15 09:00+05:30','2026-04-15',33.33,'in_progress')
ON CONFLICT DO NOTHING;

-- GAMIFICATION ------------------------------------------------------------
INSERT INTO badges (id, organization_id, name, unique_code, description, tier, points_required, is_auto_award) VALUES
('12200000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','First Pass','BDG-FIRST-PASS','Passed first assessment on first attempt','bronze',10,true),
('12200000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Perfect Score','BDG-PERFECT','Scored 100% on any assessment','silver',50,true),
('12200000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','GMP Champion','BDG-GMP-CHAMP','Completed all GMP courses in a year','gold',500,true),
('12200000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Mentor','BDG-MENTOR','Answered 10 KB questions','silver',100,true)
ON CONFLICT DO NOTHING;

INSERT INTO point_rules (id, organization_id, event_type, points_awarded, is_active) VALUES
('12210000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','course_completed',25,true),
('12210000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','assessment_passed',10,true),
('12210000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','first_attempt_pass',15,true),
('12210000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','perfect_score',50,true),
('12210000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','certificate_earned',30,true),
('12210000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000001','feedback_submitted',5,true)
ON CONFLICT DO NOTHING;

INSERT INTO employee_badges (employee_id, badge_id, awarded_at, is_featured) VALUES
('10000000-0000-0000-0000-000000000006','12200000-0000-0000-0000-000000000001','2026-02-05 12:00+05:30',true),
('10000000-0000-0000-0000-000000000003','12200000-0000-0000-0000-000000000002','2026-02-10 16:00+05:30',true)
ON CONFLICT DO NOTHING;

INSERT INTO point_transactions (id, organization_id, employee_id, event_type, points,
                                source_entity_type, source_entity_id, awarded_at) VALUES
('12220000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','course_completed',25,'training_record','91000000-0000-0000-0000-000000000001','2026-02-05 12:00+05:30'),
('12220000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','first_attempt_pass',15,'assessment_result','85000000-0000-0000-0000-000000000001','2026-02-05 12:00+05:30'),
('12220000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','certificate_earned',30,'certificate','92000000-0000-0000-0000-000000000001','2026-02-05 12:05+05:30'),
('12220000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003','perfect_score',50,'assessment_result','85000000-0000-0000-0000-000000000003','2026-02-10 16:00+05:30')
ON CONFLICT DO NOTHING;

INSERT INTO employee_point_balances (employee_id, organization_id, total_points, current_level, last_activity_at) VALUES
('10000000-0000-0000-0000-000000000006','00000000-0000-0000-0000-000000000001',70,1,'2026-02-05 12:05+05:30'),
('10000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001',75,1,'2026-02-10 16:00+05:30')
ON CONFLICT DO NOTHING;

INSERT INTO leaderboards (id, organization_id, name, scope, time_window, metric, is_active) VALUES
('12230000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Top Learners - All Time','org','all_time','points',true),
('12230000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Monthly Course Leaders','org','monthly','courses_completed',true)
ON CONFLICT DO NOTHING;

-- KNOWLEDGE BASE ----------------------------------------------------------
INSERT INTO kb_categories (id, organization_id, name, unique_code, description, display_order) VALUES
('12300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','How-To Guides','KB-HOWTO','Step-by-step guides',1),
('12300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','FAQ','KB-FAQ','Frequently asked questions',2),
('12300000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Regulatory Reference','KB-REG','Regulatory guidance',3)
ON CONFLICT DO NOTHING;

INSERT INTO kb_articles (id, organization_id, category_id, title, slug, summary, body_markdown,
                         tags, visibility, article_status, published_at, published_by,
                         next_review_due, created_by) VALUES
('12310000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','12300000-0000-0000-0000-000000000001',
 'How to Request a Training Waiver','how-to-request-training-waiver',
 'Step-by-step waiver request process','# Request a Training Waiver\n\n1. Go to My Training\n2. Click "Request Waiver"\n3. Select course, waiver type, reason\n4. Attach evidence\n5. Submit\n\nYour QA Head reviews within 5 business days.',
 ARRAY['waiver','training','process'],'organization','published','2026-01-15 10:00+05:30',
 '10000000-0000-0000-0000-000000000001','2027-01-15','10000000-0000-0000-0000-000000000001'),
('12310000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','12300000-0000-0000-0000-000000000002',
 'Why did I get "prerequisite not met"?','faq-prerequisite-not-met',
 'Prerequisite courses must be completed first',
 '# Prerequisite Error\n\nThis means a prior course/GTP must be completed before enrolling. Check the course detail page for prerequisites.',
 ARRAY['faq','prerequisite','enrollment'],'organization','published','2026-02-01 10:00+05:30',
 '10000000-0000-0000-0000-000000000001','2027-02-01','10000000-0000-0000-0000-000000000001'),
('12310000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','12300000-0000-0000-0000-000000000003',
 '21 CFR Part 11 Electronic Signature Requirements','21-cfr-part-11-esig',
 'Summary of 21 CFR Part 11 e-signature requirements',
 '# 21 CFR Part 11\n\n**Electronic signatures must include:**\n- Printed name\n- Date and time\n- Meaning (approval, review, acknowledgement)\n- Two-factor authentication (password + biometric)\n- Immutable linkage to record (hash chain)',
 ARRAY['regulatory','21cfr','esignature'],'organization','published','2026-01-20 10:00+05:30',
 '10000000-0000-0000-0000-000000000010','2028-01-20','10000000-0000-0000-0000-000000000010')
ON CONFLICT DO NOTHING;

INSERT INTO kb_article_feedback (article_id, employee_id, was_helpful, comment) VALUES
('12310000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000010',true,'Very clear'),
('12310000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000006',true,NULL)
ON CONFLICT DO NOTHING;

-- DISCUSSIONS -------------------------------------------------------------
INSERT INTO discussion_threads (id, organization_id, scope, scope_id, title, body_markdown, tags,
                                is_question, thread_status, created_by) VALUES
('12400000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','course','63000000-0000-0000-0000-000000000005',
 'Do I need to wear double gloves for Grade A?','Is it always double gloves or only when handling API?',
 ARRAY['aseptic','ppe'],true,'open','10000000-0000-0000-0000-000000000008')
ON CONFLICT DO NOTHING;

INSERT INTO discussion_posts (id, thread_id, body_markdown, is_answer, author_id) VALUES
('12410000-0000-0000-0000-000000000001','12400000-0000-0000-0000-000000000001',
 'Double gloves are always required in Grade A - inner latex plus outer sterile nitrile. SOP-QA-001 v3.0 section 4.2.',
 true,'10000000-0000-0000-0000-000000000009')
ON CONFLICT DO NOTHING;

-- COST TRACKING -----------------------------------------------------------
INSERT INTO cost_centers (id, organization_id, plant_id, department_id, name, code,
                          owner_employee_id) VALUES
('12500000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000027',
 'L&D Corporate','CC-LND-001','10000000-0000-0000-0000-000000000001'),
('12500000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000024',
 'Plant 1 QA Training','CC-P1-QA','10000000-0000-0000-0000-000000000004')
ON CONFLICT DO NOTHING;

INSERT INTO training_budgets (id, organization_id, cost_center_id, period_type, period_start, period_end,
                              allocated_amount, committed_amount, spent_amount, currency, status) VALUES
('12510000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','12500000-0000-0000-0000-000000000001',
 'fiscal_year','2026-04-01','2027-03-31',2500000.00,450000.00,120000.00,'INR','active'),
('12510000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','12500000-0000-0000-0000-000000000002',
 'fiscal_year','2026-04-01','2027-03-31',800000.00,150000.00,45000.00,'INR','active')
ON CONFLICT DO NOTHING;

INSERT INTO course_costs (id, course_id, cost_category, per_participant_cost, fixed_cost) VALUES
('12520000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','trainer_fees',500.00,5000.00),
('12520000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000005','trainer_fees',1500.00,25000.00),
('12520000-0000-0000-0000-000000000003','63000000-0000-0000-0000-000000000005','materials',200.00,0.00)
ON CONFLICT DO NOTHING;

INSERT INTO training_expenses (id, organization_id, cost_center_id, session_id, course_id,
                               cost_category, amount, currency, expense_date, vendor, invoice_number,
                               participant_count, submitted_by, approval_status) VALUES
('12530000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','12500000-0000-0000-0000-000000000002',
 '72000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','trainer_fees',6500.00,'INR',
 '2026-02-05','Internal','INT-TRN-2026-001',3,'10000000-0000-0000-0000-000000000001','approved')
ON CONFLICT DO NOTHING;

-- USER PREFERENCES --------------------------------------------------------
INSERT INTO user_preferences (employee_id, organization_id, theme, language, timezone,
                              date_format, email_digest_frequency) VALUES
('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','dark','en','Asia/Kolkata','DD/MM/YYYY','daily'),
('10000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','light','en','Asia/Kolkata','DD/MM/YYYY','weekly'),
('10000000-0000-0000-0000-000000000008','00000000-0000-0000-0000-000000000001','system','en','Asia/Kolkata','DD/MM/YYYY','instant')
ON CONFLICT DO NOTHING;

INSERT INTO user_accessibility_needs (employee_id, need_type, accommodation_notes,
                                      requires_captions, requires_extended_time,
                                      extended_time_multiplier, verified_by, verified_at, valid_until) VALUES
('10000000-0000-0000-0000-000000000008','auditory','Partial hearing loss - needs captions on video',true,false,1.0,
 '10000000-0000-0000-0000-000000000001','2026-01-10','2027-01-10')
ON CONFLICT DO NOTHING;

-- CONTENT LIBRARY ---------------------------------------------------------
INSERT INTO content_assets (id, organization_id, name, description, content_type, duration_seconds,
                            language, thumbnail_url, tags, content_status, created_by) VALUES
('12600000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Cleanroom Gowning Demo','5-minute instructional video',
 'video',300,'en','https://cdn.acmepharma.com/thumbs/gown.jpg',ARRAY['video','cleanroom','gmp'],'ready','10000000-0000-0000-0000-000000000009'),
('12600000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','ALCOA+ Slides','Data integrity slide deck',
 'slideshow',NULL,'en',NULL,ARRAY['slides','data-integrity'],'ready','10000000-0000-0000-0000-000000000004'),
('12600000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Fire Drill - SCORM','Interactive SCORM 2004 package',
 'scorm',900,'en',NULL,ARRAY['scorm','fire','interactive'],'ready','10000000-0000-0000-0000-000000000009')
ON CONFLICT DO NOTHING;

INSERT INTO lessons (id, course_id, topic_id, title, description, lesson_order, estimated_minutes,
                     is_mandatory, completion_rule) VALUES
('12610000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',
 'Introduction to Cleanrooms','Overview of cleanroom classifications',1,10,true,'viewed'),
('12610000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',
 'Gowning Video Walkthrough','Watch the 5-min gowning demo',2,10,true,'full_watch'),
('12610000-0000-0000-0000-000000000003','63000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-000000000001',
 'Gowning Quiz','Brief quiz on gowning steps',3,5,true,'quiz_passed')
ON CONFLICT DO NOTHING;

INSERT INTO lesson_content (id, lesson_id, content_asset_id, display_order, is_primary) VALUES
('12620000-0000-0000-0000-000000000001','12610000-0000-0000-0000-000000000002','12600000-0000-0000-0000-000000000001',1,true)
ON CONFLICT DO NOTHING;

INSERT INTO scorm_packages (content_asset_id, scorm_version, launch_url, passing_score, mastery_threshold) VALUES
('12600000-0000-0000-0000-000000000003','2004_4','https://cdn.acmepharma.com/scorm/fire-drill/launch.html',70.00,80.00)
ON CONFLICT DO NOTHING;

INSERT INTO lesson_progress (employee_id, lesson_id, started_at, last_accessed_at, completed_at,
                             watch_percent, total_watch_seconds, current_position_seconds) VALUES
('10000000-0000-0000-0000-000000000006','12610000-0000-0000-0000-000000000002','2026-02-05 09:05+05:30','2026-02-05 09:10+05:30','2026-02-05 09:10+05:30',100.00,300,300)
ON CONFLICT DO NOTHING;

-- SURVEYS -----------------------------------------------------------------
INSERT INTO surveys (id, organization_id, name, unique_code, description, survey_purpose,
                     is_anonymous, target_subgroups, open_from, open_until, survey_status,
                     status, created_by) VALUES
('12700000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Q2 2026 Learning Pulse','SRV-PULSE-Q2',
 'Quick pulse check on learning culture','pulse',true,ARRAY['21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000003']::UUID[],
 '2026-04-15 09:00+05:30','2026-04-30 23:59+05:30','active','active','10000000-0000-0000-0000-000000000001'),
('12700000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Training NPS 2026','SRV-NPS-2026',
 'Annual training NPS','nps',false,NULL,
 '2026-03-01 09:00+05:30','2026-03-31 23:59+05:30','closed','approved','10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO survey_questions (id, survey_id, section_name, question_order, question_text,
                              question_kind, options_json, scale_min, scale_max, is_required) VALUES
('12710000-0000-0000-0000-000000000001','12700000-0000-0000-0000-000000000001','Learning',1,
 'How effective was your training this quarter?','likert',NULL,1,5,true),
('12710000-0000-0000-0000-000000000002','12700000-0000-0000-0000-000000000001','Learning',2,
 'What topics would you like to see added?','text_long',NULL,NULL,NULL,false),
('12710000-0000-0000-0000-000000000003','12700000-0000-0000-0000-000000000002','NPS',1,
 'How likely are you to recommend our training to a colleague?','nps',NULL,0,10,true)
ON CONFLICT DO NOTHING;
