# PharmaLearn LMS — Database Schema Reference

> **Version:** 2.0 | **Date:** April 2026 | **Tables:** 292 | **Compliance:** 21 CFR Part 11

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **Total Tables** | 292 |
| **Schema Files** | 132 |
| **Schema Modules** | 22 directories |
| **Enums Defined** | 45+ |
| **RLS Policies** | 150+ |
| **Audit Triggers** | On all business tables |

---

## 1. Schema Organization

```
supabase/schemas/
├── 00_extensions/        # PostgreSQL extensions (uuid-ossp, pgcrypto, pg_cron)
├── 01_types/             # Enums, composite types, domains
├── 02_core/              # Audit trail, revisions, workflow, e-signatures, reauth
├── 03_access_control/    # Permission overrides, access policies
├── 03_config/            # System settings, feature flags, password policies
├── 03_organization/      # Organizations, plants, departments
├── 04_identity/          # Employees, roles, permissions, groups, subgroups, biometrics
├── 05_documents/         # Document categories, documents, versions, control
├── 06_courses/           # Categories, subjects, topics, courses, trainers, venues
├── 07_training/          # GTPs, sessions, batches, attendance, induction, OJT, feedback
├── 08_assessment/        # Question banks, questions, papers, attempts, results
├── 09_compliance/        # Training records, certificates, assignments, waivers, triggers
├── 10_quality/           # Deviations, CAPA, change control, regulatory audits
├── 11_audit/             # Security audit, compliance reports
├── 12_notifications/     # Templates, queue, log, reminders, escalations
├── 13_analytics/         # Dashboards, KPIs, materialized views
├── 14_workflow/          # Workflow config, delegation, phases
├── 15_cron/              # Scheduled jobs, business continuity
├── 16_infrastructure/    # System config, file storage, integrations, API enterprise
├── 17_extensions/        # Learning paths, gamification, KB, SCORM, xAPI, surveys
└── 99_policies/          # RLS policies, integrity validation
```

---

## 2. Naming Conventions

### 2.1 Identifiers

| Rule | Example | Anti-example |
|------|---------|--------------|
| Tables are **plural snake_case** | `training_records`, `employee_roles` | `TrainingRecord` |
| Primary key is always `id UUID` | `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()` | `record_id` |
| Foreign keys suffix **`_id`** | `employee_id`, `course_id` | `employee` |
| Timestamps end in **`_at`** | `created_at`, `completed_at` | `creation_date` |
| Booleans start with **`is_`/`has_`/`requires_`** | `is_active`, `requires_approval` | `active` |

### 2.2 Multi-Tenancy Columns

Every business table carries:
- `organization_id` — mandatory tenant isolation
- `plant_id` — optional plant-level scoping
- `department_id` — optional department scoping

### 2.3 Audit Columns (Standard)

```sql
created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
created_by    UUID REFERENCES employees(id),
updated_at    TIMESTAMPTZ,
updated_by    UUID REFERENCES employees(id),
is_active     BOOLEAN NOT NULL DEFAULT true
```

---

## 3. Core Tables by Module

### 3.1 Organization (3 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `organizations` | Multi-tenant root | org_code, legal_name, compliance_frameworks[], audit_retention_years |
| `plants` | Manufacturing sites | plant_code, timezone, address |
| `departments` | Org units | department_code, manager_id, parent_id |

### 3.2 Identity & Access (20 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `employees` | User accounts | username (immutable), email, employee_code, status, induction_completed |
| `roles` | Role definitions | name, level (1.00=highest), category |
| `role_categories` | Role groupings | name (login/non_login) |
| `permissions` | Permission definitions | code, name, description |
| `role_permissions` | Role-permission mapping | role_id, permission_id |
| `employee_roles` | Employee-role assignment | employee_id, role_id, is_primary |
| `employee_permission_overrides` | Direct grants/denies | employee_id, permission, granted, reason |
| `groups` | Training groups | name, organization_id |
| `subgroups` | Group subdivisions | group_id, name, default_training_types[] |
| `employee_subgroups` | Employee-subgroup membership | employee_id, subgroup_id |
| `job_responsibilities` | Role-based requirements | employee_id, responsibility, courses[] |
| `global_profiles` | Organization-wide settings | profile_name, permissions[] |
| `biometric_registrations` | Fingerprint/face data | employee_id, biometric_type, template_hash |
| `standard_reasons` | Controlled justifications | code, description, category, requires_esig |

### 3.3 Core Infrastructure (11 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `audit_trails` | Immutable audit log | entity_type, entity_id, action, event_category, row_hash, previous_hash |
| `electronic_signatures` | 21 CFR Part 11 e-sigs | employee_id, meaning, entity_type, entity_id, signature_hash |
| `signature_meanings` | E-sig meaning config | code, name, allowed_entity_types[], requires_reauth |
| `esig_reauth_sessions` | Re-authentication sessions | employee_id, expires_at, password_verified |
| `workflow_transitions` | State machine config | from_status, to_status, allowed_roles[] |
| `approval_engine` | Approval chain config | entity_type, approval_levels[], requires_esignature |
| `revision_tracking` | Version management | entity_type, entity_id, revision_number, changes |

### 3.4 Documents (5 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `document_categories` | Document classification | name, code, parent_id |
| `documents` | Controlled documents | document_number, title, type, status, effective_date |
| `document_versions` | Version history | document_id, version_number, content_hash |
| `document_acknowledgements` | Read confirmations | document_id, employee_id, acknowledged_at, esignature_id |
| `document_reading_sessions` | Reading tracking | document_id, session_id, start_time, completion_time |

### 3.5 Courses (11 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `categories` | Course categories | name, parent_id |
| `subjects` | Subject areas | category_id, name |
| `topics` | Topic breakdown | subject_id, name |
| `courses` | Course definitions | code, name, training_types[], duration_hours, passing_score |
| `course_versions` | Course version history | course_id, version_number, content_changes |
| `course_prerequisites` | Prerequisite mapping | course_id, prerequisite_course_id |
| `trainers` | Qualified trainers | employee_id, status, certifications[] |
| `trainer_competencies` | Trainer-course qualifications | trainer_id, course_id, qualified_date |
| `venues` | Training venues | name, capacity, location, equipment[] |
| `feedback_evaluation_templates` | Feedback forms | template_type, questions[], is_active |

### 3.6 Training (22 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `gtp_masters` | Group Training Plans | name, training_type, schedule_type, courses[] |
| `training_schedules` | Schedule definitions | gtp_id, start_date, end_date, trainer_id, venue_id |
| `training_sessions` | Individual sessions | schedule_id, session_date, delivery_mode, evaluation_mode |
| `training_batches` | Batch groupings | session_id, batch_code, max_participants |
| `training_invitations` | Learner invitations | session_id, employee_id, response, invited_at |
| `training_nominations` | Self-nominations | schedule_id, employee_id, status |
| `session_attendance` | Attendance records | session_id, employee_id, check_in_time, check_out_time, status |
| `attendance_corrections` | Immutable corrections | original_attendance_id, corrected_by, correction_reason |
| `induction_programs` | Induction definitions | name, modules[], duration_days |
| `induction_modules` | Module breakdown | induction_id, name, sequence, duration_hours |
| `employee_induction` | Employee enrollments | employee_id, program_id, status, trainer_id |
| `employee_induction_progress` | Module progress | employee_induction_id, module_id, completed_at |
| `ojt_masters` | OJT definitions | name, evaluation_criteria[], estimated_hours |
| `ojt_tasks` | OJT task breakdown | ojt_id, task_name, evaluation_method |
| `employee_ojt` | OJT assignments | employee_id, ojt_master_id, evaluator_id, status |
| `ojt_task_completion` | Task completions | employee_ojt_id, task_id, completed_at, esignature_id |
| `self_learning_assignments` | Self-paced assignments | employee_id, course_id, due_date |
| `lesson_progress` | Content progress | employee_id, lesson_id, progress_percentage, scorm_session_time |
| `training_feedback` | Session feedback | schedule_id, employee_id, feedback_type, responses |
| `trainer_feedback` | Trainer evaluations | session_id, trainer_id, ratings |
| `external_training_records` | External certifications | employee_id, course_name, institution, completion_date |

### 3.7 Assessment (14 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `question_banks` | Question collections | name, category, topic_id |
| `questions` | Question definitions | question_bank_id, question_type, text, points |
| `question_options` | MCQ options | question_id, option_text, is_correct |
| `question_papers` | Assessment papers | name, total_marks, passing_percentage, time_limit_minutes |
| `question_paper_items` | Paper-question mapping | paper_id, question_id, sequence |
| `assessment_attempts` | Attempt records | employee_id, paper_id, started_at, submitted_at, score |
| `assessment_responses` | Answer records | attempt_id, question_id, response, is_correct, marks |
| `assessment_results` | Final results | attempt_id, total_score, percentage, status |
| `grading_queue` | Manual grading queue | attempt_id, question_id, grader_id, status |
| `question_paper_extensions` | Time extensions | attempt_id, requested_minutes, granted_minutes, status |

### 3.8 Compliance (13 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `training_records` | Official records | employee_id, course_id, completion_date, status, esignature_id |
| `certificate_templates` | Certificate designs | name, template_content, signatories[] |
| `certificates` | Issued certificates | training_record_id, certificate_number, issued_at |
| `certificate_revocation_requests` | Revocation workflow | certificate_id, initiated_by, confirmed_by, status |
| `training_assignments` | Assigned training | employee_id, course_id, due_date, status |
| `employee_training_obligations` | Compliance obligations | employee_id, obligation_type, entity_id, due_date |
| `training_waivers` | Training exemptions | assignment_id, reason, approved_by, esignature_id |
| `competencies` | Competency definitions | name, description, courses[] |
| `employee_competencies` | Competency status | employee_id, competency_id, status, expires_at |
| `competency_gaps` | Gap analysis | employee_id, competency_id, gap_type |
| `training_matrix` | Role-course mapping | role_id, course_id, is_mandatory |
| `training_trigger_rules` | Auto-assignment rules | event_source, entity_type, criteria, courses[] |
| `training_trigger_events` | Fired triggers | rule_id, entity_id, processed_at |

### 3.9 Quality (11 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `deviations` | Deviation records | deviation_number, description, severity, status |
| `capa_records` | CAPA tracking | capa_number, deviation_id, root_cause, actions[] |
| `change_controls` | Change management | change_number, description, impact_assessment, status |
| `change_control_training` | CC-triggered training | change_control_id, course_id, affected_employees[] |
| `regulatory_audits` | Audit records | audit_number, type, auditor, findings_count |
| `audit_findings` | Finding details | audit_id, finding_number, severity, response |
| `audit_preparation_items` | Prep checklists | audit_id, item_description, responsible_id |

### 3.10 Notifications (7 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `notification_templates` | Message templates | type, subject, body, placeholders[] |
| `notification_queue` | Pending notifications | template_id, recipient_id, scheduled_at |
| `notification_log` | Sent notifications | queue_id, sent_at, status, error |
| `user_notifications` | User inbox | employee_id, title, body, read_at |
| `notification_preferences` | User settings | employee_id, channel, enabled |
| `reminder_rules` | Reminder config | entity_type, days_before, template_id |
| `escalation_rules` | Escalation config | trigger_condition, escalate_to, delay_hours |

### 3.11 Analytics (8 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `dashboard_widgets` | Widget definitions | name, query, visualization_type |
| `user_dashboards` | Custom dashboards | employee_id, widgets[], layout |
| `report_templates` | Report definitions | name, report_type, parameters[], sql_template |
| `report_executions` | Report runs | template_id, executed_by, parameters, output_path |
| `kpi_definitions` | KPI metrics | name, calculation, target_value |
| `training_analytics` | Aggregated metrics | period, total_sessions, completion_rate |
| `compliance_snapshots` | Point-in-time compliance | snapshot_date, organization_id, metrics |

### 3.12 Workflow (7 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `workflow_definitions` | Workflow config | name, entity_type, phases[] |
| `workflow_phases` | Phase definitions | workflow_id, phase_name, approvers[], sequence |
| `workflow_instances` | Active workflows | definition_id, entity_id, current_phase, status |
| `workflow_tasks` | Pending approvals | instance_id, assignee_id, due_date |
| `workflow_history` | Approval history | instance_id, action, actor_id, comments |
| `approval_delegations` | Delegation config | delegator_id, delegate_id, valid_from, valid_to |
| `out_of_office` | OOO settings | employee_id, start_date, end_date, delegate_id |

### 3.13 Extensions (34 tables)

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `scorm_packages` | SCORM content | name, version, manifest_path, launch_url |
| `scorm_attempts` | SCORM tracking | package_id, employee_id, cmi_data |
| `xapi_statements` | xAPI learning records | actor, verb, object, result |
| `learning_paths` | Structured paths | name, courses[], prerequisites[] |
| `learning_path_progress` | Path completion | path_id, employee_id, current_step |
| `gamification_points` | Point tracking | employee_id, points, source |
| `badges` | Badge definitions | name, criteria, image_url |
| `employee_badges` | Awarded badges | employee_id, badge_id, awarded_at |
| `leaderboards` | Ranking tables | period, organization_id, rankings[] |
| `kb_categories` | Knowledge base categories | name, parent_id |
| `kb_articles` | KB articles | category_id, title, content, status |
| `kb_article_versions` | Article history | article_id, version_number, content |
| `discussions` | Discussion threads | entity_type, entity_id, topic |
| `discussion_posts` | Thread posts | discussion_id, author_id, content |
| `surveys` | Survey definitions | name, questions[], status |
| `survey_responses` | Survey answers | survey_id, respondent_id, answers |
| `content_assets` | Media library | name, file_path, mime_type |
| `user_preferences` | User settings | employee_id, preferences |

---

## 4. 21 CFR Part 11 Compliance Matrix

| Requirement | Implementation |
|-------------|----------------|
| **§11.10(a)** Accuracy | Event-driven architecture, validation triggers |
| **§11.10(b)** Printable format | PDF export endpoints, `document_export_handler.dart` |
| **§11.10(c)** Record protection | SHA-256 hash chain in `audit_trails.row_hash` + `previous_hash` |
| **§11.10(e)** Audit trail | Immutable `audit_trails` table with triggers preventing UPDATE/DELETE |
| **§11.50** Signature manifestation | `electronic_signatures` with meaning, printed_name, timestamp |
| **§11.100(b)** Unique usernames | `employees.username` UNIQUE + immutability trigger |
| **§11.200** E-sig sessions | `esig_reauth_sessions` with 30-min TTL, first-sig requires password |
| **§11.300** Password controls | `password_policies` table with complexity/history/expiry rules |

---

## 5. Key Relationships

### 5.1 Employee Training Flow

```
employees ──┬── employee_roles ──── roles ──── role_permissions ──── permissions
            │
            ├── training_assignments ──── courses
            │
            ├── session_attendance ──── training_sessions ──── training_schedules ──── gtp_masters
            │
            ├── assessment_attempts ──── question_papers ──── questions
            │
            ├── training_records ──── certificates
            │
            └── employee_competencies ──── competencies
```

### 5.2 Document Control Flow

```
documents ──┬── document_versions (1:N versioning)
            │
            ├── document_acknowledgements (M:N with employees)
            │
            └── document_reading_sessions ──── training_sessions
```

### 5.3 Quality-to-Training Integration

```
deviations ──── training_trigger_events ──── training_trigger_rules ──── training_assignments
     │
capa_records
     │
change_controls ──── change_control_training
```

---

## 6. Indexes & Performance

All tables have indexes on:
- Primary key (`id`)
- Foreign keys (`*_id`)
- `organization_id` (tenant isolation)
- `created_at` (time-based queries)
- `status` (filtered queries)

Materialized views exist for:
- `mv_compliance_dashboard` — Real-time compliance metrics
- `mv_training_analytics` — Aggregated training statistics
- `mv_overdue_training` — Overdue obligations

---

## 7. RLS Policies

Row-Level Security is enabled on all business tables with policies for:
- **Tenant isolation** — Users only see their organization's data
- **Role-based access** — Permissions control read/write access
- **Self-service** — Employees see their own records
- **Manager view** — Supervisors see their team's data

---

## 8. Data Retention

| Entity | Retention Period | Regulation |
|--------|------------------|------------|
| Audit trails | Parent lifespan + 1 year | 21 CFR §11.10(e) |
| Electronic signatures | Same as signed entity | 21 CFR §11.50 |
| Training records | 7 years minimum | 21 CFR 211.180 |
| Certificates | 7 years after expiry | WHO GMP |
| Assessment attempts | 5 years | ICH E6(R2) |

---

*Schema frozen at 292 tables. Last updated: April 2026*
