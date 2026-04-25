-- ===========================================
-- PREDEFINED COMPLIANCE REPORT DEFINITIONS
-- GAP 8: 17 pharma-standard system reports
-- All rows use organization_id = NULL (global templates) and is_system = true
-- Idempotent via ON CONFLICT DO NOTHING
-- ===========================================

INSERT INTO report_definitions (
    organization_id, unique_code, name, description,
    report_category, report_type,
    query_config, column_config, filter_config,
    export_formats, is_system
) VALUES

-- 1. Training Compliance Report
(NULL, 'RPT_TRAIN_COMPLIANCE', 'Training Compliance Report',
 'Overall training completion status by employee, department, and course',
 'training', 'tabular',
 '{"source":"training_records","joins":["employees","departments","courses"],"default_sort":"employee_name ASC"}'::jsonb,
 '[{"field":"employee_name","label":"Employee","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"course_name","label":"Course","type":"text"},{"field":"overall_status","label":"Status","type":"status"},{"field":"completion_date","label":"Completed On","type":"date"},{"field":"expiry_date","label":"Expires On","type":"date"},{"field":"assessment_score","label":"Score (%)","type":"number"}]'::jsonb,
 '{"date_range":true,"department_filter":true,"role_filter":true,"status_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 2. Overdue Training Report
(NULL, 'RPT_OVERDUE_TRAINING', 'Overdue Training Report',
 'All employee assignments past due date with escalation level',
 'training', 'tabular',
 '{"source":"employee_assignments","joins":["training_assignments","employees","departments"],"where":"status = ''overdue'' OR (due_date < CURRENT_DATE AND status NOT IN (''completed'',''waived'',''cancelled''))","default_sort":"due_date ASC"}'::jsonb,
 '[{"field":"employee_name","label":"Employee","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"assignment_name","label":"Assignment","type":"text"},{"field":"due_date","label":"Due Date","type":"date"},{"field":"days_overdue","label":"Days Overdue","type":"integer","computed":true},{"field":"escalation_level","label":"Escalation Level","type":"integer"},{"field":"priority","label":"Priority","type":"text"}]'::jsonb,
 '{"date_range":true,"department_filter":true,"role_filter":true,"escalation_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 3. Certificate Expiry Report
(NULL, 'RPT_CERT_EXPIRY', 'Certificate Expiry Report',
 'Certificates approaching expiry or already expired, grouped by employee',
 'training', 'tabular',
 '{"source":"certificates","joins":["training_records","employees","courses"],"where":"expiry_date <= CURRENT_DATE + INTERVAL ''90 days'' OR status = ''expired''","default_sort":"expiry_date ASC"}'::jsonb,
 '[{"field":"employee_name","label":"Employee","type":"text"},{"field":"course_name","label":"Course","type":"text"},{"field":"certificate_number","label":"Certificate No.","type":"text"},{"field":"issued_date","label":"Issued On","type":"date"},{"field":"expiry_date","label":"Expires On","type":"date"},{"field":"days_to_expiry","label":"Days to Expiry","type":"integer","computed":true},{"field":"status","label":"Status","type":"status"}]'::jsonb,
 '{"expiry_window_days":true,"department_filter":true,"role_filter":true,"status_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 4. CAPA Training Status Report
(NULL, 'RPT_CAPA_TRAINING_STATUS', 'CAPA Training Status Report',
 'Training assignments raised from CAPA records and their completion status',
 'quality', 'tabular',
 '{"source":"capa_records","joins":["training_assignments","employee_assignments","employees","departments"],"default_sort":"capa_records.created_at DESC"}'::jsonb,
 '[{"field":"capa_number","label":"CAPA No.","type":"text"},{"field":"capa_title","label":"CAPA Title","type":"text"},{"field":"severity","label":"Severity","type":"text"},{"field":"employee_name","label":"Employee","type":"text"},{"field":"assignment_name","label":"Training Assignment","type":"text"},{"field":"due_date","label":"Due Date","type":"date"},{"field":"assignment_status","label":"Status","type":"status"},{"field":"completion_date","label":"Completed On","type":"date"}]'::jsonb,
 '{"date_range":true,"severity_filter":true,"department_filter":true,"status_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 5. Document Acknowledgment Report
(NULL, 'RPT_DOC_ACKNOWLEDGMENT', 'Document Acknowledgment Report',
 'Who has read and acknowledged each document — for SOP compliance verification',
 'documents', 'tabular',
 '{"source":"document_readings","joins":["documents","employees","departments"],"default_sort":"documents.name ASC, employees.last_name ASC"}'::jsonb,
 '[{"field":"document_name","label":"Document","type":"text"},{"field":"sop_number","label":"SOP No.","type":"text"},{"field":"version_no","label":"Version","type":"text"},{"field":"employee_name","label":"Employee","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"reading_status","label":"Status","type":"status"},{"field":"acknowledged_at","label":"Acknowledged On","type":"datetime"},{"field":"due_date","label":"Due By","type":"date"}]'::jsonb,
 '{"document_filter":true,"department_filter":true,"status_filter":true,"date_range":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 6. Trainer Performance Report
(NULL, 'RPT_TRAINER_PERFORMANCE', 'Trainer Performance Report',
 'Trainer effectiveness metrics: sessions delivered, attendance, feedback scores',
 'training', 'summary',
 '{"source":"trainers","joins":["training_sessions","session_attendance","training_feedback","trainer_feedback"],"default_sort":"overall_rating DESC"}'::jsonb,
 '[{"field":"trainer_name","label":"Trainer","type":"text"},{"field":"total_sessions","label":"Sessions","type":"integer","aggregated":true},{"field":"total_participants","label":"Participants","type":"integer","aggregated":true},{"field":"avg_attendance_pct","label":"Avg Attendance (%)","type":"number","aggregated":true},{"field":"avg_feedback_score","label":"Avg Feedback Score","type":"number","aggregated":true},{"field":"pass_rate_pct","label":"Pass Rate (%)","type":"number","aggregated":true}]'::jsonb,
 '{"date_range":true,"department_filter":true,"training_type_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 7. Audit Readiness Report
(NULL, 'RPT_AUDIT_READINESS', 'Audit Readiness Report',
 'Snapshot of compliance posture: overdue trainings, expired certs, pending approvals, open CAPAs',
 'compliance', 'dashboard',
 '{"source":"multi","entities":["employee_assignments","certificates","pending_approvals","capa_records"],"aggregation":"counts_by_status","default_sort":"risk_level DESC"}'::jsonb,
 '[{"field":"metric_name","label":"Metric","type":"text"},{"field":"count_ok","label":"Compliant","type":"integer"},{"field":"count_warning","label":"Warning","type":"integer"},{"field":"count_critical","label":"Critical/Overdue","type":"integer"},{"field":"compliance_pct","label":"Compliance (%)","type":"number","computed":true}]'::jsonb,
 '{"department_filter":true,"plant_filter":true,"as_of_date":true}'::jsonb,
 '["pdf","excel"]'::jsonb, true),

-- 8. Role Competency Gap Report
(NULL, 'RPT_ROLE_COMPETENCY_GAP', 'Role Competency Gap Report',
 'Employees with competency gaps vs. role requirements',
 'training', 'tabular',
 '{"source":"competency_gaps","joins":["employees","roles","competencies","departments"],"default_sort":"gap_severity DESC, employee_name ASC"}'::jsonb,
 '[{"field":"employee_name","label":"Employee","type":"text"},{"field":"role_name","label":"Role","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"competency_name","label":"Competency","type":"text"},{"field":"required_level","label":"Required Level","type":"text"},{"field":"current_level","label":"Current Level","type":"text"},{"field":"gap_severity","label":"Gap Severity","type":"text"},{"field":"target_date","label":"Close By","type":"date"}]'::jsonb,
 '{"department_filter":true,"role_filter":true,"gap_severity_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 9. Electronic Signature Audit Report
(NULL, 'RPT_ESIG_AUDIT', 'Electronic Signature Audit Report',
 '21 CFR Part 11 e-signature log with integrity verification status',
 'audit', 'tabular',
 '{"source":"electronic_signatures","joins":["employees","departments"],"default_sort":"timestamp DESC"}'::jsonb,
 '[{"field":"signer_name","label":"Signer","type":"text"},{"field":"employee_id_code","label":"Employee ID","type":"text"},{"field":"meaning_display","label":"Signature Type","type":"text"},{"field":"entity_type","label":"Entity Type","type":"text"},{"field":"reason","label":"Reason","type":"text"},{"field":"timestamp","label":"Signed At","type":"datetime"},{"field":"ip_address","label":"IP Address","type":"text"},{"field":"is_valid","label":"Valid","type":"boolean"},{"field":"password_reauth_verified","label":"Re-Auth","type":"boolean"}]'::jsonb,
 '{"date_range":true,"signer_filter":true,"meaning_filter":true,"entity_type_filter":true,"validity_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 10. Workflow Status Report
(NULL, 'RPT_WORKFLOW_STATUS', 'Workflow Status Report',
 'All workflow instances with current state, pending approvers, and SLA status',
 'workflow', 'tabular',
 '{"source":"workflow_instances","joins":["workflow_definitions","employees","workflow_tasks"],"default_sort":"sla_deadline ASC"}'::jsonb,
 '[{"field":"workflow_name","label":"Workflow","type":"text"},{"field":"entity_type","label":"Entity Type","type":"text"},{"field":"current_state","label":"State","type":"status"},{"field":"initiator_name","label":"Initiated By","type":"text"},{"field":"initiated_at","label":"Initiated On","type":"datetime"},{"field":"sla_deadline","label":"SLA Deadline","type":"datetime"},{"field":"is_overdue","label":"Overdue","type":"boolean"},{"field":"pending_approver","label":"Pending Approver","type":"text"}]'::jsonb,
 '{"entity_type_filter":true,"state_filter":true,"overdue_only":true,"date_range":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 11. Document Issuance Control Report
(NULL, 'RPT_DOC_ISSUANCE_CTRL', 'Document Issuance Control Report',
 'Controlled copy register: who holds which copies, retrieval status, and outstanding acknowledgments',
 'documents', 'tabular',
 '{"source":"document_issuances","joins":["documents","employees","document_retrieval_log"],"default_sort":"documents.name ASC, issued_at DESC"}'::jsonb,
 '[{"field":"document_name","label":"Document","type":"text"},{"field":"sop_number","label":"SOP No.","type":"text"},{"field":"version_no","label":"Version","type":"text"},{"field":"copy_number","label":"Copy No.","type":"text"},{"field":"issuance_type","label":"Type","type":"text"},{"field":"issued_to_name","label":"Issued To","type":"text"},{"field":"issued_at","label":"Issued On","type":"datetime"},{"field":"acknowledged_at","label":"Acknowledged On","type":"datetime"},{"field":"is_superseded","label":"Superseded","type":"boolean"},{"field":"retrieved_at","label":"Retrieved On","type":"datetime"}]'::jsonb,
 '{"document_filter":true,"issuance_type_filter":true,"department_filter":true,"outstanding_only":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 12. Training Matrix Coverage Report
(NULL, 'RPT_TRAINING_MATRIX_COVERAGE', 'Training Matrix Coverage Report',
 'Percentage of training matrix requirements fulfilled per role and department',
 'training', 'summary',
 '{"source":"training_matrix_items","joins":["training_matrix","roles","courses","employee_assignments","training_records"],"aggregation":"coverage_pct_by_role","default_sort":"coverage_pct ASC"}'::jsonb,
 '[{"field":"role_name","label":"Role","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"total_requirements","label":"Total Requirements","type":"integer","aggregated":true},{"field":"completed_count","label":"Completed","type":"integer","aggregated":true},{"field":"in_progress_count","label":"In Progress","type":"integer","aggregated":true},{"field":"overdue_count","label":"Overdue","type":"integer","aggregated":true},{"field":"coverage_pct","label":"Coverage (%)","type":"number","computed":true,"aggregated":true}]'::jsonb,
 '{"department_filter":true,"role_filter":true,"matrix_filter":true}'::jsonb,
 '["pdf","excel"]'::jsonb, true),

-- 13. New Hire Onboarding Status Report
(NULL, 'RPT_NEW_HIRE_ONBOARDING', 'New Hire Onboarding Status Report',
 'Induction program completion for employees hired in a date range',
 'hr', 'tabular',
 '{"source":"employee_induction","joins":["employees","induction_programs","induction_modules","employee_induction_progress"],"where":"employees.hire_date >= :start_date","default_sort":"employees.hire_date DESC"}'::jsonb,
 '[{"field":"employee_name","label":"Employee","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"hire_date","label":"Hire Date","type":"date"},{"field":"induction_program","label":"Induction Program","type":"text"},{"field":"overall_status","label":"Status","type":"status"},{"field":"modules_completed","label":"Modules Done","type":"integer"},{"field":"modules_total","label":"Total Modules","type":"integer"},{"field":"completion_date","label":"Completed On","type":"date"},{"field":"days_to_complete","label":"Days to Complete","type":"integer","computed":true}]'::jsonb,
 '{"hire_date_range":true,"department_filter":true,"status_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 14. SOP Revision Retraining Status
(NULL, 'RPT_SOP_RETRAINING_STATUS', 'SOP Revision Retraining Status',
 'For each SOP revision, shows who was assigned retraining and completion status',
 'documents', 'tabular',
 '{"source":"training_trigger_events","joins":["documents","training_assignments","employee_assignments","employees"],"where":"event_source = ''sop_update''","default_sort":"triggered_at DESC"}'::jsonb,
 '[{"field":"document_name","label":"SOP Name","type":"text"},{"field":"sop_number","label":"SOP No.","type":"text"},{"field":"version_no","label":"Version","type":"text"},{"field":"triggered_at","label":"Revision Date","type":"datetime"},{"field":"assignments_created","label":"Employees Assigned","type":"integer"},{"field":"completed_count","label":"Completed","type":"integer","aggregated":true},{"field":"pending_count","label":"Pending","type":"integer","aggregated":true},{"field":"overdue_count","label":"Overdue","type":"integer","aggregated":true},{"field":"completion_pct","label":"Completion (%)","type":"number","computed":true}]'::jsonb,
 '{"date_range":true,"document_filter":true,"department_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 15. Deviation-to-Training Traceability
(NULL, 'RPT_DEVIATION_TRAINING_LINK', 'Deviation-to-Training Traceability',
 'Traceability matrix linking quality deviations to training actions taken',
 'quality', 'tabular',
 '{"source":"deviations","joins":["capa_records","training_assignments","employee_assignments","employees"],"default_sort":"deviations.created_at DESC"}'::jsonb,
 '[{"field":"deviation_number","label":"Deviation No.","type":"text"},{"field":"deviation_title","label":"Deviation","type":"text"},{"field":"severity","label":"Severity","type":"text"},{"field":"capa_number","label":"CAPA No.","type":"text"},{"field":"training_assignment","label":"Training Assigned","type":"text"},{"field":"employees_assigned","label":"Employees Assigned","type":"integer","aggregated":true},{"field":"completion_pct","label":"Completion (%)","type":"number","computed":true},{"field":"status","label":"Status","type":"status"}]'::jsonb,
 '{"date_range":true,"severity_filter":true,"department_filter":true,"status_filter":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true),

-- 16. Approval Turnaround Time Report
(NULL, 'RPT_APPROVAL_TURNAROUND', 'Approval Turnaround Time Report',
 'Average and max time from submission to approval/rejection per workflow type',
 'workflow', 'summary',
 '{"source":"workflow_instances","joins":["workflow_definitions","workflow_history","employees"],"where":"completed_at IS NOT NULL","aggregation":"avg_turnaround_hours_by_workflow","default_sort":"avg_hours DESC"}'::jsonb,
 '[{"field":"workflow_name","label":"Workflow","type":"text"},{"field":"entity_type","label":"Entity Type","type":"text"},{"field":"total_instances","label":"Total","type":"integer","aggregated":true},{"field":"avg_hours","label":"Avg Hours","type":"number","aggregated":true},{"field":"max_hours","label":"Max Hours","type":"number","aggregated":true},{"field":"sla_breach_count","label":"SLA Breaches","type":"integer","aggregated":true},{"field":"rejection_rate_pct","label":"Rejection Rate (%)","type":"number","computed":true,"aggregated":true}]'::jsonb,
 '{"date_range":true,"entity_type_filter":true,"workflow_filter":true}'::jsonb,
 '["pdf","excel"]'::jsonb, true),

-- 17. Controlled Copy Issuance Status
(NULL, 'RPT_CONTROLLED_COPY_STATUS', 'Controlled Copy Issuance Status',
 'All controlled copies currently in circulation with pending retrieval tracking',
 'documents', 'tabular',
 '{"source":"document_issuances","joins":["documents","employees","departments"],"where":"issuance_type = ''controlled'' AND is_superseded = false","default_sort":"document_name ASC, copy_number ASC"}'::jsonb,
 '[{"field":"document_name","label":"Document","type":"text"},{"field":"sop_number","label":"SOP No.","type":"text"},{"field":"version_no","label":"Version","type":"text"},{"field":"copy_number","label":"Copy No.","type":"text"},{"field":"issued_to_name","label":"Holder","type":"text"},{"field":"department_name","label":"Department","type":"text"},{"field":"issued_at","label":"Issued On","type":"datetime"},{"field":"acknowledged_at","label":"Acknowledged","type":"datetime"},{"field":"retrieval_required","label":"Retrieval Required","type":"boolean"},{"field":"retrieved_at","label":"Retrieved On","type":"datetime"}]'::jsonb,
 '{"document_filter":true,"department_filter":true,"unacknowledged_only":true,"unretrieved_only":true}'::jsonb,
 '["pdf","excel","csv"]'::jsonb, true)

ON CONFLICT (organization_id, unique_code) DO NOTHING;
