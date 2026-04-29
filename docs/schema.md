# PharmaLearn LMS — Complete Database Schema Reference

> **Version:** 3.0 | **Date:** April 2026  
> **Tables:** 292 | **Enums:** 70 | **Indexes:** 693 | **Triggers:** 142  
> **Compliance:** 21 CFR Part 11 · EU Annex 11 · WHO GMP

---

## Executive Summary

| Metric | Count | Notes |
|--------|-------|-------|
| **Total Tables** | 292 | Across 22 schema modules |
| **Schema Files** | 132 | SQL definition files |
| **Custom Enums** | 70 | Type-safe domain values |
| **Indexes** | 693 | Performance optimized |
| **Triggers** | 142 | Business rule enforcement |
| **Stored Functions** | 135 | Server-side logic |
| **RLS Policies** | 129 | Row-level security |
| **Materialized Views** | 1 | `mv_employee_training_status` |
| **Foreign Key Relations** | 400+ | Referential integrity |

---

## Table of Contents

1. [Schema Organization](#1-schema-organization)
2. [Naming Conventions](#2-naming-conventions)
3. [Enum Types (70 Total)](#3-enum-types-70-total)
4. [Complete Table Inventory (292 Tables)](#4-complete-table-inventory-292-tables)
5. [Core Tables Deep Dive](#5-core-tables-deep-dive)
6. [Key Relationships & ERD](#6-key-relationships--erd)
7. [21 CFR Part 11 Compliance Matrix](#7-21-cfr-part-11-compliance-matrix)
8. [Indexes & Performance](#8-indexes--performance)
9. [Triggers & Audit](#9-triggers--audit)
10. [RLS Policies](#10-rls-policies)
11. [Data Retention](#11-data-retention)

---

## 1. Schema Organization

```
supabase/schemas/
├── 00_extensions/           # PostgreSQL extensions (4 files)
│   ├── 01_uuid.sql          # uuid-ossp
│   ├── 02_pgcrypto.sql      # pgcrypto
│   ├── 03_pg_trgm.sql       # pg_trgm (text search)
│   └── 04_btree_gist.sql    # btree_gist
│
├── 01_types/                # Enums, composite types, domains (3 files)
│   ├── 01_enums.sql         # 70 enum types
│   ├── 02_composite_types.sql
│   └── 03_domains.sql
│
├── 02_core/                 # Audit, revisions, workflow, e-sigs (11 files)
│   ├── 01_audit_log.sql     # audit_trails (immutable)
│   ├── 02_revision_tracking.sql
│   ├── 03_workflow_states.sql
│   ├── 04_approval_engine.sql
│   ├── 05_esignature_base.sql
│   ├── 06_reason_enforcement.sql
│   ├── 07_esig_reauth.sql
│   ├── 08_schema_changelog.sql
│   ├── 09_events_outbox.sql
│   ├── 10_integrity_verification.sql
│   └── 11_standard_reason_enforcement.sql
│
├── 03_organization/         # Multi-tenant hierarchy (3 files)
│   ├── 01_organizations.sql
│   ├── 02_plants.sql
│   └── 03_departments.sql
│
├── 03_config/               # System settings & policies (9 files)
│   ├── 01_retention_policies.sql
│   ├── 02_numbering_schemes.sql
│   ├── 03_approval_matrices.sql
│   ├── 04_password_policies.sql
│   ├── 05_validation_rules.sql
│   ├── 06_system_settings.sql
│   ├── 07_feature_flags.sql
│   ├── 08_mail_settings.sql
│   └── 09_time_zone_registry.sql
│
├── 03_access_control/       # Permission overrides (1 file)
│   └── 07_permission_overrides.sql
│
├── 04_identity/             # Users, roles, permissions (20 files)
│   ├── 01_role_categories.sql
│   ├── 02_roles.sql
│   ├── 03_permissions.sql
│   ├── 04_global_profiles.sql
│   ├── 05_employees.sql
│   ├── 06_employee_roles.sql
│   ├── 07_subgroups.sql
│   ├── 08_groups.sql
│   ├── 09_group_subgroups.sql
│   ├── 10_employee_subgroups.sql
│   ├── 11_job_responsibilities.sql
│   ├── 12_biometric_registrations.sql
│   ├── 13_standard_reasons.sql
│   ├── 14_content_translations.sql
│   ├── 15_user_credentials.sql
│   ├── 16_sso_configurations.sql
│   ├── 17_operational_delegations.sql
│   ├── 18_training_coordinator_assignments.sql
│   ├── 19_user_sessions.sql
│   └── 20_consent_records.sql
│
├── 05_documents/            # Document control (4 files)
│   ├── 01_document_categories.sql
│   ├── 02_documents.sql
│   ├── 03_document_control.sql
│   └── 04_document_readings.sql
│
├── 06_courses/              # Course structure (5 files)
│   ├── 01_categories_subjects.sql
│   ├── 02_topics.sql
│   ├── 03_courses.sql
│   ├── 04_trainers.sql
│   └── 05_venues_templates.sql
│
├── 07_training/             # Training delivery (13 files)
│   ├── 01_gtp_masters.sql
│   ├── 02_schedules.sql
│   ├── 03_sessions_batches.sql
│   ├── 04_invitations.sql
│   ├── 05_attendance.sql
│   ├── 06_induction.sql
│   ├── 07_ojt.sql
│   ├── 08_self_learning.sql
│   ├── 09_self_study.sql
│   ├── 09_feedback.sql
│   ├── 10_employee_training_obligations.sql
│   ├── 11_curricula.sql
│   ├── 12_matrix_curriculum_bridge.sql
│   └── 13_periodic_review_schedule.sql
│
├── 08_assessment/           # Assessments & results (6 files)
│   ├── 01_question_banks.sql
│   ├── 02_questions.sql
│   ├── 03_question_papers.sql
│   ├── 04_attempts.sql
│   ├── 05_results.sql
│   └── 06_remedial_trainings.sql
│
├── 09_compliance/           # Training records & certs (9 files)
│   ├── 01_training_records.sql
│   ├── 02_certificates.sql
│   ├── 03_assignments.sql
│   ├── 04_waivers.sql
│   ├── 05_competencies.sql
│   ├── 05_external_training.sql
│   ├── 06_training_triggers.sql
│   ├── 07_certificate_invalidation.sql
│   ├── 08_data_archives.sql
│   └── 09_archive_jobs.sql
│
├── 10_quality/              # Deviations, CAPA, CC (3 files)
│   ├── 01_deviation_capa.sql
│   ├── 02_change_control.sql
│   └── 03_regulatory_audit.sql
│
├── 11_audit/                # Security & compliance audit (4 files)
│   ├── 01_security_audit.sql
│   ├── 02_compliance_reports.sql
│   ├── 02_audit_consolidation.sql
│   └── 03_audit_canonicalization.sql
│
├── 12_notifications/        # Notifications & reminders (2 files)
│   ├── 01_notifications.sql
│   └── 02_reminders.sql
│
├── 13_analytics/            # Dashboards & KPIs (6 files)
│   ├── 01_dashboards.sql
│   ├── 02_reports.sql
│   ├── 03_compliance_report_seeds.sql
│   ├── 04_translated_views.sql
│   ├── 05_kpi_definitions.sql
│   └── 06_materialized_views.sql
│
├── 14_workflow/             # Workflow engine (3 files)
│   ├── 01_workflow_config.sql
│   ├── 02_delegation.sql
│   └── 03_workflow_phases.sql
│
├── 15_cron/                 # Scheduled jobs (4 files)
│   ├── 01_cron_jobs.sql
│   ├── 02_business_continuity.sql
│   └── 04_business_continuity.sql
│
├── 16_infrastructure/       # System config & integrations (5 files)
│   ├── 01_system_config.sql
│   ├── 02_file_storage.sql
│   ├── 03_integrations.sql
│   ├── 04_behavioral_controls.sql
│   └── 05_api_enterprise.sql
│
├── 17_extensions/           # Optional features (10 files)
│   ├── 00_extensions_schema.sql
│   ├── 01_learning_paths.sql
│   ├── 02_gamification.sql
│   ├── 03_knowledge_base.sql
│   ├── 04_discussions.sql
│   ├── 05_cost_tracking.sql
│   ├── 06_user_preferences.sql
│   ├── 07_content_library.sql
│   ├── 08_surveys_polls.sql
│   └── 08_xapi_constraints.sql
│
└── 99_policies/             # RLS & validation (6 files)
    ├── 01_rls_core.sql
    ├── 02_rls_training.sql
    ├── 03_rls_audit.sql
    ├── 04_rls_config.sql
    ├── 05_rls_compliance.sql
    └── 06_integrity_validation.sql
```

---

## 2. Naming Conventions

### 2.1 Table Names
| Rule | Example | Anti-pattern |
|------|---------|--------------|
| Plural `snake_case` | `training_records`, `employees` | `TrainingRecord` |
| Primary key always `id UUID` | `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()` | `record_id` |
| Foreign keys suffix `_id` | `employee_id`, `course_id` | `employee` |
| Timestamps end in `_at` | `created_at`, `completed_at` | `creation_date` |
| Booleans prefix `is_`/`has_`/`requires_` | `is_active`, `requires_approval` | `active` |

### 2.2 Multi-Tenancy Columns
Every business table includes:
```sql
organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,        -- optional
department_id UUID REFERENCES departments(id) ON DELETE SET NULL  -- optional
```

### 2.3 Standard Audit Columns
```sql
created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by    UUID REFERENCES employees(id),
updated_at    TIMESTAMPTZ,
updated_by    UUID REFERENCES employees(id),
is_active     BOOLEAN NOT NULL DEFAULT true
```

---

## 3. Enum Types (70 Total)

### 3.1 Workflow & Status Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `workflow_state` | draft, initiated, pending_approval, approved, returned, dropped, active, inactive | Object lifecycle |
| `approval_decision` | approve, return, drop | Workflow decisions |
| `approval_requirement` | by_approval_group, by_immediate_supervisor, not_required | Approval routing |

### 3.2 Identity Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `role_category` | login, non_login | User type (accounts vs biometric-only) |
| `employee_status` | active, inactive, locked, terminated | Account state |

### 3.3 Document Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `document_type` | sop, policy, guideline, form, procedure, work_instruction, specification, manual | Document classification |
| `document_status` | draft, initiated, under_review, approved, active, superseded, obsolete, inactive | Document lifecycle |

### 3.4 Course & Training Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `course_type` | one_time, refresher, recurring | Course recurrence |
| `training_type` | safety, gmp, technical, induction, on_job, self_study, external, regulatory, quality, soft_skills | Training classification |
| `session_type` | online, offline, hybrid, self_paced | Delivery mode |
| `session_status` | scheduled, invitation_sent, nominations_open, batch_formed, in_progress, completed, cancelled | Session lifecycle |
| `invitation_response` | pending, accepted, rejected, tentative | RSVP status |
| `nomination_status` | pending, approved, rejected, waitlisted | Self-nomination state |
| `batch_status` | formed, in_progress, completed, cancelled | Batch lifecycle |
| `participant_status` | enrolled, confirmed, attended, absent, late, excused, skipped, disqualified, completed | Trainee status |
| `enrollment_source` | invitation, self_nomination, manual, induction, retraining, refresher, training_matrix | How trainee was enrolled |
| `attendance_method` | online, offline, biometric, qr_code, manual | Check-in method |
| `attendance_status` | present, absent, late, excused, partial | Attendance record |

### 3.5 Assessment Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `question_type` | multiple_choice, multiple_select, true_false, descriptive, fill_in_blanks, matching, sequence | Question format |
| `difficulty_level` | easy, medium, hard | Question difficulty |
| `question_paper_status` | draft, prepared, released, in_progress, completed, extended, cancelled | Paper lifecycle |
| `assessment_result` | pass, fail, pending_evaluation, waived, incomplete | Attempt outcome |

### 3.6 Compliance & Assignment Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `assignment_type` | role, department, individual, capa, onboarding, retraining, refresher, sop_update | Why training was assigned |
| `assignment_source` | manual, sop_update, capa, employee_created, transfer, training_matrix, expiration, system | Origin of assignment |
| `assignment_status` | assigned, acknowledged, in_progress, completed, overdue, waived, cancelled | Assignment state |
| `assignment_priority` | low, medium, high, critical | Urgency level |
| `certificate_status` | active, expired, revoked, superseded, obsolete, suspended | Certificate validity |
| `obligation_status` | pending, in_progress, completed, overdue, failed, waived, cancelled | Training obligation state |
| `obligation_item_type` | course, document_read, ojt, assessment, external_training | What needs to be completed |
| `failure_disposition` | retraining_required, investigation_required, both, waived | What happens after fail |
| `training_result` | pass, fail, waived, incomplete, in_progress | Training outcome |
| `retraining_reason` | failed, absent, skipped, sop_updated, disqualified, expired, capa | Why retraining needed |
| `reading_status` | pending, in_progress, read, acknowledged, overdue, terminated | Document reading state |

### 3.7 Quality Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `quality_event_type` | deviation, capa, change_control, audit_finding, complaint, oos, incident | Quality event class |
| `quality_event_status` | open, investigation, in_progress, pending_approval, closed, cancelled | Event lifecycle |
| `capa_status` | open, rca_in_progress, action_planning, implementation, training_assigned, effectiveness_check_pending, closed | CAPA workflow |

### 3.8 Audit & E-Signature Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `signature_meaning` | authored, reviewed, approved, acknowledged, witnessed, verified, rejected | 21 CFR Part 11 meanings |
| `audit_action` | created, read, updated, deleted, status_changed, approved, rejected, submitted, completed, cancelled, signed, verified, exported, printed, emailed, login, logout, password_changed, role_assigned, role_removed | Audit actions |
| `access_action` | login, logout, session_timeout, failed_login, account_locked, password_reset, password_changed, mfa_enabled, mfa_disabled, mfa_verified, mfa_failed | Security events |
| `session_end_reason` | logout, session_timeout, forced, system, concurrent_login | How session ended |

### 3.9 Notification Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `notification_channel` | email, in_app, sms, push | Delivery channel |
| `notification_status` | pending, queued, sent, delivered, read, failed, bounced | Delivery state |
| `notification_priority` | low, normal, high, urgent | Message priority |
| `mail_template_type` | course_invitation, batch_formation_acceptance, attendance_status_trainee, attendance_status_supervisor, question_paper_released, result_to_trainee, result_to_supervisor, short_term_evaluation, long_term_evaluation, feedback_request, document_reading, training_reminder, certificate_expiry_reminder, training_completion, assignment_notification, password_reset, account_locked, welcome_email | Email templates |

### 3.10 Trainer & Venue Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `trainer_status` | initiated, pending_approval, active, inactive, suspended | Trainer lifecycle |
| `venue_type` | classroom, lab, conference_room, virtual, field, workshop | Venue classification |

### 3.11 Feedback & GTP Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `feedback_template_type` | long_term_evaluation, short_term_evaluation, feedback, trainer_evaluation | Feedback form type |
| `gtp_status` | draft, active, closed, archived | GTP lifecycle |
| `gtp_type` | group, subgroup, department, plant | GTP scope |
| `schedule_status` | planned, confirmed, completed, cancelled, postponed | Schedule state |

### 3.12 Content & SCORM Enums

| Enum | Values | Purpose |
|------|--------|---------|
| `content_type` | video, audio, pdf, slideshow, html5, scorm, xapi, interactive, quiz, reading, embedded_link, live_session | Content format |
| `content_status` | draft, processing, ready, failed, archived | Content lifecycle |

---

## 4. Complete Table Inventory (292 Tables)

### 4.1 Organization Module (3 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `organizations` | Multi-tenant root | org_code, legal_name, compliance_frameworks[], audit_retention_years |
| `plants` | Manufacturing sites | plant_code, timezone, address, organization_id |
| `departments` | Org units | department_code, manager_id, parent_department_id, organization_id |

### 4.2 Identity & Access Module (28 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `employees` | User accounts | username (immutable), email, employee_id, status, induction_completed, auth_user_id |
| `roles` | Role definitions | name, level, category, permissions |
| `role_categories` | Role groupings | name (login/non_login) |
| `permissions` | Permission definitions | code, name, description |
| `employee_roles` | Employee-role mapping | employee_id, role_id, is_primary |
| `employee_permission_overrides` | Direct grants/denies | employee_id, permission, granted, reason |
| `groups` | Training groups | name, organization_id |
| `subgroups` | Group subdivisions | group_id, name, default_training_types[] |
| `group_subgroups` | Group-subgroup mapping | group_id, subgroup_id |
| `employee_subgroups` | Employee-subgroup membership | employee_id, subgroup_id |
| `job_responsibilities` | Role-based requirements | employee_id, responsibility, courses[] |
| `global_profiles` | Organization-wide settings | profile_name, permissions[] |
| `biometric_registrations` | Fingerprint/face data | employee_id, biometric_type, template_hash |
| `standard_reasons` | Controlled justifications | code, description, category, requires_esig |
| `content_translations` | i18n content | entity_type, entity_id, locale, translations |
| `user_credentials` | Password history | employee_id, password_hash, created_at |
| `sso_configurations` | SSO provider config | provider, client_id, tenant_id, enabled |
| `sso_user_mappings` | SSO-employee linking | sso_provider_id, external_id, employee_id |
| `operational_delegations` | Temporary authority | delegator_id, delegate_id, permissions[], valid_from, valid_to |
| `training_coordinator_assignments` | Coordinator roles | employee_id, scope_type, scope_id |
| `user_sessions` | Active sessions | employee_id, token_hash, ip_address, expires_at |
| `consent_records` | Privacy consent | employee_id, consent_type, granted_at, revoked_at |

### 4.3 Core Infrastructure Module (15 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `audit_trails` | Immutable audit log | entity_type, entity_id, action, event_category, row_hash, previous_hash |
| `electronic_signatures` | 21 CFR Part 11 e-sigs | employee_id, meaning, entity_type, entity_id, integrity_hash |
| `signature_meanings` | E-sig meaning config | meaning, display_text, applicable_entities[], requires_password_reauth |
| `esignature_reauth_sessions` | Re-authentication | employee_id, expires_at, password_verified |
| `workflow_transitions` | State machine config | from_status, to_status, allowed_roles[] |
| `approval_engine` | Approval chain config | entity_type, approval_levels[], requires_esignature |
| `pending_approvals` | Approval queue | entity_type, entity_id, approver_id, status |
| `approval_history` | Approval records | entity_type, entity_id, decision, comments |
| `schema_changelog` | Migration tracking | version, description, applied_at |
| `events_outbox` | Event sourcing | event_type, payload, processed_at |
| `integrity_verification_log` | Hash verification | entity_type, entity_id, verified_at, is_valid |
| `mandatory_reason_actions` | Reason enforcement | action_type, requires_reason |

### 4.4 Configuration Module (18 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `retention_policies` | Data retention | entity_type, retention_days, archive_enabled |
| `numbering_schemes` | Auto-numbering | entity_type, prefix, format, current_value |
| `numbering_sequences` | Sequence tracking | scheme_id, year, last_number |
| `approval_matrices` | Approval routing | entity_type, conditions, approvers[] |
| `approval_matrix_steps` | Multi-step approvals | matrix_id, step_order, approver_type |
| `password_policies` | Password rules | min_length, complexity, history_count, expiry_days |
| `validation_rules` | Field validation | entity_type, field, rule, message |
| `system_settings` | Global config | key, value, category |
| `feature_flags` | Feature toggles | flag_name, enabled, rollout_percentage |
| `tenant_feature_flags` | Tenant-specific flags | organization_id, flag_name, enabled |
| `mail_event_templates` | Email templates | event_type, subject, body |
| `mail_event_subscriptions` | Email subscriptions | employee_id, event_type, enabled |
| `mail_delivery_log` | Email delivery | template_id, recipient, sent_at, status |
| `time_zone_registry` | Timezone config | code, utc_offset, name |

### 4.5 Document Control Module (12 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `document_categories` | Document classification | name, code, parent_id |
| `document_category_tags` | Category tagging | category_id, tag |
| `documents` | Controlled documents | document_number, title, type, status, effective_date |
| `document_versions` | Version history | document_id, version_number, content_hash |
| `document_issuances` | Document distribution | document_id, issued_to_employee_id, issued_at |
| `document_readings` | Read tracking | document_id, employee_id, started_at, completed_at, status |
| `document_retrieval_log` | Retrieval records | issuance_id, retrieved_at, retrieved_by |
| `document_print_log` | Print records | document_id, printed_by, copies, reason |

### 4.6 Courses Module (19 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `categories` | Course categories | name, parent_id, display_order |
| `subjects` | Subject areas | category_id, name, description |
| `topics` | Topic breakdown | subject_id, name, learning_objectives |
| `topic_subject_tags` | Topic-subject links | topic_id, subject_id |
| `topic_category_tags` | Topic-category links | topic_id, category_id |
| `topic_document_links` | Topic-document links | topic_id, document_id |
| `courses` | Course definitions | code, name, training_types[], duration_hours, passing_score |
| `course_versions` | Course version history | course_id, version_number, content_changes |
| `course_prerequisites` | Prerequisite mapping | course_id, prerequisite_course_id |
| `course_topics` | Course-topic mapping | course_id, topic_id, sequence |
| `course_documents` | Course-document links | course_id, document_id, is_mandatory |
| `course_subgroup_access` | Access control | course_id, subgroup_id |
| `trainers` | Qualified trainers | employee_id, status, certifications[] |
| `trainer_courses` | Trainer-course mapping | trainer_id, course_id, qualified_date |
| `external_trainers` | External trainers | name, organization, email, specializations |
| `external_trainer_courses` | External trainer quals | external_trainer_id, course_id |
| `training_venues` | Training venues | name, capacity, location, equipment[] |
| `feedback_evaluation_templates` | Feedback forms | template_type, questions[], is_active |

### 4.7 Training Module (45 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `gtp_masters` | Group Training Plans | unique_code, name, training_type, status |
| `gtp_courses` | GTP-course mapping | gtp_id, course_id, sequence_number, recurrence_months |
| `gtp_documents` | GTP-document links | gtp_id, document_id, is_mandatory |
| `gtp_subgroup_access` | GTP access control | gtp_id, subgroup_id |
| `training_schedules` | Schedule definitions | gtp_id, start_date, end_date, trainer_id, venue_id |
| `schedule_courses` | Schedule-course mapping | schedule_id, course_id |
| `schedule_trainers` | Schedule-trainer mapping | schedule_id, trainer_id |
| `training_sessions` | Individual sessions | schedule_id, session_date, delivery_mode |
| `training_batches` | Batch groupings | session_id, batch_code, max_participants |
| `batch_trainees` | Batch-trainee mapping | batch_id, employee_id, status |
| `training_invitations` | Learner invitations | session_id, employee_id, response, invited_at |
| `training_nominations` | Self-nominations | schedule_id, employee_id, status |
| `training_waitlist` | Waitlist management | schedule_id, employee_id, position |
| `session_attendance` | Attendance records | session_id, employee_id, check_in_time, check_out_time, status |
| `daily_attendance_summary` | Daily summaries | session_id, date, present_count, absent_count |
| `training_attendance_totals` | Attendance aggregates | employee_id, course_id, total_hours |
| `induction_programs` | Induction definitions | name, modules[], duration_days |
| `induction_modules` | Module breakdown | induction_id, name, sequence, duration_hours |
| `employee_induction` | Employee enrollments | employee_id, program_id, status, trainer_id |
| `employee_induction_progress` | Module progress | employee_induction_id, module_id, completed_at |
| `ojt_masters` | OJT definitions | name, evaluation_criteria[], estimated_hours |
| `ojt_tasks` | OJT task breakdown | ojt_id, task_name, evaluation_method |
| `employee_ojt` | OJT assignments | employee_id, ojt_master_id, evaluator_id, status |
| `ojt_task_completion` | Task completions | employee_ojt_id, task_id, completed_at, esignature_id |
| `self_learning_assignments` | Self-paced assignments | employee_id, course_id, due_date |
| `self_study_courses` | Self-study definitions | course_id, is_open_enrollment |
| `self_study_enrollments` | Self-study enrollments | course_id, employee_id, enrolled_at |
| `lesson_progress` | Content progress | employee_id, lesson_id, progress_percentage, completed_at |
| `learning_progress` | Overall progress | employee_id, course_id, completed_lessons, total_lessons |
| `training_feedback` | Session feedback | schedule_id, employee_id, feedback_type, responses |
| `trainer_feedback` | Trainer evaluations | session_id, trainer_id, ratings |
| `feedback_summary` | Aggregated feedback | schedule_id, average_rating, response_count |
| `external_training_records` | External certifications | employee_id, course_name, institution, completion_date |
| `employee_training_obligations` | Training obligations | employee_id, obligation_type, entity_id, due_date, status |
| `curricula` | Curriculum definitions | name, description, courses[] |
| `curriculum_items` | Curriculum-course mapping | curriculum_id, course_id, sequence |
| `curriculum_job_roles` | Curriculum-role mapping | curriculum_id, role_id |
| `training_matrix` | Role-course matrix | role_id, course_id, is_mandatory |
| `training_matrix_items` | Matrix items | matrix_id, course_id, frequency |
| `annual_training_plans` | Yearly plans | year, organization_id, courses[], budget |
| `training_budgets` | Budget tracking | year, department_id, allocated, spent |
| `training_expenses` | Expense records | training_id, amount, category |
| `periodic_review_schedules` | Review scheduling | entity_type, frequency_months, last_review |
| `periodic_review_log` | Review records | entity_id, reviewed_at, reviewed_by |

### 4.8 Assessment Module (18 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `question_banks` | Question collections | name, category, topic_id |
| `question_bank_categories` | Bank categorization | bank_id, category_id |
| `questions` | Question definitions | question_bank_id, question_type, text, points |
| `question_options` | MCQ options | question_id, option_text, is_correct |
| `question_blanks` | Fill-in-blank answers | question_id, blank_index, correct_answer |
| `question_matching_pairs` | Matching pairs | question_id, left_item, right_item |
| `question_papers` | Assessment papers | name, total_marks, passing_percentage, time_limit_minutes |
| `question_paper_sections` | Paper sections | paper_id, name, instructions |
| `question_paper_questions` | Paper-question mapping | paper_id, question_id, sequence |
| `assessment_attempts` | Attempt records | employee_id, paper_id, started_at, submitted_at |
| `assessment_responses` | Answer records | attempt_id, question_id, response, is_correct, marks |
| `assessment_results` | Final results | attempt_id, total_score, percentage, status |
| `assessment_activity_log` | Activity tracking | attempt_id, action, timestamp |
| `grading_queue` | Manual grading | attempt_id, question_id, grader_id, status |
| `phase_extensions` | Time extensions | attempt_id, requested_minutes, granted_minutes |
| `result_appeals` | Result appeals | result_id, reason, status |
| `remedial_trainings` | Remedial assignments | employee_id, course_id, reason, status |

### 4.9 Compliance Module (22 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `training_records` | Official records | employee_id, course_id, completion_date, status, esignature_id |
| `training_record_items` | Record line items | training_record_id, item_type, completion_status |
| `certificate_templates` | Certificate designs | name, template_content, signatories[] |
| `certificates` | Issued certificates | training_record_id, certificate_number, issued_at |
| `certificate_signatures` | Certificate signers | certificate_id, signer_id, esignature_id |
| `certificate_verifications` | Verification log | certificate_id, verified_at, verified_by |
| `training_assignments` | Assigned training | employee_id, course_id, due_date, status |
| `training_exemptions` | Training exemptions | assignment_id, reason, approved_by |
| `exemption_employees` | Exemption recipients | exemption_id, employee_id |
| `training_waivers` | Training waivers | assignment_id, reason, approved_by, esignature_id |
| `waiver_approval_history` | Waiver approvals | waiver_id, approver_id, decision |
| `competencies` | Competency definitions | name, description, courses[] |
| `employee_competencies` | Competency status | employee_id, competency_id, status, expires_at |
| `role_competencies` | Role-competency mapping | role_id, competency_id |
| `competency_gaps` | Gap analysis | employee_id, competency_id, gap_type |
| `competency_history` | Competency changes | employee_competency_id, changed_at, old_status, new_status |
| `training_trigger_rules` | Auto-assignment rules | event_source, entity_type, criteria, courses[] |
| `training_trigger_events` | Fired triggers | rule_id, entity_id, processed_at |
| `data_archives` | Archived data | entity_type, entity_id, archived_at, archive_path |
| `archive_jobs` | Archive jobs | job_type, status, started_at, completed_at |
| `archive_manifest` | Archive contents | archive_id, entity_type, count |

### 4.10 Quality Module (14 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `deviations` | Deviation records | deviation_number, description, severity, status |
| `deviation_training_requirements` | Deviation-training links | deviation_id, course_id, employees[] |
| `capa_records` | CAPA tracking | capa_number, deviation_id, root_cause, status |
| `change_controls` | Change management | change_number, description, impact_assessment, status |
| `change_control_training` | CC-triggered training | change_control_id, course_id |
| `change_control_training_status` | CC training status | change_control_training_id, employee_id, status |
| `regulatory_audits` | Audit records | audit_number, type, auditor, status |
| `audit_findings` | Finding details | audit_id, finding_number, severity, response |
| `audit_finding_training` | Finding-training links | finding_id, course_id |
| `audit_preparation_items` | Prep checklists | audit_id, item_description, responsible_id, status |
| `regulatory_submissions` | Submission tracking | submission_type, submitted_at, status |

### 4.11 Notification Module (12 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `notification_templates` | Message templates | type, subject, body, placeholders[] |
| `notification_queue` | Pending notifications | template_id, recipient_id, scheduled_at |
| `notification_log` | Sent notifications | queue_id, sent_at, status, error |
| `user_notifications` | User inbox | employee_id, title, body, read_at |
| `notification_preferences` | User settings | employee_id, channel, event_type, enabled |
| `reminder_rules` | Reminder config | entity_type, days_before, template_id |
| `scheduled_reminders` | Scheduled reminders | entity_id, reminder_date, sent |
| `escalation_rules` | Escalation config | trigger_condition, escalate_to, delay_hours |
| `escalation_history` | Escalation records | rule_id, entity_id, escalated_at |
| `active_escalations` | Active escalations | entity_type, entity_id, level |

### 4.12 Analytics Module (15 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `dashboard_widgets` | Widget definitions | name, query, visualization_type |
| `user_dashboards` | Custom dashboards | employee_id, widgets[], layout |
| `report_definitions` | Report definitions | name, report_type, parameters[], sql_template |
| `report_executions` | Report runs | definition_id, executed_by, parameters, output_path |
| `scheduled_reports` | Scheduled reports | definition_id, schedule, recipients[] |
| `saved_report_filters` | Saved filters | report_id, employee_id, filters |
| `saved_filters` | General filters | entity_type, employee_id, filter_config |
| `kpi_definitions` | KPI metrics | name, calculation, target_value |
| `kpi_snapshots` | KPI history | kpi_id, value, captured_at |
| `training_analytics` | Aggregated metrics | period, total_sessions, completion_rate |
| `course_analytics` | Course metrics | course_id, attempts, pass_rate |
| `employee_training_analytics` | Employee metrics | employee_id, completed_count, hours |
| `compliance_snapshots` | Point-in-time compliance | snapshot_date, organization_id, metrics |
| `training_effectiveness` | Effectiveness metrics | course_id, pre_score, post_score, improvement |

### 4.13 Workflow Module (12 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `workflow_definitions` | Workflow config | name, entity_type, phases[] |
| `workflow_phases` | Phase definitions | workflow_id, phase_name, approvers[], sequence |
| `workflow_instances` | Active workflows | definition_id, entity_id, current_phase, status |
| `workflow_instance_phases` | Instance phases | instance_id, phase_id, status |
| `workflow_tasks` | Pending approvals | instance_id, assignee_id, due_date |
| `workflow_history` | Approval history | instance_id, action, actor_id, comments |
| `workflow_approval_rules` | Approval rules | workflow_id, rule, approver_type |
| `approval_delegations` | Delegation config | delegator_id, delegate_id, valid_from, valid_to |
| `delegation_actions` | Delegation log | delegation_id, action, performed_at |
| `out_of_office` | OOO settings | employee_id, start_date, end_date, delegate_id |
| `parallel_approval_groups` | Parallel approvals | workflow_id, group_name, approvers[] |

### 4.14 Infrastructure Module (22 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `system_config_audit` | Config change log | key, old_value, new_value, changed_by |
| `file_storage` | File metadata | name, path, mime_type, size_bytes |
| `file_versions` | File versions | file_id, version_number, checksum |
| `file_associations` | File-entity links | file_id, entity_type, entity_id |
| `temporary_files` | Temp file tracking | file_id, expires_at |
| `integrations` | Integration config | name, type, endpoint, credentials |
| `integration_secrets` | Encrypted secrets | integration_id, key, encrypted_value |
| `integration_sync_logs` | Sync records | integration_id, synced_at, status |
| `webhooks` | Webhook config | url, events[], secret |
| `webhook_subscriptions` | Event subscriptions | webhook_id, event_type |
| `webhook_deliveries` | Delivery log | webhook_id, payload, status, attempts |
| `api_keys` | API key management | key_hash, name, permissions[], expires_at |
| `api_rate_limits` | Rate limit config | key_id, requests_per_minute |
| `external_id_mappings` | External ID links | external_system, external_id, entity_type, entity_id |
| `behavioral_control_definitions` | UI controls | control_name, default_behavior |
| `cron_jobs` | Scheduled jobs | name, schedule, command, enabled |
| `cron_job_history` | Job execution log | job_id, started_at, completed_at, status |
| `background_tasks` | Async task queue | task_type, payload, status |
| `business_continuity_plans` | BCP config | name, procedures[], last_tested |
| `disaster_recovery_drills` | DR drill records | plan_id, drill_date, results |
| `system_health_checks` | Health check config | check_name, endpoint, interval |
| `system_health_history` | Health history | check_id, status, response_time |
| `media_transcoding_jobs` | Transcoding queue | source_file_id, status, output_path |
| `data_exports` | Export jobs | entity_type, format, status, download_url |

### 4.15 Extensions Module (42 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `extensions.extension_status` | Extension toggles | category, is_enabled |
| **Learning Paths** | | |
| `learning_paths` | Structured paths | name, courses[], prerequisites[] |
| `learning_path_steps` | Path steps | path_id, step_order, course_id |
| `learning_path_enrollments` | Path enrollments | path_id, employee_id, enrolled_at |
| `learning_path_step_progress` | Step progress | enrollment_id, step_id, completed_at |
| **Gamification** | | |
| `badges` | Badge definitions | name, criteria, image_url |
| `employee_badges` | Awarded badges | employee_id, badge_id, awarded_at |
| `point_rules` | Point earning rules | action, points, conditions |
| `point_transactions` | Point history | employee_id, points, source |
| `employee_point_balances` | Point balances | employee_id, total_points |
| `leaderboards` | Leaderboard config | name, criteria, period |
| `leaderboard_snapshots` | Leaderboard history | leaderboard_id, rankings[], captured_at |
| **Knowledge Base** | | |
| `kb_categories` | KB categories | name, parent_id |
| `kb_articles` | KB articles | category_id, title, content, status |
| `kb_article_versions` | Article history | article_id, version_number, content |
| `kb_article_feedback` | Article ratings | article_id, employee_id, rating |
| `kb_article_views` | View tracking | article_id, employee_id, viewed_at |
| `kb_search_queries` | Search analytics | query, results_count, clicked_result |
| **Discussions** | | |
| `discussion_threads` | Discussion threads | entity_type, entity_id, title |
| `discussion_posts` | Thread posts | thread_id, author_id, content |
| `discussion_reactions` | Post reactions | post_id, employee_id, reaction_type |
| `discussion_subscriptions` | Thread subscriptions | thread_id, employee_id |
| `discussion_flags` | Flagged content | post_id, flagged_by, reason |
| **Surveys** | | |
| `surveys` | Survey definitions | name, questions[], status |
| `survey_questions` | Survey questions | survey_id, question_text, type |
| `survey_invitations` | Survey invitations | survey_id, employee_id, sent_at |
| `survey_responses` | Survey submissions | survey_id, respondent_id, submitted_at |
| `survey_answers` | Individual answers | response_id, question_id, answer |
| `survey_analytics` | Survey metrics | survey_id, response_rate, avg_score |
| `satisfaction_scales` | Rating scales | name, min_value, max_value |
| **Cost Tracking** | | |
| `cost_centers` | Cost centers | name, code, budget |
| `course_costs` | Course costs | course_id, cost_type, amount |
| `budget_alerts` | Budget alerts | cost_center_id, threshold, triggered_at |
| **Content Library** | | |
| `content_assets` | Media library | name, content_type, file_path |
| `lessons` | Course lessons | course_id, title, lesson_order |
| `lesson_content` | Lesson-content links | lesson_id, content_asset_id |
| `scorm_packages` | SCORM packages | content_asset_id, scorm_version, launch_url |
| `xapi_statements` | xAPI records | employee_id, verb, object, result |
| `xapi_verb_registry` | xAPI verbs | verb_id, display_name |
| `xapi_activity_profile` | Activity profiles | activity_id, profile_data |
| `xapi_activity_state` | Activity state | activity_id, state_data |
| `xapi_agent_profile` | Agent profiles | agent_id, profile_data |
| `content_view_tracking` | View analytics | content_asset_id, employee_id, event |
| **User Preferences** | | |
| `user_preferences` | User settings | employee_id, preferences |
| `user_accessibility_needs` | Accessibility | employee_id, needs[] |
| `ui_shortcuts` | UI shortcuts | employee_id, shortcut_config |
| `recent_items` | Recent items | employee_id, entity_type, entity_id |

### 4.16 Security Audit Module (6 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `login_audit_trail` | Login history | employee_id, ip_address, success, timestamp |
| `security_audit_trail` | Security events | event_type, severity, details |
| `data_access_audit` | Data access log | entity_type, entity_id, accessed_by, action |
| `permission_change_audit` | Permission changes | employee_id, permission, action, changed_by |
| `compliance_reports` | Compliance reports | report_type, generated_at, data |
| `legal_holds` | Legal hold records | entity_type, entity_id, hold_reason, expires_at |

---

## 5. Core Tables Deep Dive

### 5.1 employees (Identity Core)

```sql
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    auth_user_id UUID UNIQUE,              -- Supabase auth link
    organization_id UUID NOT NULL,
    plant_id UUID,
    department_id UUID,
    
    -- Identification (21 CFR §11.100(b) — unique, permanent username)
    employee_id TEXT NOT NULL,             -- Business ID (EMP001)
    username TEXT UNIQUE,                  -- Immutable after set
    email TEXT,
    
    -- Personal Info
    title TEXT,
    first_name TEXT NOT NULL,
    middle_name TEXT,
    last_name TEXT NOT NULL,
    designation TEXT,
    job_title TEXT,
    
    -- Hierarchy
    reporting_to UUID REFERENCES employees(id),
    authorized_deputy UUID REFERENCES employees(id),
    
    -- Authentication
    status employee_status DEFAULT 'active',
    mfa_enabled BOOLEAN DEFAULT false,
    last_login TIMESTAMPTZ,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMPTZ,
    must_change_password BOOLEAN DEFAULT false,
    
    -- Induction Gate (DB-enforced)
    induction_completed BOOLEAN NOT NULL DEFAULT false,
    induction_completed_at TIMESTAMPTZ,
    
    -- Compliance Metrics
    compliance_percent NUMERIC(5,2) DEFAULT 0,
    training_due_count INTEGER DEFAULT 0,
    overdue_training_count INTEGER DEFAULT 0,
    
    -- Workflow
    workflow_status workflow_state DEFAULT 'initiated',
    revision_no INTEGER DEFAULT 0,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    UNIQUE(organization_id, employee_id),
    UNIQUE(organization_id, email)
);
```

### 5.2 audit_trails (21 CFR Part 11 Core)

```sql
CREATE TABLE audit_trails (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Entity Reference
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    
    -- Action Details
    action TEXT NOT NULL,
    action_category TEXT NOT NULL DEFAULT 'modification',
    action_description TEXT,
    
    -- Unified Event Classification (replaces 5 legacy tables)
    event_category TEXT NOT NULL DEFAULT 'DATA_CHANGE'
        CHECK (event_category IN (
            'DATA_CHANGE', 'LOGIN', 'LOGOUT', 'PERMISSION_CHANGE',
            'CONFIG_CHANGE', 'DATA_ACCESS', 'ESIGNATURE',
            'PASSWORD_CHANGE', 'SESSION_TIMEOUT', 'FAILED_LOGIN', 'ACCOUNT_LOCK'
        )),
    
    -- Change Tracking
    old_value JSONB,
    new_value JSONB,
    changed_fields TEXT[],
    field_name TEXT,
    
    -- Actor Information
    performed_by UUID,
    performed_by_name TEXT NOT NULL DEFAULT 'System',
    performed_by_role TEXT,
    performed_by_email TEXT,
    
    -- Reason Tracking (Standard Reasons)
    reason TEXT,
    reason_code TEXT,
    standard_reason_id UUID,
    
    -- Context
    plant_id UUID,
    organization_id UUID,
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    
    -- Security Context
    failure_reason TEXT,
    mfa_verified BOOLEAN,
    device_info JSONB,
    
    -- Timestamp (immutable)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Integrity (21 CFR Part 11 tamper detection)
    row_hash TEXT NOT NULL,
    previous_hash TEXT,
    revision_number INTEGER NOT NULL DEFAULT 1
);

-- IMMUTABILITY TRIGGER (prevents UPDATE/DELETE)
CREATE TRIGGER audit_trail_immutable
    BEFORE UPDATE OR DELETE ON audit_trails
    FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();
```

### 5.3 electronic_signatures (21 CFR Part 11)

```sql
CREATE TABLE electronic_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Signer Information
    employee_id UUID NOT NULL,
    employee_name TEXT NOT NULL,
    employee_email TEXT,
    employee_title TEXT,
    employee_id_code TEXT,
    
    -- Signature Details
    meaning signature_meaning NOT NULL,
    meaning_display TEXT NOT NULL,
    reason TEXT,
    
    -- Entity Reference
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    
    -- Verification Context
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    
    -- Integrity (21 CFR Part 11)
    integrity_hash TEXT NOT NULL,
    data_snapshot JSONB,
    hash_schema_version INTEGER NOT NULL DEFAULT 1,
    canonical_payload JSONB,
    record_hash TEXT,
    
    -- Authentication Verification
    password_reauth_verified BOOLEAN DEFAULT false,
    biometric_verified BOOLEAN DEFAULT false,
    mfa_verified BOOLEAN DEFAULT false,
    
    -- §11.200(a) — First-signing-in-session
    is_first_in_session BOOLEAN NOT NULL DEFAULT FALSE,
    session_token_hash TEXT,
    
    -- Signature Chain
    prev_signature_id UUID REFERENCES electronic_signatures(id),
    
    -- Validity
    is_valid BOOLEAN DEFAULT true,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    revoked_by UUID,
    
    organization_id UUID,
    plant_id UUID
);
```

### 5.4 training_records (Compliance Core)

```sql
CREATE TABLE training_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    organization_id UUID NOT NULL,
    employee_id UUID NOT NULL,
    
    -- Training Reference
    training_type training_type NOT NULL,
    training_source TEXT NOT NULL,
    training_method TEXT CHECK (training_method IN (
        'ILT', 'EXTERNAL', 'BLENDED', 'OJT', 'DOC_READ', 'COMPLETED', 'WBT'
    )),
    course_id UUID,
    gtp_id UUID,
    schedule_id UUID,
    induction_id UUID,
    ojt_id UUID,
    document_id UUID,
    
    -- External Training
    external_training_name TEXT,
    external_training_provider TEXT,
    
    -- Completion Details
    training_date DATE NOT NULL,
    completion_date DATE,
    expiry_date DATE,
    duration_hours NUMERIC(6,2),
    
    -- Results
    attendance_percentage NUMERIC(5,2),
    assessment_score NUMERIC(5,2),
    assessment_passed BOOLEAN,
    overall_status training_completion_status NOT NULL,
    
    -- Certificate
    certificate_id UUID,
    
    -- Metadata
    trainer_names TEXT,
    venue_name TEXT,
    remarks TEXT,
    evidence_attachments JSONB DEFAULT '[]',
    
    -- E-Signature
    esignature_id UUID,
    
    -- Postdating (GxP ALCOA+)
    is_postdated BOOLEAN NOT NULL DEFAULT FALSE,
    postdated_reason_id UUID,
    postdated_reason_text TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 6. Key Relationships & ERD

### 6.1 Employee Training Flow

```
┌─────────────┐
│  employees  │
└──────┬──────┘
       │
       ├──────────────────────────────────────────────────────────────┐
       │                                                              │
       ▼                                                              ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────────────┐
│ employee_roles  │────►│     roles       │────►│      permissions            │
└─────────────────┘     └─────────────────┘     └─────────────────────────────┘
       │
       ├──────────────────────────────────────────────────────────────┐
       │                                                              │
       ▼                                                              ▼
┌─────────────────────────┐                              ┌────────────────────────┐
│ training_assignments    │                              │ employee_training_     │
│ (what they must do)     │                              │ obligations            │
└──────────┬──────────────┘                              └────────────┬───────────┘
           │                                                          │
           ▼                                                          ▼
┌─────────────────────────┐     ┌─────────────────┐     ┌────────────────────────┐
│ training_invitations    │────►│ training_       │────►│ session_attendance     │
│ (session invites)       │     │ sessions        │     │ (check-in/out)         │
└─────────────────────────┘     └─────────────────┘     └────────────┬───────────┘
                                        │                            │
                                        ▼                            │
                                ┌─────────────────┐                  │
                                │ training_       │                  │
                                │ schedules       │                  │
                                └────────┬────────┘                  │
                                         │                           │
                                         ▼                           ▼
                                ┌─────────────────┐     ┌────────────────────────┐
                                │ gtp_masters     │     │ assessment_attempts    │
                                │ (Group Plans)   │     │ (quiz/exam)            │
                                └────────┬────────┘     └────────────┬───────────┘
                                         │                           │
                                         ▼                           ▼
                                ┌─────────────────┐     ┌────────────────────────┐
                                │ courses         │     │ assessment_results     │
                                └─────────────────┘     └────────────┬───────────┘
                                                                     │
                                         ┌───────────────────────────┘
                                         │
                                         ▼
                                ┌─────────────────────────┐
                                │ training_records        │◄────── Official Record
                                │ (compliance record)     │
                                └──────────┬──────────────┘
                                           │
                                           ▼
                                ┌─────────────────────────┐
                                │ certificates            │◄────── If passed
                                │ (issued certs)          │
                                └──────────┬──────────────┘
                                           │
                                           ▼
                                ┌─────────────────────────┐
                                │ employee_competencies   │◄────── Competency updated
                                │ (skill tracking)        │
                                └─────────────────────────┘
```

### 6.2 Document Control Flow

```
┌─────────────────────┐
│ document_categories │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐     ┌─────────────────────────┐
│     documents       │────►│   document_versions     │ (1:N versioning)
│ (controlled docs)   │     │   (version history)     │
└──────────┬──────────┘     └─────────────────────────┘
           │
           ├─────────────────────────────────────────────┐
           │                                             │
           ▼                                             ▼
┌─────────────────────────┐             ┌────────────────────────────┐
│ document_issuances      │             │ document_readings          │
│ (hard copy distribution)│             │ (read acknowledgements)    │
└──────────┬──────────────┘             └────────────┬───────────────┘
           │                                         │
           ▼                                         ▼
┌─────────────────────────┐             ┌────────────────────────────┐
│ document_retrieval_log  │             │ electronic_signatures      │
│ (return tracking)       │             │ (acknowledgement e-sig)    │
└─────────────────────────┘             └────────────────────────────┘
```

### 6.3 Quality-to-Training Integration

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────────┐
│   deviations    │────►│   capa_records  │────►│ training_trigger_rules  │
│ (quality events)│     │   (CAPA)        │     │ (auto-assignment rules) │
└────────┬────────┘     └─────────────────┘     └───────────┬─────────────┘
         │                                                  │
         │                                                  ▼
         │              ┌─────────────────┐     ┌─────────────────────────┐
         │              │ change_controls │────►│ training_trigger_events │
         │              │ (change mgmt)   │     │ (fired triggers)        │
         │              └────────┬────────┘     └───────────┬─────────────┘
         │                       │                          │
         │                       ▼                          ▼
         │              ┌─────────────────────────┐ ┌────────────────────────┐
         └─────────────►│ change_control_training │ │ training_assignments   │
                        │ (CC-triggered training) │ │ (new assignments)      │
                        └─────────────────────────┘ └────────────────────────┘
```

### 6.4 Assessment Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────────────┐
│ question_banks  │────►│    questions    │────►│ question_paper_questions│
│ (collections)   │     │ (MCQ, TF, etc.) │     │ (paper composition)     │
└─────────────────┘     └────────┬────────┘     └───────────┬─────────────┘
                                 │                          │
                                 ▼                          ▼
                        ┌─────────────────┐     ┌─────────────────────────┐
                        │ question_options│     │   question_papers       │
                        │ (MCQ choices)   │     │ (assessment papers)     │
                        └─────────────────┘     └───────────┬─────────────┘
                                                            │
                        ┌───────────────────────────────────┘
                        │
                        ▼
                ┌─────────────────────────┐
                │  assessment_attempts    │◄───── Employee takes test
                │  (attempt records)      │
                └──────────┬──────────────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
           ▼               ▼               ▼
┌──────────────────┐ ┌────────────────┐ ┌─────────────────────┐
│assessment_       │ │ grading_queue  │ │ assessment_results  │
│responses         │ │ (manual grade) │ │ (final score)       │
│(answers)         │ └────────────────┘ └──────────┬──────────┘
└──────────────────┘                               │
                                                   ▼
                                           ┌─────────────────┐
                                           │Pass → training_ │
                                           │       records   │
                                           │                 │
                                           │Fail → remedial_ │
                                           │       trainings │
                                           └─────────────────┘
```

### 6.5 Workflow & Approval Flow

```
┌──────────────────────┐
│ workflow_definitions │
│ (workflow config)    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐     ┌──────────────────────────┐
│  workflow_phases     │────►│ workflow_approval_rules  │
│  (approval stages)   │     │ (who can approve)        │
└──────────┬───────────┘     └──────────────────────────┘
           │
           ▼
┌──────────────────────┐
│ workflow_instances   │◄───── Entity enters workflow
│ (active workflows)   │
└──────────┬───────────┘
           │
           ├─────────────────────────────────┐
           │                                 │
           ▼                                 ▼
┌──────────────────────┐     ┌──────────────────────────┐
│  workflow_tasks      │     │ workflow_instance_phases │
│  (pending approvals) │     │ (phase tracking)         │
└──────────┬───────────┘     └──────────────────────────┘
           │
           ▼
┌──────────────────────┐     ┌──────────────────────────┐
│  workflow_history    │     │  electronic_signatures   │
│  (approval log)      │────►│  (e-sig on approval)     │
└──────────────────────┘     └──────────────────────────┘
```

---

## 7. 21 CFR Part 11 Compliance Matrix

| Requirement | Section | Implementation |
|-------------|---------|----------------|
| **System Validation** | §11.10(a) | Event-driven architecture, validation triggers |
| **Accurate Copies** | §11.10(b) | PDF export endpoints, `document_export_handler.dart` |
| **Record Protection** | §11.10(c) | SHA-256 hash chain: `audit_trails.row_hash` + `previous_hash` |
| **Limited Access** | §11.10(d) | RLS policies (129), role-based permissions |
| **Audit Trail** | §11.10(e) | Immutable `audit_trails` table with UPDATE/DELETE triggers |
| **Sequence Checks** | §11.10(f) | `workflow_transitions` state machine |
| **Authority Checks** | §11.10(g) | `pending_approvals`, `workflow_tasks` |
| **Device Checks** | §11.10(h) | `system_health_checks`, `integrity_verification_log` |
| **Training** | §11.10(i) | `training_records`, `employee_competencies` |
| **Documentation** | §11.10(j) | Version-controlled schemas, `schema_changelog` |
| **Controls for Systems** | §11.10(k) | `password_policies`, `validation_rules` |
| **Signature Manifestation** | §11.50 | `electronic_signatures` with meaning, name, timestamp |
| **Signature Linking** | §11.70 | `prev_signature_id` chain, `integrity_hash` |
| **Unique User IDs** | §11.100(b) | `employees.username` UNIQUE + immutability trigger |
| **ID/Password Verification** | §11.200 | `esignature_reauth_sessions` with 30-min TTL |
| **Password Controls** | §11.300 | `password_policies` with complexity/history/expiry |

---

## 8. Indexes & Performance

### 8.1 Index Statistics
- **Total Indexes:** 693
- **B-tree Indexes:** 650+
- **GIN Indexes:** 30+ (full-text search, JSONB)
- **GiST Indexes:** 10+ (range queries)

### 8.2 Common Index Patterns

```sql
-- Primary key (auto-created)
CREATE INDEX idx_[table]_id ON [table](id);

-- Foreign keys
CREATE INDEX idx_[table]_[fk]_id ON [table]([fk]_id);

-- Multi-tenant isolation (CRITICAL)
CREATE INDEX idx_[table]_org ON [table](organization_id);
CREATE INDEX idx_[table]_plant ON [table](plant_id);

-- Time-based queries
CREATE INDEX idx_[table]_created_at ON [table](created_at DESC);

-- Status filtering
CREATE INDEX idx_[table]_status ON [table](status);

-- Active records only (partial index)
CREATE INDEX idx_[table]_active ON [table](status) WHERE status = 'active';

-- Full-text search
CREATE INDEX idx_[table]_search ON [table] USING GIN(search_vector);
CREATE INDEX idx_employees_name_search ON employees 
    USING GIN ((first_name || ' ' || last_name) gin_trgm_ops);

-- JSONB queries
CREATE INDEX idx_[table]_json ON [table] USING GIN([column] jsonb_path_ops);
```

---

## 9. Triggers & Audit

### 9.1 Trigger Statistics
- **Total Triggers:** 142
- **Audit Triggers:** 80+ (track_entity_changes)
- **Revision Triggers:** 30+ (increment_revision)
- **Validation Triggers:** 20+
- **Immutability Triggers:** 5+ (audit_trail_immutable)

### 9.2 Standard Trigger Functions

```sql
-- Track all changes to audit_trails
CREATE FUNCTION track_entity_changes() RETURNS TRIGGER;

-- Increment revision number on update
CREATE FUNCTION increment_revision() RETURNS TRIGGER;

-- Set created_by from current user
CREATE FUNCTION set_created_by() RETURNS TRIGGER;

-- Prevent modification of audit records
CREATE FUNCTION prevent_audit_modification() RETURNS TRIGGER;

-- Generate hash for tamper detection
CREATE FUNCTION generate_audit_hash() RETURNS TEXT;

-- Enforce username immutability
CREATE FUNCTION enforce_username_immutable() RETURNS TRIGGER;
```

---

## 10. RLS Policies

### 10.1 Policy Statistics
- **Total Policies:** 129
- **SELECT Policies:** 50+
- **INSERT Policies:** 30+
- **UPDATE Policies:** 30+
- **DELETE Policies:** 15+

### 10.2 Standard Policy Patterns

```sql
-- Tenant isolation (org-level)
CREATE POLICY org_isolation ON [table]
    USING (organization_id = current_setting('app.organization_id')::UUID);

-- Role-based read access
CREATE POLICY role_read ON [table] FOR SELECT
    USING (has_permission('read_[entity]'));

-- Self-service (own records)
CREATE POLICY own_records ON [table]
    USING (employee_id = current_setting('app.employee_id')::UUID);

-- Manager access (team records)
CREATE POLICY manager_view ON [table]
    USING (employee_id IN (SELECT get_direct_reports(current_employee())));
```

---

## 11. Data Retention

| Entity | Retention | Regulation | Archive Table |
|--------|-----------|------------|---------------|
| Audit trails | Parent lifespan + 1 year | 21 CFR §11.10(e) | Never archived |
| Electronic signatures | Same as signed entity | 21 CFR §11.50 | Never archived |
| Training records | 7 years minimum | 21 CFR 211.180 | `data_archives` |
| Certificates | 7 years after expiry | WHO GMP | `data_archives` |
| Assessment attempts | 5 years | ICH E6(R2) | `data_archives` |
| Login audit | 2 years | Internal policy | `data_archives` |
| Notification logs | 1 year | Internal policy | Purged |
| Temporary files | 24 hours | N/A | Auto-deleted |

---

## Quick Reference

### Table Count by Module

| Module | Tables | Schema Directory |
|--------|--------|------------------|
| Organization | 3 | `03_organization/` |
| Identity | 28 | `04_identity/` |
| Core | 15 | `02_core/` |
| Config | 18 | `03_config/` |
| Documents | 12 | `05_documents/` |
| Courses | 19 | `06_courses/` |
| Training | 45 | `07_training/` |
| Assessment | 18 | `08_assessment/` |
| Compliance | 22 | `09_compliance/` |
| Quality | 14 | `10_quality/` |
| Notifications | 12 | `12_notifications/` |
| Analytics | 15 | `13_analytics/` |
| Workflow | 12 | `14_workflow/` |
| Infrastructure | 22 | `16_infrastructure/` |
| Extensions | 42 | `17_extensions/` |
| Security Audit | 6 | `11_audit/` |
| **TOTAL** | **292** | |

---

*Schema frozen at 292 tables. Last updated: April 2026*
