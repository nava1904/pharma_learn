-- ===========================================
-- SEED DATA: WORKFLOW & DELEGATION
-- ===========================================

INSERT INTO workflow_definitions (id, organization_id, workflow_name, applicable_entity_types,
                                  states, transitions, initial_state, created_by, is_active) VALUES
('E0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Course Approval',
 ARRAY['course'],
 '{"draft":{"display":"Draft","color":"#888"},"initiated":{"display":"Initiated","color":"#4a90e2"},"pending_approval":{"display":"Pending Approval","color":"#f5a623"},"approved":{"display":"Approved","color":"#2ecc71","terminal":false},"returned":{"display":"Returned","color":"#e74c3c"},"active":{"display":"Active","color":"#27ae60"},"inactive":{"display":"Inactive","color":"#95a5a6","terminal":true}}',
 '[{"from":"draft","to":"initiated","action":"submit"},{"from":"initiated","to":"pending_approval","action":"send_for_approval"},{"from":"pending_approval","to":"approved","action":"approve"},{"from":"pending_approval","to":"returned","action":"return"},{"from":"approved","to":"active","action":"activate"}]',
 'draft','10000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

INSERT INTO workflow_approval_rules (id, organization_id, workflow_id, approval_level, approver_roles,
                                     require_all_approvers, approval_deadline_days) VALUES
('E0100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','E0000000-0000-0000-0000-000000000001',1,
 ARRAY['00000000-0000-0000-0000-000000000001005']::UUID[],false,3),
('E0100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','E0000000-0000-0000-0000-000000000001',2,
 ARRAY['00000000-0000-0000-0000-000000000001004']::UUID[],false,5)
ON CONFLICT DO NOTHING;

INSERT INTO workflow_instances (id, organization_id, workflow_definition_id, related_entity_type,
                                related_entity_id, current_state, initiated_at, initiated_by, is_active) VALUES
('E1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','E0000000-0000-0000-0000-000000000001',
 'course','63000000-0000-0000-0000-000000000004','approved','2026-02-10 09:00+05:30','10000000-0000-0000-0000-000000000009',true)
ON CONFLICT DO NOTHING;

INSERT INTO workflow_tasks (id, organization_id, workflow_instance_id, assigned_to_id,
                            task_description, due_date, task_status, completed_at, completed_by) VALUES
('E1100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','E1000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',
 'Review & approve Deviation & CAPA Handling course','2026-02-13','completed','2026-02-12 15:00+05:30','10000000-0000-0000-0000-000000000001'),
('E1100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','E1000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',
 'QA Head approval','2026-02-15','completed','2026-02-15 10:00+05:30','10000000-0000-0000-0000-000000000002')
ON CONFLICT DO NOTHING;

INSERT INTO workflow_history (id, workflow_instance_id, from_state, to_state, action_taken,
                              performed_by, performed_at, reason) VALUES
('E1200000-0000-0000-0000-000000000001','E1000000-0000-0000-0000-000000000001','draft','initiated','submit','10000000-0000-0000-0000-000000000009','2026-02-10 09:00+05:30','Ready for review'),
('E1200000-0000-0000-0000-000000000002','E1000000-0000-0000-0000-000000000001','initiated','pending_approval','send_for_approval','10000000-0000-0000-0000-000000000009','2026-02-10 09:30+05:30','Routing per workflow'),
('E1200000-0000-0000-0000-000000000003','E1000000-0000-0000-0000-000000000001','pending_approval','approved','approve','10000000-0000-0000-0000-000000000002','2026-02-15 10:00+05:30','APR001 - Content reviewed & endorsed')
ON CONFLICT DO NOTHING;

INSERT INTO approval_delegations (id, organization_id, delegating_employee_id, delegated_to_employee_id,
                                  delegation_type, start_date, end_date, applicable_approval_types, comments) VALUES
('E2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000004',
 'full','2026-04-20','2026-04-30',ARRAY['course','training_assignment','waiver']::TEXT[],'QA Head on leave - Priya as deputy (Learn-IQ authorized deputy)')
ON CONFLICT DO NOTHING;

INSERT INTO out_of_office (id, organization_id, employee_id, start_date, end_date,
                           backup_approver_id, auto_delegate_approvals, notification_sent) VALUES
('E3000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002',
 '2026-04-20','2026-04-30','10000000-0000-0000-0000-000000000004',true,true)
ON CONFLICT DO NOTHING;
