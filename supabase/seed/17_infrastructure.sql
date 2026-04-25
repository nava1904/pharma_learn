-- ===========================================
-- SEED DATA: INFRASTRUCTURE
-- System settings, feature flags, files, integrations, SSO
-- ===========================================

INSERT INTO system_settings (id, organization_id, setting_key, setting_value, setting_type, scope,
                             updated_by) VALUES
('10100000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','email_from','"noreply@acmepharma.com"','string','organization','10000000-0000-0000-0000-000000000001'),
('10100000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','support_email','"support@acmepharma.com"','string','organization','10000000-0000-0000-0000-000000000001'),
('10100000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','session_timeout_minutes','30','number','organization','10000000-0000-0000-0000-000000000001'),
('10100000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','max_upload_size_mb','100','number','organization','10000000-0000-0000-0000-000000000001'),
('10100000-0000-0000-0000-000000000005','00000000-0000-0000-0000-000000000001','biometric_required_for_esig','true','boolean','organization','10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO feature_flags (id, organization_id, flag_name, is_enabled, enabled_for_org,
                           percentage_rollout, updated_by) VALUES
('10200000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','learning_paths_v2',true,true,100,'10000000-0000-0000-0000-000000000001'),
('10200000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','gamification',true,true,100,'10000000-0000-0000-0000-000000000001'),
('10200000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','scorm_support',true,true,100,'10000000-0000-0000-0000-000000000001'),
('10200000-0000-0000-0000-000000000004','00000000-0000-0000-0000-000000000001','ai_question_generator',false,true,0,'10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO api_keys (id, organization_id, key_name, key_hash, key_prefix, created_by,
                      expires_at, is_active) VALUES
('10300000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Flutter App Key',
 encode(digest('flutter-app-secret-2026','sha256'),'hex'),'flk_abc123','10000000-0000-0000-0000-000000000001',
 '2027-01-01',true),
('10300000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','HRMS Integration Key',
 encode(digest('hrms-integration-secret','sha256'),'hex'),'hrms_xyz789','10000000-0000-0000-0000-000000000001',
 '2027-01-01',true)
ON CONFLICT DO NOTHING;

INSERT INTO webhooks (id, organization_id, event_type, target_url, retry_policy, headers,
                      is_active, created_by) VALUES
('10400000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','certificate_issued',
 'https://hrms.acmepharma.com/webhook/certificates','{"max_retries":3,"backoff":"exponential"}',
 '{"X-Source":"PharmaLearn"}',true,'10000000-0000-0000-0000-000000000001'),
('10400000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','training_completed',
 'https://hrms.acmepharma.com/webhook/training','{"max_retries":3,"backoff":"exponential"}',
 '{"X-Source":"PharmaLearn"}',true,'10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO file_storage (id, organization_id, plant_id, file_type, file_name, original_file_name,
                          file_size_bytes, mime_type, storage_path, file_hash, uploaded_by, is_active) VALUES
('10500000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'document','SOP-QA-001_v3.0.pdf','Cleanroom_Gowning_v3.pdf',1284500,'application/pdf',
 '/storage/org-acme/sop/SOP-QA-001_v3.0.pdf',encode(digest('sop-qa-001-v3-content','sha256'),'hex'),
 '10000000-0000-0000-0000-000000000004',true),
('10500000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001',NULL,
 'certificate','ACME-2026-CR-0001.pdf','Certificate_EMP006.pdf',245000,'application/pdf',
 '/storage/org-acme/certificates/ACME-2026-CR-0001.pdf',encode(digest('cert-001-content','sha256'),'hex'),
 '10000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

INSERT INTO file_associations (id, file_id, associated_entity_type, associated_entity_id, is_primary) VALUES
('10600000-0000-0000-0000-000000000001','10500000-0000-0000-0000-000000000001','document_version','52000000-0000-0000-0000-000000000003',true),
('10600000-0000-0000-0000-000000000002','10500000-0000-0000-0000-000000000002','certificate','92000000-0000-0000-0000-000000000001',true)
ON CONFLICT DO NOTHING;

INSERT INTO integrations (id, organization_id, integration_name, integration_type, api_url,
                          api_credentials, sync_enabled, is_active, created_by) VALUES
('10700000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','Acme HRMS','hrms',
 'https://hrms.acmepharma.com/api/v1','{"_encrypted":"REDACTED_CREDS"}',true,true,'10000000-0000-0000-0000-000000000001'),
('10700000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000001','Azure AD','sso',
 'https://login.microsoftonline.com/acme','{"_encrypted":"REDACTED_CREDS"}',true,true,'10000000-0000-0000-0000-000000000001'),
('10700000-0000-0000-0000-000000000003','00000000-0000-0000-0000-000000000001','Morpho Biometric Device','biometric_device',
 'tcp://192.168.10.55:4370','{"device_id":"BIO-P1-01"}',true,true,'10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;

INSERT INTO sso_configurations (id, organization_id, sso_provider, provider_url, client_id,
                                client_secret, user_attribute_mapping, auto_create_users,
                                auto_assign_roles, is_active, created_by) VALUES
('10800000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000001','azure_ad',
 'https://login.microsoftonline.com/acme','client-id-redacted','{"_encrypted":"REDACTED"}',
 '{"email":"mail","name":"displayName","employee_id":"employeeId"}',true,
 '{"default_role":"00000000-0000-0000-0000-000000000001010"}',true,'10000000-0000-0000-0000-000000000001')
ON CONFLICT DO NOTHING;
