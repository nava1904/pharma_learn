-- ===========================================
-- SEED DATA: QUALITY EVENTS
-- Deviations, CAPA, Change Control, Audit Findings
-- ===========================================

INSERT INTO deviations (id, organization_id, plant_id, deviation_number, deviation_date,
                        reported_by, description, severity, impact_assessment, root_cause,
                        corrective_action, preventive_action, target_closure_date, status,
                        is_active) VALUES
('A0000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'DEV-2026-001','2026-02-08','10000000-0000-0000-0000-000000000005',
 'Temperature excursion in cold room (recorded 10°C vs spec 2-8°C for 27 min)','high',
 'Batch 26B-0045 potentially compromised; 2 other batches in storage require investigation',
 'Failed thermostat sensor; no redundant alarm configured',
 'Replace sensor; commission redundant alarm; batch review by QA',
 'Update SOP-PROD-011 to mandate dual sensors; train maintenance team on sensor checks',
 '2026-03-15','investigation',true),
('A0000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'DEV-2026-002','2026-02-20','10000000-0000-0000-0000-000000000004',
 'Operator EMP007 found a step in MBR skipped during granulation','medium',
 'No product impact; documentation error only','Operator confused about updated SOP v2.1',
 'Retrain operator on SOP-PROD-002 v2.1','Add SOP-update read-and-ack enforcement before task',
 '2026-03-05','closed',true)
ON CONFLICT DO NOTHING;

INSERT INTO capa_records (id, organization_id, plant_id, deviation_id, capa_number, capa_status,
                          root_cause_analysis, corrective_actions, preventive_actions,
                          training_requirements, is_active) VALUES
('A1000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'A0000000-0000-0000-0000-000000000001','CAPA-2026-001','training_assigned',
 '5-Why analysis: sensor failure + missing redundancy + no periodic check',
 '[{"action":"Replace sensor","owner":"maintenance","deadline":"2026-02-28"},{"action":"Install redundant alarm","owner":"engineering","deadline":"2026-03-15"}]',
 '[{"action":"Update SOP-PROD-011","owner":"qa","deadline":"2026-03-10"},{"action":"Train maint team","owner":"training","deadline":"2026-03-20"}]',
 '[{"course_id":"63000000-0000-0000-0000-000000000004","assignees":"maintenance_team","deadline":"2026-03-20"}]',
 true),
('A1000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'A0000000-0000-0000-0000-000000000002','CAPA-2026-002','closed',
 'SOP v2.1 update not cascaded to operator read list',
 '[{"action":"Mandatory retraining EMP007","owner":"training","done":true}]',
 '[{"action":"SOP update workflow to auto-assign read","owner":"it","deadline":"2026-04-30"}]',
 '[{"course_id":"63000000-0000-0000-0000-000000000001","assignees":"EMP007","deadline":"2026-03-05"}]',
 true)
ON CONFLICT DO NOTHING;

INSERT INTO deviation_training_requirements (id, deviation_id, capa_id, course_id,
                                             assigned_to_roles, training_deadline,
                                             required_for_closure, is_mandatory) VALUES
('A1100000-0000-0000-0000-000000000001','A0000000-0000-0000-0000-000000000001','A1000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000004',
 ARRAY['00000000-0000-0000-0000-000000000001010']::UUID[],'2026-03-20',true,true)
ON CONFLICT DO NOTHING;

INSERT INTO change_controls (id, organization_id, plant_id, change_number, description,
                             change_type, requester_id, requested_date, change_reason,
                             impact_assessment, implementation_plan, implementation_date, status,
                             is_active) VALUES
('A2000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'CC-2026-001','Replace compression machine vendor (Vendor A → Vendor B)',
 'equipment','10000000-0000-0000-0000-000000000003','2026-02-15',
 'Vendor A service contract ended; Vendor B machine offers better yield',
 'Moderate - new PQ required; operator retraining required',
 '[{"phase":"PQ","start":"2026-04-01"},{"phase":"Validation batch","start":"2026-05-15"},{"phase":"Operator retraining","start":"2026-05-01"}]',
 '2026-06-15','pending_approval',true)
ON CONFLICT DO NOTHING;

INSERT INTO change_control_training (id, change_control_id, course_id, assigned_to_employees,
                                     training_deadline, is_mandatory) VALUES
('A2100000-0000-0000-0000-000000000001','A2000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000001',
 ARRAY['10000000-0000-0000-0000-000000000005','10000000-0000-0000-0000-000000000006','10000000-0000-0000-0000-000000000007']::UUID[],
 '2026-05-15',true)
ON CONFLICT DO NOTHING;

INSERT INTO regulatory_audits (id, organization_id, plant_id, audit_number, audit_date,
                               auditor_name, audit_scope, audit_findings_count, status, is_active) VALUES
('A3000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'AUDIT-2026-01','2026-04-10','US FDA Inspector J. Martinez','Full GMP inspection',3,'pending_approval',true),
('A3000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000013',
 'AUDIT-2026-02','2026-05-20','WHO Inspector A. Okafor','Sterile facility audit',0,'open',true)
ON CONFLICT DO NOTHING;

INSERT INTO audit_findings (id, regulatory_audit_id, finding_description, severity, root_cause,
                            corrective_action, closure_date) VALUES
('A3100000-0000-0000-0000-000000000001','A3000000-0000-0000-0000-000000000001',
 'Training records for 2 contract operators not found on audit day','minor',
 'Records stored on local SharePoint; not synced to eLMS','Migrate all contract operator records to PharmaLearn LMS',
 '2026-06-30'),
('A3100000-0000-0000-0000-000000000002','A3000000-0000-0000-0000-000000000001',
 'Out-of-date SOP displayed at workstation','major',
 'SOP lifecycle not integrated with physical display','Auto-print workflow from LMS; QR linked live SOPs',
 '2026-07-15')
ON CONFLICT DO NOTHING;

INSERT INTO audit_finding_training (id, audit_finding_id, course_id, assigned_to_roles,
                                    training_deadline, is_mandatory) VALUES
('A3200000-0000-0000-0000-000000000001','A3100000-0000-0000-0000-000000000002','63000000-0000-0000-0000-000000000002',
 ARRAY['00000000-0000-0000-0000-000000000001008','00000000-0000-0000-0000-000000000001010']::UUID[],
 '2026-06-30',true)
ON CONFLICT DO NOTHING;

INSERT INTO audit_preparation_items (id, regulatory_audit_id, item_description,
                                     responsible_person_id, target_date, status) VALUES
('A3300000-0000-0000-0000-000000000001','A3000000-0000-0000-0000-000000000001',
 'Mock audit walk-through','10000000-0000-0000-0000-000000000002','2026-03-20','pending'),
('A3300000-0000-0000-0000-000000000002','A3000000-0000-0000-0000-000000000001',
 'Verify all training matrix compliance >= 98%','10000000-0000-0000-0000-000000000001','2026-03-30','pending')
ON CONFLICT DO NOTHING;
