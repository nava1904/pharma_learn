-- ===========================================
-- SEED DATA: NOTIFICATIONS
-- ===========================================

INSERT INTO notification_templates (id, organization_id, template_name, mail_template_type,
                                    subject_template, body_template, footer_template,
                                    is_system_template, is_active) VALUES
('C0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Course Invitation','course_invitation',
 'You are invited to: {{course_name}}',
 'Hi {{employee_name}},\n\nYou have been invited to attend {{course_name}} on {{session_date}} at {{venue}}.\n\nTrainer: {{trainer_name}}\n\nPlease confirm your attendance by {{deadline}}.',
 'PharmaLearn LMS - Acme Pharma Ltd.',true,true),
('C0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Result to Trainee','result_to_trainee',
 'Assessment Result: {{course_name}}',
 'Hi {{employee_name}},\n\nYour result for {{course_name}}: {{result}} ({{marks_obtained}}/{{total_marks}}).\n\n{{result_message}}',
 'PharmaLearn LMS',true,true),
('C0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Certificate Expiry Reminder','certificate_expiry_reminder',
 'Your {{course_name}} certificate expires in {{days_remaining}} days',
 'Hi {{employee_name}},\n\nYour certificate {{certificate_number}} will expire on {{expiry_date}}. Please schedule refresher training.',
 'PharmaLearn LMS',true,true),
('C0000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Document Reading Required','document_reading',
 '{{document_name}} v{{version}} - Read & Acknowledge',
 'Hi {{employee_name}},\n\n{{document_name}} has been updated to v{{version}}. Please read & acknowledge by {{deadline}}.',
 'PharmaLearn LMS',true,true)
ON CONFLICT DO NOTHING;

INSERT INTO notification_queue (id, organization_id, template_id, recipient_id, recipient_email,
                                channel, status, content, scheduled_time, sent_time) VALUES
('C1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','C0000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006','ramesh.kumar@acmepharma.com',
 'email','sent','{"subject":"You are invited to: Cleanroom Entry Training","body":"..."}','2026-01-28 09:00+05:30','2026-01-28 09:00+05:30'),
('C1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','C0000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000006','ramesh.kumar@acmepharma.com',
 'email','sent','{"subject":"Assessment Result: Cleanroom Entry","body":"PASS 9/10"}','2026-02-05 11:30+05:30','2026-02-05 11:30+05:30'),
('C1000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','C0000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000006','ramesh.kumar@acmepharma.com',
 'email','queued','{"subject":"Your Cleanroom certificate expires in 30 days","body":"..."}','2027-01-05 08:00+05:30',NULL)
ON CONFLICT DO NOTHING;

INSERT INTO notification_log (id, organization_id, notification_queue_id, recipient_id, channel,
                              status, delivery_timestamp, opened_at) VALUES
('C2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','C1000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006',
 'email','delivered','2026-01-28 09:00:12+05:30','2026-01-28 10:15+05:30'),
('C2000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','C1000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000006',
 'email','delivered','2026-02-05 11:30:05+05:30','2026-02-05 12:00+05:30')
ON CONFLICT DO NOTHING;

INSERT INTO user_notifications (id, organization_id, employee_id, subject, message, notification_type,
                                related_entity_type, related_entity_id, is_read, read_at) VALUES
('C3000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006',
 'Training Completed','You passed Cleanroom Entry Training.','success','training_record','91000000-0000-0000-0000-000000000001',true,'2026-02-05 12:00+05:30'),
('C3000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',
 'Retraining Required','You did not pass Cleanroom Entry. Retake scheduled.','warning','training_record','91000000-0000-0000-0000-000000000002',false,NULL)
ON CONFLICT DO NOTHING;

INSERT INTO notification_preferences (id, organization_id, employee_id, notification_type, channel,
                                      is_enabled, quiet_hours_start, quiet_hours_end) VALUES
('C4000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004',
 'course_invitation','email',true,'22:00','07:00'),
('C4000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004',
 'course_invitation','sms',false,NULL,NULL)
ON CONFLICT DO NOTHING;

INSERT INTO reminder_rules (id, organization_id, entity_type, trigger_event, days_before_event,
                            notification_template_id, is_active) VALUES
('C5000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','certificate','certificate_expiring',30,
 'C0000000-0000-0000-0000-000000000003',true),
('C5000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','certificate','certificate_expiring',7,
 'C0000000-0000-0000-0000-000000000003',true),
('C5000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','assignment','assignment_due',3,
 'C0000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

INSERT INTO escalation_rules (id, organization_id, entity_type, initial_delay_days, escalation_level_count,
                              notification_template_ids, escalation_recipients, is_active) VALUES
('C6000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','assignment',3,2,
 ARRAY['C0000000-0000-0000-0000-000000000001']::UUID[],
 '{"1":"reporting_to","2":"department_head"}',true)
ON CONFLICT DO NOTHING;
