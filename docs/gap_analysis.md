Here is the complete gap analysis report:

---

# PharmaLearn LMS — Comprehensive Gap Analysis Report
**Date:** 2026-04-26 | **Analysis Scope:** URS → Schema → API → Shared Packages

---

## Executive Summary

The codebase is **~60% API-complete** with a frozen, compliant schema (232 tables, 13/13 CFR checklist). Core CRUD and auth are production-ready. The main blockers are: lifecycle_monitor and workflow_engine servers are framework-only (0% logic), the Flutter client is skeleton-only, and several critical service classes are missing from the shared package.

---

## A. Complete Route Inventory (~390+ endpoints)

### ACCESS (98 endpoints)
**Auth** — login, refresh, register, logout, profile, MFA (enable/verify/setup/disable), password change, sessions (list/revoke/revoke-all), permissions check, e-sig certificate (upload/list/delete), SSO (login/callback)

**Employees** — list, create, bulk, get, patch, deactivate, credentials reset, unlock, roles (list/assign/remove)

**Roles** — list, create, get, patch, delete

**Groups** — list, get, create, update, delete, members (add/remove)

**Delegations** — list, get, create, update, revoke

**SSO Configs** — list, get, create, update, delete, test

**Biometric** — list, register, login, revoke

**Consent** — policies (list/get/create/update), me, pending, accept, revoke

**Notifications** — list, unread-count, mark-read, mark-all-read, delete, settings (get/patch)

---

### CREATE (113+ endpoints)
**Courses** — list, create, get, patch, **delete** *(new)*, submit, approve, topics (list/add), documents (list/add/remove)

**Question Banks** — list, get, create, update, delete + questions (create/update/delete)

**Question Papers** — list, get, create, update, delete, add/remove questions, publish

**GTPs** — list, create, get, patch, submit, approve, courses (list/add)

**Curricula** — list, get, create, update, add/remove courses, submit, approve

**SCORM** — packages list, upload, get, delete, launch, initialize, commit, progress

**Trainers** — list, get, create, update, delete, approve, certifications, competencies

**Venues** — list, get, create, update, delete

**Config** — password policies, approval matrices (CRUD), numbering schemes, system settings, feature flags, retention policies, validation rules

---

### TRAIN (66+ endpoints)
**Schedules** — list, create, get, update, cancel, submit, approve, reject, assign, enroll/unenroll, enrollments, invitations

**Batches** — list, create, get, update, add-schedule

**Sessions** — list, get, check-in, check-out, attendance (list/mark/correct/upload)

**Invitations** — respond

**OJT** — list, get, tasks list, task-complete *(esig)*, sign-off *(esig)*, complete *(esig)*

**Self-Learning** — start, progress, complete, status

**Me** — dashboard, training-history, **obligations** *(new)*, **certificates** *(new)*

**Induction** — status, modules, module detail, complete *(esig)*

**Obligations** — list, get, waive

---

### CERTIFY (63+ endpoints)
**Assessments** — start, answer, submit, get, history, grade, question analysis

**E-Signatures** — list, get, create, verify, history

**Reauth** — create, validate

**Remedial** — my, list, create, get, start, complete *(esig)*, cancel

**Certificates** — list, get, download, revoke/initiate, revoke/confirm, revoke/cancel, verify (public)

**Compliance** — my, dashboard, employee-detail, summary report, reports (list/run/get/download)

**Competencies** — my, gaps, employee-view

**Waivers** — my, **create** *(new)*, list, get, approve, reject

**Integrity** — verify, status

---

### WORKFLOW (50+ endpoints)
**Approvals** — list, history, get, approve, reject

**Quality** — deviations (list/create/get/patch/capa), CAPAs (list/create/get/patch/close), change controls (list/create/get/patch/implement/close)

**Standard Reasons** — list, create, get, update

**Admin** — events status, dead-letter (list/retry)

**Audit** — entity audit, search, export

**Notifications** — list, read, read-all, preferences

---

### REPORTS (11 endpoints)
Templates (list/get), run, runs (list/status/download), schedules (list/create/get/update/delete)

---

## B. URS Requirements vs Implementation

| Domain | Requirement | Status | Gap |
|---|---|---|---|
| **Auth** | Login, MFA, sessions, lockout, SSO | ✅ | — |
| **Auth** | Password reset (self-service email flow) | ⚠️ PARTIAL | Reset request/token endpoint not in routes |
| **RBAC** | Roles, permissions, JWT embedding, RLS | ✅ | — |
| **Documents** | SOP/WI lifecycle, version control, approval | ⚠️ PARTIAL | Document endpoints exist in schema; dedicated `/v1/documents/` CRUD routes unclear |
| **Training** | Classroom, OJT, self-learning, induction | ✅ | — |
| **Training** | Real-time trainer dashboard (WebSocket) | ⚠️ PARTIAL | Relic WebSocket mentioned; no dashboard routes implemented |
| **Training** | Offline attendance sync | ⚠️ PARTIAL | Hive planned; sync service not implemented |
| **Assessment** | MCQ, T/F, essay; auto-grade | ✅ | — |
| **Assessment** | Manual grading + moderation workflow | ⚠️ PARTIAL | `grading_queue` table exists; dedicated grader list/assign endpoints unclear |
| **Assessment** | Proctoring (tab-switch, copy-paste detection) | ⚠️ PARTIAL | `proctoring_data JSONB` on attempts; detection events must come from client |
| **Certification** | Certificate generation, e-sig, QR verification | ✅ | — |
| **Certification** | PDF rendering with PKI signature | ⚠️ PARTIAL | E-sig records exist; actual PDF generation service missing |
| **Compliance** | Compliance % dashboard, overdue alerts | ✅ | — |
| **Compliance** | Automated escalation notifications | ⚠️ PARTIAL | `lifecycle_monitor` jobs defined but not implemented |
| **Reports** | 10 report types, PDF/Excel export | ⚠️ PARTIAL | Route exists; report generator service not implemented |
| **Workflow** | Multi-step approvals, escalation | ⚠️ PARTIAL | `workflow_engine` server = framework only |
| **SCORM** | SCORM 1.2 upload, launch, CMI tracking | ✅ | — |
| **SCORM** | Score sync to training records | ⚠️ PARTIAL | Schema supports it; sync logic in handler unclear |
| **Notifications** | In-app + email | ✅ | — |
| **Audit** | Immutable audit trail, 21 CFR §11 | ✅ | — |
| **Mobile/Web** | Flutter UI screens | ❌ MISSING | `main.dart` only; no Vyuh screens built |

---

## C. Shared Package Gaps

**Location:** `packages/pharmalearn_shared/lib/`

**Present:** `SupabaseClient`, `RequestContext` (Zone-based), `EventPublisher`, `ApiResponse`, `AuthContext`, `EsigRequest`, `Pagination`, `ReportTemplates`, auth/cors/esig/induction-gate/logger/rate-limit middleware, `EsigService`, `JwtService`, `OutboxService`, `PermissionChecker`, `ResponseBuilder`, `ErrorHandler`

| Missing Service | Used By | Impact |
|---|---|---|
| `ScormService` | scormCommitHandler, scormLaunchHandler | SCORM CMI parsing and launch protocol broken |
| `AssessmentService` | assessmentSubmitHandler, assessmentGradeHandler | Auto-grading accuracy and adaptive selection missing |
| `CertificateService` | certificate generation flow | PDF + QR + PKI signature generation missing |
| `ReportGeneratorService` | reportRunHandler | Report templates cannot render; PDF/Excel export blocked |
| `WorkflowEngineService` | workflow_engine routes | State machine transitions not callable from shared code |
| `OfflineSyncService` | Flutter client | Hive cache + server-wins conflict resolution not built |
| `NotificationService` (templates) | lifecycle_monitor, workflow_engine | Template rendering logic absent |
| `AnalyticsService` | dashboard handlers | Metric aggregation queries not centralized |

---

## D. Schema vs Handler Mismatches

| Handler Reference | Actual Schema Name | Status | Action |
|---|---|---|---|
| `from('waivers')` in waivers_handler.dart | `training_waivers` | ⚠️ TABLE NAME MISMATCH | Handler uses `waivers` — verify if view exists or fix to `training_waivers` |
| `ojt_modules` in me_training_history | `ojt_masters` | ⚠️ MISMATCH | Fix FK join name to `ojt_masters` |
| `self_learning_modules` | `ojt_masters` / courses | ⚠️ UNCLEAR | Verify if `self_learning_modules` is a separate table or `courses` |
| `training_obligations` | `employee_training_obligations` | ⚠️ MISMATCH | Actual table is `employee_training_obligations` |
| `certificate_id` on `ojt_assignments` VIEW | Not in ojt_assignments view columns | ❌ MISSING | Training history handler tries to join `certificate_id` that VIEW doesn't return |
| `periodic_reviews` | `periodic_review_schedules` | ✅ Fixed in G10 | — |
| `retention_days` | `retention_years` | ✅ Fixed in G10 | — |

---

## E. Plan vs Reality Gaps

| Plan Promise | Reality | Gap Level |
|---|---|---|
| Route prefix: flat `/v1/certificates/` | Actual: `/v1/certify/certificates/` | ⚠️ Docs stale (doesn't affect code) |
| `lifecycle_monitor`: job handlers implemented | Framework only — no job logic | ❌ CRITICAL |
| `workflow_engine`: approval state machine | Framework only — no state logic | ❌ CRITICAL |
| Flutter: Vyuh auto-gen screens | `main.dart` only | ❌ CRITICAL |
| `certify/esignatures`, `certify/integrity`, `certify/remedial` mounted | All three mounted ✅ | ✅ |
| `mountTrainRoutes` includes all sub-domains | Now fully mounted ✅ | ✅ |
| Certificate revocation: 3-step flow | 3 endpoints implemented ✅ | ✅ |
| Two-person integrity CHECK constraint | G3 migration added ✅ | ✅ |
| `get_employee_permissions` in auth-hook | G11 migration adds it ✅ | ✅ |

---

## F. Priority Fix List

### CRITICAL (P0 — blocks production)

| # | Gap | Files | Effort |
|---|---|---|---|
| 1 | **lifecycle_monitor job handlers** — compliance metrics, cert expiry alerts, escalation not computed | `lifecycle_monitor/lib/services/` | 3–5 days |
| 2 | **workflow_engine approval state machine** — multi-step approvals never advance; quality workflows blocked | `workflow_engine/lib/routes/internal/` | 5–7 days |
| 3 | **Flutter UI screens** — users have no interface | `lib/` (Vyuh screens) | 10–14 days |
| 4 | **`waivers` → `training_waivers` table name** — existing waivers handlers will 404 at runtime | `certify/waivers/waivers_handler.dart` | 1 hour |
| 5 | **`training_obligations` → `employee_training_obligations`** — me_obligations_handler uses wrong table name | `train/me/me_obligations_handler.dart` | 30 min |
| 6 | **CertificateService (PDF + PKI)** — certificates issued without actual PDF; CFR §11.200 incomplete | New: `packages/pharmalearn_shared/lib/src/services/certificate_service.dart` | 3–4 days |

### HIGH (P1 — major feature gaps)

| # | Gap | Fix |
|---|---|---|
| 7 | **Report generation engine** — `reportRunHandler` exists but renders nothing | Implement `ReportGeneratorService` |
| 8 | **Manual grading endpoints** — essay/short-answer questions ungraded | Add grader-list, assign-grader, submit-grade handlers |
| 9 | **SCORM score sync to training records** | Wire `scorm_sessions.raw_score` → `training_records` on `LMSFinish` |
| 10 | **Password reset self-service flow** | Add `POST /v1/auth/password/reset-request` and `POST /v1/auth/password/reset` |
| 11 | **`ojt_modules` join in training history** | Fix `me_training_history_handler.dart:98` — use `ojt_masters` not `ojt_modules` |
| 12 | **Offline sync service** | Implement Hive cache + sync interceptor in shared package |
| 13 | **Competency admin CRUD** — only read endpoints exist | Add `POST /v1/certify/competencies`, `PATCH /v1/certify/competencies/:id` |

### MEDIUM (P2)

| # | Gap |
|---|---|
| 14 | Proctoring client events (tab-switch, copy-paste) wired to `assessment_activity_log` |
| 15 | Adaptive question selection for assessments |
| 16 | Trainer dashboard WebSocket |
| 17 | `POST /v1/train/induction/modules/:id/complete` (per-module completion) |
| 18 | Document management `/v1/documents/` CRUD routes (if separate from courses) |
| 19 | Escalation SLA timer in workflow_engine |

### LOW (P3)

| # | Gap |
|---|---|
| 20 | Learning paths & gamification |
| 21 | ML-based content recommendations |
| 22 | Real-time analytics streaming |

---

## Summary Scorecard

| Layer | Completeness | Blocker? |
|---|---|---|
| Schema (232 tables) | 100% ✅ | No |
| Migrations (G1–G14) | 100% ✅ | No |
| API routes mounted | ~95% ✅ | No |
| API handler logic | ~60% ⚠️ | Partial |
| Shared package services | ~40% ⚠️ | Yes (PDF, SCORM, reports) |
| lifecycle_monitor jobs | 0% ❌ | Yes (compliance metrics) |
| workflow_engine state machine | 0% ❌ | Yes (approvals) |
| Flutter client screens | 0% ❌ | Yes (no UI) |
| 21 CFR Part 11 compliance | ~80% ⚠️ | PDF signing needed |

**Immediate must-fix before any internal UAT:** items #4 and #5 (wrong table names in handlers written today) — those will throw errors on first request. The rest are phased implementation work.