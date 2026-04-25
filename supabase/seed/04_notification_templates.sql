-- ===========================================
-- SEED DATA: NOTIFICATION TEMPLATES
-- ===========================================

INSERT INTO notification_templates (organization_id, unique_code, name, notification_type, channel, subject_template, body_template, variables, is_system) VALUES
    -- Training Assignment
    ('00000000-0000-0000-0000-000000000001', 'TRAIN_ASSIGNED', 'Training Assigned', 'training_assigned', 'email', 
     'New Training Assignment: {{training_name}}',
     'Dear {{employee_name}},\n\nYou have been assigned a new training: {{training_name}}\n\nDue Date: {{due_date}}\n\nPlease complete this training before the due date.\n\nBest regards,\nTraining Team',
     '["employee_name", "training_name", "due_date", "training_url"]', true),
    
    -- Training Reminder
    ('00000000-0000-0000-0000-000000000001', 'TRAIN_REMINDER', 'Training Reminder', 'training_reminder', 'email',
     'Reminder: Training Due in {{days_remaining}} days',
     'Dear {{employee_name}},\n\nThis is a reminder that your training "{{training_name}}" is due in {{days_remaining}} days.\n\nDue Date: {{due_date}}\n\nPlease complete this training to maintain compliance.\n\nBest regards,\nTraining Team',
     '["employee_name", "training_name", "days_remaining", "due_date"]', true),
    
    -- Training Overdue
    ('00000000-0000-0000-0000-000000000001', 'TRAIN_OVERDUE', 'Training Overdue', 'training_overdue', 'email',
     'URGENT: Training Overdue - {{training_name}}',
     'Dear {{employee_name}},\n\nYour training "{{training_name}}" is now overdue.\n\nOriginal Due Date: {{due_date}}\nDays Overdue: {{days_overdue}}\n\nPlease complete this training immediately to restore compliance status.\n\nBest regards,\nTraining Team',
     '["employee_name", "training_name", "due_date", "days_overdue"]', true),
    
    -- Training Completed
    ('00000000-0000-0000-0000-000000000001', 'TRAIN_COMPLETED', 'Training Completed', 'training_completed', 'email',
     'Training Completed: {{training_name}}',
     'Dear {{employee_name}},\n\nCongratulations! You have successfully completed the training: {{training_name}}\n\nCompletion Date: {{completion_date}}\nScore: {{score}}%\n\nYour certificate has been generated and is available in your training portal.\n\nBest regards,\nTraining Team',
     '["employee_name", "training_name", "completion_date", "score", "certificate_url"]', true),
    
    -- Approval Request
    ('00000000-0000-0000-0000-000000000001', 'APPROVAL_REQUEST', 'Approval Request', 'approval_required', 'email',
     'Approval Required: {{entity_type}} - {{entity_name}}',
     'Dear {{approver_name}},\n\nA new {{entity_type}} requires your approval:\n\nName: {{entity_name}}\nSubmitted By: {{submitter_name}}\nSubmitted On: {{submitted_date}}\n\nPlease review and take action.\n\nBest regards,\nPharmaLearn System',
     '["approver_name", "entity_type", "entity_name", "submitter_name", "submitted_date", "approval_url"]', true),
    
    -- Approval Completed
    ('00000000-0000-0000-0000-000000000001', 'APPROVAL_COMPLETED', 'Approval Completed', 'approval_completed', 'email',
     '{{entity_type}} {{action}}: {{entity_name}}',
     'Dear {{submitter_name}},\n\nYour {{entity_type}} "{{entity_name}}" has been {{action}} by {{approver_name}}.\n\n{{#if comments}}Comments: {{comments}}{{/if}}\n\nBest regards,\nPharmaLearn System',
     '["submitter_name", "entity_type", "entity_name", "action", "approver_name", "comments"]', true),
    
    -- Certificate Expiring
    ('00000000-0000-0000-0000-000000000001', 'CERT_EXPIRING', 'Certificate Expiring', 'certificate_expiring', 'email',
     'Certificate Expiring: {{training_name}}',
     'Dear {{employee_name}},\n\nYour certificate for "{{training_name}}" will expire on {{expiry_date}}.\n\nPlease complete the refresher training to renew your certification.\n\nBest regards,\nTraining Team',
     '["employee_name", "training_name", "expiry_date", "training_url"]', true),
    
    -- Assessment Failed
    ('00000000-0000-0000-0000-000000000001', 'ASSESS_FAILED', 'Assessment Failed', 'assessment_failed', 'email',
     'Assessment Result: {{assessment_name}}',
     'Dear {{employee_name}},\n\nYou did not pass the assessment "{{assessment_name}}".\n\nScore: {{score}}%\nPassing Score: {{passing_score}}%\nAttempts Used: {{attempts_used}}/{{max_attempts}}\n\n{{#if remaining_attempts}}You have {{remaining_attempts}} attempts remaining. Please review the material and try again.{{/if}}\n\nBest regards,\nTraining Team',
     '["employee_name", "assessment_name", "score", "passing_score", "attempts_used", "max_attempts", "remaining_attempts"]', true),
    
    -- Escalation Notice
    ('00000000-0000-0000-0000-000000000001', 'ESCALATION', 'Escalation Notice', 'escalation', 'email',
     'Escalation: Overdue Training - {{employee_name}}',
     'Dear {{supervisor_name}},\n\nThis is an escalation notice regarding overdue training for your team member:\n\nEmployee: {{employee_name}}\nTraining: {{training_name}}\nDue Date: {{due_date}}\nDays Overdue: {{days_overdue}}\n\nPlease take immediate action to ensure compliance.\n\nBest regards,\nPharmaLearn System',
     '["supervisor_name", "employee_name", "training_name", "due_date", "days_overdue"]', true)
ON CONFLICT (organization_id, unique_code) DO NOTHING;

-- In-app notification templates
INSERT INTO notification_templates (organization_id, unique_code, name, notification_type, channel, body_template, variables, is_system) VALUES
    ('00000000-0000-0000-0000-000000000001', 'INAPP_TRAIN_ASSIGNED', 'Training Assigned (In-App)', 'training_assigned', 'in_app',
     'New training assigned: {{training_name}}. Due: {{due_date}}',
     '["training_name", "due_date"]', true),
    
    ('00000000-0000-0000-0000-000000000001', 'INAPP_APPROVAL', 'Approval Required (In-App)', 'approval_required', 'in_app',
     '{{entity_type}} "{{entity_name}}" needs your approval',
     '["entity_type", "entity_name"]', true),
    
    ('00000000-0000-0000-0000-000000000001', 'INAPP_COMPLETED', 'Training Completed (In-App)', 'training_completed', 'in_app',
     'Congratulations! You completed {{training_name}} with {{score}}%',
     '["training_name", "score"]', true)
ON CONFLICT (organization_id, unique_code) DO NOTHING;
