-- ===========================================
-- SEED DATA: CORE (workflow transitions, signature meanings)
-- audit_trails and electronic_signatures are appended by triggers
-- ===========================================

-- Learn-IQ standard workflow transitions (if not already seeded by DDL)
INSERT INTO workflow_transitions (id, from_state, to_state, action_name, action_display_name,
                                  requires_approval, requires_reason, requires_esignature,
                                  allowed_roles, min_approver_level, description) VALUES
('11100000-0000-0000-0000-000000000001','draft','initiated','submit','Submit for Review',false,false,false,ARRAY['creator'],NULL,'Move from draft to initiated'),
('11100000-0000-0000-0000-000000000002','initiated','pending_approval','send_for_approval','Route to Approver',true,false,false,ARRAY['creator','any_with_perm'],NULL,'Send for approval'),
('11100000-0000-0000-0000-000000000003','pending_approval','approved','approve','Approve',false,true,true,ARRAY['approver'],5.00,'Approve'),
('11100000-0000-0000-0000-000000000004','pending_approval','returned','return','Return for Revision',false,true,false,ARRAY['approver'],5.00,'Return for revision'),
('11100000-0000-0000-0000-000000000005','pending_approval','dropped','drop','Drop/Reject',false,true,true,ARRAY['approver'],5.00,'Drop / reject permanently'),
('11100000-0000-0000-0000-000000000006','returned','initiated','resubmit','Resubmit After Revision',false,false,false,ARRAY['creator'],NULL,'Resubmit'),
('11100000-0000-0000-0000-000000000007','approved','active','activate','Activate',false,false,true,ARRAY['approver'],NULL,'Make active'),
('11100000-0000-0000-0000-000000000008','active','inactive','deactivate','Deactivate',true,true,true,ARRAY['approver'],4.00,'Retire/deactivate')
ON CONFLICT DO NOTHING;

-- Signature meanings (21 CFR Part 11)
INSERT INTO signature_meanings (id, meaning, display_text, description, applicable_entities,
                                requires_reason, requires_password_reauth, is_active, display_order) VALUES
('11200000-0000-0000-0000-000000000001','authored','Authored By','I am the author of this record',
 ARRAY['course','document','question','question_paper','training_assignment'],false,true,true,1),
('11200000-0000-0000-0000-000000000002','reviewed','Reviewed By','I have reviewed this record',
 ARRAY['course','document','training_record','certificate','capa_record'],true,true,true,2),
('11200000-0000-0000-0000-000000000003','approved','Approved By','I approve this record',
 ARRAY['course','document','training_assignment','waiver','certificate','capa_record'],true,true,true,3),
('11200000-0000-0000-0000-000000000004','acknowledged','Acknowledged By','I have read and acknowledge this',
 ARRAY['document','sop','policy'],false,false,true,4),
('11200000-0000-0000-0000-000000000005','witnessed','Witnessed By','I witnessed this action',
 ARRAY['ojt_task_completion','biometric_registration'],true,true,true,5),
('11200000-0000-0000-0000-000000000006','verified','Verified By','I verified this record',
 ARRAY['certificate','assessment_result'],true,true,true,6),
('11200000-0000-0000-0000-000000000007','rejected','Rejected By','I reject this record',
 ARRAY['course','document','waiver','training_assignment'],true,true,true,7)
ON CONFLICT DO NOTHING;

-- Sample electronic signature (course approval)
INSERT INTO electronic_signatures (id, employee_id, employee_name, employee_email, employee_title,
                                   employee_id_code, meaning, meaning_display, reason, entity_type,
                                   entity_id, ip_address, user_agent, integrity_hash, data_snapshot,
                                   password_reauth_verified, biometric_verified,
                                   organization_id, plant_id, is_valid) VALUES
('11300000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','Rajesh Menon','rajesh.menon@acmepharma.com','QA Head',
 'EMP002','approved','Approved By','APR001 - Content reviewed and endorsed',
 'course','63000000-0000-0000-0000-000000000004','103.21.45.67','Chrome 120',
 encode(digest('course-63-approval-content','sha256'),'hex'),
 '{"course_id":"63000000-0000-0000-0000-000000000004","name":"Deviation & CAPA Handling","version":1}',
 true,true,'00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',true)
ON CONFLICT DO NOTHING;

-- Sample pending approval (training waiver pending approval)
INSERT INTO pending_approvals (id, entity_type, entity_id, entity_display_name, requested_action,
                               current_state, target_state, initiated_by, initiator_name,
                               initiator_role_level, initiated_at, requires_approval, approval_type,
                               min_approver_level, due_date, status, plant_id, organization_id,
                               comments) VALUES
('11400000-0000-0000-0000-000000000001','course','63000000-0000-0000-0000-000000000005','Aseptic Techniques v1',
 'approve','pending_approval','approved','10000000-0000-0000-0000-000000000009','Mohit Joshi',6.00,
 '2026-02-20 09:00+05:30',true,'by_approval_group',5.00,'2026-02-28','pending',
 '00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000001','Please review and approve')
ON CONFLICT DO NOTHING;
