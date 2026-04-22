Now I have a complete picture. Let me write the full implementation plan:

---

# PharmaLearn LMS — Backend & API Layer: Full Implementation Plan to 100%

**Baseline:** Schema 100% ✅ · API routes ~95% ✅ · Handler logic ~70% · Lifecycle jobs ~60% · Workflow engine ~40% · Regulatory compliance ~75%

---

## PHASE 0 — Critical Bug Fixes (Day 1, do first before anything else)

These cause hard runtime errors on first request.

### 0.1 Fix table name mismatches

**File:** `apps/api_server/pharma_learn/api/lib/routes/certify/waivers/waivers_handler.dart`

Every `from('waivers')` must be `from('training_waivers')`. Also column differences:
- `employee_id` ✅ same
- `approved_by` ✅ same  
- `rejection_reason` → `rejection_reason` ✅
- `employee_assignment_id` does NOT exist on `training_waivers` — it uses `assignment_id` (FK to `training_assignments`)
- `requested_at` → `requested_at` ✅
- `status` is `workflow_state` enum values: `pending_approval`, `approved`, `rejected`

**Fix:** Replace all `from('waivers')` → `from('training_waivers')`, fix column `employee_assignment_id` → `assignment_id`, fix status values `'pending'`→`'pending_approval'`.

**File:** `apps/api_server/pharma_learn/api/lib/routes/train/me/me_training_history_handler.dart`

Line 98: `from('ojt_assignments').select(... ojt_modules!inner ...)` — the VIEW is `ojt_assignments` (exists ✅) but it does not expose `certificate_id`. Remove that column from the select, and fix `ojt_modules!inner` → no join needed (VIEW already has columns from `ojt_masters`).

Line 148: `from('self_learning_progress')` — verify this table name. The schema has `learning_progress` or `content_view_tracking`. Check and align.

**File:** `apps/api_server/pharma_learn/api/lib/routes/train/me/me_obligations_handler.dart` (created today)

Uses `employee_training_obligations` — this is CORRECT per schema. However `nullsFirst: false` is not a valid Supabase Dart SDK argument; use `referencedTable: null` pattern or just remove. Also fix pagination — the current code paginates in Dart (slow); use `.range()` instead.

### 0.2 Fix me_obligations_handler pagination and column errors

Replace in-Dart pagination with proper `.range()` call and remove `nullsFirst` argument.

### 0.3 Add missing `GET /v1/train/sessions/:id/qr` route (needed for check-in flow)

`session_checkin_handler` validates QR tokens but there's no endpoint to *generate* the QR image. Add `session_qr_handler.dart` and wire it.

---

## PHASE 1 — Missing Handler Files (Days 1–5)

Many routes reference handlers that are declared in route files but the actual handler function implementations are split across fewer files than expected. This phase creates the missing implementations.

### 1.1 Assessment — missing handlers

Currently only `assessments_handler.dart` and `assessment_grade_handler.dart` exist, yet routes reference: `assessmentAnswerHandler`, `assessmentSubmitHandler`, `assessmentGetHandler`, `assessmentHistoryHandler`, `assessmentQuestionAnalysisHandler`.

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/assessment_answer_handler.dart`
- `POST /v1/certify/assessments/:id/answer`
- Upsert into `assessment_responses` with `question_id`, `selected_option_ids`/`text_response`
- Enforce timer: reject if `NOW() > started_at + time_limit + 30s grace`
- Record `time_spent_seconds`, `is_marked_for_review`
- Return updated attempt progress

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/assessment_submit_handler.dart`
- `POST /v1/certify/assessments/:id/submit`
- Final timer check with 30s grace
- Auto-grade: MCQ/true_false/matching → compare against `correct_answer_ids` on `question_options`
- Compute `total_marks`, `obtained_marks`, `percentage`, `is_passed` (≥ `pass_mark`)
- Update `assessment_attempts.status = 'graded'` (or `'in_review'` if essay questions exist)
- If `is_passed`: call `create_certificate` RPC or inline certificate generation
- If `!is_passed` and `attempt_number >= max_attempts`: create `training_remedials` row
- Publish `assessment.submitted` and `assessment.passed`/`assessment.failed` events

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/assessment_get_handler.dart`
- `GET /v1/certify/assessments/:id`
- Return attempt + responses + question paper metadata

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/assessment_history_handler.dart`
- `GET /v1/certify/assessments/history`
- All attempts for auth employee across all obligations, paginated

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/assessment_question_analysis_handler.dart`
- `GET /v1/certify/assessments/:id/questions/analysis`
- Per-question: `correct_count`, `incorrect_count`, `skip_count`, `avg_time_seconds`, `difficulty_index`
- Admin/trainer only (permission check)

**Add to routes.dart:** `GET /v1/certify/assessments/grading-queue`
- Lists `assessment_attempts` with `status = 'in_review'` ordered by submission time
- Returns pending manual-grade items: attempt_id, employee_name, question_paper_name, submitted_at
- Permission: requires `assessments.grade`

**Update:** `apps/api_server/pharma_learn/api/lib/routes/certify/assessments/routes.dart`
- Mount all new handlers
- Add grading queue route

### 1.2 Induction — per-module completion

**Create:** `apps/api_server/pharma_learn/api/lib/routes/train/induction/induction_module_complete_handler.dart`
- `POST /v1/train/induction/modules/:id/complete`
- Mark individual module complete in `employee_induction_progress`
- Check if all modules done → trigger overall induction completion
- On full completion: call `inductionCompleteHandler` logic (e-sig requirement from URS)
- URS §5.1 milestone tracking (Day 30/60/90 flags)

**Update routes.dart:** mount `POST /v1/train/induction/modules/:id/complete`

### 1.3 Password Reset (Self-Service)

`POST /v1/auth/password/change` exists (for authenticated users) but there's no unauthenticated reset flow (forgot password).

**Create:** `apps/api_server/pharma_learn/api/lib/routes/access/auth/password_reset_handler.dart`

```
POST /v1/auth/password/reset-request  (public — no auth)
  Body: { email: string }
  → Look up employee by email
  → Generate time-limited token (UUID, 15 min expiry) stored in password_reset_tokens table
  → Send email via send-notification Edge Function
  → Return 200 always (don't reveal if email exists — security)

POST /v1/auth/password/reset  (public — no auth)
  Body: { token: string, new_password: string }
  → Validate token (exists, not expired, not used)
  → Enforce password policy (min length, complexity from password_policies table)
  → Update via GoTrue supabase.auth.admin.updateUserById
  → Mark token consumed
  → Log audit event
  → Publish auth.password_reset event
```

**Migration needed:** `CREATE TABLE IF NOT EXISTS password_reset_tokens (id UUID PK, employee_id UUID FK, token TEXT UNIQUE, expires_at TIMESTAMPTZ, used_at TIMESTAMPTZ, created_at TIMESTAMPTZ)`

**Update routes.dart:** mount both endpoints as public (no `authMiddleware`)

### 1.4 Competency Admin CRUD

**Create:** `apps/api_server/pharma_learn/api/lib/routes/certify/competencies/competency_admin_handler.dart`

```
POST /v1/certify/competencies        (create competency — training_manager only)
  Body: { name, description, category, required_level, assessment_criteria }
  → Insert into competencies table

PATCH /v1/certify/competencies/:id   (update)
DELETE /v1/certify/competencies/:id  (soft delete — set is_active = false)

POST /v1/certify/competencies/:id/assign  (assign to employee)
  Body: { employee_id, attained_level, assessed_by, evidence }
  → Insert into employee_competencies

GET /v1/certify/competencies          (list all competencies for org, paginated)
```

**Update routes.dart**

### 1.5 Session QR Generation

**Create:** `apps/api_server/pharma_learn/api/lib/routes/train/sessions/session_qr_handler.dart`
- `GET /v1/train/sessions/:id/qr`
- Permission: trainer or training_coordinator
- Verify session is `in_progress`
- Check `training_sessions.qr_token` (created by G1 migration)
- Generate QR code image (use `qr` Dart package or return raw token for client-side rendering)
- Return `{ qr_token, qr_expires_at, session_id }` — client renders QR image

**Update sessions/routes.dart**

### 1.6 Training Obligations — Coordinator Endpoints

URS §5.1.30 requires coordinator view of all obligations with Total/At Risk/Not At Risk/Overdue breakdown.

**Create:** `apps/api_server/pharma_learn/api/lib/routes/train/obligations/obligations_coordinator_handler.dart`
- `GET /v1/train/obligations/coordinator` — org-wide pending obligations dashboard
- `GET /v1/train/obligations/coordinator/at-risk` — due within 7 days, not completed
- `POST /v1/train/obligations` — coordinator creates obligation for specific employee(s)
- `PATCH /v1/train/obligations/:id/extend` — extend due date with reason

**Update train/obligations/routes.dart**

---

## PHASE 2 — lifecycle_monitor: Complete Job Logic (Days 3–8)

The job framework exists and handlers are created. The issue is handler logic completeness and table name accuracy. Each job needs to be production-hardened.

### 2.1 Compliance Metrics Job — harden logic

**File:** `lifecycle_monitor/lib/routes/jobs/compliance_metrics_handler.dart`

Current issue: N+1 query (one DB call per employee). Replace with a single `recalculate_compliance_metrics()` RPC call (already defined in G5 migration).

```dart
// REPLACE current loop with single RPC call
await supabase.rpc('recalculate_compliance_metrics');
```

Also add: insert a row into `audit_trails` for the job execution (job_type, execution_time, employees_updated count) — required for 21 CFR audit completeness.

### 2.2 Certificate Expiry Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/expiry_handlers.dart`

Current issues:
- Uses `certificates.employees!employee_id` join — verify FK name is `employee_id` (correct per schema)
- Uses `courses!course_id` — verify `certificates` has `course_id` column (check schema: `training_records.course_id` → `certificates.training_record_id`)
- Fix join chain: `certificates → training_records → courses`
- Add duplicate notification prevention (check `notifications` table before inserting)
- Add 60-day and 90-day thresholds (URS mentions these)

```dart
final thresholds = [90, 60, 30, 14, 7, 1]; // Add 90 and 60
```

Also add: **password expiry alerts** in same file — query `user_credentials.expires_at` and notify.

### 2.3 Overdue Training Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/overdue_training_handler.dart`

Must:
1. Call `mark_overdue_reviews()` RPC (marks `periodic_review_schedules` as OVERDUE)
2. Also update `employee_training_obligations.status = 'overdue'` where `due_date < NOW() AND status IN ('pending', 'in_progress')`
3. Notify employee + manager via `notifications` table
4. Notify via email (send-notification Edge Function)
5. Log job execution to `background_jobs` table

### 2.4 Integrity Check Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/integrity_check_handler.dart`

Must call `verify_audit_hash_chain()` RPC and:
1. If failures found: create `system_alerts` row with severity = 'CRITICAL'
2. Notify super_admin via email
3. Log to `audit_trails` with action `'integrity_check_failed'`
4. Return count of failures in job result

### 2.5 Archive Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/archive_job_handler.dart`

Must call `process_retention_policies()` RPC and:
1. Move completed `audit_trails` older than policy `retention_years` to `audit_trails_archive`
2. Log archival action itself to fresh `audit_trails` entry (meta-audit)
3. Return count of archived records

### 2.6 Events Fanout Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/events_fanout_handler.dart`

This is the most critical job — processes `events_outbox` and routes to consumers.

Must implement:
1. Lock event with `UPDATE events_outbox SET processing_started_at = NOW() WHERE id = ? AND processing_started_at IS NULL`
2. Route by `event_type` to appropriate consumer:
   - `*.submitted` → POST to workflow_engine `/internal/workflow/advance-step`
   - `assessment.failed` → create remedial training
   - `certificate.issued` → notify employee
   - `training.completed` → update compliance metrics
3. On success: call `mark_event_processed()` RPC
4. On failure: call `schedule_event_retry()` RPC (exponential backoff)
5. After max retries: `is_dead_letter = true` (handled by scheduler's `_deadLetterAlertJob`)

### 2.7 Report Generation Job — complete wiring

**File:** `lifecycle_monitor/lib/routes/jobs/report_generation_handler.dart`

Already wired to `ReportGeneratorService.processQueuedReports()`. Verify:
1. `ReportGeneratorService` handles all 10 report template types from `ReportTemplate` enum
2. PDF is uploaded to `pharmalearn-files` bucket correctly
3. `compliance_reports.status` transitions: `queued → processing → ready / failed`
4. On completion: notify requesting employee via `notifications`

### 2.8 Periodic Review Job — complete logic

**File:** `lifecycle_monitor/lib/routes/jobs/periodic_review_handler.dart`

Must:
1. Query `periodic_review_schedules WHERE next_review_due <= NOW() AND status = 'PENDING'`
2. For each: create a new training obligation for the employee
3. Update status to `'IN_REVIEW'`
4. Notify employee + coordinator

### 2.9 Add missing lifecycle_monitor migration

**Migration:** `supabase/migrations/20260426_015_g15_lifecycle_monitor_jobs.sql`

```sql
-- background_jobs table for job execution tracking (21 CFR audit)
CREATE TABLE IF NOT EXISTS background_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running'
        CHECK (status IN ('running', 'completed', 'failed')),
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    execution_ms INTEGER,
    organization_id UUID REFERENCES organizations(id)
);
CREATE INDEX ON background_jobs(job_name, started_at DESC);

-- password_reset_tokens table (for Phase 1.3)
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX ON password_reset_tokens(token) WHERE used_at IS NULL;

-- scorm_packages: ensure status column has correct default
-- (idempotent — G13 already added this)
ALTER TABLE scorm_packages ALTER COLUMN status SET DEFAULT 'ready';
```

---

## PHASE 3 — workflow_engine: Complete State Machine (Days 5–12)

The framework exists. Need to harden each handler and add the missing pieces.

### 3.1 advance_step_handler — complete implementation

**File:** `workflow_engine/lib/routes/internal/advance_step_handler.dart`

Current stub needs:
1. After seeding steps, query first pending step
2. Look up who can approve (employees matching `required_role` in org)
3. Notify those employees via `notifications` table
4. Publish `approval.step_pending` event to `events_outbox`
5. Return full step details including `required_role`, `step_name`, approver candidates

### 3.2 approve_step_handler — complete implementation

**File:** `workflow_engine/lib/routes/internal/approve_step_handler.dart`

Must:
1. Validate approver has required `role_level >= min_approval_tier`
2. Call `approve_step(step_id, approved_by, esignature_id)` RPC
3. Check quorum for parallel steps: query count of approved steps at same `step_order`, compare to `quorum` on matrix
4. If quorum met: call `skip_parallel_steps(entity_type, entity_id, step_order)`
5. Call `check_approval_complete(entity_type, entity_id)`
6. If complete: call `_markEntityEffective()` for the entity type
7. If not complete: notify next approver(s) in serial flow
8. Write to `audit_trails`

The `_markEntityEffective()` function must handle each entity type:
- `document` → `UPDATE documents SET status = 'effective', effective_from = NOW()`
- `course` → `UPDATE courses SET status = 'effective'`
- `training_schedule` → `UPDATE training_schedules SET status = 'approved'`
- `waiver` → `UPDATE training_waivers SET status = 'approved'`
- `gtp` → `UPDATE gtp_masters SET status = 'effective'`

### 3.3 reject_workflow_handler — complete implementation

**File:** `workflow_engine/lib/routes/internal/reject_workflow_handler.dart`

Must:
1. Call `reject_step(step_id, rejected_by, reason, esig_id)` RPC
2. Mark entity as `returned`/`rejected` based on entity type
3. Notify submitter with rejection reason
4. Publish `{entity_type}.rejected` event
5. Write to `audit_trails`

### 3.4 complete_workflow_handler — complete implementation

**File:** `workflow_engine/lib/routes/internal/complete_workflow_handler.dart`

Called after all steps approved. Routes to correct entity table for status update.

### 3.5 Add Approval Return Handler (internal)

**Create:** `workflow_engine/lib/routes/internal/return_for_corrections_handler.dart`
- `POST /internal/workflow/return`
- Soft-reject: marks entity as `returned` (not `rejected`)
- Steps are reset so submitter can fix and resubmit
- Notify submitter with what needs to change

### 3.6 Wire PgListenerService to EventRouter

**File:** `workflow_engine/lib/services/workflow_listener_service.dart`

Must listen to `pg_notify` channel `events_outbox_new`, filter for workflow-relevant events:
- `document.submitted`, `course.submitted`, `training_schedule.submitted`, `waiver.submitted`, `gtp.submitted`
- For each: HTTP POST to `/internal/workflow/advance-step`

Filter OUT non-workflow events (assessment, compliance, etc.) — those go to lifecycle_monitor.

### 3.7 workflow_engine Migration

**Migration:** `supabase/migrations/20260426_016_g16_workflow_engine.sql`

```sql
-- workflow_instances: tracks complete workflow lifecycle per entity
CREATE TABLE IF NOT EXISTS workflow_instances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    matrix_id UUID REFERENCES approval_matrices(id),
    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'approved', 'rejected', 'returned', 'cancelled')),
    submitted_by UUID REFERENCES employees(id),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    current_step_order INTEGER DEFAULT 1,
    rejection_reason TEXT,
    return_reason TEXT,
    UNIQUE(entity_type, entity_id)  -- one active workflow per entity
);
CREATE INDEX ON workflow_instances(status, submitted_at DESC);
CREATE INDEX ON workflow_instances(entity_type, entity_id);

-- approval_step_delegations: handle delegation during approval
CREATE TABLE IF NOT EXISTS approval_step_delegations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    step_id UUID NOT NULL REFERENCES approval_steps(id) ON DELETE CASCADE,
    delegated_from UUID NOT NULL REFERENCES employees(id),
    delegated_to UUID NOT NULL REFERENCES employees(id),
    delegation_id UUID REFERENCES operational_delegations(id),
    delegated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

---

## PHASE 4 — ReportGeneratorService: All 10 Report Types (Days 8–14)

**File:** `lifecycle_monitor/lib/services/report_generator_service.dart`

The service skeleton exists with PDF/CSV via `pdf` and `csv` packages. Need to implement `_fetchReportData()` for all 10 template types.

### 4.1 Report Templates to Implement

Per `packages/pharmalearn_shared/lib/src/models/report_templates.dart` and URS:

| Template ID | Report Name | Data Source | Required Filters |
|---|---|---|---|
| `employee_training_dossier` | Complete training dossier for one employee | `employee_training_obligations` + `certificates` + `assessment_attempts` | `employee_id`, `date_range` |
| `department_compliance_summary` | Dept-level compliance % | `employees` + `employee_training_obligations` grouped by dept | `department_id`, `as_of_date` |
| `overdue_training_report` | All overdue obligations | `employee_training_obligations WHERE status = 'overdue'` | `department_id`, `plant_id`, `date_range` |
| `certificate_expiry_report` | Expiring/expired certs | `certificates WHERE valid_until <= NOW() + interval` | `days_ahead`, `department_id` |
| `sop_acknowledgment_report` | Who acknowledged which SOP version | `document_readings` + `documents` | `document_id`, `department_id` |
| `assessment_performance_report` | Pass rates, avg scores, attempts per course | `assessment_attempts` + `question_papers` | `course_id`, `date_range` |
| `esignature_audit_report` | All e-sigs in period (21 CFR §11.400) | `electronic_signatures` + `audit_trails` | `date_range`, `employee_id` |
| `system_access_log_report` | Login/logout/failed attempt log | `user_sessions` + `audit_trails WHERE action LIKE 'auth%'` | `date_range`, `employee_id` |
| `integrity_verification_report` | Audit chain hash verification results | `audit_trails` + `system_alerts WHERE type = 'integrity'` | `date_range` |
| `audit_readiness_report` | Full org compliance snapshot | Aggregate all above | `organization_id`, `as_of_date` |

### 4.2 PDF Template Requirements (21 CFR §11 compliant)

Every generated PDF must contain:
- Organization letterhead (name, address, logo)
- Report title + report number (`{ORG}-RPT-{YYYY}-{SEQ:5}` from numbering_schemes)
- Generated timestamp (TIMESTAMPTZ with timezone)
- Generated by (employee name + ID)
- Page numbers (`Page X of Y`)
- Digital signature block (generated_by e-sig)
- Classification footer (`CONTROLLED DOCUMENT — TRAINING RECORD`)
- SHA-256 hash of report content (stored in `report_executions.file_hash`)

### 4.3 CSV Export

All reports must also produce CSV alongside PDF:
- Same data, tabular format
- UTF-8 BOM for Excel compatibility
- Header row with column names
- Stored at `report_executions.storage_path_csv`

### 4.4 Report scheduling

**File:** `lifecycle_monitor/lib/routes/jobs/report_generation_handler.dart`

Also process `scheduled_reports` where `next_run_at <= NOW()`:
1. Create `report_executions` row with `status = 'queued'`
2. Update `scheduled_reports.next_run_at` based on cron_expression
3. Send generated report to `delivery_method` (email / storage bucket)

---

## PHASE 5 — Certificate Generation Service (Days 10–15)

Currently no service class exists. The `certificates` table rows are created but PDF generation is missing.

### 5.1 Create CertificateService

**Create:** `packages/pharmalearn_shared/lib/src/services/certificate_service.dart`

```dart
class CertificateService {
  /// Called after assessment passes or training completes
  Future<CertificateResult> generateCertificate({
    required String employeeId,
    required String organizationId,
    required String trainingRecordId,
    required String? assessmentAttemptId,
    required String courseId,
    required double? percentageScore,
    required String? grade,
    required String issuedByEmployeeId,
    required String reauthSessionId,  // for e-sig
  });
}
```

Internally:
1. Look up `certificate_templates` for this course (or org default)
2. Fetch employee data, course data, org data
3. Generate `certificate_number` via `generate_next_number(org_id, 'certificate')` RPC
4. Build PDF using `pw.Document()` with template layout
5. Replace placeholders: `{{employee_name}}`, `{{certificate_number}}`, `{{completion_date}}`, `{{expiry_date}}`, `{{course_name}}`, `{{marks}}`, `{{grade}}`
6. Embed QR code pointing to `https://app.pharmalearn.com/verify/{certificate_number}`
7. Compute `file_hash` = SHA-256 of PDF bytes
8. Upload to `pharmalearn-files/certificates/{orgId}/{certificate_number}.pdf`
9. Create e-signature via `EsigService.createEsignature()`
10. Insert `certificates` row
11. Update `training_records.certificate_id`
12. Publish `certificate.issued` event

### 5.2 Add certificate_templates table

**Check schema:** `supabase/schemas/09_compliance/` — if `certificate_templates` doesn't exist, add migration.

**Migration G15 (or G16):**
```sql
CREATE TABLE IF NOT EXISTS certificate_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    layout_json JSONB NOT NULL DEFAULT '{}',
    logo_url TEXT,
    background_url TEXT,
    primary_color TEXT DEFAULT '#1A3A5C',
    font_family TEXT DEFAULT 'Helvetica',
    -- Signature configuration
    signatory_count INTEGER DEFAULT 1 CHECK (signatory_count IN (1, 2)),
    signatory_1_title TEXT DEFAULT 'Training Manager',
    signatory_2_title TEXT,
    -- Validity (months; NULL = never expires)
    default_validity_months INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Seed default template per org
INSERT INTO certificate_templates (organization_id, name, is_default)
SELECT id, 'Default Certificate Template', TRUE FROM organizations
WHERE NOT EXISTS (SELECT 1 FROM certificate_templates WHERE organization_id = organizations.id AND is_default);
```

### 5.3 Wire CertificateService into assessmentSubmitHandler

After `is_passed = true`:
```dart
final cert = await CertificateService(supabase).generateCertificate(...);
```

Wire same logic in:
- `self_learning_complete_handler.dart` (when `assessment_required = false`)
- `ojt_complete_handler.dart`
- `induction_complete_handler.dart`

### 5.4 Public Certificate Verification

**File:** `certify/certificates/routes.dart` — ensure `GET /v1/certify/certificates/verify/:certificateNumber` is public (no auth required).

Handler must return:
```json
{
  "valid": true,
  "certificate_number": "ALFA-CERT-2026-00001",
  "employee_name": "Rahul Kumar",
  "course_name": "GMP Fundamentals",
  "issued_at": "2026-04-26",
  "valid_until": "2027-04-26",
  "issuer": "Alfa Pharmaceuticals Pvt Ltd",
  "verification_hash": "sha256:abc...",
  "status": "active"
}
```

---

## PHASE 6 — Document Control System: Complete Handlers (Days 10–16)

Routes exist. Need to verify every handler is complete.

### 6.1 Verify Document Approval Flow

**File:** `create/documents/document_approve_handler.dart`

Must:
1. Accept body with `reauth_session_id` + `meaning` + optional `comments`
2. Validate approver has `documents.approve` permission
3. Call `EsigService.createEsignature()` with entity_type='document', entity_id, meaning='APPROVE'
4. Insert into `document_approvals` table (level, approver, date, comments, esig_id)
5. Advance workflow: call workflow_engine `POST /internal/workflow/advance-step` OR call `approve_step()` RPC directly
6. If all steps complete: `UPDATE documents SET status = 'effective', effective_from = NOW()`
7. Publish `document.approved` event
8. Return updated document

**File:** `create/documents/document_reject_handler.dart`

Must:
1. E-sig required (rejection is a regulated action that returns to submitter)
2. Update `approval_steps.status = 'rejected'`
3. `UPDATE documents SET status = 'returned'`
4. Notify document owner with rejection reason
5. Publish `document.rejected` event

### 6.2 Document Readings (SOP acknowledgment — URS §5.3)

**File:** `create/documents/document_readings_handler.dart`

`POST /v1/documents/:id/readings` — create reading record

`POST /v1/documents/:id/readings/:readingId/acknowledge` — e-sig acknowledgment

This is a critical 21 CFR requirement: employees must acknowledge reading effective SOPs. The acknowledgment creates an e-signature in `electronic_signatures` table.

Verify handler:
- Inserts into `document_readings` with `employee_id`, `document_version_id`, `read_at`
- Acknowledgment: calls `EsigService.createEsignature()` with meaning='READ_AND_UNDERSTOOD'
- Updates `document_readings.acknowledged_at`, `acknowledged_esig_id`

### 6.3 Controlled Copy Issuance

**File:** `create/documents/document_issue_handler.dart`
- `POST /v1/documents/:id/issue-copy`
- Creates record in `controlled_copies` table (copy number, issued_to, issued_at, location)
- Requires `documents.issue` permission
- Copy must be for effective documents only

If `controlled_copies` table doesn't exist: add to migration G15.

### 6.4 Document Integrity Verification

**File:** `create/documents/document_integrity_handler.dart`
- `GET /v1/documents/:id/integrity`
- Recomputes SHA-256 of document file from Storage
- Compares against stored `documents.file_hash`
- Returns `{ valid: bool, stored_hash, computed_hash, checked_at }`

### 6.5 Document Export

**File:** `create/documents/document_export_handler.dart`
- `GET /v1/documents/:id/export`
- Returns signed URL to PDF in Storage (or generates PDF on-the-fly for HTML documents)

---

## PHASE 7 — Training Session & Attendance: Complete QR + Biometric (Days 12–17)

### 7.1 Session Check-in with QR Token Validation

**File:** `train/sessions/session_checkin_handler.dart`

Complete logic:
```dart
// QR flow
final qrToken = body['qr_token'] as String?;
if (qrToken != null) {
  // Validate HMAC signature
  final parts = qrToken.split('.');
  if (parts.length != 2) throw ValidationException(...);
  
  final payload = utf8.decode(base64Url.decode(parts[0]));
  final parts2 = payload.split('|');
  final tokenSessionId = parts2[0];
  final expiresAt = DateTime.parse(parts2[1]);
  
  if (tokenSessionId != sessionId) throw ValidationException('QR token is for a different session');
  if (DateTime.now().isAfter(expiresAt)) throw ValidationException('QR token has expired');
  
  final expectedSig = Hmac(sha256, utf8.encode(qrSecret)).convert(utf8.encode(parts[0])).toString();
  if (expectedSig != parts[1]) throw ValidationException('Invalid QR token signature');
}

// Biometric flow
final biometricVerified = body['biometric_verified'] as bool? ?? false;
final biometricReference = body['biometric_reference'] as String?;
// Trust client-side biometric result (device-local verification)
// Record biometric_reference for audit trail

// Insert session_attendance
await supabase.from('session_attendance').insert({
  'session_id': sessionId,
  'employee_id': auth.employeeId,
  'check_in_at': now,
  'check_in_method': qrToken != null ? 'qr' : biometricVerified ? 'biometric' : 'manual',
  'biometric_verified': biometricVerified,
  'biometric_reference': biometricReference,
});
```

### 7.2 Session QR Token Generation

**File:** `train/sessions/session_checkin_handler.dart` needs its complement: `session_qr_handler.dart`

```dart
// GET /v1/train/sessions/:id/qr
// Called by trainer to display QR on screen/projector

// Check session is in_progress
// Generate/refresh qr_token if expired
final expiresAt = session['end_time'] ?? DateTime.now().add(Duration(hours: 8));
final payload = base64Url.encode(utf8.encode('$sessionId|${expiresAt.toIso8601String()}'));
final sig = Hmac(sha256, utf8.encode(qrSecret)).convert(utf8.encode(payload)).toString();
final qrToken = '$payload.$sig';

await supabase.from('training_sessions').update({
  'qr_token': qrToken,
  'qr_expires_at': expiresAt.toIso8601String(),
}).eq('id', sessionId);

return ApiResponse.ok({
  'qr_token': qrToken,
  'qr_expires_at': expiresAt.toIso8601String(),
  'session_id': sessionId,
}).toResponse();
```

### 7.3 Attendance Upload (Bulk CSV)

**File:** `train/sessions/session_attendance_handler.dart`

`POST /v1/train/sessions/:id/attendance/upload`

Must:
1. Accept `multipart/form-data` with CSV file
2. Parse CSV: columns `employee_code`, `check_in_time`, `check_out_time`, `status`
3. Look up `employees.employee_number` to get IDs
4. Batch insert `session_attendance` rows
5. Return: `{ processed: N, errors: [{row: N, reason: '...'}] }`

### 7.4 Attendance Correction with Audit Trail

**File:** `train/sessions/session_attendance_handler.dart`

`PATCH /v1/train/sessions/:id/attendance/:employeeId`

Must:
- Require `reason` field (mandatory for corrections per URS)
- Insert correction record into `attendance_corrections` table
- Update `session_attendance` (preserve original values in correction table)
- Log to `audit_trails`

---

## PHASE 8 — SCORM: Complete Runtime (Days 13–18)

### 8.1 scorm_commit_handler — complete CMI persistence

**File:** `create/scorm/` — verify `scormCommitHandler` exists and check its logic

Must:
1. Accept CMI data object from SCORM runtime
2. Validate session token matches `scorm_sessions.id`
3. Merge `cmi_data JSONB` (partial update, not full replace)
4. Update `scorm_sessions.last_activity_at`
5. If `cmi.completion_status = 'completed'` OR `cmi.lesson_status = 'passed'`:
   - Update `scorm_sessions.completion_status = 'completed'`
   - Update `scorm_sessions.score_raw`, `score_percentage`
   - Call `self_learning_complete_handler` logic inline to mark obligation complete
   - If course has assessment_required=false: generate certificate
   - Publish `scorm.completed` event

### 8.2 scorm_launch_handler — generate signed launch URL

**File:** `create/scorm/`

Must:
1. Look up `scorm_packages.launch_url` and `storage_path`
2. Generate signed URL for the SCORM content in Storage (time-limited, 4h)
3. Create or resume `scorm_sessions` row
4. Return `{ launch_url: signedUrl, session_id, cmi_data: existingCmi }`

### 8.3 SCORM Offline Handling

Since SCORM runs in a WebView, CMI commits may queue when offline. The Flutter client buffers them in Hive. The server just needs to accept batched commits:

**Add:** `POST /v1/scorm/:id/batch-commit`
- Accepts array of CMI snapshots with timestamps
- Replays them in order
- Returns final state

### 8.4 scorm_packages missing status column write

**File:** `create/scorm/scorm_upload_handler.dart`

After `ScormService.processPackage()`:
```dart
await supabase.from('scorm_packages').update({
  'status': 'ready',
  'launch_url': manifest.launchUrl,
  'manifest_json': manifest.toJson(),
  'file_name': uploadedFileName,
}).eq('id', packageId);
```

On error:
```dart
await supabase.from('scorm_packages').update({
  'status': 'error',
  'error_message': e.toString(),
}).eq('id', packageId);
```

---

## PHASE 9 — Assessment Auto-Grading & Remedial Engine (Days 16–21)

### 9.1 Auto-Grading Implementation

**File:** `certify/assessments/assessment_submit_handler.dart`

```dart
Future<GradingResult> _autoGrade(
  SupabaseClient supabase,
  String attemptId,
  String questionPaperId,
) async {
  // Load all responses
  final responses = await supabase
      .from('assessment_responses')
      .select('*, questions!inner(question_type, correct_option_ids, max_marks)')
      .eq('attempt_id', attemptId);

  double totalObtained = 0;
  double totalMarks = 0;
  int autoGraded = 0;
  int manualRequired = 0;

  for (final r in responses) {
    final type = r['questions']['question_type'] as String;
    final maxMarks = (r['questions']['max_marks'] as num).toDouble();
    totalMarks += maxMarks;

    if (type == 'essay' || type == 'short_answer') {
      manualRequired++;
      continue; // cannot auto-grade
    }

    // MCQ, true_false, matching
    final correctIds = (r['questions']['correct_option_ids'] as List).cast<String>();
    final selectedIds = (r['selected_option_ids'] as List? ?? []).cast<String>();

    final isCorrect = _setsEqual(correctIds, selectedIds);
    final marks = isCorrect ? maxMarks : 0.0;

    await supabase.from('assessment_responses').update({
      'is_correct': isCorrect,
      'marks_obtained': marks,
      'is_auto_graded': true,
    }).eq('id', r['id']);

    if (isCorrect) totalObtained += marks;
    autoGraded++;
  }

  return GradingResult(totalObtained, totalMarks, autoGraded, manualRequired);
}
```

After auto-grading:
- If `manualRequired > 0`: set `attempt.status = 'in_review'` (queued for grader)
- If all auto-graded: compute `passed = (obtained/total) * 100 >= pass_mark`, set `status = 'graded'`

### 9.2 Manual Grading Handler — complete logic

**File:** `certify/assessments/assessment_grade_handler.dart`

Must:
1. Permission check: `assessments.grade`
2. Accept per-response grades: `[{ response_id, marks_awarded, feedback }]`
3. Validate marks ≤ max_marks per question
4. Update `assessment_responses` rows
5. After grading all manual questions: recompute total, determine pass/fail
6. Update `assessment_attempts.status = 'graded'`, `is_passed`, `percentage`
7. If passed: call `CertificateService.generateCertificate()`
8. If failed and `attempt_number >= max_attempts`: create remedial training

### 9.3 Grade Moderation (10% random review)

**Add to routes:** `GET /v1/certify/assessments/moderation-queue`

Select 10% of recently graded attempts randomly for moderation review. Flag with `requires_moderation = true` on `assessment_attempts`.

**Add:** `POST /v1/certify/assessments/:id/moderate`
- Second reviewer confirms or overrides grades
- If discrepancy > 25%: escalate to QA manager
- Publish `assessment.moderated` event

### 9.4 Remedial Auto-Assignment

**Create:** `packages/pharmalearn_shared/lib/src/services/remedial_service.dart`

```dart
class RemedialService {
  Future<String> createRemedialTraining({
    required String employeeId,
    required String courseId,
    required String failedAttemptId,
    required String organizationId,
  }) async {
    // 1. Look up remedial course configuration for this course
    // 2. Create training_remedials row with lower pass threshold (60%)
    // 3. Assign remedial materials
    // 4. Notify employee + manager
    // 5. Set due date (2 weeks from today, per URS)
    // 6. Return remedial_id
  }
}
```

Wire into `assessmentSubmitHandler` and `assessmentGradeHandler` on failure.

---

## PHASE 10 — Missing Routes: Complete URS Coverage (Days 18–24)

### 10.1 Training Matrix (Curriculum Management)

URS §5.1.9–10: Role-based curriculum auto-assignment

**Create:** `apps/api_server/pharma_learn/api/lib/routes/train/matrix/`

```
GET    /v1/train/matrix                        List training matrices
POST   /v1/train/matrix                        Create matrix (role → courses mapping)
GET    /v1/train/matrix/:id                    Get matrix
PATCH  /v1/train/matrix/:id                    Update matrix
POST   /v1/train/matrix/:id/items             Add course to matrix
DELETE /v1/train/matrix/:id/items/:itemId     Remove course from matrix
POST   /v1/train/matrix/:id/apply             Apply matrix (spawn obligations for all matching employees)
```

Wire to `train/routes.dart`.

### 10.2 Training Assignments (Coordinator creates campaigns)

URS §5.1.3: Coordinator creates assignment campaigns

Obligations route already has `GET /v1/train/obligations`, but missing:

```
POST   /v1/train/assignments                Create assignment campaign (coordinator)
GET    /v1/train/assignments                List campaigns with completion stats
GET    /v1/train/assignments/:id            Campaign detail + per-employee progress
GET    /v1/train/assignments/:id/progress   Per-employee status breakdown
PATCH  /v1/train/assignments/:id/extend     Bulk extend due date
DELETE /v1/train/assignments/:id/cancel     Cancel campaign + notify employees
```

**Create:** `apps/api_server/pharma_learn/api/lib/routes/train/assignments/`

### 10.3 Trainer Management Completeness

**Verify** `create/trainers/` handlers are complete:
- Trainer approval with e-sig
- Trainer certification verification (compare against `training_certifications`)
- Competency validation before trainer can deliver course

**Add:** `GET /v1/trainers/:id/schedule` — trainer's upcoming sessions
**Add:** `GET /v1/trainers/available` — trainers available for a date/time slot

### 10.4 Venue Management Completeness

**Verify** `create/venues/` handlers — add:
- `GET /v1/venues/:id/availability` — check for scheduling conflicts

### 10.5 Category Management (URS §5.1 course categorization)

**File:** `create/categories/routes.dart` — verify it's mounted in `create/routes.dart`

### 10.6 Periodic Reviews Management

**File:** `create/periodic_reviews/routes.dart` — verify handlers exist and mount

Must have:
```
GET    /v1/periodic-reviews                   List review schedules
POST   /v1/periodic-reviews                   Create schedule
GET    /v1/periodic-reviews/:id               Get
PATCH  /v1/periodic-reviews/:id               Update
POST   /v1/periodic-reviews/:id/complete      Mark completed (e-sig)
GET    /v1/periodic-reviews/due               Due for review this month
```

### 10.7 GTP (Global Training Plan) Completeness

**Verify** `create/gtps/routes.dart` and add missing:
- `GET /v1/gtps/:id/progress` — enrollment + completion statistics
- `POST /v1/gtps/:id/enroll` — enroll employees/department/role
- `GET /v1/gtps/:id/enrollments` — list enrolled employees + status

### 10.8 Quality — CAPA Training Integration

When a CAPA is created from a deviation, it should be able to auto-assign training:

**Add to CAPA handler:** after `capaCreateHandler`:
- Check if CAPA has `training_required = true`
- If yes: call `TrainingAssignmentService.createFromCapa(capaId, employeeIds, courseId)`

### 10.9 Change Control Training Integration

When a change control is implemented and approved, affected employees need re-training:

**Add to `changeControlImplementHandler`:**
- Publish `change_control.implemented` event
- lifecycle_monitor picks up event and creates training obligations for affected roles

### 10.10 Employee Onboarding / Bulk Import

**File:** `access/employees/employee_bulk_handler.dart`

Must:
1. Accept CSV or JSON array of employee records
2. Validate all fields (employee_number unique, email unique, role exists, dept exists)
3. Batch create users in GoTrue and `employees` table
4. Auto-assign induction program (query `induction_plans` for their role/dept)
5. Auto-assign mandatory training based on `training_matrix` for their role
6. Send welcome email with login credentials
7. Return `{ created: N, failed: N, errors: [{row: N, reason: '...'}] }`

---

## PHASE 11 — Audit & Integrity: Complete 21 CFR §11 (Days 20–25)

### 11.1 Audit Trail for Every Write Operation

Every handler that modifies data must write to `audit_trails`. Many currently use the DB trigger `track_entity_changes()` — but the trigger doesn't capture the HTTP actor (employee_id from JWT).

**Solution:** Before every INSERT/UPDATE/DELETE, set session variable:
```sql
SET LOCAL app.current_employee_id = '<employeeId>';
```

This is already done via Supabase's `set_config()` in RLS context. Verify all handlers pass `auth.employeeId` correctly.

**Add middleware:** `apps/api_server/pharma_learn/api/lib/middleware/audit_context_middleware.dart`
```dart
Future<Response> auditContextMiddleware(Request req, Handler next) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  // Set session variable so DB triggers can capture actor
  await supabase.rpc('set_config', params: {
    'p_key': 'app.current_employee_id',
    'p_value': auth.employeeId,
  });
  return next(req);
}
```

Wire this into all authenticated routes.

### 11.2 Audit Search — Complete Handler

**File:** `workflow/audit/` — verify `auditSearchHandler` is complete

Must support filters:
- `entity_type`, `entity_id` — for entity-specific audit trail
- `employee_id` — all actions by a person
- `action` — specific action type
- `date_from`, `date_to` — time range
- `page`, `per_page` — pagination

Must return sortable, exportable (CSV) results. This is the primary 21 CFR §11.400 compliance surface.

### 11.3 Audit Export (21 CFR §11 inspectability)

**File:** `workflow/audit/audit_export_handler.dart`

`GET /v1/workflow/audit/:entityType/:entityId/export`

Returns PDF export of full audit trail for a document/course/certificate. Required for FDA inspection readiness.

### 11.4 Integrity Verification Chain

**File:** `certify/integrity/integrity_verify_handler.dart`

`POST /v1/certify/integrity/verify`

Must:
1. Call `verify_audit_hash_chain()` RPC
2. Return per-record verification status
3. Flag any broken chain entries
4. For broken chain: create `system_alerts` with severity CRITICAL

### 11.5 System Alerts Management

**Add routes to workflow domain:**
```
GET /v1/admin/alerts                List system alerts (super_admin only)
PATCH /v1/admin/alerts/:id/resolve  Mark alert resolved
GET /v1/admin/alerts/critical       Critical-only alerts (homepage widget)
```

### 11.6 Data Retention Enforcement (21 CFR record retention)

Verify `process_retention_policies()` RPC correctly:
- Uses `retention_years` (not `retention_days`)
- Archives (does not delete) training records, audit trails
- Never deletes `electronic_signatures` records
- Logs retention action itself to `audit_trails`

---

## PHASE 12 — Notifications & Alerting: Complete System (Days 20–26)

### 12.1 Verify Notifications Table Column Alignment

`notifications` table in G12 migration has: `template_key, title, body, data, category, priority, action_url, entity_type, entity_id, is_read, read_at`

`notificationsListHandler` must query this table with these exact columns.

Check `access/notifications/` handlers align to G12 schema (not an older schema version).

### 12.2 send-notification Edge Function

The Supabase Edge Function at `supabase/functions/send-notification/` is called by lifecycle_monitor and workflow_engine for email delivery.

**Verify** it handles all template keys:
- `cert_expiry_30d`, `cert_expiry_14d`, `cert_expiry_7d`, `cert_expiry_1d`
- `password_expiry_warning`
- `approval_escalation`
- `dead_letter_alert`
- `training_overdue`
- `assessment_passed`, `assessment_failed`
- `document_approved`, `document_rejected`
- `induction_complete`
- `welcome_employee`

### 12.3 Notification Preferences

**File:** `access/notifications/notification_settings_handler.dart`

Must respect `notification_settings` table:
- Per employee preferences (email, in-app, push toggle)
- Per category preferences (training alerts, compliance alerts, system alerts)
- Quiet hours configuration

### 12.4 Real-Time Attendance Feed (Supabase Realtime)

Trainers need live attendance updates during sessions. This is server-side done by Supabase Realtime — no additional API code needed, but the Flutter client must subscribe to:
```
supabase.from('session_attendance').on(SupabaseEventTypes.insert, ...)
```

Document this in API response of `GET /v1/train/sessions/:id` — include `realtime_channel: 'session_attendance'` in response body.

---

## PHASE 13 — Compliance Dashboard: Complete Analytics (Days 22–27)

### 13.1 Compliance Dashboard Handler

**File:** `certify/compliance/compliance_handler.dart`

`GET /v1/certify/compliance/dashboard`

Must return (URS §5.1.18, §5.1.30 graphical pendency):
```json
{
  "summary": {
    "total_employees": 245,
    "fully_compliant": 198,
    "compliance_rate": 80.8,
    "overdue_trainings": 47,
    "expiring_certs_30d": 23,
    "pending_approvals": 12
  },
  "by_department": [
    { "dept_name": "Manufacturing", "compliance_rate": 78.5, "overdue": 15 }
  ],
  "by_training_type": [
    { "type": "GMP", "completion_rate": 92.0 }
  ],
  "trends": [
    { "month": "2026-03", "compliance_rate": 75.0 },
    { "month": "2026-04", "compliance_rate": 80.8 }
  ],
  "at_risk_employees": [
    { "id": "uuid", "name": "...", "overdue_count": 3, "compliance_rate": 40.0 }
  ]
}
```

### 13.2 My Compliance Handler

**File:** `certify/compliance/compliance_handler.dart`

`GET /v1/certify/compliance/my`

Returns for authenticated employee:
```json
{
  "compliance_rate": 85.0,
  "completed_count": 17,
  "overdue_count": 2,
  "pending_count": 5,
  "certificates": [...],
  "upcoming_deadlines": [...],
  "overdue_obligations": [...]
}
```

### 13.3 Me Dashboard Handler

**File:** `train/me/me_dashboard_handler.dart`

URS §5.1.5 — employee to-do list:

```json
{
  "to_do": [
    {
      "id": "uuid",
      "title": "GMP Fundamentals",
      "document_number": "SOP-001",
      "training_type": "e-learning",
      "is_online": true,
      "has_questionnaire": true,
      "due_date": "2026-05-15",
      "status": "assigned",
      "days_until_due": 19
    }
  ],
  "summary": {
    "total": 8,
    "overdue": 1,
    "due_this_week": 2,
    "completed_this_month": 5
  },
  "upcoming_sessions": [...],
  "recent_certificates": [...]
}
```

---

## PHASE 14 — Migration: G15 Complete Missing DDL (Day 1–3, parallel with Phase 0)

Write one comprehensive migration that adds everything not yet in schema:

**File:** `supabase/migrations/20260426_015_g15_complete_ddl.sql`

```sql
-- 1. password_reset_tokens (for Phase 1.3)
CREATE TABLE IF NOT EXISTS password_reset_tokens (...);

-- 2. background_jobs (for Phase 2 lifecycle job audit)
CREATE TABLE IF NOT EXISTS background_jobs (...);

-- 3. certificate_templates (for Phase 5)
CREATE TABLE IF NOT EXISTS certificate_templates (...);

-- 4. controlled_copies (for Phase 6.3 document control)
CREATE TABLE IF NOT EXISTS controlled_copies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id),
    document_version_id UUID REFERENCES document_versions(id),
    copy_number TEXT NOT NULL UNIQUE,
    issued_to UUID NOT NULL REFERENCES employees(id),
    issued_by UUID NOT NULL REFERENCES employees(id),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    location TEXT,
    purpose TEXT,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'returned', 'destroyed')),
    returned_at TIMESTAMPTZ,
    organization_id UUID NOT NULL REFERENCES organizations(id)
);

-- 5. training_remedials (for Phase 9.4)
-- (check if training_remedials or remedial_trainings already exists)

-- 6. workflow_instances (for Phase 3.7)
CREATE TABLE IF NOT EXISTS workflow_instances (...);

-- 7. attendance_corrections audit table
CREATE TABLE IF NOT EXISTS attendance_corrections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_attendance_id UUID NOT NULL,
    corrected_by UUID NOT NULL REFERENCES employees(id),
    reason TEXT NOT NULL,
    original_status TEXT,
    new_status TEXT,
    original_check_in TEXT,
    new_check_in TEXT,
    corrected_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. system_alerts table
CREATE TABLE IF NOT EXISTS system_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES organizations(id),
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    title TEXT NOT NULL,
    description TEXT,
    entity_type TEXT,
    entity_id UUID,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON system_alerts(severity, resolved_at) WHERE resolved_at IS NULL;

-- 9. assessment grade moderation columns on assessment_attempts
ALTER TABLE assessment_attempts
    ADD COLUMN IF NOT EXISTS requires_moderation BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS moderated_by UUID REFERENCES employees(id),
    ADD COLUMN IF NOT EXISTS moderated_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS moderation_notes TEXT;

-- 10. document_readings columns if missing
ALTER TABLE document_readings
    ADD COLUMN IF NOT EXISTS acknowledged_esig_id UUID REFERENCES electronic_signatures(id),
    ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ;

-- 11. RPC: set_config wrapper for audit context middleware
CREATE OR REPLACE FUNCTION set_config(p_key TEXT, p_value TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    PERFORM set_config(p_key, p_value, TRUE);
END;
$$;
```

---

## PHASE 15 — Shared Package: Missing Services (Days 5–15, parallel)

**Target:** `packages/pharmalearn_shared/lib/src/services/`

### Services to Create

| File | Purpose | Used By |
|---|---|---|
| `certificate_service.dart` | PDF generation + e-sig + Storage upload | assessmentSubmitHandler, ojtCompleteHandler, inductionCompleteHandler |
| `remedial_service.dart` | Auto-create remedial training on failure | assessmentSubmitHandler, assessmentGradeHandler |
| `notification_service.dart` | Template-based in-app + email notifications | All domains |
| `compliance_service.dart` | Compliance metric calculation helpers | lifecycle_monitor |
| `training_assignment_service.dart` | Bulk-spawn obligations from campaigns | training_assignments handlers, training_matrix apply |
| `audit_service.dart` | Structured audit trail writes (beyond DB trigger) | High-value actions (esig, approval, certificate) |

### Export all new services in `pharmalearn_shared.dart`

---

## PHASE 16 — pubspec.yaml: Add Missing Packages (Day 1)

**File:** `packages/pharmalearn_shared/pubspec.yaml`

Verify these are present (add if missing):
```yaml
dependencies:
  pdf: ^3.10.8           # Certificate PDF generation
  qr: ^3.0.1             # QR code data generation
  csv: ^6.0.0            # CSV report export
  crypto: ^3.0.3         # HMAC-SHA256 for QR tokens
  archive: ^3.4.0        # SCORM ZIP (already present)
  xml: ^6.5.0            # SCORM manifest (already present)
  mime: ^1.0.4           # MIME type detection for uploads
  intl: ^0.19.0          # Date/number formatting for reports
```

**File:** `apps/api_server/pharma_learn/api/pubspec.yaml`
```yaml
dependencies:
  qr: ^3.0.1             # QR code for session check-in
  crypto: ^3.0.3         # HMAC for QR token signing
```

---

## IMPLEMENTATION SEQUENCE & SCHEDULE

```
Week 1 (Days 1–5):
├── Phase 0: Bug fixes (4h) ← DO FIRST
├── Phase 14: G15 migration (4h) ← parallel
├── Phase 16: pubspec packages (1h) ← parallel
├── Phase 1.1: Assessment handlers (2d)
└── Phase 1.3: Password reset (1d)

Week 2 (Days 6–10):
├── Phase 1.2: Induction module complete (4h)
├── Phase 1.4: Competency admin (4h)
├── Phase 1.5: Session QR (4h)
├── Phase 2: lifecycle_monitor hardening (3d)
└── Phase 7: Session check-in + QR + attendance (2d)

Week 3 (Days 11–15):
├── Phase 3: workflow_engine complete (5d)
├── Phase 5: CertificateService (3d)
└── Phase 15: Shared package services (parallel)

Week 4 (Days 16–20):
├── Phase 4: Report generator all 10 templates (5d)
├── Phase 8: SCORM complete runtime (2d)
└── Phase 9: Auto-grading + remedial engine (3d)

Week 5 (Days 21–25):
├── Phase 6: Document control handlers (3d)
├── Phase 10: Missing routes complete (3d)
├── Phase 11: Audit & integrity (2d)
└── Phase 12: Notifications complete (2d)

Week 6 (Days 26–30):
├── Phase 13: Compliance dashboard (2d)
├── Phase 1.6: Coordinator obligations (2d)
├── Phase 10.1–10.4: Matrix + assignments + trainer (3d)
└── Integration testing + regulatory checklist verification
```

---

## REGULATORY COMPLIANCE CHECKLIST

Every feature below must be verified before production:

### 21 CFR Part 11
- [ ] §11.100: Electronic records are accurate, complete, human-readable, inspectable
- [ ] §11.100: System validates fields before saving (ValidationException on all handlers)
- [ ] §11.200: E-signature includes signer name, date/time, and meaning (context)
- [ ] §11.200: Two-person integrity enforced for certificate revocation (`CHECK confirmed_by != initiated_by`)
- [ ] §11.300: E-signature linked to specific record via `entity_type + entity_id`
- [ ] §11.400: Audit trail captures all creates, modifies, deletes with actor + timestamp
- [ ] §11.400: Audit records are immutable (no UPDATE/DELETE on `audit_trails`)
- [ ] §11.400: Audit trail is searchable and exportable (PDF + CSV)
- [ ] §11.500: System validated — integration test suite covers all 400+ endpoints

### ALCOA+ Principles (per ref/notes.pdf)
- [ ] **A**ttributable: every record linked to `employee_id` who created it
- [ ] **L**egible: all records human-readable; no encoded blobs without decode API
- [ ] **C**ontemporaneous: timestamps use `TIMESTAMPTZ` (server-side, not client)
- [ ] **O**riginal: first record preserved; corrections create new rows (not overwrites)
- [ ] **A**ccurate: validation on all inputs; no default values that mask missing data
- [ ] **+Complete**: no nullable required fields; status flows cover all states
- [ ] **+Consistent**: UTC timestamps everywhere; timezone stored in settings
- [ ] **+Enduring**: retention policy enforced; archive (not delete)
- [ ] **+Available**: backup + RTO ≤ 15 min per URS §4.6.1.9

### GAMP 5 Category 4
- [ ] IQ: Schema migrations are the Installation Qualification record
- [ ] OQ: Integration test suite is the Operational Qualification record
- [ ] PQ: UAT against URS is the Performance Qualification record
- [ ] Change control: all schema changes via numbered migrations with rollback notes

---

## FINAL API SURFACE AFTER ALL PHASES

```
ACCESS:     ~105 endpoints (add password reset routes)
CREATE:     ~120 endpoints (add GTP progress/enroll, trainer schedule)
TRAIN:      ~95 endpoints (add matrix, assignments, QR, coordinator, induction module complete)
CERTIFY:    ~75 endpoints (add grading queue, moderation, competency admin)
WORKFLOW:   ~60 endpoints (add system alerts, return handler)
REPORTS:    ~14 endpoints (add scheduled report run endpoint)
HEALTH:     ~4 endpoints
TOTAL:      ~473 endpoints — 100% URS coverage
```

This is the complete backend and API layer implementation plan. Every phase maps directly to specific files, specific URS clauses, and specific regulatory requirements. Implement phases in sequence within each week, with Phase 0 and Phase 14/16 done on Day 1 before anything else.