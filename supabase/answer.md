# PharmaLearn — Complete ERD & Object Model

> Canvas-style walk-through of the entire Supabase/Postgres schema for the PharmaLearn LMS.
> Every table is shown as a **tile** with its key columns and foreign keys, grouped by module.
> Scroll through the canvas below, then read the **Relationships**, **Core vs. Join Tables**,
> and **Enabled Scenarios** sections.

---

## 0. At-a-glance

| # | Module (schema folder) | Tables | Purpose |
|--:|---|--:|---|
| 03 | `organization` | 3 | Tenant → Plant → Department hierarchy |
| 04 | `identity` | 13 | Users, roles, groups, subgroups, biometrics, standard reasons |
| 02 | `core` | 7 | Audit log, revisions, workflow state machine, approvals, e-sig base |
| 05 | `documents` | 5 | SOP / Policy / WI / Form with versions & acknowledgements |
| 06 | `courses` | 11 | Courses, categories, subjects, topics, trainers, venues, templates |
| 07 | `training` | 22 | GTP, schedules, sessions/batches, invites, attendance, induction, OJT, self-learning, feedback |
| 08 | `assessment` | 14 | Question banks, questions, papers, attempts, responses, results, grading queue |
| 09 | `compliance` | 13 | Records, certificates, assignments, waivers, competencies, matrix |
| 10 | `quality` | 11 | Deviations, CAPA, change control, regulatory audit |
| 11 | `audit` | 5 | Login audit, data access, permission changes, system config |
| 12 | `notifications` | 7 | Templates, queue, log, user-level, prefs, reminders, escalation |
| 13 | `analytics` | 8 | Dashboards, widgets, rolled-up analytics, report defs, scheduled reports |
| 14 | `workflow` | 7 | Workflow definitions, approval rules, instances, tasks, history, delegation, OOO |
| 15 | `cron` | 3 | Cron jobs, run history, background tasks |
| 16 | `infrastructure` | 9 | Settings, flags, API keys, webhooks, files, integrations, SSO |
| 17 | `extensions` | 34 | Learning paths, gamification, KB, discussions, cost, prefs, content, surveys |
| — | **TOTAL** | **~170** | — |

> All objects live in the **`public`** schema (no schema-qualified names in DDL / seed).

---

## 1. Naming Conventions

### 1.1 Identifiers
| Rule | Example | Anti-example |
|---|---|---|
| Tables are **plural snake_case** | `training_records`, `employee_roles` | `TrainingRecord`, `EmployeeRole` |
| Columns are **snake_case, singular** | `employee_id`, `started_at` | `EmployeeID`, `StartDate` |
| Primary key is always `id UUID DEFAULT gen_random_uuid()` | — | — |
| Foreign keys suffix **`_id`** and match the referenced table's singular form | `course_id` → `courses.id` | `course` (no suffix) |
| Timestamps end in **`_at`** | `created_at`, `approved_at`, `deactivated_at` | `creation_date`, `when_approved` |
| Booleans start with **`is_` / `has_` / `requires_`** | `is_active`, `requires_approval`, `has_expired` | `active`, `expired` |
| Counts / numerics end in semantic suffix | `duration_minutes`, `file_size_bytes`, `score_percentage` | `duration`, `size`, `score` |
| JSON blobs end in **`_json`** / **`_data`** / plain descriptive noun | `settings`, `data_snapshot`, `retry_policy` | `json_blob` |
| Enum columns are singular nouns matching the enum type | `status workflow_status_enum` | — |

### 1.2 Multi-tenancy columns
Every business table carries **at least** `organization_id`; plant-level tables also carry `plant_id`; some also carry `department_id`. Root tables (`organizations`, `role_categories`, `signature_meanings`, `workflow_transitions`) do **not** carry `organization_id` — they are global.

### 1.3 Audit columns (on nearly every table)
```
created_at  TIMESTAMPTZ DEFAULT now()
created_by  UUID REFERENCES employees(id)
updated_at  TIMESTAMPTZ
updated_by  UUID REFERENCES employees(id)
is_active   BOOLEAN DEFAULT true      -- soft-delete flag
```

### 1.4 Versioning pattern
Parent table holds the **logical** record; a companion `*_versions` table holds immutable snapshots:
```
documents             (1) ─< document_versions        (N)
courses               (1) ─< course_versions          (N)
kb_articles           (1) ─< kb_article_versions      (N)
```
The parent has `current_version_number INT`; versions have `(parent_id, version_number)` unique.

### 1.5 Join-table naming
- Two-way join: `<a>_<b>` → `employee_roles`, `role_permissions`, `group_subgroups`
- Three-way / contextual join: `<a>_<b>_<context>` → `course_prerequisites`, `role_competencies`
- Progress / snapshot joins: `<entity>_progress`, `<entity>_snapshot` → `lesson_progress`, `leaderboard_snapshots`

### 1.6 State / workflow conventions
- `status` = machine-executable state (enum: `draft`, `pending_approval`, …)
- `*_state` = user-facing description (free text)
- Terminal states are marked in JSON metadata (`"terminal":true`)
- Role levels are `NUMERIC(4,2)` from 1.00 (Super Admin) down to 99.00 (Trainee) — **lower = higher authority**
- Approver level must be **strictly less than** initiator level (enforced in `workflow_approval_rules.min_approver_level`)

---

## 2. The Canvas — Every Table as a Tile

Legend: `PK` primary key · `FK` foreign key · `UQ` unique · `IX` indexed · `⧗` audited · `♛` versioned parent

### 2.1 Module `organization`  ·  3 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│  organizations           │  │  plants                  │  │  departments             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id            PK         │  │ id            PK         │  │ id            PK         │
│ org_code      UQ         │  │ organization_id  FK→org  │  │ organization_id FK→org   │
│ legal_name               │  │ plant_code    UQ(org)    │  │ plant_id        FK→plant │
│ display_name             │  │ plant_name               │  │ department_code UQ(plant)│
│ industry                 │  │ location                 │  │ department_name          │
│ country, currency, tz    │  │ timezone                 │  │ head_employee_id FK→emp  │
│ gstin, licenses          │  │ is_hq          BOOL      │  │ cost_center              │
│ is_active, created_*     │  │ is_active, created_*     │  │ is_active, created_*     │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

### 2.2 Module `identity`  ·  13 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ role_categories          │  │ roles                    │  │ permissions              │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id            PK         │  │ id            PK         │  │ id            PK         │
│ category_code UQ         │  │ organization_id FK       │  │ permission_code UQ       │
│ category_name            │  │ role_category_id FK      │  │ resource                 │
│ display_order            │  │ role_code     UQ(org)    │  │ action                   │
│ is_active                │  │ role_name                │  │ description              │
│                          │  │ role_level   NUM(4,2) IX │  │                          │
│                          │  │ is_approver  BOOL        │  │                          │
│                          │  │ max_subordinate_level    │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ role_permissions  [JOIN] │  │ global_profiles          │  │ employees                │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id  PK                   │  │ id            PK         │  │ id            PK         │
│ role_id       FK→roles   │  │ global_profile_code UQ   │  │ organization_id FK       │
│ permission_id FK→perms   │  │ profile_name             │  │ plant_id        FK       │
│ granted_by    FK→emp     │  │ role_template_json       │  │ department_id   FK       │
│ granted_at               │  │ applicable_industries[]  │  │ employee_code   UQ(org)  │
│ UQ(role, permission)     │  │ is_active                │  │ employee_name            │
└──────────────────────────┘  └──────────────────────────┘  │ email           UQ       │
                                                           │ auth_user_id    FK→auth  │
                                                           │ is_login_user   BOOL     │
                                                           │ is_biometric_only        │
                                                           │ date_of_joining          │
                                                           │ mobile, emergency_contact│
                                                           │ manager_id      FK self  │
                                                           └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ employee_roles   [JOIN]  │  │ subgroups                │  │ groups                   │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id FK           │  │ organization_id FK       │  │ organization_id FK       │
│ role_id     FK           │  │ plant_id        FK       │  │ plant_id        FK       │
│ assigned_at              │  │ subgroup_code UQ(plant)  │  │ group_code    UQ(plant)  │
│ assigned_by FK→emp       │  │ subgroup_name            │  │ group_name               │
│ effective_from/to        │  │ description              │  │ group_type  ENUM         │
│ is_primary_role  BOOL    │  │ is_active                │  │ is_active                │
│ UQ(employee, role)       │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ group_subgroups  [JOIN]  │  │ employee_subgroups [JOIN]│  │ job_responsibilities     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ group_id    FK           │  │ employee_id FK           │  │ organization_id FK       │
│ subgroup_id FK           │  │ subgroup_id FK           │  │ role_id         FK       │
│ UQ(group, subgroup)      │  │ assigned_at              │  │ responsibility_text      │
│                          │  │ UQ(employee, subgroup)   │  │ display_order            │
└──────────────────────────┘  └──────────────────────────┘  │ is_active                │
                                                           └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ biometric_registrations  │  │ standard_reasons         │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ employee_id FK           │  │ organization_id FK       │
│ biometric_type ENUM      │  │ reason_code   UQ         │
│ template_hash            │  │ reason_text              │
│ device_id       FK       │  │ reason_category ENUM     │
│ enrolled_at              │  │ display_order            │
│ enrolled_by     FK       │  │ is_active                │
│ witnessed_by    FK       │  │                          │
│ is_active                │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.3 Module `core`  ·  7 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ audit_trails    (⧗imm)   │  │ revision_history         │  │ workflow_transitions     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ entity_type  TEXT        │  │ from_state    TEXT       │
│ entity_type              │  │ entity_id    UUID        │  │ to_state      TEXT       │
│ entity_id                │  │ revision_number INT      │  │ action_name   UQ         │
│ action  ENUM             │  │ changed_by    FK→emp     │  │ action_display_name      │
│ old_values JSONB         │  │ change_reason            │  │ requires_approval BOOL   │
│ new_values JSONB         │  │ field_diffs JSONB        │  │ requires_reason   BOOL   │
│ performed_by FK          │  │ snapshot_before JSONB    │  │ requires_esignature BOOL │
│ performed_at             │  │ snapshot_after  JSONB    │  │ allowed_roles TEXT[]     │
│ ip_address, user_agent   │  │                          │  │ min_approver_level NUM   │
│ integrity_hash (SHA-256) │  │                          │  │                          │
│ prev_hash   (chain)      │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ pending_approvals        │  │ approval_history         │  │ signature_meanings       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ entity_type, entity_id   │  │ pending_approval_id FK   │  │ meaning       UQ         │
│ entity_display_name      │  │ action_taken  ENUM       │  │ display_text             │
│ requested_action         │  │ performed_by  FK→emp     │  │ description              │
│ current_state            │  │ performed_at             │  │ applicable_entities[]    │
│ target_state             │  │ reason                   │  │ requires_reason BOOL     │
│ initiated_by, initiator* │  │ esignature_id FK         │  │ requires_password_reauth │
│ initiator_role_level NUM │  │ comments                 │  │ is_active                │
│ requires_approval        │  │                          │  │                          │
│ min_approver_level NUM   │  │                          │  │                          │
│ due_date, status ENUM    │  │                          │  │                          │
│ plant_id, organization_id│  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐
│ electronic_signatures    │       Part 11 21 CFR table — IMMUTABLE
├──────────────────────────┤
│ id PK                    │
│ employee_id FK           │
│ employee_name/email/title│
│ employee_id_code         │
│ meaning, meaning_display │
│ reason                   │
│ entity_type, entity_id   │
│ ip_address, user_agent   │
│ integrity_hash           │
│ data_snapshot JSONB      │
│ password_reauth_verified │
│ biometric_verified       │
│ is_valid   BOOL          │
│ organization_id, plant_id│
└──────────────────────────┘
```

### 2.4 Module `documents`  ·  5 tiles (♛ versioned)

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ document_categories      │  │ documents         ♛       │  │ document_versions        │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ document_id  FK          │
│ category_code UQ         │  │ plant_id        FK       │  │ version_number INT       │
│ category_name            │  │ category_id     FK       │  │ version_status ENUM      │
│ parent_category_id self  │  │ document_code UQ(org)    │  │ file_path / file_hash    │
│ requires_approval BOOL   │  │ document_title           │  │ effective_date           │
│ retention_years          │  │ document_type ENUM       │  │ expiry_date              │
└──────────────────────────┘  │ current_version_number   │  │ authored_by, reviewed_by │
                              │ status workflow_status   │  │ approved_by  FK→emp      │
                              │ retention_period_years   │  │ is_current   BOOL        │
                              └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ document_reads  [JOIN]   │  │ document_acknowledgements│
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ document_version_id FK   │  │ document_version_id FK   │
│ employee_id        FK    │  │ employee_id         FK   │
│ read_at TIMESTAMPTZ      │  │ acknowledged_at          │
│ read_duration_seconds    │  │ esignature_id       FK   │
│ scroll_percentage        │  │ comments                 │
│ device_info              │  │ UQ(version, employee)    │
│ UQ(version, employee)    │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.5 Module `courses`  ·  11 tiles (♛ versioned)

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ course_categories        │  │ subjects                 │  │ topics                   │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ organization_id FK       │
│ category_code UQ(org)    │  │ category_id     FK       │  │ subject_id      FK       │
│ category_name            │  │ subject_code   UQ(cat)   │  │ topic_code    UQ(subj)   │
│ display_color            │  │ subject_name             │  │ topic_name               │
│ is_active                │  │                          │  │ learning_objectives[]    │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ courses              ♛   │  │ course_versions          │  │ course_topics    [JOIN]  │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ course_id   FK           │  │ course_id FK             │
│ course_code UQ(org)      │  │ version_number INT       │  │ topic_id  FK             │
│ course_name              │  │ version_status ENUM      │  │ display_order            │
│ course_type  ENUM        │  │ content_payload JSONB    │  │ is_mandatory BOOL        │
│ delivery_mode ENUM       │  │ authored_by / approved_by│  │                          │
│ duration_minutes         │  │ effective_date           │  │                          │
│ passing_score_percent    │  │ expiry_date              │  │                          │
│ max_attempts             │  │                          │  │                          │
│ current_version_number   │  │                          │  │                          │
│ status workflow_status   │  │                          │  │                          │
│ tags[], is_mandatory     │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ trainers                 │  │ venues                   │  │ feedback_templates       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ organization_id FK       │
│ trainer_type ENUM        │  │ plant_id        FK       │  │ template_name            │
│ employee_id   FK? (int)  │  │ venue_code   UQ(plant)   │  │ template_type ENUM       │
│ external_name/email(ext) │  │ venue_name               │  │ questions_json JSONB     │
│ qualifications, spec[]   │  │ capacity     INT         │  │ rating_scale             │
│ certifications JSONB     │  │ location                 │  │ is_default    BOOL       │
│ hourly_rate              │  │ has_projector BOOL       │  │                          │
│ rating_avg               │  │ has_whiteboard           │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ trainer_courses  [JOIN]  │  │ satisfaction_scales      │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ trainer_id FK            │  │ scale_name               │
│ course_id  FK            │  │ scale_points INT         │
│ qualified_on             │  │ labels JSONB             │
│ last_delivered_on        │  │ is_default    BOOL       │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.6 Module `training`  ·  22 tiles (highest-traffic module)

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ group_training_plans  ♛  │  │ gtp_courses      [JOIN]  │  │ gtp_versions             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ gtp_id    FK             │  │ gtp_id       FK          │
│ plant_id        FK       │  │ course_id FK             │  │ version_number INT       │
│ gtp_code UQ(org)         │  │ display_order INT        │  │ version_status ENUM      │
│ gtp_name                 │  │ is_mandatory BOOL        │  │ payload JSONB            │
│ audience_criteria JSONB  │  │ completion_deadline_days │  │                          │
│ frequency ENUM           │  │                          │  │                          │
│ current_version_number   │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ training_schedules       │  │ training_sessions        │  │ training_batches         │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id / plant  │  │ schedule_id     FK       │  │ session_id     FK        │
│ schedule_code  UQ        │  │ session_code   UQ        │  │ batch_code     UQ        │
│ gtp_id          FK       │  │ course_id       FK       │  │ batch_name               │
│ course_id       FK       │  │ trainer_id      FK       │  │ max_trainees   INT       │
│ schedule_type ENUM       │  │ venue_id        FK       │  │ current_trainee_count    │
│ start_date / end_date    │  │ scheduled_start          │  │ status ENUM              │
│ status        ENUM       │  │ scheduled_end            │  │                          │
└──────────────────────────┘  │ delivery_mode ENUM       │  │                          │
                              │ status ENUM              │  │                          │
                              └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ batch_trainees   [JOIN]  │  │ training_invitations     │  │ training_nominations     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ batch_id   FK            │  │ session_id      FK       │  │ session_id     FK        │
│ employee_id FK           │  │ employee_id     FK       │  │ nominee_id     FK→emp    │
│ added_at                 │  │ invitation_status ENUM   │  │ nominated_by   FK→emp    │
│ added_by                 │  │ invited_at               │  │ nomination_reason        │
│ UQ(batch, employee)      │  │ responded_at             │  │ approval_status ENUM     │
│                          │  │ response_note            │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ session_attendance       │  │ daily_attendance_summary │  │ induction_programs    ♛  │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ session_id   FK          │  │ session_id   FK          │  │ organization_id FK       │
│ employee_id  FK          │  │ attendance_date          │  │ program_code UQ          │
│ check_in_at              │  │ total_invited INT        │  │ program_name             │
│ check_out_at             │  │ total_present INT        │  │ applicable_roles UUID[]  │
│ verification_method ENUM │  │ total_absent  INT        │  │ duration_days INT        │
│ biometric_hash           │  │ attendance_percent       │  │ current_version_number   │
│ late_minutes, status     │  │                          │  │ status workflow_status   │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ induction_modules        │  │ induction_enrollments    │  │ induction_progress       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ program_id  FK           │  │ program_id  FK           │  │ enrollment_id FK         │
│ module_code UQ(program)  │  │ employee_id FK           │  │ module_id     FK         │
│ module_name              │  │ enrollment_date          │  │ started_at, completed_at │
│ display_order            │  │ expected_completion_date │  │ score_percentage         │
│ duration_hours           │  │ actual_completion_date   │  │ status ENUM              │
│ content_type ENUM        │  │ status ENUM              │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ ojt_assignments          │  │ ojt_tasks                │  │ ojt_task_completion      │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ ojt_assignment_id FK     │  │ task_id     FK           │
│ plant_id        FK       │  │ task_code  UQ(ojt)       │  │ completed_at             │
│ employee_id     FK       │  │ task_description         │  │ completed_by FK→emp      │
│ supervisor_id   FK→emp   │  │ required_observations    │  │ witnessed_by FK→emp      │
│ course_id       FK       │  │ competency_required      │  │ evidence_url             │
│ start_date / due_date    │  │ display_order            │  │ signature_id FK          │
│ status ENUM              │  │                          │  │ score, status ENUM       │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ self_learning_enrollments│  │ self_learning_progress   │  │ training_feedback        │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id   FK         │  │ enrollment_id FK         │  │ session_id    FK         │
│ course_id     FK         │  │ last_accessed_at         │  │ employee_id   FK         │
│ enrolled_at              │  │ progress_percent         │  │ template_id   FK         │
│ deadline                 │  │ time_spent_minutes       │  │ overall_rating INT       │
│ status ENUM              │  │ last_lesson_id FK        │  │ responses_json JSONB     │
│ approved_by   FK→emp     │  │                          │  │ submitted_at             │
└──────────────────────────┘  └──────────────────────────┘  │ is_anonymous  BOOL       │
                                                           └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ training_effectiveness   │  │ training_reschedules     │  │ training_cancellations   │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ session_id   FK          │  │ session_id    FK         │  │ session_id    FK         │
│ evaluated_at             │  │ old_start / new_start    │  │ cancelled_at             │
│ kirkpatrick_level INT    │  │ reason                   │  │ cancelled_by  FK→emp     │
│ reaction_score           │  │ requested_by  FK→emp     │  │ reason                   │
│ learning_score           │  │ approved_by   FK→emp     │  │ affected_count INT       │
│ behavior_score           │  │                          │  │                          │
│ results_score            │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

### 2.7 Module `assessment`  ·  14 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ question_bank_categories │  │ question_banks           │  │ questions                │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ question_bank_id FK      │
│ category_code UQ         │  │ bank_code UQ(org)        │  │ question_code  UQ(bank)  │
│ category_name            │  │ bank_name                │  │ question_text   TEXT     │
│                          │  │ topic_id  FK             │  │ question_type ENUM       │
│                          │  │ category_id FK           │  │ difficulty_level ENUM    │
│                          │  │ total_questions INT      │  │ marks, time_limit_sec    │
│                          │  │ is_active                │  │ explanation              │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ question_options         │  │ question_matching_pairs  │  │ question_blanks          │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ question_id FK           │  │ question_id FK           │  │ question_id FK           │
│ option_text              │  │ left_text / right_text   │  │ blank_position INT       │
│ is_correct BOOL          │  │ display_order            │  │ correct_answer           │
│ display_order INT        │  │                          │  │ case_sensitive BOOL      │
│ option_label (A/B/C)     │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ question_papers          │  │ question_paper_questions │  │ assessment_attempts      │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ paper_id    FK           │  │ paper_id      FK         │
│ paper_code UQ(org)       │  │ question_id FK           │  │ employee_id   FK         │
│ paper_name               │  │ display_order            │  │ attempt_number INT       │
│ course_id  FK            │  │ marks_override           │  │ started_at, submitted_at │
│ total_marks  INT         │  │                          │  │ time_taken_minutes       │
│ passing_marks            │  │                          │  │ status ENUM              │
│ duration_minutes         │  │                          │  │                          │
│ randomize_questions BOOL │  │                          │  │                          │
│ shuffle_options     BOOL │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ assessment_responses     │  │ assessment_results       │  │ grading_queue            │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ attempt_id   FK          │  │ attempt_id  FK UQ        │  │ response_id  FK          │
│ question_id  FK          │  │ total_marks INT          │  │ assigned_to  FK→emp      │
│ response_text            │  │ obtained_marks INT       │  │ assigned_at              │
│ selected_options UUID[]  │  │ score_percentage         │  │ due_by                   │
│ matching_pairs   JSONB   │  │ pass_status BOOL         │  │ status ENUM              │
│ blanks_answers   JSONB   │  │ graded_by   FK→emp       │  │                          │
│ marks_awarded    NUM     │  │ graded_at                │  │                          │
│ auto_graded BOOL         │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ result_appeals           │  │ assessment_proctoring    │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ result_id   FK           │  │ attempt_id FK            │
│ employee_id FK           │  │ proctor_type ENUM        │
│ appeal_reason            │  │ violations JSONB         │
│ appeal_status ENUM       │  │ recording_url            │
│ reviewer_id FK→emp       │  │ screenshot_count INT     │
│ decision                 │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.8 Module `compliance`  ·  13 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ training_records         │  │ certificates             │  │ certificate_templates    │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ certificate_number UQ    │  │ organization_id FK       │
│ employee_id FK           │  │ organization_id FK       │  │ template_name            │
│ course_id   FK           │  │ training_record_id FK    │  │ template_html            │
│ training_type ENUM       │  │ employee_id        FK    │  │ pdf_layout_json          │
│ session_id  FK?          │  │ course_id          FK    │  │ qr_code_enabled BOOL     │
│ start_date/complete_date │  │ issued_on / expires_on   │  │ is_default              │
│ duration_minutes         │  │ status  ENUM             │  │                          │
│ score_percentage         │  │ pdf_path, qr_code        │  │                          │
│ pass_status BOOL         │  │ signed_by  FK→emp        │  │                          │
│ attempts_count           │  │ esignature_id FK         │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ training_assignments     │  │ employee_assignments     │  │ training_matrix          │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ assignment_id  FK        │  │ organization_id FK       │
│ assignment_name          │  │ employee_id    FK        │  │ role_id / subgroup_id FK │
│ course_id    FK          │  │ assigned_at              │  │ course_id       FK       │
│ target_type ENUM         │  │ due_date                 │  │ is_mandatory BOOL        │
│ target_criteria JSONB    │  │ completed_at             │  │ recurrence_months        │
│ deadline_days INT        │  │ status ENUM              │  │ priority ENUM            │
│ priority ENUM            │  │                          │  │                          │
│ status ENUM              │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ training_waivers         │  │ waiver_approvals         │  │ competencies             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id   FK         │  │ waiver_id    FK          │  │ organization_id FK       │
│ course_id     FK         │  │ approver_id  FK→emp      │  │ competency_code UQ       │
│ reason_code   FK         │  │ action ENUM              │  │ competency_name          │
│ justification TEXT       │  │ action_at                │  │ competency_type ENUM     │
│ requested_by  FK         │  │ comments                 │  │ proficiency_levels JSONB │
│ waiver_status ENUM       │  │ esignature_id FK         │  │                          │
│ expiry_date              │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ role_competencies [JOIN] │  │ employee_competencies    │  │ competency_gaps          │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ role_id       FK         │  │ employee_id    FK        │  │ employee_id    FK        │
│ competency_id FK         │  │ competency_id  FK        │  │ competency_id  FK        │
│ required_level INT       │  │ current_level  INT       │  │ required_level INT       │
│ UQ(role, competency)     │  │ acquired_on              │  │ current_level  INT       │
│                          │  │ last_assessed_on         │  │ gap_size       INT       │
│                          │  │ evidence_url             │  │ remediation_plan         │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

### 2.9 Module `quality`  ·  11 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ deviations               │  │ deviation_training_req   │  │ capa_records             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ deviation_code UQ        │  │ deviation_id  FK         │  │ capa_code UQ             │
│ organization_id / plant  │  │ course_id     FK         │  │ deviation_id FK?         │
│ reported_by   FK→emp     │  │ target_employees UUID[]  │  │ capa_type ENUM           │
│ deviation_type ENUM      │  │ deadline_days INT        │  │ root_cause TEXT          │
│ severity ENUM            │  │ is_mandatory BOOL        │  │ action_plan TEXT         │
│ description              │  │                          │  │ owner_id   FK→emp        │
│ root_cause_summary       │  │                          │  │ status ENUM              │
│ status ENUM              │  │                          │  │ due_date / closed_at     │
│ reported_at              │  │                          │  │ effectiveness_verified   │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ capa_actions             │  │ change_controls          │  │ change_control_training  │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ capa_id   FK             │  │ cc_code UQ               │  │ change_control_id FK     │
│ action_description       │  │ organization_id / plant  │  │ course_id         FK     │
│ owner_id  FK→emp         │  │ change_type ENUM         │  │ target_audience JSONB    │
│ due_date / completed_at  │  │ impact_assessment        │  │ deadline_days INT        │
│ status ENUM              │  │ approval_status ENUM     │  │                          │
│                          │  │ effective_date           │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ regulatory_audits        │  │ audit_findings           │  │ audit_finding_training   │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ audit_code UQ            │  │ audit_id FK              │  │ finding_id FK            │
│ organization_id / plant  │  │ finding_code UQ          │  │ course_id  FK            │
│ audit_type ENUM          │  │ finding_type ENUM        │  │ target_audience JSONB    │
│ auditor_name/agency      │  │ severity ENUM            │  │ deadline_days INT        │
│ audit_date_range         │  │ description              │  │                          │
│ status ENUM              │  │ capa_id  FK?             │  │                          │
│ overall_rating           │  │ status ENUM              │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ audit_preparation_items  │  │ audit_evidence           │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ audit_id  FK             │  │ audit_id   FK            │
│ item_description         │  │ finding_id FK?           │
│ owner_id  FK→emp         │  │ evidence_type ENUM       │
│ due_date / completed_at  │  │ file_id       FK         │
│ status ENUM              │  │ description              │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.10 Module `audit`  ·  5 tiles (immutable, append-only)

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ login_audit_trail        │  │ data_access_audit        │  │ permission_change_audit  │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id FK           │  │ employee_id FK           │  │ target_employee_id FK    │
│ login_time              │  │ access_at                │  │ changed_by_id      FK    │
│ logout_time             │  │ entity_type, entity_id   │  │ change_type ENUM         │
│ ip_address / user_agent │  │ access_type ENUM         │  │ before_permissions JSONB │
│ login_status ENUM        │  │ ip_address              │  │ after_permissions  JSONB │
│ failure_reason           │  │ query_hash               │  │ reason                   │
│ sso_provider             │  │                          │  │ performed_at             │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ system_config_audit      │  │ compliance_reports       │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ setting_key              │  │ report_name              │
│ before_value JSONB       │  │ report_type ENUM         │
│ after_value  JSONB       │  │ period_start / end       │
│ changed_by FK            │  │ generated_by FK          │
│ change_reason            │  │ file_id FK               │
│ performed_at             │  │ hash                     │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.11 Module `notifications`  ·  7 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ notification_templates   │  │ notification_queue       │  │ notification_log         │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ template_code UQ         │  │ template_id  FK          │  │ queue_id FK              │
│ channel ENUM             │  │ recipient_id FK→emp      │  │ sent_at                  │
│ subject_template         │  │ payload_json JSONB       │  │ channel ENUM             │
│ body_template            │  │ scheduled_for            │  │ status ENUM              │
│ variables[]              │  │ status ENUM              │  │ provider_response JSONB  │
│ locale                   │  │ attempts INT             │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ user_notifications       │  │ notification_preferences │  │ reminder_rules           │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id  FK          │  │ employee_id FK UQ        │  │ organization_id FK       │
│ notification_type ENUM   │  │ email_enabled BOOL       │  │ rule_name                │
│ title, body              │  │ sms_enabled   BOOL       │  │ trigger_entity TEXT      │
│ entity_type, entity_id   │  │ push_enabled  BOOL       │  │ days_before_due INT      │
│ is_read  BOOL            │  │ quiet_hours_start/end    │  │ template_id FK           │
│ read_at                  │  │ digest_frequency ENUM    │  │ is_active BOOL           │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐
│ escalation_rules         │
├──────────────────────────┤
│ id PK                    │
│ organization_id FK       │
│ trigger_entity / event   │
│ escalation_delay_hours   │
│ escalate_to_role_level   │
│ template_id  FK          │
│ max_escalations INT      │
└──────────────────────────┘
```

### 2.12 Module `analytics`  ·  8 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ dashboard_widgets        │  │ user_dashboards          │  │ training_analytics       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ widget_code UQ           │  │ employee_id FK           │  │ organization_id FK       │
│ widget_name              │  │ dashboard_name           │  │ period_start / end       │
│ widget_type ENUM         │  │ layout_json JSONB        │  │ total_trainings INT      │
│ data_query JSONB         │  │ is_default   BOOL        │  │ completed, overdue       │
│ default_config JSONB     │  │                          │  │ avg_score_percent        │
│                          │  │                          │  │ compliance_percent       │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ course_analytics         │  │ employee_training_analyt.│  │ report_definitions       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ course_id FK             │  │ employee_id FK           │  │ report_code UQ           │
│ period_start / end       │  │ period_start / end       │  │ report_name              │
│ enrollments_count        │  │ trainings_completed      │  │ data_source TEXT         │
│ completions_count        │  │ avg_score_percent        │  │ query_template TEXT      │
│ avg_score                │  │ on_time_completion_pct   │  │ filters_json  JSONB      │
│ satisfaction_avg         │  │ overdue_count            │  │ format ENUM              │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ scheduled_reports        │  │ report_history           │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ report_definition_id FK  │  │ report_definition_id FK  │
│ schedule_cron            │  │ generated_at             │
│ recipient_list TEXT[]    │  │ file_id FK               │
│ is_active BOOL           │  │ status ENUM              │
│ last_run_at              │  │ row_count INT            │
│ next_run_at              │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

### 2.13 Module `workflow`  ·  7 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ workflow_definitions     │  │ workflow_approval_rules  │  │ workflow_instances       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ workflow_name            │  │ workflow_id FK           │  │ workflow_definition_id FK│
│ applicable_entity_types  │  │ approval_level INT       │  │ related_entity_type      │
│ states  JSONB            │  │ approver_roles UUID[]    │  │ related_entity_id        │
│ transitions JSONB        │  │ require_all_approvers    │  │ current_state            │
│ initial_state            │  │ approval_deadline_days   │  │ initiated_at / by        │
│ is_active BOOL           │  │                          │  │ is_active                │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ workflow_tasks           │  │ workflow_history         │  │ approval_delegations     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ workflow_instance_id FK  │  │ workflow_instance_id FK  │  │ delegating_employee_id FK│
│ assigned_to_id FK→emp    │  │ from_state / to_state    │  │ delegated_to_employee FK │
│ task_description         │  │ action_taken             │  │ delegation_type ENUM     │
│ due_date                 │  │ performed_by FK          │  │ start_date / end_date    │
│ task_status ENUM         │  │ performed_at             │  │ applicable_types TEXT[]  │
│ completed_at / by        │  │ reason                   │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐
│ out_of_office            │
├──────────────────────────┤
│ id PK                    │
│ employee_id FK           │
│ start_date / end_date    │
│ backup_approver_id FK    │
│ auto_delegate_approvals  │
│ notification_sent BOOL   │
└──────────────────────────┘
```

### 2.14 Module `cron`  ·  3 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ cron_jobs                │  │ cron_job_history         │  │ background_tasks         │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ cron_job_id FK           │  │ task_type ENUM           │
│ job_name    UQ           │  │ execution_time           │  │ task_status ENUM         │
│ job_type    ENUM         │  │ duration_seconds         │  │ priority INT             │
│ schedule_expression      │  │ status ENUM              │  │ payload JSONB            │
│ last_run_time            │  │ rows_affected INT        │  │ started_at / completed_at│
│ next_run_time            │  │ error_message            │  │ error_detail             │
│ status ENUM              │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

### 2.15 Module `infrastructure`  ·  9 tiles

```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ system_settings          │  │ feature_flags            │  │ api_keys                 │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ organization_id FK       │
│ setting_key   UQ(org)    │  │ flag_name    UQ          │  │ key_name UQ              │
│ setting_value JSONB      │  │ is_enabled BOOL          │  │ key_hash                 │
│ setting_type  ENUM       │  │ enabled_for_org BOOL     │  │ key_prefix               │
│ scope ENUM               │  │ percentage_rollout INT   │  │ expires_at               │
│ updated_by FK            │  │ updated_by FK            │  │ is_active BOOL           │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ webhooks                 │  │ file_storage             │  │ file_associations  [JOIN]│
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ file_id FK               │
│ event_type  ENUM         │  │ plant_id  FK             │  │ associated_entity_type   │
│ target_url               │  │ file_type ENUM           │  │ associated_entity_id     │
│ retry_policy JSONB       │  │ file_name / orig_name    │  │ is_primary BOOL          │
│ headers JSONB            │  │ file_size_bytes          │  │                          │
│ is_active                │  │ mime_type / file_hash    │  │                          │
│                          │  │ storage_path             │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ integrations             │  │ sso_configurations       │  │ integration_sync_log     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ integration_id FK        │
│ integration_name         │  │ sso_provider ENUM        │  │ sync_type ENUM           │
│ integration_type ENUM    │  │ provider_url             │  │ started_at / ended_at    │
│ api_url                  │  │ client_id                │  │ status ENUM              │
│ api_credentials JSONB    │  │ client_secret (encr)     │  │ records_synced INT       │
│ sync_enabled BOOL        │  │ attribute_mapping JSONB  │  │ error JSONB              │
│ is_active                │  │ auto_create_users BOOL   │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

### 2.16 Module `extensions`  ·  34 tiles (new)

**Learning Paths**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ learning_paths           │  │ learning_path_steps      │  │ course_prerequisites     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ learning_path_id FK      │  │ course_id       FK       │
│ path_code UQ             │  │ step_order INT           │  │ prerequisite_type ENUM   │
│ path_name                │  │ course_id    FK?         │  │ prerequisite_ref_id UUID │
│ target_audience JSONB    │  │ learning_path_id_nested  │  │ is_mandatory BOOL        │
│ estimated_duration_hrs   │  │ is_mandatory BOOL        │  │ min_score_percent        │
│ status learning_path_st. │  │ unlock_condition ENUM    │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ learning_path_enrollments│  │ learning_path_step_prog. │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ learning_path_id FK      │  │ enrollment_id FK         │
│ employee_id      FK      │  │ step_id       FK         │
│ enrollment_status ENUM   │  │ started_at/completed_at  │
│ enrolled_at / due_date   │  │ score_percentage         │
│ progress_percent         │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

**Gamification**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ badges                   │  │ employee_badges          │  │ point_rules              │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ employee_id FK           │  │ organization_id FK       │
│ badge_code UQ            │  │ badge_id    FK           │  │ event_type point_event   │
│ badge_name               │  │ awarded_at               │  │ points_awarded INT       │
│ tier badge_tier          │  │ awarded_for JSONB        │  │ cooldown_hours INT       │
│ criteria_json JSONB      │  │ UQ(emp, badge)           │  │ is_active BOOL           │
│ icon_url                 │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ point_transactions       │  │ employee_point_balances  │  │ leaderboards             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id FK           │  │ employee_id FK UQ        │  │ organization_id FK       │
│ event_type  point_event  │  │ current_balance INT      │  │ leaderboard_name         │
│ points      INT          │  │ lifetime_points INT      │  │ scope ENUM               │
│ rule_id  FK?             │  │ last_updated_at          │  │ period  ENUM             │
│ related_entity_type/id   │  │ tier badge_tier          │  │ metric  ENUM             │
│ created_at               │  │                          │  │ is_active BOOL           │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐
│ leaderboard_snapshots    │
├──────────────────────────┤
│ id PK                    │
│ leaderboard_id FK        │
│ snapshot_date            │
│ rankings JSONB           │
└──────────────────────────┘
```

**Knowledge Base**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ kb_categories            │  │ kb_articles         ♛    │  │ kb_article_versions      │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ article_id    FK         │
│ category_code UQ         │  │ category_id     FK       │  │ version_number INT       │
│ category_name            │  │ article_code  UQ         │  │ body_markdown            │
│ parent_category_id self  │  │ title                    │  │ change_note              │
│ display_order            │  │ body_markdown            │  │ authored_by   FK         │
│                          │  │ search_vector TSVECTOR IX│  │ effective_date           │
│                          │  │ tags[], view_count       │  │                          │
│                          │  │ current_version_number   │  │                          │
│                          │  │ status ENUM              │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ kb_article_feedback      │  │ kb_article_views         │  │ kb_search_queries        │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ article_id  FK           │  │ article_id  FK           │  │ organization_id FK       │
│ employee_id FK           │  │ employee_id FK           │  │ employee_id FK           │
│ helpful     BOOL         │  │ viewed_at                │  │ query_text               │
│ comment                  │  │ duration_seconds         │  │ result_count INT         │
│ created_at               │  │                          │  │ clicked_article_id FK    │
│                          │  │                          │  │ searched_at              │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

**Discussions**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ discussion_threads       │  │ discussion_posts         │  │ discussion_reactions     │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ thread_id FK             │  │ post_id     FK           │
│ course_id FK? / kb FK?   │  │ parent_post_id FK self   │  │ employee_id FK           │
│ thread_title             │  │ employee_id FK           │  │ reaction_type ENUM       │
│ created_by FK            │  │ body                     │  │ UQ(post, emp, type)      │
│ post_count INT           │  │ is_answer BOOL           │  │                          │
│ last_post_at             │  │ flagged_count INT        │  │                          │
│ is_locked BOOL           │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ discussion_subscriptions │  │ discussion_flags         │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ thread_id   FK           │  │ post_id     FK           │
│ employee_id FK           │  │ employee_id FK           │
│ UQ(thread, emp)          │  │ reason                   │
│                          │  │ reviewed_by FK→emp       │
│                          │  │ resolved BOOL            │
└──────────────────────────┘  └──────────────────────────┘
```

**Cost tracking**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ cost_centers             │  │ training_budgets         │  │ course_costs             │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ organization_id FK       │  │ course_id   FK           │
│ cost_center_code UQ      │  │ fiscal_year              │  │ cost_type ENUM           │
│ cost_center_name         │  │ cost_center_id FK        │  │ amount NUMERIC(12,2)     │
│ owner_id FK→emp          │  │ allocated_amount         │  │ currency                 │
│ parent_id self           │  │ spent_amount             │  │ billing_model ENUM       │
│                          │  │ currency                 │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ training_expenses        │  │ budget_alerts            │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ budget_id FK             │
│ session_id FK?           │  │ threshold_percent INT    │
│ cost_center_id FK        │  │ triggered_at             │
│ expense_type ENUM        │  │ alert_status ENUM        │
│ amount / currency        │  │ notified_to UUID[]       │
│ invoice_url / incurred   │  │                          │
└──────────────────────────┘  └──────────────────────────┘
```

**User Preferences & Accessibility**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ user_preferences         │  │ user_accessibility_needs │  │ saved_filters            │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ employee_id FK UQ        │  │ employee_id FK UQ        │  │ employee_id FK           │
│ locale, timezone         │  │ screen_reader  BOOL      │  │ filter_name              │
│ theme ENUM               │  │ high_contrast  BOOL      │  │ entity_type              │
│ date_format              │  │ large_text     BOOL      │  │ filter_json JSONB        │
│ digest_frequency ENUM    │  │ extended_time_multiplier │  │ is_default BOOL          │
│ quiet_hours_start/end    │  │ assistive_tech JSONB     │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐
│ ui_shortcuts             │  │ recent_items             │
├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │
│ employee_id FK           │  │ employee_id FK           │
│ shortcut_key             │  │ entity_type              │
│ action                   │  │ entity_id                │
│ UQ(emp, key)             │  │ accessed_at              │
│                          │  │ access_count INT         │
└──────────────────────────┘  └──────────────────────────┘
```

**Content library (actual learning payload)**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ content_assets           │  │ lessons                  │  │ lesson_content    [JOIN] │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ course_id FK             │  │ lesson_id FK             │
│ asset_code UQ            │  │ lesson_code UQ(course)   │  │ content_asset_id FK      │
│ asset_type ENUM (video/  │  │ lesson_title             │  │ display_order            │
│   doc/slideshow/scorm/   │  │ display_order            │  │ is_required BOOL         │
│   xapi/audio/interactive)│  │ duration_minutes         │  │                          │
│ file_id FK               │  │ lesson_type ENUM         │  │                          │
│ duration_seconds         │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ scorm_packages           │  │ xapi_statements (LRS)    │  │ lesson_progress          │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ content_asset_id FK      │  │ statement_id UUID UQ     │  │ employee_id FK           │
│ scorm_version ENUM       │  │ actor_employee_id FK     │  │ lesson_id   FK           │
│ manifest_path            │  │ verb_iri                 │  │ first_accessed_at        │
│ launch_path              │  │ object_type / id         │  │ last_accessed_at         │
│ entry_point              │  │ result_json JSONB        │  │ completed_at             │
│ mastery_score            │  │ context_json JSONB       │  │ progress_percent         │
│                          │  │ timestamp                │  │ time_spent_minutes       │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐
│ content_view_tracking    │
├──────────────────────────┤
│ id PK                    │
│ employee_id / asset_id   │
│ view_started_at          │
│ view_ended_at            │
│ watch_duration_sec       │
│ playback_position_sec    │
│ device_info JSONB        │
└──────────────────────────┘
```

**Surveys & polls**
```
┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ surveys                  │  │ survey_questions         │  │ survey_invitations       │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ organization_id FK       │  │ survey_id FK             │  │ survey_id FK             │
│ survey_code UQ           │  │ question_order INT       │  │ employee_id FK           │
│ survey_title             │  │ question_text            │  │ invited_at               │
│ survey_type ENUM (pulse/ │  │ question_type ENUM       │  │ responded_at             │
│   nps/exit/engagement/   │  │ options_json JSONB       │  │ reminder_count INT       │
│   custom)                │  │ is_required BOOL         │  │                          │
│ start_date / end_date    │  │ scale_config JSONB       │  │                          │
│ is_anonymous BOOL        │  │                          │  │                          │
│ status ENUM              │  │                          │  │                          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘

┌──────────────────────────┐  ┌──────────────────────────┐  ┌──────────────────────────┐
│ survey_responses         │  │ survey_answers           │  │ survey_analytics         │
├──────────────────────────┤  ├──────────────────────────┤  ├──────────────────────────┤
│ id PK                    │  │ id PK                    │  │ id PK                    │
│ survey_id FK             │  │ response_id FK           │  │ survey_id FK             │
│ employee_id FK?          │  │ question_id FK           │  │ computed_at              │
│ respondent_hash (anon)   │  │ answer_text              │  │ total_invited            │
│ submitted_at             │  │ answer_numeric           │  │ total_responded          │
│ is_complete BOOL         │  │ answer_selections UUID[] │  │ nps_score / avg_rating   │
│                          │  │ answer_json JSONB        │  │ sentiment JSONB          │
└──────────────────────────┘  └──────────────────────────┘  └──────────────────────────┘
```

---

## 3. Relationship Highlights

Below are the **critical relationships** between modules. `1───<` = one-to-many.

### 3.1 Identity spine
```
organizations 1───< plants 1───< departments
organizations 1───< employees
plants        1───< employees
departments   1───< employees
employees     1───< employees                    (manager_id, self-FK)
employees     N───N roles              via employee_roles
roles         N───N permissions        via role_permissions
employees     N───N subgroups          via employee_subgroups
groups        N───N subgroups          via group_subgroups
```

### 3.2 Training closure (end-to-end)
```
group_training_plans  1───< training_schedules  1───< training_sessions  1───< training_batches  N──N employees (batch_trainees)
training_sessions     1───< training_invitations
training_sessions     1───< session_attendance      ──> biometric_registrations
training_sessions     1───< training_feedback
training_sessions     1───< training_reschedules / training_cancellations
training_sessions     1───< training_effectiveness
                          │
courses      1───< lessons  1──N content_assets       via lesson_content
courses      1───< course_topics >──N topics
courses      N───N trainers         via trainer_courses
courses      1───< course_prerequisites
courses      1───< course_costs
```

### 3.3 Assessment chain
```
question_banks  1───< questions  1───< question_options
questions  1───< question_matching_pairs / question_blanks
questions  N───N question_papers via question_paper_questions
question_papers  1───< assessment_attempts
assessment_attempts 1───< assessment_responses
assessment_attempts 1───1 assessment_results  1───< result_appeals
assessment_responses ───> grading_queue (when not auto-graded)
```

### 3.4 Compliance & certification
```
courses         1───< training_records  1───< certificates  >── certificate_templates
training_sessions 1───< training_records
training_assignments 1───< employee_assignments
roles / subgroups  1───< training_matrix  >──── courses
employees  1───< training_waivers  1───< waiver_approvals
employees  1───< employee_competencies  ──> competencies ──N roles (role_competencies)
employees  1───< competency_gaps
```

### 3.5 Quality loop (what triggers training)
```
deviations ───< deviation_training_requirements ───> courses
deviations ───< capa_records ───< capa_actions
change_controls ───< change_control_training ───> courses
regulatory_audits ───< audit_findings ───< audit_finding_training ───> courses
                                          └──── audit_evidence
                                          └──── capa_records (cross link)
```

### 3.6 Workflow envelope (wraps everything approvable)
```
workflow_definitions 1───< workflow_approval_rules
workflow_definitions 1───< workflow_instances  1───< workflow_tasks / workflow_history
workflow_instances  ──> ANY entity (polymorphic via related_entity_type/id)
approval_delegations / out_of_office  ──> employees (delegator, delegate)
pending_approvals 1───< approval_history ──> electronic_signatures
```

### 3.7 Cross-cutting
```
audit_trails        ──> ANY entity (polymorphic) + hash-chained by prev_hash
revision_history    ──> ANY entity (polymorphic)   ─ per-change field diff
electronic_signatures ──> ANY entity
file_storage ───< file_associations ──> ANY entity
notification_queue ──> notification_log, user_notifications
```

---

## 4. Core Tables vs. Join Tables

### 4.1 Core (entity) tables — identified by a real-world noun
These carry **business meaning**, RLS, full audit columns, and usually a unique business code:

| Category | Examples |
|---|---|
| Organization | `organizations`, `plants`, `departments` |
| Identity | `employees`, `roles`, `permissions`, `groups`, `subgroups` |
| Content | `documents`, `courses`, `lessons`, `content_assets`, `kb_articles` |
| Training | `group_training_plans`, `training_sessions`, `induction_programs`, `ojt_assignments` |
| Assessment | `question_banks`, `questions`, `question_papers`, `assessment_attempts` |
| Compliance | `training_records`, `certificates`, `training_assignments`, `training_waivers`, `competencies` |
| Quality | `deviations`, `capa_records`, `change_controls`, `regulatory_audits` |
| Workflow | `workflow_definitions`, `workflow_instances`, `pending_approvals`, `electronic_signatures` |
| Infrastructure | `file_storage`, `api_keys`, `integrations`, `sso_configurations` |
| Extensions | `learning_paths`, `badges`, `surveys`, `cost_centers` |

### 4.2 Join (association) tables — identified by two-noun name
Pure linkage — usually just `(a_id, b_id, <context cols>)` with a unique constraint on the pair:

| Join table | Connects |
|---|---|
| `employee_roles` | employees ↔ roles |
| `role_permissions` | roles ↔ permissions |
| `group_subgroups` | groups ↔ subgroups |
| `employee_subgroups` | employees ↔ subgroups |
| `course_topics` | courses ↔ topics |
| `gtp_courses` | GTPs ↔ courses |
| `batch_trainees` | training_batches ↔ employees |
| `trainer_courses` | trainers ↔ courses |
| `question_paper_questions` | papers ↔ questions |
| `role_competencies` | roles ↔ competencies |
| `file_associations` | files ↔ any entity (polymorphic) |
| `lesson_content` | lessons ↔ content_assets |
| `document_reads` | document_versions ↔ employees (with metrics) |

### 4.3 Hybrid / enriched joins
Join shape, but they carry real data (progress, scores, timestamps) — so they're treated as first-class tables:

- `employee_assignments` (assignment ↔ employee + due_date + status)
- `session_attendance` (session ↔ employee + check-in/out + verification)
- `employee_competencies` (employee ↔ competency + level + evidence)
- `lesson_progress`, `learning_path_step_progress`, `induction_progress`
- `training_feedback`, `kb_article_feedback`, `discussion_reactions`

### 4.4 Polymorphic linkers
Reference ANY table via `(entity_type TEXT, entity_id UUID)`:
- `audit_trails`, `revision_history`, `electronic_signatures`
- `pending_approvals`, `workflow_instances`
- `file_associations`, `user_notifications`

---

## 5. Enabled Scenarios

### 5.1 Operations (day-to-day "do the work")
- **Plan a GTP** for a plant → create `group_training_plans` → attach courses via `gtp_courses` → generate `training_schedules` → `training_sessions` → `training_batches` with `batch_trainees`.
- **Dispatch invitations** (`training_invitations`) with e-mail/SMS/push via `notification_queue`.
- **Mark attendance** biometric or QR via `session_attendance`; summary rolled up into `daily_attendance_summary`.
- **Run induction** for a new hire via `induction_enrollments` → per-module `induction_progress`.
- **On-the-job training** with supervisor witnessing: `ojt_assignments` → `ojt_tasks` → `ojt_task_completion` with `witnessed_by` + `signature_id`.
- **Self-learning** with managerial approval via `self_learning_enrollments` → tracked in `self_learning_progress`.
- **Conduct assessment** (online, in-session, or proctored) via `assessment_attempts` → responses → results; auto-grade MCQ/TF, queue descriptive for `grading_queue`.
- **Issue certificate** on pass via `certificates` with QR + e-signature; distribute PDF via `file_storage`.
- **Waive a requirement** via `training_waivers` with justification → `waiver_approvals`.
- **Trigger training from deviation/CAPA/change-control/audit finding** via the `*_training_requirements` / `*_training` tables.
- **Role-based mandatory matrix**: `training_matrix` rows define "role X must complete course Y every N months" → auto-spawn assignments.
- **Learning path journey**: `learning_path_enrollments` → `learning_path_step_progress`; prerequisites enforced via `course_prerequisites`.
- **Survey / pulse / NPS** via `surveys` → `survey_invitations` → `survey_responses` / `survey_answers` → analytics.
- **Knowledge-base browsing & search** via `kb_articles` (tsvector index), logged in `kb_search_queries`, feedback via `kb_article_feedback`.

### 5.2 Tracking (who did what, where is it now)
- Real-time status of every approval (`pending_approvals.status`, `workflow_instances.current_state`).
- Per-employee progress: `training_records`, `lesson_progress`, `induction_progress`, `ojt_task_completion`, `self_learning_progress`, `learning_path_step_progress`.
- Per-course health: `course_analytics` (enrollments, completions, avg score, satisfaction).
- Per-plant compliance %: `training_analytics` rolled daily by `cron_jobs.analytics_rollup`.
- Matrix-driven gap: `competency_gaps` auto-computed from `role_competencies` vs `employee_competencies`.
- Cost visibility: `training_budgets.spent_amount` vs `allocated_amount` with `budget_alerts`.
- Reading depth: `document_reads.scroll_percentage`, `read_duration_seconds` give you "did they really read it?"
- Content engagement: `content_view_tracking.watch_duration_sec`, `playback_position_sec`; `xapi_statements` for granular LRS events.
- Attendance stats: biometric vs QR vs manual breakdown in `session_attendance.verification_method`.

### 5.3 Audit & History (who did what, when, why)
- **Immutable `audit_trails`** with `integrity_hash` and `prev_hash` SHA-256 chain — tamper-evident per 21 CFR Part 11 §11.10(e).
- **`revision_history`** with field-level `field_diffs` JSONB and before/after snapshots — answers "what was this record before?".
- **`login_audit_trail`** (success + failure) with IP, user-agent, SSO provider.
- **`data_access_audit`** logs SELECT-level access to sensitive entities.
- **`permission_change_audit`** captures before/after permission sets for every role/employee change.
- **`system_config_audit`** logs mutations to `system_settings` and `feature_flags`.
- **`workflow_history`** logs every state transition with reason + e-sig reference.
- **`approval_history`** logs each decision (approve/reject/return) on a pending_approval.
- **`cron_job_history`** captures every batch run with duration + rows_affected + error.
- **`integration_sync_log`** captures every HRMS / AD sync.
- **`kb_search_queries`** logs every search for analytics & gap-spotting.

### 5.4 Version Control
- **Documents** — `documents` (logical) ↔ `document_versions` (immutable snapshots), with `is_current` flag and `effective_date` / `expiry_date`.
- **Courses** — `courses` ↔ `course_versions` with `content_payload JSONB` snapshot.
- **GTPs** — `group_training_plans` ↔ `gtp_versions`.
- **Induction programs** — `induction_programs` carries `current_version_number` (version history overlay on revision_history).
- **KB articles** — `kb_articles` ↔ `kb_article_versions` with `change_note` + authored_by.
- **Workflow definitions** — states/transitions captured as JSONB; changes tracked via `revision_history`.
- **Question papers** — via revision_history; each paper version is effectively an assessment form blueprint.
- **Certificate templates** — `template_html` versioned via revision_history.
- Every version is **immutable once effective**; edits always create a new version.

### 5.5 Approval Workflow
- **Hierarchical approval** — `workflow_approval_rules.approval_level` supports multi-stage (e.g. reviewer → QA Head → Regulatory); `require_all_approvers` toggles all-vs-any.
- **Role-level enforcement** — `min_approver_level NUMERIC(4,2)` ensures approver is more senior than initiator (`initiator_role_level`).
- **State machine** — `workflow_transitions` table defines allowed moves: `draft → initiated → pending_approval → (approved | returned | dropped) → active → inactive`.
- **Approver delegation** — `approval_delegations` with type `full` / `partial` / `specific_types`.
- **Out-of-office auto-routing** — `out_of_office.backup_approver_id` + `auto_delegate_approvals`.
- **Standard reasons** enforcement — `standard_reasons` (APR001–APR005, REJ001–REJ005, RET001–RET003, WAV001–WAV004) are picked from dropdown, not free-text.
- **E-signature binding** — every approval of a regulated entity writes to `electronic_signatures` with `meaning` + `reason` + `password_reauth_verified` + `biometric_verified`.

### 5.6 Notifications & Escalation
- **Template-driven** — `notification_templates` with variable interpolation; multi-channel (`email`, `sms`, `push`, `in_app`).
- **Per-user preferences** — `notification_preferences.quiet_hours_*`, `digest_frequency`, per-channel opt-out.
- **Reminder cadence** — `reminder_rules` with `days_before_due`.
- **Escalation ladder** — `escalation_rules.escalate_to_role_level` + `max_escalations` auto-escalates overdue items up the hierarchy.
- **In-app inbox** — `user_notifications` with `is_read` + `read_at`.
- **Digest** — configured in `user_preferences.digest_frequency` (`immediate` / `daily` / `weekly`).
- **Webhook outbound** — `webhooks` publishes events (`certificate_issued`, `training_completed`, etc.) to external systems.

### 5.7 Analytics & Reporting
- **Pre-configured widgets** — `dashboard_widgets` with `widget_type` (bar/pie/KPI/table) and `data_query JSONB`.
- **Role-scoped dashboards** — `user_dashboards.layout_json` lets each employee arrange their own view.
- **Scheduled reports** — `scheduled_reports.schedule_cron` + `recipient_list` → auto-generated PDF/XLSX via `report_history`.
- **Roll-up analytics** — nightly `cron_jobs` populate `training_analytics`, `course_analytics`, `employee_training_analytics`.
- **Leaderboards** — `leaderboards` + `leaderboard_snapshots` for public recognition.
- **Survey analytics** — `survey_analytics` with computed NPS score + sentiment.
- **KB content analytics** — helpful/not-helpful ratio, top searches, articles-without-matches.

### 5.8 Security & RLS
- **Row-Level Security** — policies in `99_policies/*.sql` scope by `organization_id` and `plant_id`.
- **Role-based permissions** via `role_permissions` granting resource×action.
- **SSO via SAML/OAuth** — `sso_configurations` (Azure AD, Okta, etc.) with `attribute_mapping` for JIT-provisioning.
- **API keys** — `api_keys.key_hash` (never stored in clear) with `expires_at`.
- **Password re-auth on signing** — `electronic_signatures.password_reauth_verified`.
- **Biometric verification** — `biometric_registrations` + `electronic_signatures.biometric_verified`.
- **Session timeout** — `system_settings.session_timeout_minutes`.
- **IP allow-list / lockout** — derived from `login_audit_trail` failure patterns.

### 5.9 Compliance (21 CFR Part 11 / EU Annex 11)
- **§11.10(e) Audit Trail** — `audit_trails` + `revision_history` immutable + hash chain.
- **§11.50 Signature Manifestations** — `electronic_signatures` carries name, title, date-time, meaning, and is imprinted on `data_snapshot`.
- **§11.70 Signature/Record Linking** — `entity_type`+`entity_id` FK + `integrity_hash` cryptographically binds sig to record.
- **§11.100(b) User Uniqueness** — `employees.email UQ`, `employee_code UQ(org)`, one biometric template per user per device.
- **§11.200 Non-Biometric Sig** — two-component (ID + password re-auth) enforced per action.
- **§11.300 Controls for ID/Passwords** — via SSO + `system_settings` (complexity, rotation).
- **Annex 11 §9 Audit Trails** — covered same as above, with regular review via `data_access_audit`.
- **Annex 11 §4 Validation** — `change_controls` captures validated-state changes to the LMS itself.
- **Retention** — `documents.retention_period_years`, `document_categories.retention_years`, `certificates.expires_on`.
- **Data integrity ALCOA+** — Attributable (performed_by), Legible (human-readable columns, not binary), Contemporaneous (`performed_at` DEFAULT now()), Original (immutable audit), Accurate (hash chain).

### 5.10 Content Delivery
- **Blended learning** — mix `lessons` of type `video` / `document` / `slideshow` / `scorm` / `xapi` / `live_session`.
- **SCORM 1.2 & 2004** via `scorm_packages.scorm_version` with manifest path.
- **xAPI LRS** — `xapi_statements` captures actor→verb→object→result statements.
- **Offline-aware** — `content_view_tracking` accepts backfilled events on reconnect (Flutter app).
- **Resumability** — `lesson_progress.playback_position_sec` (via `content_view_tracking`) lets video pick up where it left off.

### 5.11 Gamification & Engagement
- **Badges** (`bronze` / `silver` / `gold` / `platinum` / `diamond`) awarded via `criteria_json` rules engine.
- **Points** — `point_rules` define events (`complete_course`, `perfect_score`, `first_attempt_pass`); transactions accumulated in `employee_point_balances`.
- **Leaderboards** — scoped by org / plant / department / group, period monthly/quarterly/all-time, metric points/completions/avg-score.
- **Recent-activity widget** from `recent_items`.
- **Preference-driven UI** — `user_preferences.theme` (light/dark), `locale`, `date_format`.

### 5.12 Collaboration
- **Discussion forums** per course / per KB article / standalone — threaded replies via `parent_post_id`.
- **Answer acceptance** — `discussion_posts.is_answer` marks the accepted answer (StackOverflow style).
- **Reactions** — like/insightful/helpful counted in `discussion_reactions`.
- **Subscriptions** — `discussion_subscriptions` for thread notifications.
- **Moderation** — `discussion_flags` with reviewer workflow.

### 5.13 Cost Management
- **Training budget per fiscal year** per cost center.
- **Cost attribution** — each course carries per-delivery or per-hour cost via `course_costs`.
- **Actual expenses** — `training_expenses` linked to `training_sessions`.
- **Budget thresholds** — `budget_alerts` fire at configured percent of allocation.
- **ROI report** — compare `training_budgets.spent_amount` against `training_effectiveness` Kirkpatrick scores.

### 5.14 Accessibility & Personalization
- **Screen-reader / high-contrast / large-text** flags in `user_accessibility_needs`.
- **Extended time** on assessments via `extended_time_multiplier` (e.g. 1.5× for ADA/WCAG compliance).
- **Saved filters** per entity view.
- **Custom keyboard shortcuts** in `ui_shortcuts`.
- **Per-user timezone / date format / locale**.

### 5.15 Integrations & Extensibility
- **HRMS sync** — `integrations` with `sync_enabled`; log in `integration_sync_log`.
- **Biometric devices** — `integrations.integration_type='biometric_device'` with `api_credentials` JSONB.
- **SSO** — Azure AD, Okta, generic OIDC/SAML via `sso_configurations`.
- **Webhook outbound** to any URL with retry policy.
- **Feature flags** for gradual rollout (`percentage_rollout`).
- **Custom reports** via `report_definitions.query_template`.

---

## 6. Known Issues / Follow-ups

| # | Issue | Impact | Fix |
|--:|---|---|---|
| 1 | Role UUIDs in several seed files (`05_identity.sql`, `10_compliance.sql`, `13_notifications.sql`, `14_analytics.sql`, `15_workflow.sql`) use a 13-character last segment like `00000000-0000-0000-0000-000000001001` instead of the required 12-char segment. | Seeds will fail with `invalid input syntax for type uuid` on insert. | Pick a safe canonical form, e.g. `00000000-0000-0000-0001-000000001001`, and `sed`-replace across those files. |
| 2 | `auth_user_id` FK on `employees` references Supabase `auth.users` which isn't seeded in test env. | Inserts will fail unless FK is nullable (it is) or `auth.users` rows are pre-populated. | Acceptable as-is: leave `auth_user_id = NULL` for biometric-only users and fixture rows. |
| 3 | `revision_history` is not seeded — no sample "before/after" rows. | No impact on demos; but audit-trail demo looks thin. | Add 2-3 example revisions in `12_audit.sql`. |
| 4 | `xapi_statements` schema doesn't enforce actor IRI format per xAPI spec. | Valid xAPI statements from third-party tools may need additional normalization. | Add CHECK constraint or do it in ingestion layer. |
| 5 | No dedicated `feedback_course_mapping` — training feedback is session-scoped only. | Can't capture "feedback on an entire GTP" directly. | Add `gtp_id` optional FK to `training_feedback` if needed. |

---

## 7. File Inventory

### 7.1 Schema DDL (`supabase/schemas/`)
- `00_extensions/` (4 files) — `uuid-ossp`, `pgcrypto`, `pg_trgm`, `btree_gist`
- `01_types/` (3) — enums, composite types, domains
- `02_core/` (5) — audit, revisions, workflow, approvals, e-sig base
- `03_organization/` (3), `04_identity/` (13), `05_documents/` (2)
- `06_courses/` (5), `07_training/` (9), `08_assessment/` (5)
- `09_compliance/` (5), `10_quality/` (3), `11_audit/` (2)
- `12_notifications/` (2), `13_analytics/` (2), `14_workflow/` (2)
- `15_cron/` (1), `16_infrastructure/` (3)
- **`17_extensions/` (8 NEW)** — learning paths, gamification, KB, discussions, cost, prefs, content library, surveys
- `99_policies/` (3) — RLS policies

### 7.2 Seed data (`supabase/seed/`)
- `00_reset.sql`
- `01_organizations.sql`, `01_organizations_plants_departments.sql`
- `02_roles_permissions.sql`, `03_standard_reasons.sql`, `04_notification_templates.sql`
- `05_identity.sql`, `06_documents.sql`, `07_courses.sql`, `08_training.sql`
- `09_assessment.sql`, `10_compliance.sql`, `11_quality.sql`, `12_audit.sql`
- `13_notifications.sql`, `14_analytics.sql`, `15_workflow.sql`
- `16_cron.sql`, `17_infrastructure.sql`, `18_core.sql`
- **`19_extensions.sql` (NEW)** — seed for all 8 extension modules

---

*Document generated 2026-04-22. Scope: ~170 tables covering the full PharmaLearn user manual feature-set plus gamification, learning paths, KB, discussions, cost tracking, accessibility, content library, and surveys — a superset of the manual for a production-grade regulated pharma LMS.*
