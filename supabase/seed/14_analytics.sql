-- ===========================================
-- SEED DATA: ANALYTICS & REPORTS
-- ===========================================

INSERT INTO dashboard_widgets (id, organization_id, widget_name, widget_type, data_source,
                               query_definition, refresh_frequency_minutes, is_system_widget, is_active) VALUES
('D0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Compliance %','kpi','training_analytics',
 '{"metric":"compliance_percent","aggregation":"avg","scope":"organization"}',60,true,true),
('D0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Pending Approvals','kpi','pending_approvals',
 '{"filter":"status=pending","groupBy":"approver"}',5,true,true),
('D0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Overdue Assignments','chart','employee_assignments',
 '{"filter":"status=overdue","chartType":"bar","groupBy":"department"}',15,true,true),
('D0000000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','Pass Rate by Course','chart','assessment_results',
 '{"metric":"percentage","chartType":"bar","groupBy":"course_id"}',60,true,true)
ON CONFLICT DO NOTHING;

INSERT INTO user_dashboards (id, organization_id, employee_id, dashboard_name, layout, is_default) VALUES
('D1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','My Dashboard',
 '{"widgets":[{"id":"D0000000-0000-0000-0000-000000000001","pos":{"x":0,"y":0},"size":{"w":4,"h":2}},{"id":"D0000000-0000-0000-0000-000000000002","pos":{"x":4,"y":0},"size":{"w":4,"h":2}}]}',true),
('D1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','QA Head Dashboard',
 '{"widgets":[{"id":"D0000000-0000-0000-0000-000000000001","pos":{"x":0,"y":0},"size":{"w":6,"h":2}},{"id":"D0000000-0000-0000-0000-000000000004","pos":{"x":6,"y":0},"size":{"w":6,"h":4}}]}',true)
ON CONFLICT DO NOTHING;

INSERT INTO training_analytics (id, organization_id, metric_date, total_employees, trained_count,
                                compliance_percent, avg_training_hours, courses_completed,
                                assessments_taken, pass_rate, fail_rate, certificate_count) VALUES
('D2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','2026-02-28',10,7,87.50,2.8,4,5,80.00,20.00,3),
('D2000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','2026-03-31',10,8,92.00,3.1,5,7,85.71,14.29,4)
ON CONFLICT DO NOTHING;

INSERT INTO course_analytics (id, organization_id, course_id, metric_date, enrollments, completions,
                              completion_rate, avg_score, satisfaction_score) VALUES
('D3000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001','2026-02-28',3,3,100.00,75.00,4.5),
('D3000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000003','2026-02-28',3,2,66.67,100.00,4.0)
ON CONFLICT DO NOTHING;

INSERT INTO employee_training_analytics (id, organization_id, employee_id, year, total_trainings,
                                         total_hours, assessment_score_avg, certification_count,
                                         compliance_status) VALUES
('D4000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000006',2026,1,1.5,90.00,1,'compliant'),
('D4000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000007',2026,1,1.5,60.00,0,'non_compliant'),
('D4000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000003',2026,1,1.5,100.00,1,'compliant')
ON CONFLICT DO NOTHING;

INSERT INTO report_definitions (id, organization_id, report_name, report_type, query_definition,
                                parameter_schema, export_formats, created_by, is_system_report, is_active) VALUES
('D5000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Training Compliance Report','compliance',
 '{"source":"training_analytics","filters":["date_range","department","role"]}',
 '{"date_from":{"type":"date","required":true},"date_to":{"type":"date","required":true},"department_id":{"type":"uuid","required":false}}',
 ARRAY['pdf','excel','csv'],'10000000-0000-0000-0000-000000000001',true,true),
('D5000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Certificate Expiry Report','expiry',
 '{"source":"certificates","filters":["days_until_expiry"]}',
 '{"days":{"type":"number","required":true,"default":30}}',
 ARRAY['pdf','excel'],'10000000-0000-0000-0000-000000000001',true,true)
ON CONFLICT DO NOTHING;

INSERT INTO scheduled_reports (id, organization_id, report_id, recipient_ids, schedule_type,
                               schedule_cron, next_run_time, is_active) VALUES
('D6000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','D5000000-0000-0000-0000-000000000001',
 ARRAY['10000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002']::UUID[],'monthly',
 '0 8 1 * *','2026-05-01 08:00+05:30',true)
ON CONFLICT DO NOTHING;
