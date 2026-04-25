-- ===========================================
-- SEED DATA: AUDIT & SECURITY TRAILS
-- ===========================================

INSERT INTO login_audit_trail (id, organization_id, employee_id, ip_address, user_agent,
                               login_time, logout_time, session_duration, login_status,
                               mfa_verified) VALUES
('B0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',
 '103.21.45.67','Mozilla/5.0 (Macintosh) Chrome/120','2026-04-15 08:30+05:30','2026-04-15 17:30+05:30',32400,
 'success',true),
('B0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004',
 '103.21.45.68','Mozilla/5.0 (Windows) Chrome/120','2026-04-15 09:00+05:30','2026-04-15 18:15+05:30',33300,
 'success',true),
('B0000000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000004',
 '103.21.45.69','Mozilla/5.0 (iPhone) Safari/18','2026-04-15 20:10+05:30',NULL,NULL,'failed',false)
ON CONFLICT DO NOTHING;

INSERT INTO data_access_audit (id, organization_id, employee_id, resource_type, resource_id,
                               action, access_time, ip_address, justification) VALUES
('B1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000010',
 'training_records','91000000-0000-0000-0000-000000000001','read','2026-04-15 11:00+05:30','103.21.45.70','Audit preparation'),
('B1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000010',
 'certificates','92000000-0000-0000-0000-000000000001','export','2026-04-15 11:05+05:30','103.21.45.70','FDA audit evidence')
ON CONFLICT DO NOTHING;

INSERT INTO permission_change_audit (id, organization_id, employee_id, role_id, action,
                                     performed_by, performed_at, effective_date, change_reason) VALUES
('B2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000009',
 '00000000-0000-0000-0000-000000000001009','role_assigned','10000000-0000-0000-0000-000000000002',
 '2022-12-01 09:00+05:30','2022-12-01','Promotion to Lead Trainer')
ON CONFLICT DO NOTHING;

INSERT INTO system_config_audit (id, organization_id, setting_name, setting_type, old_value,
                                 new_value, changed_by, changed_at, change_reason) VALUES
('B3000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','default_pass_mark','number','65.00','70.00',
 '10000000-0000-0000-0000-000000000001','2026-01-05 10:00+05:30','Align with corporate quality policy 2026')
ON CONFLICT DO NOTHING;
