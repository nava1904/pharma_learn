-- ===========================================
-- COMBINED MIGRATION FILE
-- ===========================================
-- This file combines all schemas for single-file deployment
-- Generated for PharmaLearn LMS - 21 CFR Part 11 Compliant
-- ===========================================

-- Run schemas in order by sourcing individual files
-- Or use the deploy_schemas.sh script for incremental deployment

\echo 'Starting PharmaLearn database migration...'

-- Extensions
\i ./schemas/00_extensions/01_uuid.sql
\i ./schemas/00_extensions/02_pgcrypto.sql
\i ./schemas/00_extensions/03_pg_trgm.sql
\i ./schemas/00_extensions/04_btree_gist.sql

-- Types
\i ./schemas/01_types/01_enums.sql
\i ./schemas/01_types/02_composite_types.sql
\i ./schemas/01_types/03_domains.sql

-- Core
\i ./schemas/02_core/01_audit_log.sql
\i ./schemas/02_core/02_revision_tracking.sql
\i ./schemas/02_core/03_workflow_states.sql
\i ./schemas/02_core/04_approval_engine.sql
\i ./schemas/02_core/05_esignature_base.sql
\i ./schemas/02_core/06_reason_enforcement.sql
\i ./schemas/02_core/07_esig_reauth.sql

-- Organization
\i ./schemas/03_organization/01_organizations.sql
\i ./schemas/03_organization/02_plants.sql
\i ./schemas/03_organization/03_departments.sql

-- Identity
\i ./schemas/04_identity/01_role_categories.sql
\i ./schemas/04_identity/02_roles.sql
\i ./schemas/04_identity/03_permissions.sql
\i ./schemas/04_identity/04_role_permissions.sql
\i ./schemas/04_identity/05_global_profiles.sql
\i ./schemas/04_identity/06_employees.sql
\i ./schemas/04_identity/07_employee_roles.sql
\i ./schemas/04_identity/08_subgroups.sql
\i ./schemas/04_identity/09_groups.sql
\i ./schemas/04_identity/10_employee_subgroups.sql
\i ./schemas/04_identity/11_job_responsibilities.sql
\i ./schemas/04_identity/12_biometric.sql
\i ./schemas/04_identity/13_standard_reasons.sql

-- Documents
\i ./schemas/05_documents/01_document_categories.sql
\i ./schemas/05_documents/02_documents.sql
\i ./schemas/05_documents/03_document_control.sql

-- Courses
\i ./schemas/06_courses/01_categories_subjects.sql
\i ./schemas/06_courses/02_topics.sql
\i ./schemas/06_courses/03_courses.sql
\i ./schemas/06_courses/04_trainers.sql
\i ./schemas/06_courses/05_venues_templates.sql

-- Training
\i ./schemas/07_training/01_gtp_masters.sql
\i ./schemas/07_training/02_schedules.sql
\i ./schemas/07_training/03_sessions_batches.sql
\i ./schemas/07_training/04_invitations.sql
\i ./schemas/07_training/05_attendance.sql
\i ./schemas/07_training/06_induction.sql
\i ./schemas/07_training/07_ojt.sql
\i ./schemas/07_training/08_self_learning.sql
\i ./schemas/07_training/09_feedback.sql

-- Assessment
\i ./schemas/08_assessment/01_question_banks.sql
\i ./schemas/08_assessment/02_questions.sql
\i ./schemas/08_assessment/03_question_papers.sql
\i ./schemas/08_assessment/04_attempts.sql
\i ./schemas/08_assessment/05_results.sql

-- Compliance
\i ./schemas/09_compliance/01_training_records.sql
\i ./schemas/09_compliance/02_certificates.sql
\i ./schemas/09_compliance/03_assignments.sql
\i ./schemas/09_compliance/04_waivers.sql
\i ./schemas/09_compliance/05_competencies.sql

-- Compliance Extensions
\i ./schemas/09_compliance/06_training_triggers.sql

-- Quality
\i ./schemas/10_quality/01_deviation_capa.sql
\i ./schemas/10_quality/02_change_control.sql
\i ./schemas/10_quality/03_regulatory_audit.sql

-- Audit
\i ./schemas/11_audit/01_security_audit.sql
\i ./schemas/11_audit/02_compliance_reports.sql

-- Notifications
\i ./schemas/12_notifications/01_notifications.sql
\i ./schemas/12_notifications/02_reminders.sql

-- Analytics
\i ./schemas/13_analytics/01_dashboards.sql
\i ./schemas/13_analytics/02_reports.sql
\i ./schemas/13_analytics/03_compliance_report_seeds.sql

-- Workflow
\i ./schemas/14_workflow/01_workflow_config.sql
\i ./schemas/14_workflow/02_delegation.sql
\i ./schemas/14_workflow/03_workflow_phases.sql

-- Cron
\i ./schemas/15_cron/01_cron_jobs.sql

-- Infrastructure
\i ./schemas/16_infrastructure/01_system_config.sql
\i ./schemas/16_infrastructure/02_file_storage.sql
\i ./schemas/16_infrastructure/03_integrations.sql
\i ./schemas/16_infrastructure/04_behavioral_controls.sql

-- RLS Policies
\i ./schemas/99_policies/01_rls_core.sql
\i ./schemas/99_policies/02_rls_training.sql
\i ./schemas/99_policies/03_rls_audit.sql

\echo 'Migration complete!'
