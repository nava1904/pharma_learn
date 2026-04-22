PharmaLearn — API Layer: Relic Monorepo (flutter_elog Structure)
Context
The PostgreSQL schema (v2, ~232 tables) is frozen and scores 13/13 on the 21 CFR §11 checklist.
This plan replaces the previous Dart Frog multi-server plan. The revised approach uses:

Framework: relic: ^1.2.0 (modern independent Dart server by Serverpod team — NOT Serverpod ORM) — Serverpod ORM is NOT used, Dart Frog is NOT used, Shelf is NOT used
Relic — trie-based router, strongly typed headers, RelicApp() with ..get(), ..post(), ..use() method chaining; path params via Symbols req.pathParameters[#id]; requires Dart ^3.8.0
Structure: apps/api_server/pharma_learn/ with api/ + lifecycle_monitor/ + workflow_engine/ sub-servers, mirroring flutter_elog exactly
Shared package: packages/pharmalearn_shared/
Flutter state management: MobX (flutter_mobx + mobx + mobx_codegen) — NOT Riverpod, NOT BLoC
Apple Principles (from docs/architecture_onpremise.md): Simplicity, Focus, Integration, Attention to Detail, UX First
URS sources: ref/Learn IQ URS.pdf (EE/URS/23/022), ref/Learn IQ _ URS.pdf (Alfa A-SOP-QA-015-01-04-01), ref/notes.pdf (user manual)
All domain plans: docs/access_plan.md, docs/create_plan.md, docs/train_plan.md, docs/certify_plan.md, docs/cross.md, docs/SCORM_SUPPORT.md, docs/API_TOOLS_REFERENCE.md
⚠️ Stale sub-docs: SCORM_SUPPORT.md and API_TOOLS_REFERENCE.md predate the locked stack. SCORM_SUPPORT.md incorrectly states SCORM 2004 support and uses Riverpod examples. API_TOOLS_REFERENCE.md lists excluded frameworks (Dart Frog, Riverpod, BLoC). Treat plan.md as authoritative on all conflicts.
Technology choices — locked
Layer	Choice	Explicitly excluded
API server framework	relic: ^1.2.0	Serverpod ORM, Dart Frog, Shelf, Aqueduct
Flutter state management	mobx + flutter_mobx	Riverpod, BLoC, Provider
DB access (server)	supabase Dart client (service role)	Serverpod ORM, Prisma
Auth	GoTrue JWT (RS256) via dart_jsonwebtoken	Keycloak (allowed as OIDC IdP in sso_configurations only)
Real-time	Supabase Realtime WebSocket	Redis Pub/Sub, RabbitMQ
Background jobs	lifecycle_monitor Relic server + pg_notify	BullMQ, Celery
Event bus	Supabase events_outbox + pg_notify	Redis, Kafka
File storage	Supabase Storage	MinIO
PDF generation	Supabase Edge Function (generates + stores)	Server-side Dart PDF
SCORM version	SCORM 1.2 only	SCORM 2004 sequencing
API gateway	NGINX reverse proxy	Kong
Deployment	Docker Compose (prod) + Makefile (dev)	Kubernetes
Observability	Structured JSON logs + Prometheus /metrics	DataDog, New Relic
Flutter UI auto-gen	Vyuh entity system for config/CRUD screens	Custom code for workflow screens
Push notifications	In-app (Supabase Realtime) + email (send-notification Edge Function)	FCM
Flutter DI	get_it + injectable	Provider, Riverpod
Offline caching	Hive (4 scenarios) with server-wins conflict resolution	SQLite
SCORM CMI delivery	JS bridge (flutter_inappwebview) → Flutter → POST /v1/scorm/:id/commit	Direct fetch from WebView
API versioning	URL versioning /v1/ and /v2/ co-exist in same Relic process	Header versioning
MobX side effects	reaction() in widget initState / dispose	NavigationStore, autorun
Apple Principles applied to API design:

Simplicity — 3 processes (api + lifecycle_monitor + workflow_engine); one consistent response envelope; one Dart everywhere
Focus — 5 route domains (access, create, train, certify, workflow) each doing one thing well
Integration — DB + API + events designed together; events_outbox + pg_notify for cross-domain coordination
Attention to Detail — RFC 7807 errors with actionable messages; every edge case (lockout, reauth expiry, two-person revoke) handled at DB + API layer
UX First — < 100ms API response (p95); consistent {data, meta, error} envelope; self-documenting OpenAPI

Current Implementation Status (2026-04-25)
Layer	Status	Notes
Supabase schema (232 tables)	✅ Frozen	13/13 on 21 CFR §11 checklist
Schema DDL gaps G1–G5	✅ Resolved	Migrations 20260425_001–005
API server (Relic :8080)	✅ Complete	All handlers implemented, phase 2 handlers mounted
lifecycle_monitor (:8086)	✅ Complete	Job scheduler with 10+ cron jobs, pg_notify listener
workflow_engine (:8085)	✅ Complete	Approval state machine with advance/approve/reject handlers
pharmalearn_shared package	✅ Complete	All services, middleware, models, utilities implemented
Flutter client	❌ Skeleton only	main.dart entry point only
Integration tests	⚠️ Partial	4 test files (login, esig, 2-person revoke, assessment, checkin, induction, approval)

Schema Additions (April 2026 Migrations)
Migration File	Gap	Change
20260425_001_g1_session_qr_token.sql	G1	training_sessions.qr_token TEXT UNIQUE + qr_expires_at TIMESTAMPTZ (HMAC-signed per-session QR token)
20260425_002_g2_ojt_task_esig.sql	G2	ojt_task_completion.esignature_id UUID REFERENCES electronic_signatures(id) (per-task e-sig for witness sign-off)
20260425_003_g3_cert_revocation.sql	G3	New certificate_revocation_requests table with CHECK(confirmed_by != initiated_by) (21 CFR two-person integrity)
20260425_004_g4_assessment_review.sql	G4	assessment_attempts.requires_review BOOLEAN DEFAULT false (proctoring flag for suspicious submissions)
20260425_005_g5_compliance_functions.sql	G5	SQL function for lifecycle_monitor compliance metric computation (employees.compliance_percent every 6h)

Confirmed Architectural Decisions (Interview-Grilled)
#	Decision	Choice	Notes
1	Event bus	Supabase + pg_notify only	No Redis, Kafka
2	Server count	3 processes: api :8080, lifecycle_monitor :8086, workflow_engine :8085	
3	SSO	GoTrue primary; Keycloak allowed as OIDC IdP via sso_configurations	
4	File storage	Supabase Storage only	No MinIO
5	PDF generation	Edge Function generates + stores; GET /download returns signed URL	
6	SCORM version	SCORM 1.2 only	No SCORM 2004 sequencing
7	API gateway	NGINX only	No Kong
8	Deployment	Docker Compose (prod) + Makefile (dev: make dev → dart run × 3)	
9	Real-time	Supabase Realtime backbone; Relic WS for proctoring + live trainer dashboard	
10	Observability	Structured JSON logs + Prometheus /metrics on each server	
11	Vyuh	Auto-gen: config tables + list/detail CRUD; Custom: login, e-sig, assessment, check-in, OJT, compliance	
12	Multi-tenancy	RLS for user reads (user-scoped client); service role for admin writes	
13	Password transport	Plain over HTTPS → GoTrue + argon2id server-side	No client-side hashing
14	Token refresh	Supabase auto-refresh + Dio interceptor retry on 401	
15	Push notifications	In-app via Supabase Realtime + email via send-notification Edge Function	No FCM
16	Induction gate	Defense-in-depth: auth_middleware (403) + go_router redirect	
17	E-sig reauth UX	Password asked once per 30-min window (flutter_secure_storage); one reauth per action	
18	Assessment proctoring	Server-side timing + rapid submission detection only	
19	Compliance metrics	Pre-computed employees.compliance_percent by lifecycle_monitor every 6h	
20	Permission caching	JWT claims embed permissions array (auth-hook Edge Function); no per-request DB call	
21	Certificate verify	Minimal public response: name, course, dates, status, org only	No employee ID in response
22	workflow_engine trigger	pg_notify + 5s poll (identical pattern to lifecycle_monitor)	
23	API versioning	URL versioning: /v1/ and /v2/ co-exist; additive-only within a version	
24	MobX side effects	reaction() in widget initState; dispose in dispose()	
25	Vyuh screens breakdown	Auto-gen: config tables, venues, roles, groups, delegations, trainers, question banks, competencies, periodic reviews	Custom: login, MFA, induction, assessment, check-in, document approval, OJT sign-off, cert revoke, compliance dashboard, e-sig dialog
26	auth-hook state	Hook exists with employee_id/org_id/plant_id; ADD permissions array + induction_completed	In supabase/functions/auth-hook/index.ts
27	Local dev setup	make dev → supabase start + 3× dart run; make prod → docker-compose.prod.yml	
28	Notification dispatch	lifecycle_monitor jobs call supabase.functions.invoke('send-notification') directly	Reads mail_event_templates
29	workflow_engine routes	Internal-only: WorkflowListenerService calls its own route handlers; no external exposure	Routes: /internal/workflow/advance-step, /internal/workflow/complete, /health
30	Offline sync conflict	Server-wins: if record exists, cached offline data is discarded (no-op upsert)	
31	SCORM CMI commit	JS bridge (flutter_inappwebview) → LMSCommit() handler → scormStore.commitCmi() → POST /v1/scorm/:id/commit	
32	Build runner / codegen	Single dart run build_runner build --delete-conflicting-outputs; Makefile targets: make codegen, make codegen-watch	
Domain Business Rules (Regulatory & Operational)
These rules are enforced at the API handler layer (not just schema). Each rule references the URS clause that mandates it.

Attendance & Sessions
80% threshold (Alfa §4.3.19): A session_attendance row is counted as ATTENDED only when attendance_percentage ≥ 80. The session_complete_handler computes this after POST /v1/train/sessions/:id/complete. Records below the threshold are marked PARTIAL — they do NOT generate a training_record and do NOT trigger certificate generation.
Attendance correction is immutable (21 CFR §11.10): The session_attendance table must never be PATCHed after check-in. Corrections must INSERT a new row into the attendance_correction table (linking to original_attendance_id) with corrected_by + correction_reason. The session_attendance_mark_handler enforces this — any PATCH to a finalized attendance record returns 409 ImmutableRecordException.
Post-dated attendance (Alfa §4.3.19): Coordinators may mark attendance up to 7 days after session_date. The session_attendance_mark_handler allows back-dated entry but logs the correction in audit_trails. The 7-day window is configurable via system_settings['training.attendance_correction_window_days'].
Overdue Escalation Tiers (Alfa §4.3.3, EE §5.1.30):
  Day 1–7 past due_date: employee_assignments.status → 'overdue'; obligation shows YELLOW flag on dashboard
  Day 8–14: overdue_training_handler sends employee an email notification via send-notification Edge Function
  Day 15–29: notification escalated to employee's direct manager (employees.manager_id)
  Day 30+: notification escalated to plant director (roles.role_level = 'director'); CAPA candidate flagged in quality module
The escalation_level and last_escalation_at columns on employee_assignments track which tier has fired. The overdue_training_handler (runs hourly) checks these and sends only the delta notification.

Training Assignment Rules
Prerequisite chain enforcement (Alfa §4.2.1.25): Before spawning employee_assignments for a course, the training trigger engine checks courses.prerequisite_course_ids JSONB. If any prerequisite is not completed (training_records.overall_status = 'completed') for that employee, the assignment is created with status = 'blocked'. The obligation shows as BLOCKED on the to-do list. When the prerequisite completes (training.completed event), the blocked obligation is automatically unblocked by the lifecycle_monitor unblock_prerequisites job.
course.course_type renewal consequences (EE §5.1.10):
  ONE_TIME: single employee_assignments row; once completed, no re-enrolment unless new SOP version triggers a re-training event.
  PERIODIC: frequency_type (monthly/quarterly/annual) drives recurrence. After completing, the next due_date is computed as completed_at + frequency_interval. lifecycle_monitor creates the next assignment automatically.
  COMPETENCY: completion only counts if competency_score ≥ courses.pass_mark AND the competency attainment is recorded in employee_competencies. Re-assessment required when role competency matrix (role_competencies) is updated.
Matrix-to-obligation sync (EE §5.1.9): When a training_matrix row transitions to status = 'active', a lifecycle_monitor job reads training_matrix_items and bulk-inserts employee_assignments for all employees whose role_id matches. The job is idempotent (ON CONFLICT DO NOTHING). Sync fires on matrix activation AND on new employee role assignment (training_trigger_rules event = 'new_hire' or 'role_change').
Blended sessions (Alfa §4.3.13): For training_schedules.schedule_type = 'blended', completion requires BOTH the ILT component (session_attendance ≥ 80%) AND the WBT component (learning_progress.status = 'completed'). The session_complete_handler checks both conditions before writing training_records. Failure to complete WBT within blended_wbt_deadline_days generates a separate obligation with status = 'overdue'.

Assessment Rules
Timer server-anchored (Q5): assessment_attempts.started_at is set by the server. Client computes deadline = started_at + time_limit_minutes. Server rejects any submit arriving after started_at + time_limit_minutes + 30s (30s grace for network latency only). No pause/resume.
Proctoring thresholds (certify_plan.md): These exact thresholds set requires_review = true on assessment_attempts (G4 migration):
  tab_switch > 3 occurrences
  copy_paste: any occurrence
  rapid_submit: time_taken_seconds < (total_questions × 3)
  focus_loss > 2 occurrences (mobile app backgrounded)
  Flagged attempts enter grading_queue with priority = 'proctoring_review'. They do NOT auto-fail.
Pass mark precedence: question_papers.pass_mark is the authority for assessments. courses.pass_mark is used only when no question_paper is assigned (document-reading acknowledgement courses).

Top-Level Folder Structure
pharma_learn/              ← repo root (supabase/ already exists)
  apps/
    api_server/
      pharma_learn/        ← equivalent to elog/ in flutter_elog
        api/               ← Main API server, port 8080
        lifecycle_monitor/ ← Background jobs, port 8086 (internal)
        workflow_engine/   ← Approval workflow runner, port 8085 (semi-internal)
      sso/                 ← GoTrue / SAML proxy (optional, thin wrapper)
  packages/
    pharmalearn_shared/    ← Shared Dart package (no server)
  supabase/                ← (already exists — frozen)
  ref/                     ← (already exists — PDFs)
  docs/                    ← (already exists — plans)
packages/pharmalearn_shared/
Shared code consumed by all three servers. No HTTP server — pure Dart library.

packages/pharmalearn_shared/
  pubspec.yaml
  lib/
    pharmalearn_shared.dart            ← barrel export
    src/
      client/
        supabase_client.dart           ← Singleton SupabaseClient (service role)
        supabase_user_client.dart      ← User-scoped client (JWT passthrough)
      models/
        api_response.dart              ← {data, meta, error} envelope
        pagination.dart                ← {page, per_page, total, total_pages}
        error_response.dart            ← RFC 7807 Problem Detail
        esig_request.dart              ← {reauth_session_id, meaning, reason, is_first_in_session}
        sort_options.dart
      middleware/
        auth_middleware.dart           ← GoTrue JWKS verify + user_sessions idle-timeout
        audit_middleware.dart          ← Injects audit context; DB triggers do actual writes
        esig_middleware.dart           ← Validates reauth session per 21 CFR §11.200
        rate_limit_middleware.dart     ← api_rate_limits table + in-process token bucket
        cors_middleware.dart
        logger_middleware.dart         ← Structured JSON via `logger`
      services/
        jwt_service.dart               ← GoTrue JWT decode + RS256 verify
        esig_service.dart              ← create_esignature() / validate_reauth_session() RPCs
        outbox_service.dart            ← publish_event() + pg_notify listener
        notification_service.dart      ← Wraps send-notification Edge Function
        file_service.dart              ← Supabase Storage upload/download/signed URL
        password_service.dart          ← validate_credential() RPC wrapper
        scorm_service.dart             ← SCORM package parsing + CMI data handling
      utils/
        response_builder.dart          ← ApiResponse helpers (ok, created, noContent, paginated)
        error_handler.dart             ← Exception → HTTP status + RFC 7807 body
        permission_checker.dart        ← check_permission() RPC wrapper
        constants.dart                 ← Permission names, event types, route prefixes
pubspec.yaml (shared):

name: pharmalearn_shared
version: 1.0.0
environment:
  sdk: ">=3.8.0 <4.0.0"   # relic requires Dart >=3.8
dependencies:
  relic: ^1.2.0            # HTTP framework — replaces shelf entirely
  supabase: ^2.5.0
  dart_jsonwebtoken: ^2.12.1
  crypto: ^3.0.3
  http: ^1.2.1
  logger: ^2.3.0
  uuid: ^4.4.0
  json_annotation: ^4.9.0
  mime: ^1.0.5
dev_dependencies:
  build_runner: ^2.4.9
  json_serializable: ^6.7.1
  lints: ^3.0.0
  test: ^1.25.0
  mocktail: ^1.0.1
apps/api_server/pharma_learn/api/ — Main API Server (port 8080)
Handles ALL domain endpoints. Routes organized into 5 domain modules.

Internal structure
api/
  bin/
    server.dart                       ← Entry point; Pipeline + createRouter()
  lib/
    context/
      request_context.dart            ← AuthContext: userId, employeeId, orgId, plantId, sessionId
      supabase_context.dart           ← DB client injected via Relic middleware
    models/                           ← API-specific models (extends shared models where needed)
      training_dashboard_model.dart
      compliance_report_model.dart
      scorm_launch_model.dart
    routes/
      access/                         ← AUTH, EMPLOYEES, ROLES, RBAC, SSO, BIOMETRIC, CONSENT
        auth/
          login_handler.dart          ← POST /v1/auth/login
          register_handler.dart       ← POST /v1/auth/register
          logout_handler.dart         ← POST /v1/auth/logout
          refresh_handler.dart        ← POST /v1/auth/refresh
          profile_handler.dart        ← GET /v1/auth/profile
          mfa_handler.dart            ← POST /v1/auth/mfa/verify|enable|disable|verify-setup
          biometric_handler.dart      ← POST /v1/auth/biometric/login
          sso_handler.dart            ← GET|POST /v1/auth/sso, POST /v1/auth/sso/login
          password_handler.dart       ← POST /v1/auth/password/change|reset
          esig_cert_handler.dart      ← POST /v1/auth/esig/upload-certificate
          permissions_handler.dart    ← POST /v1/auth/permissions/check
          sessions_handler.dart       ← GET /v1/auth/sessions, POST .../[id]/revoke
          routes.dart
        employees/
          employees_handler.dart      ← GET|POST /v1/access/employees
          employee_bulk_handler.dart  ← POST /v1/access/employees/bulk (Alfa §4.3.6 — CSV/JSON batch import)
          employee_handler.dart       ← GET|PATCH /v1/access/employees/:id
          employee_deactivate_handler.dart ← PATCH /v1/access/employees/:id/deactivate (Alfa §3.1.4 — disable, not delete)
          employee_roles_handler.dart ← GET|POST|DELETE /v1/access/employees/:id/roles
          employee_creds_handler.dart ← POST /v1/access/employees/:id/credentials, .../unlock
          routes.dart
        roles/
          roles_handler.dart          ← GET|POST /v1/access/roles
          role_handler.dart           ← GET|PATCH|DELETE /v1/access/roles/:id
          routes.dart
        groups/
          groups_handler.dart         ← GET|POST /v1/access/groups
          group_handler.dart          ← GET|PATCH /v1/access/groups/:id
          group_members_handler.dart  ← GET|POST /v1/access/groups/:id/members
          routes.dart
        delegations/
          delegations_handler.dart    ← GET|POST /v1/access/delegations (Alfa §4.4.6 — unplanned leave delegation)
          delegation_handler.dart     ← GET /v1/access/delegations/:id
          delegation_revoke_handler.dart ← POST /v1/access/delegations/:id/revoke
          routes.dart
        sso/
          sso_configs_handler.dart    ← GET|POST /v1/access/sso/configurations
          sso_config_handler.dart     ← GET|PATCH /v1/access/sso/configurations/:id
          sso_test_handler.dart       ← POST /v1/access/sso/configurations/:id/test
          routes.dart
        biometric/
          biometric_register_handler.dart ← POST /v1/biometric/register
          biometric_verify_handler.dart   ← POST /v1/biometric/verify
          routes.dart
        consent/
          consent_handler.dart        ← GET|POST /v1/consent
          consent_withdraw_handler.dart ← POST /v1/consent/[id]/withdraw
          routes.dart
        routes.dart                   ← Access domain aggregator
      create/                         ← DOCUMENTS, COURSES, GTPS, QUESTION BANKS, CONFIG
        documents/
          documents_handler.dart      ← GET|POST /v1/documents
          document_handler.dart       ← GET|PATCH /v1/documents/[id]
          document_delete_handler.dart ← DELETE /v1/documents/[id] (draft status only; non-draft returns 409; create_plan.md §document-delete)
          document_submit_handler.dart   ← POST /v1/documents/[id]/submit
          document_approve_handler.dart  ← POST /v1/documents/[id]/approve [esig]
          document_reject_handler.dart   ← POST /v1/documents/[id]/reject [esig]
          document_versions_handler.dart ← GET /v1/documents/[id]/versions
          document_readings_handler.dart ← GET|POST /v1/documents/[id]/readings
          document_reading_ack_handler.dart ← POST .../readings/[id]/acknowledge [esig]
          document_integrity_handler.dart   ← GET /v1/documents/[id]/integrity
          document_issue_handler.dart       ← POST /v1/documents/[id]/issue-copy
          document_export_handler.dart      ← GET /v1/create/documents/[id]/export (PDF: document + esig history; 21 CFR §11.10(b) printable format)
          routes.dart
        courses/
          courses_handler.dart        ← GET|POST /v1/courses
          course_handler.dart         ← GET|PATCH /v1/courses/[id]
          course_submit_handler.dart  ← POST /v1/courses/[id]/submit
          course_approve_handler.dart ← POST /v1/courses/[id]/approve [esig]
          course_topics_handler.dart  ← GET|POST /v1/courses/[id]/topics
          course_documents_handler.dart ← GET|POST /v1/courses/[id]/documents (course_documents join table; links supplementary docs to course; create_plan.md §course-documents)
          routes.dart
        gtps/
          gtps_handler.dart           ← GET|POST /v1/gtps
          gtp_handler.dart            ← GET|PATCH /v1/gtps/[id]
          gtp_submit_handler.dart     ← POST /v1/gtps/[id]/submit
          gtp_approve_handler.dart    ← POST /v1/gtps/[id]/approve [esig]
          gtp_courses_handler.dart    ← GET|POST /v1/gtps/[id]/courses
          routes.dart
        question_banks/
          question_banks_handler.dart ← GET|POST /v1/question-banks
          question_bank_handler.dart  ← GET|PATCH /v1/question-banks/[id]
          questions_handler.dart      ← GET|POST /v1/questions
          question_handler.dart       ← GET|PATCH|DELETE /v1/questions/[id]
          routes.dart
        question_papers/
          question_papers_handler.dart  ← GET|POST /v1/question-papers
          question_paper_handler.dart   ← GET|PATCH /v1/question-papers/[id]
          question_paper_publish_handler.dart ← POST /v1/question-papers/[id]/publish [esig]
          question_paper_items_handler.dart   ← GET|POST /v1/question-papers/[id]/items
          routes.dart
        trainers/
          trainers_handler.dart       ← GET|POST /v1/trainers
          trainer_handler.dart        ← GET|PATCH /v1/trainers/[id]
          trainer_approve_handler.dart ← POST /v1/trainers/[id]/approve [esig]
          trainer_certs_handler.dart  ← GET|POST /v1/trainers/[id]/certifications
          routes.dart
        venues/
          venues_handler.dart         ← GET|POST /v1/venues
          venue_handler.dart          ← GET|PATCH /v1/venues/[id]
          routes.dart
        curricula/
          curricula_handler.dart      ← GET|POST /v1/curricula
          curriculum_handler.dart     ← GET|PATCH /v1/curricula/[id]
          curriculum_publish_handler.dart ← POST /v1/curricula/[id]/publish [esig]
          curriculum_items_handler.dart   ← GET|POST /v1/curricula/[id]/items
          routes.dart
        scorm/
          scorm_packages_handler.dart ← POST /v1/scorm/packages (upload)
          scorm_launch_handler.dart   ← GET /v1/scorm/[id]/launch
          scorm_initialize_handler.dart ← POST /v1/scorm/[id]/initialize
          scorm_commit_handler.dart   ← POST /v1/scorm/[id]/commit (CMI data)
          scorm_progress_handler.dart ← GET /v1/scorm/[id]/progress
          routes.dart
        periodic_reviews/
          periodic_reviews_handler.dart ← GET|POST /v1/periodic-reviews
          periodic_review_handler.dart  ← GET /v1/periodic-reviews/[id]
          periodic_review_complete_handler.dart ← POST /v1/periodic-reviews/[id]/complete [esig]
          routes.dart
        config/
          approval_matrices_handler.dart ← GET|POST /v1/config/approval-matrices
          approval_matrix_handler.dart   ← GET|PATCH /v1/config/approval-matrices/[id]
          numbering_schemes_handler.dart ← GET|POST /v1/config/numbering-schemes
          numbering_next_handler.dart    ← POST /v1/config/numbering-schemes/[id]/next
          retention_policies_handler.dart ← GET|POST /v1/config/retention-policies
          system_settings_handler.dart   ← GET|POST|PUT /v1/config/system-settings [esig for critical]
          feature_flags_handler.dart     ← GET|PUT /v1/config/feature-flags
          validation_rules_handler.dart  ← GET|POST /v1/config/validation-rules
          password_policies_handler.dart ← GET|PATCH /v1/config/password-policies
          routes.dart
        categories/
          categories_handler.dart     ← GET|POST /v1/categories
          category_handler.dart       ← GET|PATCH /v1/categories/[id]
          routes.dart
        routes.dart                   ← Create domain aggregator
      train/                          ← SCHEDULES, SESSIONS, OJT, INDUCTION, SELF-LEARNING
        schedules/
          schedules_handler.dart      ← GET|POST /v1/train/schedules
          schedule_handler.dart       ← GET|PATCH /v1/train/schedules/:id
          schedule_submit_handler.dart   ← POST /v1/train/schedules/:id/submit
          schedule_approve_handler.dart  ← POST /v1/train/schedules/:id/approve [esig]
          schedule_assign_handler.dart   ← POST /v1/train/schedules/:id/assign (bulk TNI)
          schedule_enroll_handler.dart   ← POST /v1/train/schedules/:id/enroll
          schedule_sessions_handler.dart ← GET|POST /v1/train/schedules/:id/sessions
          schedule_invitations_handler.dart ← GET|POST /v1/train/schedules/:id/invitations
          schedule_batches_handler.dart  ← GET|POST /v1/train/schedules/:id/batches
          routes.dart
        sessions/
          sessions_handler.dart       ← GET /v1/train/sessions
          session_handler.dart        ← GET|PATCH /v1/train/sessions/:id
          session_checkin_handler.dart   ← POST /v1/train/sessions/:id/check-in (QR token or biometric; backed by G1 qr_token column)
          session_checkout_handler.dart  ← POST /v1/train/sessions/:id/check-out
          session_attendance_handler.dart ← GET /v1/train/sessions/:id/attendance
          session_attendance_mark_handler.dart ← PATCH /v1/train/sessions/:id/attendance/:empId (post-dated entry; corrections INSERT into attendance_correction table — NOT PATCH existing row; 21 CFR §11.10 immutability)
          attendance_correction_handler.dart   ← POST /v1/train/sessions/:id/attendance/:empId/correct (creates attendance_correction row with original_attendance_id + corrected_by + reason)
          session_attendance_bulk_handler.dart ← POST /v1/train/sessions/:id/mark-attendance
          session_attendance_upload_handler.dart ← POST /v1/train/sessions/:id/attendance/upload (scanned sheet upload, Alfa §4.3.19)
          session_complete_handler.dart  ← POST /v1/train/sessions/:id/complete [esig]
          routes.dart
        obligations/
          obligations_handler.dart    ← GET|POST /v1/train/obligations
          obligation_handler.dart     ← GET /v1/train/obligations/:id
          obligation_waive_handler.dart ← POST /v1/train/obligations/:id/waive [esig]
          routes.dart
        induction/
          induction_handler.dart      ← GET /v1/train/induction (my status)
          induction_items_handler.dart ← GET /v1/train/induction/:programId/items
          induction_item_complete_handler.dart ← POST /v1/train/induction/:programId/items/:itemId/complete
          induction_complete_handler.dart ← POST /v1/train/induction/complete [esig]
          routes.dart
        ojt/
          ojt_handler.dart            ← GET|POST /v1/train/ojt
          ojt_detail_handler.dart     ← GET /v1/train/ojt/:id
          ojt_items_handler.dart      ← GET /v1/train/ojt/:id/items
          ojt_signoff_handler.dart    ← POST /v1/train/ojt/:id/sign-off [esig; backed by G2 ojt_task_completion.esignature_id]
          ojt_complete_handler.dart   ← POST /v1/train/ojt/:id/complete [esig]
          routes.dart
        self_learning/
          self_learning_handler.dart  ← GET /v1/train/self-learning
          self_learning_assign_handler.dart ← POST /v1/train/self-learning/assign
          self_learning_progress_handler.dart ← GET|POST /v1/train/self-learning/:id/progress
          self_learning_complete_handler.dart ← POST /v1/train/self-learning/:id/complete
          routes.dart
        coordinators/
          coordinators_handler.dart   ← GET|POST /v1/train/coordinators (✅ implemented and mounted)
          coordinator_handler.dart    ← GET|PATCH /v1/train/coordinators/:id
          coordinator_deactivate_handler.dart ← POST /v1/train/coordinators/:id/deactivate
          routes.dart
        me/
          me_dashboard_handler.dart   ← GET /v1/train/me/dashboard (graphical progress, EE §5.1.7)
          me_obligations_handler.dart ← GET /v1/train/me/obligations
          me_sessions_handler.dart    ← GET /v1/train/me/sessions
          me_certificates_handler.dart ← GET /v1/train/me/certificates
          me_training_history_handler.dart ← GET /v1/train/me/training-history (EE §5.1.23 full history, distinct from certificates)
          routes.dart
        compliance_report_handler.dart ← GET /v1/train/compliance-report (dept/plant view, Alfa §4.3.3)
        triggers_handler.dart          ← POST /v1/train/triggers/process (SOP update → re-enroll; ✅ implemented and mounted)
        routes.dart                   ← Train domain aggregator
      certify/                        ← ASSESSMENTS, CERTIFICATES, COMPLIANCE, E-SIGNATURES
        assessments/
          assessment_start_handler.dart    ← POST /v1/certify/assessments/start
          assessment_handler.dart          ← GET /v1/certify/assessments/:id
          assessment_answer_handler.dart   ← POST /v1/certify/assessments/:id/answer
          assessment_submit_handler.dart   ← POST /v1/certify/assessments/:id/submit [esig; server validates time_limit_minutes via started_at + 30s grace]
          assessment_progress_handler.dart ← GET /v1/certify/assessments/:id/progress
          assessment_results_handler.dart  ← GET /v1/certify/assessments/:id/results
          assessment_publish_handler.dart  ← POST /v1/certify/assessments/:id/publish-results [esig]
          assessment_grade_handler.dart    ← POST /v1/certify/assessments/:id/grade (manual grading by evaluator; for open-ended / short-answer questions; certify_plan.md §grading-queue)
          assessment_question_analysis_handler.dart ← GET /v1/certify/assessments/:id/question-analysis (missed-questions per question, wrong-answer distribution; URS §4.2.1.19)
          routes.dart
        analytics/
          course_analytics_handler.dart   ← GET /v1/certify/analytics/courses/:id (pass-rate trend, completion rate over time; certify_plan.md §analytics)
          question_stats_handler.dart     ← GET /v1/certify/analytics/questions/:id (discrimination index, difficulty index; certify_plan.md §item-analysis)
          routes.dart
        certificates/
          certificates_handler.dart   ← GET /v1/certify/certificates
          certificate_handler.dart    ← GET /v1/certify/certificates/:id
          certificate_verify_handler.dart ← GET /v1/certify/certificates/verify/:certificateNumber (public, no auth)
          certificate_revoke_initiate_handler.dart ← POST /v1/certify/certificates/:id/revoke/initiate [esig, step 1]
          certificate_revoke_confirm_handler.dart  ← POST /v1/certify/certificates/:id/revoke/confirm [esig, different employee — DB CHECK(confirmed_by != initiated_by)]
          certificate_revoke_cancel_handler.dart   ← POST /v1/certify/certificates/:id/revoke/cancel [no esig — withdrawal; audit_trails log only]
          certificate_download_handler.dart ← GET /v1/certify/certificates/:id/download (PDF signed URL)
          routes.dart
          -- Backed by: certificate_revocation_requests table (migration 20260425_003_g3_cert_revocation.sql)
        remedial/
          remedial_handler.dart       ← GET|POST /v1/certify/remedial (✅ implemented and mounted)
          remedial_complete_handler.dart ← POST /v1/certify/remedial/:id/complete
          routes.dart
        competencies/
          competencies_handler.dart   ← GET|POST /v1/certify/competencies
          competency_handler.dart     ← GET|PATCH /v1/certify/competencies/:id
          competency_assess_handler.dart ← POST /v1/certify/competencies/:id/assess
          routes.dart
        waivers/
          waivers_handler.dart        ← GET|POST /v1/certify/waivers
          waiver_handler.dart         ← GET /v1/certify/waivers/:id
          waiver_approve_handler.dart ← POST /v1/certify/waivers/:id/approve [esig]
          waiver_reject_handler.dart  ← POST /v1/certify/waivers/:id/reject
          routes.dart
        esignatures/
          esig_create_handler.dart    ← POST /v1/certify/esignatures/create [esig reauth] (✅ implemented and mounted)
          esig_verify_handler.dart    ← POST /v1/certify/esignatures/verify
          esig_entity_handler.dart    ← GET /v1/certify/esignatures/:entityType/:entityId
          routes.dart
        reauth/
          reauth_create_handler.dart  ← POST /v1/certify/reauth/create (get reauth_session_id, 30 min TTL)
          reauth_validate_handler.dart ← POST /v1/certify/reauth/validate
          routes.dart
        integrity/
          integrity_verify_handler.dart ← POST /v1/certify/integrity/verify (hash chain, admin only) (✅ implemented and mounted)
          routes.dart
        compliance/
          compliance_dashboard_handler.dart ← GET /v1/certify/compliance/dashboard
          compliance_certs_handler.dart     ← GET /v1/certify/compliance/certificates
          compliance_overdue_handler.dart   ← GET /v1/certify/compliance/overdue
          compliance_reports_handler.dart   ← GET|POST /v1/certify/compliance/reports
          compliance_report_run_handler.dart ← POST /v1/certify/compliance/reports/:id/run
          compliance_report_download_handler.dart ← GET /v1/compliance/reports/[id]/download
          routes.dart
        integrity/
          integrity_verify_handler.dart ← POST /v1/integrity/verify (hash chain, admin only)
          routes.dart
        routes.dart                   ← Certify domain aggregator
      workflow/                       ← APPROVALS, NOTIFICATIONS, AUDIT TRAIL, QUALITY
        approvals/
          approvals_pending_handler.dart  ← GET /v1/approvals/pending
          approval_handler.dart           ← GET /v1/approvals/[id]
          approval_approve_handler.dart   ← POST /v1/approvals/[id]/approve [esig]
          approval_reject_handler.dart    ← POST /v1/approvals/[id]/reject [esig]
          approval_return_handler.dart    ← POST /v1/approvals/[id]/return
          approvals_history_handler.dart  ← GET /v1/approvals/history
          routes.dart
        notifications/
          notifications_handler.dart     ← GET /v1/notifications
          notification_read_handler.dart ← POST /v1/notifications/[id]/read
          notifications_read_all_handler.dart ← POST /v1/notifications/read-all
          notification_prefs_handler.dart ← GET|PATCH /v1/notifications/preferences
          routes.dart
        standard_reasons/
          standard_reasons_handler.dart  ← GET|POST /v1/standard-reasons
          standard_reason_handler.dart   ← GET|PATCH /v1/standard-reasons/[id]
          routes.dart
        audit/
          audit_entity_handler.dart      ← GET /v1/audit/[entityType]/[entityId]
          audit_search_handler.dart      ← GET /v1/audit/search
          audit_export_handler.dart      ← GET /v1/workflow/audit/[entityType]/[entityId]/export (CSV/PDF; 21 CFR §11.10(b) inspection readiness)
          routes.dart
        quality/
          deviations_handler.dart        ← GET|POST /v1/quality/deviations
          deviation_handler.dart         ← GET|PATCH /v1/quality/deviations/[id]
          deviation_capa_handler.dart    ← POST /v1/quality/deviations/[id]/capa
          capas_handler.dart             ← GET|POST /v1/quality/capas
          capa_handler.dart              ← GET|PATCH /v1/quality/capas/[id]
          capa_close_handler.dart        ← POST /v1/quality/capas/[id]/close [esig]
          change_controls_handler.dart   ← GET|POST /v1/quality/change-controls
          change_control_handler.dart    ← GET|PATCH /v1/quality/change-controls/[id]
          change_control_submit_handler.dart ← POST /v1/quality/change-controls/[id]/submit
          routes.dart
        admin/
          admin_events_status_handler.dart ← GET /v1/admin/events/status (pending_count, dead_letter_count, avg_latency_ms, oldest_pending_age_s; operations monitoring without direct DB)
          routes.dart
        routes.dart                   ← Workflow domain aggregator
      health/
        health_handler.dart           ← GET /health (liveness)
        health_detailed_handler.dart  ← GET /health/detailed (readiness + DB ping)
        routes.dart
      routes.dart                     ← Master router: mounts all 5 domain routers + health
    services/
      scorm_parser_service.dart       ← SCORM zip extraction + manifest parsing
      pdf_service.dart                ← Certificate PDF generation (calls Edge Function)
      realtime_service.dart           ← Supabase Realtime channel subscriptions
    utils/
      param_helpers.dart              ← Path param extraction + UUID validation
      query_parser.dart               ← Pagination/filter query param parsing
    pharma_learn_api.dart             ← createPipeline(), createRouter(), startServer()
  test/
    access/
      login_test.dart
      esig_flow_test.dart
    certify/
      two_person_revoke_test.dart
      assessment_flow_test.dart
    train/
      checkin_test.dart
      induction_gate_test.dart
    workflow/
      approval_chain_test.dart
  pubspec.yaml
  analysis_options.yaml
  .env.local                          ← local dev overrides (gitignored)
  env-vars.yaml                       ← documented env var schema
pubspec.yaml (api):

name: pharma_learn_api
version: 1.0.0
environment:
  sdk: ">=3.8.0 <4.0.0"   # relic requires Dart >=3.8
dependencies:
  pharmalearn_shared:
    path: ../../../../packages/pharmalearn_shared
  relic: ^1.2.0            # HTTP framework
  supabase: ^2.5.0
  dart_jsonwebtoken: ^2.12.1
  archive: ^3.4.0           # SCORM zip extraction
  xml: ^6.5.0               # SCORM manifest parsing
  logger: ^2.3.0
  uuid: ^4.4.0
  http: ^1.2.1
  mime: ^1.0.5
dev_dependencies:
  lints: ^3.0.0
  test: ^1.25.0
  mocktail: ^1.0.1
apps/api_server/pharma_learn/lifecycle_monitor/ (port 8086, internal)
Runs cron-triggered jobs and pg_listen event fanout.

lifecycle_monitor/
  bin/server.dart
  lib/
    routes/
      jobs/
        archive_job_handler.dart        ← POST /jobs/archive (retention policy)
        integrity_check_handler.dart    ← POST /jobs/integrity-check (verify_audit_hash_chain())
        cert_expiry_handler.dart        ← POST /jobs/cert-expiry (scan + notify)
        overdue_training_handler.dart   ← POST /jobs/overdue-training (flag + escalate)
        periodic_review_handler.dart    ← POST /jobs/periodic-review (mark_overdue_reviews())
        events_fanout_handler.dart      ← POST /jobs/events (outbox poll + delivery)
        password_expiry_handler.dart    ← POST /jobs/password-expiry
        session_cleanup_handler.dart    ← POST /jobs/session-cleanup (expire idle sessions)
        compliance_metrics_handler.dart ← POST /jobs/compliance-metrics
        routes.dart
      health_handler.dart               ← GET /health
      routes.dart
    services/
      pg_listener_service.dart          ← pg_notify subscriber on 'events_outbox' channel
      event_fanout_service.dart         ← Routes events to downstream API endpoints
      job_scheduler_service.dart        ← Polls pending cron triggers
    lifecycle_monitor.dart
  pubspec.yaml
Middleware Pipeline (per request in api/)
Order: Logger → CORS → Supabase-inject → Auth → RateLimit → [EsigCheck if route requires] → Handler

Relic uses app.use('/', middleware) for global middleware and the Middleware typedef (Handler Function(Handler)) identical to Shelf's pattern, making the middleware logic portable.

// pharma_learn_api.dart  — server setup with Relic
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

RelicApp createApp() {
  final app = RelicApp();

  // Global middleware (order matters)
  app
    ..use('/', loggerMiddleware())
    ..use('/', corsMiddleware())
    ..use('/', supabaseProviderMiddleware())   // injects SupabaseClient into request context
    ..use('/', authMiddleware())               // excludes /health and login paths internally
    ..use('/', rateLimitMiddleware());

  // Mount domain routers
  mountAccessRoutes(app);
  mountCreateRoutes(app);
  mountTrainRoutes(app);
  mountCertifyRoutes(app);
  mountWorkflowRoutes(app);
  mountHealthRoutes(app);

  // 404 fallback
  app.fallback = respondWith(
    (_) => Response.notFound(body: Body.fromString('{"error":"Route not found"}'),
                             headers: Headers.response(contentType: ContentType.json)),
  );

  return app;
}

// Entry point
Future<void> main() async {
  final app = createApp();
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  await app.serve(port: port);
  print('PharmaLearn API running on :$port');
}
// routes/access/routes.dart — domain router mount
void mountAccessRoutes(RelicApp app) {
  app
    ..post('/v1/auth/login',            loginHandler)
    ..post('/v1/auth/logout',           logoutHandler)
    ..post('/v1/auth/refresh',          refreshHandler)
    ..get( '/v1/auth/profile',          profileHandler)
    ..post('/v1/auth/mfa/verify',       mfaVerifyHandler)
    ..post('/v1/auth/biometric/login',  biometricLoginHandler)
    ..post('/v1/auth/sso/login',        ssoLoginHandler)
    ..post('/v1/auth/password/change',  passwordChangeHandler)
    ..post('/v1/auth/permissions/check',permissionsCheckHandler)
    ..get( '/v1/auth/sessions',         sessionsHandler)
    ..get( '/v1/employees',             employeesListHandler)
    ..post('/v1/employees',             employeesCreateHandler)
    ..get( '/v1/employees/:id',         employeeGetHandler)
    ..patch('/v1/employees/:id',        employeePatchHandler);
    // ... remaining access routes
}
// Handler — path param access with Relic symbols
Future<Response> employeeGetHandler(Request req) async {
  final id       = req.pathParameters[#id]!;   // symbol-based, not string
  final supabase = req.context['supabase'] as SupabaseClient;
  // ...
}
auth_middleware.dart — 5 steps (Relic Middleware = Handler Function(Handler)):
Extract Authorization: Bearer <jwt>
Verify RS256 via GoTrue JWKS; skip for public paths (/health, /v1/auth/login, etc.)
Load user_sessions row by jwt_id (jti claim); check revoked_at IS NULL AND expires_at > NOW()
Idle-timeout: if last_activity_at < NOW() - idle_timeout_seconds → call revoke_user_session() RPC → 401 SESSION_TIMEOUT
Update last_activity_at = NOW() + inject AuthContext into req.context['auth']
esig_middleware.dart — per-route wrap (not global):
Read body JSON and cache in req.context['body'] (body can only be read once in Relic)
Extract e_signature.reauth_session_id from cached body OR Authorization-Reauth header
Call validate_reauth_session(reauth_id) RPC
Verify is_first_in_session — if TRUE require both password+identifier (§11.200(a)); if FALSE password only
Inject EsigContext into req.context['esig']
error_handler.dart — RFC 7807 mapping (Relic fallback error handler):
Exception	HTTP	type
PermissionDeniedException	403	/errors/permission-denied
NotFoundException	404	/errors/not-found
ValidationException	422	/errors/validation
EsigRequiredException	428	/errors/esig-required
ImmutableRecordException	409	/errors/immutable-record
AccountLockedException	423	/errors/account-locked
SessionTimeoutException	401	/errors/session-timeout
InductionGateException	403	/errors/induction-required
Handler Pattern (every *_handler.dart follows this)
// routes/access/auth/login_handler.dart
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

// Relic handler signature: (Request) → Future<Response>
Future<Response> loginHandler(Request req) async {
  final body     = await readJson(req);           // reads body once, caches result
  final email    = requireString(body, 'email');
  final pwHash   = requireString(body, 'password_hash');
  final supabase = req.context['supabase'] as SupabaseClient;  // injected by middleware

  // 1. Validate credential via DB RPC (handles lockout + failed_attempts)
  final valid = await supabase.rpc('validate_credential', params: {
    'p_input_hash': pwHash,
    'p_policy_threshold': 5,
  }) as bool;
  if (!valid) throw AuthException('Invalid credentials or account locked');

  // 2. Sign in via GoTrue → get JWT
  final session = await supabase.auth.signInWithPassword(email: email, password: pwHash);

  // 3. Publish domain event to events_outbox
  await supabase.rpc('publish_event', params: {
    'p_aggregate_type': 'auth',
    'p_aggregate_id': session.user!.id,
    'p_event_type': 'auth.login',
    'p_payload': jsonEncode({'ip': req.headers.value('x-forwarded-for') ?? 'unknown'}),
  });

  return ApiResponse.ok({'session': session.session, 'user': session.user}).toResponse();
}
// routes/access/routes.dart — access domain mount function (no Router class needed)
import 'package:relic/relic.dart';
import 'auth/login_handler.dart';
// ... other imports

void mountAccessRoutes(RelicApp app) {
  app
    ..post('/v1/auth/login',             loginHandler)
    ..post('/v1/auth/logout',            logoutHandler)
    ..post('/v1/auth/refresh',           refreshHandler)
    ..get( '/v1/auth/profile',           profileHandler)
    ..post('/v1/auth/mfa/verify',        mfaVerifyHandler)
    ..post('/v1/auth/mfa/enable',        mfaEnableHandler)
    ..post('/v1/auth/biometric/login',   biometricLoginHandler)
    ..post('/v1/auth/sso/login',         ssoLoginHandler)
    ..post('/v1/auth/password/change',   passwordChangeHandler)
    ..post('/v1/auth/permissions/check', permissionsCheckHandler)
    ..get( '/v1/auth/sessions',          sessionsListHandler)
    ..post('/v1/auth/sessions/:id/revoke', sessionRevokeHandler)
    ..get( '/v1/employees',              employeesListHandler)
    ..post('/v1/employees',              employeesCreateHandler)
    ..get( '/v1/employees/:id',          employeeGetHandler)
    ..patch('/v1/employees/:id',         employeePatchHandler)
    ..get( '/v1/roles',                  rolesListHandler)
    ..post('/v1/roles',                  rolesCreateHandler)
    ..get( '/v1/delegations',            delegationsListHandler)
    ..post('/v1/delegations',            delegationsCreateHandler);
}
// pharma_learn_api.dart — master mount (replaces old Router.mount pattern)
void mountHealthRoutes(RelicApp app) {
  app
    ..get('/health',          healthHandler)
    ..get('/health/detailed', healthDetailedHandler);
}

// Path param access uses Symbol keys in Relic:
// Route: '/v1/employees/:id'
// Handler: final id = req.pathParameters[#id]!;
E-Signature Flow (21 CFR §11.200)
Every [esig]-annotated endpoint follows this 6-step flow:

Client: POST /v1/reauth/create → {reauth_session_id} (30-min TTL from system_settings['security.password_reauth_window_min'])
Client: calls target endpoint with body {..., e_signature: {reauth_session_id, meaning, reason, is_first_in_session}}
esig_middleware: calls validate_reauth_session(reauth_session_id) RPC → verifies not expired, not consumed
Handler: calls create_esignature(employee_id, meaning, entity_type, entity_id, ...) RPC → returns esig_id
Handler: stores esig_id FK on entity (e.g. approvals.esig_id); calls consume_reauth_session(reauth_session_id) RPC
Handler: calls publish_event() to write to events_outbox (same logical transaction)
Two-Person Certificate Revocation (ALCOA+ / M-06)
Uses a 3-step workflow backed by the certificate_revocation_requests table (migration G3):

Step 1 — POST /v1/certify/certificates/:id/revoke/initiate
  Body: {reason, e_signature: {reauth_session_id, meaning:'REVOKE_INITIATE'}}
  → Inserts certificate_revocation_requests row (status='pending')
  → Notifies second approver via notification_service

Step 2 — POST /v1/certify/certificates/:id/revoke/confirm
  Body: {request_id, e_signature: {reauth_session_id, meaning:'REVOKE_CONFIRM'}}
  Guard: confirmed_by MUST differ from initiated_by (DB CHECK constraint + app layer)
  → Updates request to status='confirmed'; sets certificates.status='revoked'
  → Both esignature IDs logged for full 21 CFR §11 audit trail

Step 3 (optional) — POST /v1/certify/certificates/:id/revoke/cancel
  Body: {request_id, reason}
  Guard: only initiator or their supervisor
  No e-sig required (withdrawal before execution, not a regulated finalization)
  → Updates request to status='cancelled'; logs to audit_trails

DB enforcement: CHECK(confirmed_by IS NULL OR confirmed_by != initiated_by) in certificate_revocation_requests table prevents same-person confirm at the database layer.

URS Full Coverage Map
URS Clause	Domain	Endpoint(s)
Alfa §3.1.4 (disable user, not delete)	access	PATCH /v1/access/employees/:id/deactivate; user_credentials.is_active (no deletion)
Alfa §3.1.41-47 (password controls)	access	POST /v1/auth/password/change, GET /v1/config/password-policies
Alfa §4.1.1.7 (multilingual — Marathi, Hindi)	Flutter	flutter_localizations + arb files (not an API endpoint; Flutter-side l10n)
Alfa §4.2.1.16-21 (GTP management)	create, train	POST /v1/create/gtps, POST /v1/train/schedules
Alfa §4.2.1.25 (TNI + curricula)	train	POST /v1/train/schedules/:id/assign, POST /v1/create/curricula
Alfa §4.2.1.28 (auto-numbering)	create	POST /v1/create/config/numbering-schemes/:id/next
Alfa §4.2.1.34 (e-sig on submit)	create, certify	POST .../submit (all submit endpoints)
Alfa §4.3.3 (plant-wise list)	train, certify	GET /v1/certify/compliance/dashboard (filtered by plant_id)
Alfa §4.3.4 (configurable approval)	create, workflow	POST /v1/create/config/approval-matrices
Alfa §4.3.6 (bulk user import)	access	POST /v1/access/employees/bulk (CSV/JSON batch registration)
Alfa §4.3.11 (OJT witness sign-off)	train	POST /v1/train/ojt/:id/sign-off [esig; G2 per-task esignature_id]
Alfa §4.3.12 (training waiver)	train, certify	POST /v1/certify/waivers, POST /v1/train/obligations/:id/waive
Alfa §4.3.13 (blended sessions: ILT + WBT %)	train, create	training_schedules.schedule_type = 'blended'; sessions must complete both components
Alfa §4.3.19 (post-dated + scanned attendance)	train	PATCH /v1/train/sessions/:id/attendance/:empId; POST /v1/train/sessions/:id/attendance/upload
Alfa §4.4.4 (training material revision history)	create	GET /v1/create/documents/:id/versions
Alfa §4.4.6 (unplanned leave delegation)	access	POST /v1/access/delegations
Alfa §4.4.8 (periodic review)	create	POST /v1/create/periodic-reviews/:id/complete
Alfa §4.5.1-5 (login + lockout)	access	POST /v1/auth/login (validate_credential RPC; 3-attempt lockout)
Alfa §4.5.9 (biometric login)	access	POST /v1/auth/biometric/login
Alfa §4.5.2-7 (SSO/AD)	access	POST /v1/auth/sso/login, POST /v1/access/sso/configurations
Alfa §4.5.30 (ALCOA+ compliance)	all	audit_trails (Attributable, Legible, Contemporaneous) + electronic_signatures (Original, Accurate) + immutable DB triggers (Complete, Consistent, Enduring, Available)
Alfa §4.5.41 (time zone tracking)	all	All timestamps stored as TIMESTAMPTZ; audit_trails.created_at AT TIME ZONE in queries
Alfa §4.6.1.9 (RTO ≤15 min)	lifecycle_monitor	Docker health checks + GET /health/detailed + business_continuity_plans table
Alfa §4.9.8 (decommissioning)	access, admin	PATCH /v1/access/employees/:id/deactivate; data export endpoints; disposal plan docs
EE §5.1.5 (to-do list columns)	train	GET /v1/train/me/obligations (title, doc_no, training_type, delivery_mode, questionnaire, due_date, status)
EE §5.1.6 (induction gate)	train	POST /v1/train/induction/complete (auth_middleware + go_router guard)
EE §5.1.7 (graphical progress)	train	GET /v1/train/me/dashboard
EE §5.1.8 (attendance check-in)	train	POST /v1/train/sessions/:id/check-in (QR HMAC token; G1 qr_token column)
EE §5.1.10 (waiver with e-sig)	train, certify	POST /v1/train/obligations/:id/waive [esig]; training_waivers.esignature_id
EE §5.1.12 (print certificates)	certify	GET /v1/certify/certificates/:id/download (PDF signed URL)
EE §5.1.15 (competency gaps)	certify	GET /v1/certify/competencies (role_competencies vs employee_competencies delta)
EE §5.1.20 (course approval)	create	POST /v1/create/courses/:id/approve [esig]
EE §5.1.23 (training history)	train	GET /v1/train/me/training-history
EE §5.1.27-45 (Training Coordinator)	train	GET|POST /v1/train/coordinators
EE §5.4.2 (AD/SSO)	access	POST /v1/access/sso/configurations
EE §5.6.10 (session security/idle)	access	auth_middleware idle-timeout (user_sessions.last_activity_at)
EE §5.9.2 (password management)	access	POST /v1/auth/password/change
EE §5.13.4-5 (retention + archival)	lifecycle_monitor	POST /jobs/archive (retention_policies; floor: 6yr GMP, 7yr clinical; archive-not-delete policy)
SCORM §5.x (content delivery, SCORM 1.2 only)	create	POST /v1/create/scorm/packages, GET /v1/create/scorm/:id/launch
21 CFR §11.10(b) (printable / retrievable format)	create, workflow	GET /v1/create/documents/:id/export (PDF+esig history); GET /v1/workflow/audit/:entityType/:entityId/export (CSV/PDF)
21 CFR §11.10(c) (record protection)	certify	POST /v1/certify/integrity/verify (SHA-256 hash chain on audit_trails)
21 CFR §11.10(e) (audit trail)	workflow	GET /v1/workflow/audit/:entityType/:entityId
Alfa §4.2.1.19 (missed-questions analysis)	certify	GET /v1/certify/assessments/:id/question-analysis (wrong-answer distribution per question)
Alfa §4.4.3 (retention period configuration)	lifecycle_monitor, create	GET|POST /v1/create/config/retention-policies; floor constraints enforced in archive_job_handler
Alfa §4.6.3–4.6.10 (backup/restore/BCP)	admin	business_continuity_plans table; GET /health/detailed (readiness); Docker health checks
Alfa §4.8.10–12 (audit trail timestamps non-editable)	all	audit_trails timestamps are DB-generated (DEFAULT NOW()); no API endpoint allows timestamp override; documented in immutable trigger on audit_trails
21 CFR §11.50 (sig manifestation — name, date, meaning)	certify	POST /v1/certify/esignatures/create; electronic_signatures.meaning + printed_name + signed_at
21 CFR §11.100(b) (unique username, non-reusable)	access	employees.username UNIQUE + immutable trigger; user_credentials no re-use policy
21 CFR §11.200 (e-sig session chain)	certify	POST /v1/certify/reauth/create + esig_middleware (30-min TTL; first-in-session requires ID+password)
21 CFR §11.300 (password controls)	access	password_policies (min length, complexity, history, expiry) + user_credentials
M-06 (two-person cert revocation)	certify	POST /v1/certify/certificates/:id/revoke/initiate → /confirm → /cancel; certificate_revocation_requests table (G3)
Environment Variables (.env.local)
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_ROLE_KEY=eyJ...
SUPABASE_ANON_KEY=eyJ...
SUPABASE_STORAGE_BUCKET=pharmalearn-files
PORT=8080
LIFECYCLE_MONITOR_PORT=8086
WORKFLOW_ENGINE_PORT=8085
ALLOWED_ORIGINS=http://localhost:3000,https://app.pharmalearn.internal
LOG_LEVEL=info
# Lifecycle Monitor job intervals (seconds)
JOB_INTEGRITY_CHECK_INTERVAL=86400
JOB_CERT_EXPIRY_INTERVAL=3600
JOB_OVERDUE_TRAINING_INTERVAL=3600
JOB_EVENTS_POLL_INTERVAL=5
JOB_ARCHIVE_INTERVAL=86400
JOB_PASSWORD_EXPIRY_INTERVAL=3600
JOB_SESSION_CLEANUP_INTERVAL=900
JOB_COMPLIANCE_METRICS_INTERVAL=21600
JOB_PERIODIC_REVIEW_INTERVAL=86400
Critical Files to Create (Ordered by dependency)
#	Path	Purpose
1	packages/pharmalearn_shared/pubspec.yaml	Shared package
2	packages/pharmalearn_shared/lib/src/client/supabase_client.dart	Service-role singleton
3	packages/pharmalearn_shared/lib/src/middleware/auth_middleware.dart	JWT + session idle-timeout
4	packages/pharmalearn_shared/lib/src/middleware/esig_middleware.dart	§11.200 reauth validation
5	packages/pharmalearn_shared/lib/src/middleware/rate_limit_middleware.dart	Token bucket
6	packages/pharmalearn_shared/lib/src/models/api_response.dart	{data, meta, error}
7	packages/pharmalearn_shared/lib/src/utils/error_handler.dart	RFC 7807 mapping
8	packages/pharmalearn_shared/lib/src/services/esig_service.dart	Reauth RPC wrappers
9	packages/pharmalearn_shared/lib/src/services/outbox_service.dart	publish_event()
10	packages/pharmalearn_shared/lib/pharmalearn_shared.dart	Barrel export
11	apps/api_server/pharma_learn/api/pubspec.yaml	Main API deps
12	apps/api_server/pharma_learn/api/lib/pharma_learn_api.dart	Server setup + pipeline
13	apps/api_server/pharma_learn/api/bin/server.dart	Entry point
14	apps/api_server/pharma_learn/api/lib/context/request_context.dart	Auth context model
15	apps/api_server/pharma_learn/api/lib/routes/routes.dart	Master router
16	apps/api_server/pharma_learn/api/lib/routes/health/routes.dart	Health checks
17	apps/api_server/pharma_learn/api/lib/routes/access/routes.dart	Access aggregator
18	apps/api_server/pharma_learn/api/lib/routes/access/auth/login_handler.dart	Login
19	apps/api_server/pharma_learn/api/lib/routes/access/auth/routes.dart	Auth routes
20	apps/api_server/pharma_learn/api/lib/routes/access/employees/employees_handler.dart	Employees CRUD
21	apps/api_server/pharma_learn/api/lib/routes/create/routes.dart	Create aggregator
22	apps/api_server/pharma_learn/api/lib/routes/create/documents/document_approve_handler.dart	Doc approval + esig
23	apps/api_server/pharma_learn/api/lib/routes/create/scorm/scorm_commit_handler.dart	SCORM CMI data
24	apps/api_server/pharma_learn/api/lib/routes/train/routes.dart	Train aggregator
25	apps/api_server/pharma_learn/api/lib/routes/train/sessions/session_checkin_handler.dart	QR/biometric check-in
26	apps/api_server/pharma_learn/api/lib/routes/train/me/me_dashboard_handler.dart	Employee dashboard
27	apps/api_server/pharma_learn/api/lib/routes/certify/routes.dart	Certify aggregator
28	apps/api_server/pharma_learn/api/lib/routes/certify/reauth/reauth_create_handler.dart	§11.200 reauth
29	apps/api_server/pharma_learn/api/lib/routes/certify/certificates/certificate_revoke_initiate_handler.dart	Two-person revoke step 1
30	apps/api_server/pharma_learn/api/lib/routes/certify/compliance/compliance_dashboard_handler.dart	KPI dashboard
31	apps/api_server/pharma_learn/api/lib/routes/workflow/routes.dart	Workflow aggregator
32	apps/api_server/pharma_learn/api/lib/routes/workflow/approvals/approvals_pending_handler.dart	Pending approvals
33	apps/api_server/pharma_learn/lifecycle_monitor/pubspec.yaml	Lifecycle monitor deps
34	apps/api_server/pharma_learn/lifecycle_monitor/bin/server.dart	Lifecycle entry point
35	apps/api_server/pharma_learn/lifecycle_monitor/lib/routes/jobs/events_fanout_handler.dart	Outbox fanout
36	apps/api_server/pharma_learn/lifecycle_monitor/lib/services/pg_listener_service.dart	pg_notify listener
Verification Plan
Unit tests — each *_handler.dart has a matching test using mocktail to mock SupabaseClient
Integration smoke — dart test apps/api_server/pharma_learn/api/test/access/login_test.dart against local Supabase
E-sig flow — POST /v1/certify/reauth/create → POST /v1/create/documents/:id/approve → verify electronic_signatures row with is_first_in_session=TRUE and prev_signature_id chain
Two-person revoke (3-step) — POST /v1/certify/certificates/:id/revoke/initiate → verify pending status; POST same endpoint by same user for /confirm → expect DB error on CHECK(confirmed_by != initiated_by); POST with different authorized user → expect 200 and certificates.status = 'revoked'
Revoke cancel — POST /v1/certify/certificates/:id/revoke/cancel by initiator → expect status = 'cancelled', no esig required, audit_trails entry created
Idle-timeout — advance last_activity_at past threshold → next request → 401 SESSION_TIMEOUT + audit_trails row with event_category='SESSION_TIMEOUT'
Rate limit — exceed api_rate_limits threshold → 429 Retry-After header
Audit chain — after 10 API calls → POST /v1/certify/integrity/verify → {is_valid: true}
Induction gate — employee with induction_completed=false hits any non-induction endpoint → 403 InductionGateException
QR check-in — transition session to in_progress → verify training_sessions.qr_token populated (G1); scan QR → POST /v1/train/sessions/:id/check-in → verify session_attendance row; replay same token → expect 409 (already checked in)
OJT esig — complete ojt_task → verify ojt_task_completion.esignature_id populated (G2); attempt same user for supervisor final sign-off → expect two-person guard
Compliance formula — create 4 obligations: 2 completed, 1 overdue, 1 waived → POST /jobs/compliance-metrics → employees.compliance_percent = 66.67 (waived excluded from denominator)
SCORM flow — POST /v1/create/scorm/packages → GET /v1/create/scorm/:id/launch → POST /v1/create/scorm/:id/commit (CMI data) → GET /v1/create/scorm/:id/progress reflects completion (SCORM 1.2 only; SCORM 2004 not supported)
Bulk import — POST /v1/access/employees/bulk with CSV of 10 employees → verify 10 employee rows + 10 employee_assignments auto-spawned via training trigger
Health — GET :8080/health → {status: ok, latency_ms: <100}; GET :8086/health → {status: ok, events_outbox_lag: 0}
Regulatory Retention Floors & Archival Policy
These floors are non-negotiable minimums regardless of what retention_policies table entries say. The archive_job_handler enforces them:

Record Type	Minimum Retention	Regulatory Basis
GMP training records (employee_assignments, training_records)	6 years from completion date	WHO GMP Annex 1; Alfa A-SOP-QA-015-01 §4.5.42
Clinical trial training records	7 years from trial end	ICH E6(R2) GCP
Audit trails (audit_trails table)	Entire lifespan of the parent record + 1 year	21 CFR §11.10(e); EU Annexure 11 §9
Electronic signatures (electronic_signatures)	Same as the entity they sign	21 CFR §11.50
Certificates (certificates table)	6 years from issue date (or until revoked + 6 years)	WHO GMP; Alfa §4.5.42

Archive Policy — "archive-not-delete": The archive_job_handler MUST NOT perform DELETE. It sets data_archives.archived = true and writes a snapshot to data_archives.archive_payload JSONB. The original row is retained with status = 'archived'. Physical deletion is only permitted via a separate disposal workflow triggered by decommissioning (documented in business_continuity_plans + signed by QA head with e-sig).

Printable / Retrievable Format (21 CFR §11.10(b)):
  GET /v1/certify/certificates/:id/download → PDF (already implemented)
  GET /v1/create/documents/:id/export → PDF of document + all approval esig history (ensures human-readable format for FDA inspection without software dependency)
  GET /v1/workflow/audit/:entityType/:entityId/export → CSV/PDF audit trail export for any record (needed for §11.10(b) inspection readiness)

Flutter Client — MobX Architecture
State management is MobX (mobx + flutter_mobx + mobx_codegen). No Riverpod. No BLoC.

Flutter pubspec.yaml (apps/pharma_learn/pubspec.yaml)
dependencies:
  flutter:
    sdk: flutter
  # Supabase
  supabase_flutter: ^2.5.0
  # MobX state management
  mobx: ^2.3.3
  flutter_mobx: ^2.2.1
  # Navigation
  go_router: ^13.2.0
  # Network
  dio: ^5.4.0
  connectivity_plus: ^6.0.0
  # Local storage & security
  flutter_secure_storage: ^9.0.0
  hive_flutter: ^1.1.0
  # Biometric auth
  local_auth: ^2.2.0
  # Forms
  flutter_form_builder: ^9.2.0
  form_builder_validators: ^10.4.0
  # PDF viewing
  syncfusion_flutter_pdfviewer: ^25.1.0
  # Charts (compliance dashboard)
  fl_chart: ^0.66.0
  # Tables
  data_table_2: ^2.5.0
  # Utilities
  intl: ^0.19.0
  logger: ^2.3.0
  uuid: ^4.4.0
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  get_it: ^7.6.0          # DI container
  injectable: ^2.3.0       # DI code gen
  web_socket_channel: ^2.4.0

dev_dependencies:
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  mobx_codegen: ^2.6.1
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  injectable_generator: ^2.4.0
Flutter Folder Structure
apps/pharma_learn/lib/
  core/
    api/
      api_client.dart          ← Dio instance with JWT interceptor + refresh
      api_endpoints.dart       ← All endpoint URL constants
    di/
      injection.dart           ← get_it + injectable setup
    models/                    ← Freezed models matching API response shapes
    stores/
      app_store.dart           ← Root store (auth gate, global loading)
    router/
      app_router.dart          ← go_router with auth guard + induction gate
  features/
    auth/
      data/auth_repository.dart
      stores/auth_store.dart
      screens/login_screen.dart
    documents/
      data/document_repository.dart
      stores/document_store.dart
      screens/document_list_screen.dart
      screens/document_detail_screen.dart
    courses/
      data/course_repository.dart
      stores/course_store.dart
    training/
      data/training_repository.dart
      stores/training_store.dart
      screens/my_dashboard_screen.dart
      screens/session_checkin_screen.dart
    assessment/
      data/assessment_repository.dart
      stores/assessment_store.dart
      screens/assessment_screen.dart
    certificates/
      data/certificate_repository.dart
      stores/certificate_store.dart
    approvals/
      data/approval_repository.dart
      stores/approval_store.dart
    notifications/
      data/notification_repository.dart
      stores/notification_store.dart
  main.dart
MobX Store Pattern (canonical — every store follows this)
// features/auth/stores/auth_store.dart
import 'package:mobx/mobx.dart';
import 'package:injectable/injectable.dart';
part 'auth_store.g.dart';

@lazySingleton
class AuthStore = _AuthStore with _$AuthStore;

abstract class _AuthStore with Store {
  final AuthRepository _repository;
  _AuthStore(this._repository);

  // ── Observables ──────────────────────────────────────────────────
  @observable
  AuthStatus status = AuthStatus.initial;

  @observable
  Employee? currentEmployee;

  @observable
  String? errorMessage;

  @observable
  bool isMfaRequired = false;

  // ── Computed ──────────────────────────────────────────────────────
  @computed
  bool get isAuthenticated => status == AuthStatus.authenticated;

  @computed
  bool get inductionCompleted => currentEmployee?.inductionCompleted ?? false;

  @computed
  bool get isLoading => status == AuthStatus.loading;

  // ── Actions ───────────────────────────────────────────────────────
  @action
  Future<void> login({required String email, required String passwordHash}) async {
    status = AuthStatus.loading;
    errorMessage = null;
    try {
      final result = await _repository.login(email: email, passwordHash: passwordHash);
      currentEmployee = result.employee;
      if (result.mfaRequired) {
        isMfaRequired = true;
        status = AuthStatus.mfaPending;
      } else {
        status = AuthStatus.authenticated;
      }
    } on AccountLockedException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.locked;
    } catch (e) {
      errorMessage = e.toString();
      status = AuthStatus.error;
    }
  }

  @action
  Future<void> logout() async {
    await _repository.logout();
    currentEmployee = null;
    status = AuthStatus.initial;
  }

  @action
  Future<void> verifyMfa(String totpCode) async { ... }

  @action
  void clearError() => errorMessage = null;
}

enum AuthStatus { initial, loading, authenticated, mfaPending, locked, error }
// features/training/stores/training_store.dart
@lazySingleton
class TrainingStore = _TrainingStore with _$TrainingStore;

abstract class _TrainingStore with Store {
  final TrainingRepository _repository;

  @observable
  ObservableList<TrainingObligation> myObligations = ObservableList();

  @observable
  ObservableList<TrainingSession> upcomingSessions = ObservableList();

  @observable
  TrainingDashboard? dashboard;

  @observable
  bool isLoadingDashboard = false;

  @computed
  int get overdueCount =>
      myObligations.where((o) => o.status == 'OVERDUE').length;

  @action
  Future<void> loadDashboard() async {
    isLoadingDashboard = true;
    try {
      dashboard = await _repository.getMyDashboard();
      myObligations.setAll(0, await _repository.getMyObligations());
    } finally {
      isLoadingDashboard = false;
    }
  }

  @action
  Future<void> checkIn({
    required String sessionId,
    required String method,   // 'QR' | 'BIOMETRIC' | 'MANUAL'
    String? qrCode,
  }) async { ... }
}
API Client (Dio with JWT interceptor)
// core/api/api_client.dart
@lazySingleton
class ApiClient {
  late final Dio _dio;

  ApiClient(AuthTokenStore tokenStore) {
    _dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,               // e.g. http://localhost:8080
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.addAll([
      AuthInterceptor(tokenStore),           // Adds Authorization header
      RefreshInterceptor(tokenStore, _dio),  // Auto-refresh on 401
      LogInterceptor(requestBody: false),
    ]);
  }

  Future<ApiResponse<T>> get<T>(String path, ...) async { ... }
  Future<ApiResponse<T>> post<T>(String path, {dynamic data, ...}) async { ... }
  Future<ApiResponse<T>> patch<T>(String path, {dynamic data}) async { ... }
  Future<ApiResponse<T>> delete<T>(String path) async { ... }
}
go_router — Auth Guard + Induction Gate
// core/router/app_router.dart
@singleton
class AppRouter {
  final AuthStore _authStore;

  late final GoRouter router = GoRouter(
    redirect: (context, state) {
      final isAuth = _authStore.isAuthenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isAuth && !isLoginRoute) return '/login';
      if (isAuth && isLoginRoute) return '/dashboard';

      // Induction gate: non-induction routes blocked until complete
      if (isAuth && !_authStore.inductionCompleted) {
        final allowed = state.matchedLocation.startsWith('/induction');
        if (!allowed) return '/induction';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, _) => const LoginScreen()),
      GoRoute(path: '/induction', builder: (ctx, _) => const InductionScreen()),
      ShellRoute(
        builder: (ctx, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: ...),
          GoRoute(path: '/documents', builder: ...),
          GoRoute(path: '/documents/:id', builder: ...),
          GoRoute(path: '/training', builder: ...),
          GoRoute(path: '/assessments/:id', builder: ...),
          GoRoute(path: '/certificates', builder: ...),
          GoRoute(path: '/approvals', builder: ...),
        ],
      ),
    ],
  );
}
Handler Implementations — Critical Endpoints
Relic conventions used throughout:

Handler signature: Future<Response> xyzHandler(Request req)
Path params via symbol: req.pathParameters[#id]!
Context values: req.context['supabase'], req.context['auth'], req.context['esig'], req.context['body']
Extension methods on Request defined in constants.dart provide shorthand: req.supabase, req.auth, req.esig
Response body: Body.fromString(jsonEncode({...})) with ContentType.json header
ApiResponse.toResponse() wraps this internally
1. access/auth/login_handler.dart
// POST /v1/auth/login
// Body: {email: string, password_hash: string}
// Returns: {session: {...}, employee: {...}}
Future<Response> loginHandler(Request req) async {
  final body     = await readJson(req);          // reads + caches body
  final email    = requireString(body, 'email');
  final pwHash   = requireString(body, 'password_hash');
  final supabase = req.context['supabase'] as SupabaseClient;

  // 1. Validate credential via DB (handles lockout + failed_attempts increment)
  final valid = await supabase.rpc('validate_credential', params: {
    'p_employee_id': null,
    'p_input_hash': pwHash,
    'p_policy_threshold': 5,
  }) as bool;

  if (!valid) {
    // Check if locked (failed_attempts >= threshold)
    final locked = await supabase
        .from('user_credentials')
        .select('locked_at')
        .eq('employee_id', employeeId)
        .maybeSingle();
    if (locked?['locked_at'] != null) throw AccountLockedException('Account locked');
    throw AuthException('Invalid credentials');
  }

  // 2. Sign in via GoTrue to get JWT
  final authResponse = await supabase.auth.signInWithPassword(
    email: email, password: pwHash,
  );

  // 3. Create user_session record
  final employee = await supabase.from('employees')
      .select('*, user_credentials(mfa_enabled)')
      .eq('email', email)
      .single();

  // 4. Write audit trail (DB trigger also does this, but explicit for LOGIN)
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee',
    'entity_id': employee['id'],
    'action': 'LOGIN',
    'event_category': 'LOGIN',
    'performed_by': employee['id'],
    'organization_id': employee['organization_id'],
  });

  // 5. Publish event
  await supabase.rpc('publish_event', params: {
    'p_aggregate_type': 'auth',
    'p_aggregate_id': employee['id'],
    'p_event_type': 'auth.login',
    'p_payload': jsonEncode({'ip': req.headers.value('x-forwarded-for') ?? 'unknown'}),
    'p_org_id': employee['organization_id'],
  });

  return ApiResponse.ok({
    'session': authResponse.session?.toJson(),
    'employee': employee,
    'mfa_required': employee['user_credentials']['mfa_enabled'] ?? false,
  }).toResponse();
}
2. create/documents/document_approve_handler.dart
// POST /v1/documents/:id/approve   [esig_middleware required]
// Body: {e_signature: {reauth_session_id, meaning:'APPROVE', reason}, comments}
Future<Response> documentApproveHandler(Request req) async {
  final docId    = parseUuid(req.pathParameters[#id]!);
  final auth     = req.context['auth'] as AuthContext;
  final supabase = req.context['supabase'] as SupabaseClient;
  final esig     = req.context['esig'] as EsigContext;    // injected by esig_middleware
  final body     = req.context['body'] as Map<String, dynamic>;

  // Permission check
  await PermissionChecker(supabase).require(auth.employeeId, Permissions.approveDocuments);

  // 1. Load document + approval step
  final doc = await supabase.from('documents')
      .select('*, document_control(*)')
      .eq('id', docId).single();
  if (doc['document_control']['status'] != 'UNDER_REVIEW') {
    throw ConflictException('Document is not under review');
  }

  // 2. Create e-signature record
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId,
    meaning: 'APPROVE',
    entityType: 'document',
    entityId: docId,
    isFirstInSession: esig.isFirstInSession,
    orgId: auth.orgId,
  );

  // 3. Advance approval step via DB function
  await supabase.rpc('advance_approval_step', params: {
    'p_entity_type': 'document',
    'p_entity_id': docId,
    'p_approver_id': auth.employeeId,
    'p_esig_id': esigId,
    'p_comments': body['comments'],
  });

  // 4. Consume reauth session (single-use)
  await EsigService(supabase).consumeReauthSession(esig.reauthSessionId);

  // 5. Publish event
  await OutboxService(supabase).publish(
    aggregateType: 'document', aggregateId: docId,
    eventType: EventTypes.documentApproved,
    payload: {'approved_by': auth.employeeId, 'esig_id': esigId},
    orgId: auth.orgId,
  );

  final updated = await supabase.from('documents')
      .select('*, document_control(*)').eq('id', docId).single();
  return ApiResponse.ok({'document': updated, 'esig_id': esigId}).toResponse();
}
3. certify/certificates/certificate_revoke_initiate_handler.dart
// POST /v1/certify/certificates/:id/revoke/initiate   (Step 1 of 3)
// Body: { reason: string, e_signature: {reauth_session_id, meaning:'REVOKE_INITIATE'} }
// Inserts certificate_revocation_requests (status='pending').
// A second authorized user (different employee) must call /confirm to finalize.
Future<Response> certificateRevokeInitiateHandler(Request req) async {
  final certId   = parseUuid(req.pathParameters[#id]!);
  final auth     = req.context['auth'] as AuthContext;
  final supabase = req.context['supabase'] as SupabaseClient;
  final body     = await readJson(req);

  final esigReq = EsigRequest.fromJson(body['e_signature'] as Map<String, dynamic>);
  final esigSvc = EsigService(supabase);

  // 1. Validate reauth session for initiator
  await esigSvc.validateReauthSession(esigReq.reauthSessionId);

  // 2. Ensure certificate is active
  final cert = await supabase.from('certificates').select('status').eq('id', certId).single();
  if (cert['status'] != 'active') throw ConflictException('Certificate is not active');

  // 3. Create initiator e-signature
  final esigId = await esigSvc.createEsignature(
    employeeId: auth.employeeId, meaning: 'REVOKE_INITIATE',
    entityType: 'certificate_revocation_requests', entityId: certId,
    isFirstInSession: esigReq.isFirstInSession,
  );

  // 4. Insert revocation request (DB CHECK prevents same-person confirm later)
  final request = await supabase.from('certificate_revocation_requests').insert({
    'certificate_id': certId,
    'initiated_by': auth.employeeId,
    'initiation_reason': body['reason'],
    'initiation_esignature_id': esigId,
    'status': 'pending',
  }).select().single();

  await esigSvc.consumeReauthSession(esigReq.reauthSessionId);
  await OutboxService(supabase).publish(
    aggregateType: 'certificate', aggregateId: certId,
    eventType: EventTypes.certificateRevocationInitiated,
    payload: {'request_id': request['id'], 'initiated_by': auth.employeeId},
  );

  return ApiResponse.created({'request_id': request['id'],
    'message': 'Revocation initiated. A different authorized user must confirm.'}).toResponse();
}
4. train/sessions/session_checkin_handler.dart
// POST /v1/sessions/:id/check-in
// Body: {check_in_method: 'QR'|'BIOMETRIC'|'MANUAL', qr_code?, employee_id?}
Future<Response> sessionCheckinHandler(Request req) async {
  final sessionId = parseUuid(req.pathParameters[#id]!);
  final auth      = req.context['auth'] as AuthContext;
  final supabase  = req.context['supabase'] as SupabaseClient;
  final body      = await readJson(req);

  final method     = requireString(body, 'check_in_method');
  final employeeId = optionalString(body, 'employee_id') ?? auth.employeeId;

  // 1. Validate session is ONGOING
  final session = await supabase.from('training_sessions')
      .select().eq('id', sessionId).single();
  if (session['status'] != 'IN_PROGRESS') {
    throw ConflictException('Session is not currently in progress');
  }

  // 2. QR code validation (if QR method)
  if (method == 'QR') {
    final qrCode = requireString(body, 'qr_code');
    if (qrCode != session['session_code']) {
      throw ValidationException({'qr_code': 'Invalid QR code'});
    }
  }

  // 3. Upsert session_attendance (idempotent check-in)
  final attendance = await supabase.from('session_attendance').upsert({
    'session_id': sessionId,
    'employee_id': employeeId,
    'check_in_time': DateTime.now().toIso8601String(),
    'check_in_method': method,
    'attendance_status': 'PRESENT',
  }, onConflict: 'session_id,employee_id').select().single();

  return ApiResponse.ok({
    'attendance': attendance,
    'session': {'id': sessionId, 'session_code': session['session_code']},
    'checked_in_at': attendance['check_in_time'],
  }).toResponse();
}
5. certify/assessments/assessment_submit_handler.dart
// POST /v1/assessments/:id/submit  [esig_middleware required]
// Body: {e_signature: {...}}
Future<Response> assessmentSubmitHandler(Request req) async {
  final attemptId = parseUuid(req.pathParameters[#id]!);
  final auth      = req.context['auth'] as AuthContext;
  final supabase  = req.context['supabase'] as SupabaseClient;
  final esig      = req.context['esig'] as EsigContext;

  // 1. Load attempt + validate it's submittable
  final attempt = await supabase.from('assessment_attempts')
      .select('*, question_papers(pass_mark, total_marks)')
      .eq('id', attemptId).single();
  if (attempt['employee_id'] != auth.employeeId) throw PermissionDeniedException('Not your assessment');
  if (attempt['status'] != 'IN_PROGRESS') throw ConflictException('Assessment not in progress');

  // 2. Create e-signature (§11.200: employee signs submission)
  final esigId = await EsigService(supabase).createEsignature(
    employeeId: auth.employeeId, meaning: 'SUBMIT',
    entityType: 'assessment_attempt', entityId: attemptId,
    isFirstInSession: esig.isFirstInSession,
  );

  // 3. Calculate score + grade via DB function
  final gradeResult = await supabase.rpc('grade_assessment_attempt', params: {
    'p_attempt_id': attemptId,
    'p_esig_id': esigId,
  }) as Map<String, dynamic>;

  // 4. Consume reauth
  await EsigService(supabase).consumeReauthSession(esig.reauthSessionId);

  // 5. If passed — publish event that triggers certificate generation
  if (gradeResult['passed'] == true) {
    await OutboxService(supabase).publish(
      aggregateType: 'assessment_attempt', aggregateId: attemptId,
      eventType: EventTypes.assessmentSubmitted,
      payload: {
        'employee_id': auth.employeeId,
        'passed': true,
        'score': gradeResult['score'],
        'training_record_id': attempt['training_record_id'],
      },
      orgId: auth.orgId,
    );
  }

  return ApiResponse.ok({
    'result': gradeResult,
    'esig_id': esigId,
    'attempt_id': attemptId,
  }).toResponse();
}
6. lifecycle_monitor/routes/jobs/events_fanout_handler.dart
// POST /jobs/events  — called by cron every 5s OR triggered by pg_notify
Future<Response> eventsFanoutHandler(Request req) async {
  final supabase = req.context['supabase'] as SupabaseClient;
  int processed  = 0;
  int failed     = 0;

  // Poll pending events (batch of 50)
  final events = await supabase.from('events_outbox').select()
      .isFilter('processed_at', null)
      .eq('is_dead_letter', false)
      .or('next_retry_at.is.null,next_retry_at.lte.${DateTime.now().toIso8601String()}')
      .order('created_at').limit(50);

  for (final event in events as List) {
    try {
      // Mark processing started (optimistic lock)
      await supabase.from('events_outbox')
          .update({'processing_started_at': DateTime.now().toIso8601String()})
          .eq('id', event['id'])
          .isFilter('processing_started_at', null); // only if not already picked up

      // Route to handler based on event_type
      await _routeEvent(supabase, event);

      // Mark processed
      await supabase.rpc('mark_event_processed', params: {'p_event_id': event['id']});
      processed++;
    } catch (e) {
      await supabase.rpc('schedule_event_retry', params: {
        'p_event_id': event['id'],
        'p_error': e.toString(),
      });
      failed++;
    }
  }

  return ApiResponse.ok({
    'processed': processed,
    'failed': failed,
    'total': events.length,
  }).toResponse();
}

Future<void> _routeEvent(SupabaseClient supabase, Map event) async {
  switch (event['event_type'] as String) {
    case 'assessment.submitted':
      await _handleAssessmentSubmitted(supabase, event);
    case 'certificate.revoked':
      await _handleCertificateRevoked(supabase, event);
    case 'training.completed':
      await _handleTrainingCompleted(supabase, event);
    case 'document.approved':
      await _handleDocumentApproved(supabase, event);
    // ... more event types
  }
}

Future<void> _handleAssessmentSubmitted(SupabaseClient db, Map event) async {
  final payload = event['payload'] as Map<String, dynamic>;
  if (payload['passed'] != true) return;

  // Trigger certificate generation via Edge Function
  final certId = await db.rpc('generate_certificate_for_training', params: {
    'p_training_record_id': payload['training_record_id'],
    'p_employee_id': payload['employee_id'],
  });

  // Send notification
  await db.rpc('publish_event', params: {
    'p_aggregate_type': 'certificate',
    'p_aggregate_id': certId,
    'p_event_type': 'certificate.issued',
    'p_payload': jsonEncode({'employee_id': payload['employee_id']}),
  });
}
Cross-Module Saga Patterns (from docs/cross.md)
Two saga patterns coordinate cross-domain state changes. Failure at any step triggers compensation.

Saga 1 — Orchestration: Course Publication (CREATE → TRAIN → CERTIFY)
The lifecycle_monitor drives this saga as an orchestrator:
  Step 1: CREATE — course.submit → workflow_engine advances approval → course.approved event published
  Step 2: TRAIN — on course.approved event → training_trigger_rules evaluated → employee_assignments bulk-created
  Step 3: CERTIFY — on training.completed event → certificate generation Edge Function invoked → certificate.issued event published
Compensation (rollback): If step 2 fails (bulk-assign error), compensation_course_publication() RPC is called:
  Deletes orphan employee_assignments for this course
  Sets course.status back to 'pending_publication'
  Publishes 'course.publication_failed' event for UI notification

Saga 2 — Choreography: Training Completion Event Chain (no central orchestrator)
Each domain reacts to events from the previous domain via events_outbox + pg_notify:
  training.completed event → lifecycle_monitor calls certificate generation Edge Function
  certificate.issued event → lifecycle_monitor checks employee's entire obligation list for completion → if all complete → publishes 'employee.fully_compliant' event
  employee.fully_compliant event → compliance dashboard metric refresh (employees.compliance_percent recalculated immediately, no waiting for 6h cron)
Compensation: If certificate generation Edge Function times out (>10s), the events_fanout_handler schedules a retry via schedule_event_retry() RPC. After 3 retries, the event is marked 'dead_letter' and a Prometheus alert fires. The training_record remains with status='completed'; only certificate generation is retried.

Eventual Consistency SLA: Cross-domain state propagation target is < 5 seconds under normal load (events_fanout polls every 5s + pg_notify is immediate). The events_outbox.processed_at column records actual delivery time. Prometheus metric pharma_events_outbox_pending tracks pending lag.

Event Type Registry (outbox_service.dart canonical event types)
All events published via OutboxService.publish() use ONLY these event types. The constants are in packages/pharmalearn_shared/lib/src/utils/constants.dart:

Event Type	Publisher	Subscribers	Key Payload Fields
document.created	create/document_handler	workflow_engine (approval trigger)	{document_id, org_id, created_by, document_type}
document.approved	workflow_engine	lifecycle_monitor (TRAIN trigger), notification_service	{document_id, org_id, approved_by, version_no}
course.published	create/course_approve_handler	lifecycle_monitor (saga orchestrator)	{course_id, org_id, course_type, assessment_required}
training.assigned	train/obligations_handler	notification_service (send to employee)	{assignment_id, employee_id, due_date, course_name}
training.completed	train/session_complete / self_learning_complete	lifecycle_monitor (certificate generation)	{training_record_id, employee_id, course_id, org_id, passed}
assessment.passed	certify/assessment_submit_handler	lifecycle_monitor (certificate generation), notification_service	{attempt_id, employee_id, score, training_record_id}
assessment.failed	certify/assessment_submit_handler	lifecycle_monitor (remedial assignment), notification_service	{attempt_id, employee_id, score, pass_mark, training_record_id}
certificate.issued	lifecycle_monitor/events_fanout	notification_service, compliance_metrics recalc	{certificate_id, employee_id, certificate_number, course_id, expiry_date}
certificate.expired	lifecycle_monitor/cert_expiry_handler	notification_service (employee + manager), training trigger	{certificate_id, employee_id, course_id, expired_at}

Idempotency: Every event payload includes an idempotency_key (default: UUID of the source entity). Subscribers check events_outbox.idempotency_key before processing to prevent duplicate side-effects on retry.

Grade Moderation Flow (certify_plan.md)
For assessment types with manual grading (short-answer, open-ended questions):
  Primary evaluator calls POST /v1/certify/assessments/:id/grade → inserts grading_queue row with grade_1 score
  Second evaluator grades the same submission independently → grade_2 score recorded
  If |grade_1 − grade_2| > 10% of total_marks: the grading_queue row is flagged moderation_required = true; a random 25% sample from the same batch goes to a third moderator
  Third moderator score becomes the authoritative grade; assessment_results.score is updated; the discrepancy is logged in audit_trails
  Fuzzy matching for short answers uses an 85% similarity threshold (Levenshtein distance normalized by answer length) before falling back to manual grading

GET /admin/event-processing-status health endpoint:
  GET /v1/admin/events/status → returns {pending_count, dead_letter_count, avg_latency_ms, oldest_pending_age_s}
  Used by operations team to monitor events_outbox backlog without direct DB access

Key Request/Response Shapes
POST /v1/auth/login
Request:  {email: string, password_hash: string}
Response: {data: {session: {access_token, refresh_token, expires_in}, employee: {id, name, email, induction_completed, organization_id, plant_id}, mfa_required: bool}}
Errors:   401 auth.invalid | 423 account-locked
POST /v1/reauth/create (§11.200 reauth session)
Request:  {password_hash: string, meaning: 'APPROVE'|'SUBMIT'|'REVOKE'|'SIGN'}
Response: {data: {reauth_session_id: UUID, expires_at: ISO8601, meaning: string}}
Errors:   401 session-timeout | 400 invalid-password
POST /v1/documents/:id/approve
Request:  {e_signature: {reauth_session_id: UUID, meaning:'APPROVE', reason: string, is_first_in_session: bool}, comments?: string}
Response: {data: {document: {...}, esig_id: UUID, approval_step: {level, approved_by, approved_at}}}
Errors:   428 esig-required | 409 conflict (wrong status) | 403 permission-denied
POST /v1/sessions/:id/check-in
Request:  {check_in_method: 'QR'|'BIOMETRIC'|'MANUAL', qr_code?: string, employee_id?: UUID}
Response: {data: {attendance_id: UUID, checked_in_at: ISO8601, session_code: string}}
Errors:   409 session-not-in-progress | 422 invalid-qr-code
POST /v1/assessments/start
Request:  {question_paper_id: UUID, training_record_id: UUID}
Response: {data: {attempt_id: UUID, started_at: ISO8601, time_limit_minutes: int, question_count: int, questions: [{id, text, type, options?}]}}
GET /v1/compliance/dashboard
Query:    ?plant_id=UUID&department_id=UUID&as_of=ISO8601
Response: {data: {compliance_percent: float, total_employees: int, compliant: int, overdue: int, upcoming_due: int, by_department: [{...}], certificates_expiring_30d: int}}
GET /v1/me/dashboard
Response: {data: {employee: {...}, my_obligations: [{course, due_date, status}], upcoming_sessions: [{...}], certificates: [{...}], completion_percent: float, pending_approvals: int}}
Lifecycle Monitor — All Jobs
Job	Trigger	Frequency	DB Call / Action
events_fanout	pg_notify + poll	every 5s	Poll events_outbox, route, mark processed
cert_expiry	cron	every hour	Query certs expiring ≤30d, send notifications
overdue_training	cron	every hour	mark_overdue_reviews(), query overdue obligations, escalate
integrity_check	cron	nightly	verify_audit_hash_chain() RPC, update system_health_checks
archive	cron	nightly	archive_jobs table per retention_policies, write data_archives
password_expiry	cron	daily	Scan user_credentials.expires_at, send 7d/1d warning emails
session_cleanup	cron	every 15m	Revoke user_sessions where expires_at < NOW()
compliance_metrics	cron	every 6h	Recalculate employees.compliance_percent per plant
periodic_review	cron	daily	mark_overdue_reviews() for periodic_review_schedules
workflow_engine — Internal Structure
Port 8085. No external exposure. Only WorkflowListenerService (pg_notify + 5s poll) calls its own handlers internally.

workflow_engine/
  bin/server.dart                          ← RelicApp on :8085 (internal network only)
  lib/
    routes/
      internal/
        advance_step_handler.dart          ← POST /internal/workflow/advance-step
        complete_workflow_handler.dart     ← POST /internal/workflow/complete
        reject_workflow_handler.dart       ← POST /internal/workflow/reject
        routes.dart
      health_handler.dart                  ← GET /health
      routes.dart
    services/
      workflow_listener_service.dart       ← pg_notify channel 'workflow_events' + 5s poll
      approval_state_machine.dart          ← Core FSM: load matrix → advance step → notify
    workflow_engine.dart
  pubspec.yaml                             ← same deps as lifecycle_monitor
Approval state machine flow (advance_step_handler.dart):

Load approval_matrices row for {entity_type, organization_id}
Find current approval_steps row where status = 'PENDING' and lowest step_order
Mark step APPROVED (with esig_id from event payload)
Check if more steps remain → if YES: notify next approver via supabase.functions.invoke('send-notification')
If NO more steps: update entity status to 'EFFECTIVE' + publish {entity_type}.approved event
workflow_listener_service.dart (pg_notify pattern, identical to lifecycle_monitor):

// Subscribes to pg_notify channel for workflow events (document.submitted, course.submitted, gtp.submitted, etc.)
// Falls back to 5s polling of events_outbox WHERE event_type LIKE '%.submitted'
// On receipt: POSTs internally to /internal/workflow/advance-step
auth-hook Edge Function — Required Changes
File: supabase/functions/auth-hook/index.ts

The hook exists and already embeds employee_id, organization_id, plant_id. Two additions required:

// ADD to auth-hook/index.ts after existing claims extraction:
const { data: permissions } = await supabaseAdmin
  .rpc('get_employee_permissions', { p_employee_id: employee.id });

const { data: employee_record } = await supabaseAdmin
  .from('employees')
  .select('induction_completed')
  .eq('id', employee.id)
  .single();

return {
  ...existingResponse,
  app_metadata: {
    ...existingResponse.app_metadata,
    permissions: permissions ?? [],           // NEW: string[] e.g. ['documents.approve', 'courses.create']
    induction_completed: employee_record?.induction_completed ?? false,  // NEW: boolean
  }
};
auth_middleware.dart reads these without any extra DB call:

final appMeta  = jwtPayload['app_metadata'] as Map<String, dynamic>;
final permissions       = List<String>.from(appMeta['permissions'] ?? []);
final inductionDone     = appMeta['induction_completed'] as bool? ?? false;
final authCtx = AuthContext(
  userId: jwtPayload['sub']!,
  employeeId: appMeta['employee_id']!,
  orgId: appMeta['organization_id']!,
  plantId: appMeta['plant_id']!,
  permissions: permissions,
  inductionCompleted: inductionDone,
  sessionId: jwtPayload['jti']!,
);
Dev / Prod Setup
Makefile (repo root)
.PHONY: dev codegen codegen-watch test docker-prod

# Start all 3 servers locally (dart run, hot-reloadable)
dev:
	supabase start &
	cd apps/api_server/pharma_learn/api && dart run bin/server.dart &
	cd apps/api_server/pharma_learn/lifecycle_monitor && dart run bin/server.dart &
	cd apps/api_server/pharma_learn/workflow_engine && dart run bin/server.dart &
	@echo "API :8080 | Lifecycle :8086 | Workflow :8085 | Supabase Studio :54323"

# Flutter code generation (all generators in one pass)
codegen:
	cd apps/pharma_learn && dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
codegen-watch:
	cd apps/pharma_learn && dart run build_runner watch --delete-conflicting-outputs

# Run all tests
test:
	dart test apps/api_server/pharma_learn/api/test/
	dart test apps/api_server/pharma_learn/lifecycle_monitor/test/
	flutter test apps/pharma_learn/test/

# Production deployment
docker-prod:
	docker compose -f docker-compose.prod.yml up --build -d
docker-compose.prod.yml (production)
services:
  nginx:
    image: nginx:alpine
    ports: ["80:80", "443:443"]
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on: [pharma_api]

  pharma_api:
    build:
      context: ./apps/api_server/pharma_learn/api
      dockerfile: Dockerfile
    environment:
      PORT: 8080
      SUPABASE_URL: ${SUPABASE_URL}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
    ports: ["8080:8080"]   # internal; nginx proxies externally
    restart: unless-stopped

  lifecycle_monitor:
    build:
      context: ./apps/api_server/pharma_learn/lifecycle_monitor
      dockerfile: Dockerfile
    environment:
      PORT: 8086
      SUPABASE_URL: ${SUPABASE_URL}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
    ports: ["8086:8086"]   # internal only, not exposed to internet
    restart: unless-stopped

  workflow_engine:
    build:
      context: ./apps/api_server/pharma_learn/workflow_engine
      dockerfile: Dockerfile
    environment:
      PORT: 8085
      SUPABASE_URL: ${SUPABASE_URL}
      SUPABASE_SERVICE_ROLE_KEY: ${SUPABASE_SERVICE_ROLE_KEY}
    ports: ["8085:8085"]   # internal only
    restart: unless-stopped
NGINX config (nginx.conf — reverse proxy)
upstream pharma_api { server pharma_api:8080; }

server {
  listen 443 ssl;
  server_name app.pharmalearn.internal;

  location /v1/ { proxy_pass http://pharma_api; }
  location /health { proxy_pass http://pharma_api; }
  location /metrics { deny all; }  # Prometheus internal only

  # CORS handled by Relic cors_middleware; NGINX passes through
  proxy_set_header Host $host;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Real-IP $remote_addr;
}
Prometheus Metrics
Each Relic server exposes GET /metrics on its port (internal only; NGINX blocks /metrics externally).

// packages/pharmalearn_shared/lib/src/middleware/metrics_middleware.dart
// Counters exposed:
// pharma_api_requests_total{method, route, status}
// pharma_api_response_ms{route}                    ← histogram
// pharma_events_outbox_pending                      ← gauge (lifecycle_monitor only)
// pharma_failed_logins_total
// pharma_esig_operations_total{meaning}
// pharma_rate_limit_hits_total{endpoint}

// Collected by Prometheus scraping :8080/metrics, :8086/metrics, :8085/metrics
// Grafana dashboards for: request rate, p95 latency, outbox lag, failed login rate
Vyuh Screen Classification
Auto-generated via vyuh_entity_system (@VyuhEntity())
Simple CRUD — no multi-step workflow, no e-sig, no domain-specific UX:

Config: approval matrices, numbering schemes, retention policies, system settings, feature flags, validation rules, password policies
Master data: standard reasons, categories
Resources: venues, roles, groups, delegations, question banks, competencies, trainers, coordinators, periodic reviews

Vyuh @VyuhEntity code generation pattern (pub.vyuh.tech packages — NOT CMS Sanity Vyuh):
// features/access/models/role_model.dart
import 'package:vyuh_entity_annotations/vyuh_entity_annotations.dart';
import 'package:json_annotation/json_annotation.dart';
part 'role_model.g.dart';

@VyuhEntity(
  endpoint: '/v1/access/roles',        // maps GET / POST / PATCH / DELETE on this path
  displayName: 'Roles',
  icon: Icons.badge_outlined,
)
@JsonSerializable()
class RoleModel {
  final String? id;

  @VyuhProperty(label: 'Role Name', required: true)
  final String name;

  @VyuhProperty(label: 'Role Level', type: PropertyType.integer)
  final int roleLevel;

  @VyuhProperty(label: 'Description')
  final String? description;

  RoleModel({this.id, required this.name, required this.roleLevel, this.description});
  factory RoleModel.fromJson(Map<String, dynamic> json) => _$RoleModelFromJson(json);
  Map<String, dynamic> toJson() => _$RoleModelToJson(this);
}

// run: dart run build_runner build --delete-conflicting-outputs
// generates: RolesListScreen (sortable, filterable), RoleDetailScreen, RoleEditScreen
// wire into app_router.dart: GoRoute(path: '/roles', builder: (ctx, _) => RolesListScreen())

// vyuh_table usage for compliance tables:
VyuhTable<EmployeeAssignment>(
  columns: [
    VyuhColumn(label: 'Employee', valueBuilder: (r) => r.employeeName),
    VyuhColumn(label: 'Course', valueBuilder: (r) => r.courseName),
    VyuhColumn(label: 'Due Date', valueBuilder: (r) => r.dueDate.toLocal().toString()),
    VyuhColumn(label: 'Status', valueBuilder: (r) => r.status, color: (r) => r.statusColor),
  ],
  onSort: (col, asc) => store.sortObligations(col, asc),
  onFilter: (query) => store.filterObligations(query),
)

// vyuh_timelines usage for document version history:
VyuhTimeline(
  events: document.versions.map((v) => TimelineEvent(
    title: 'Version ${v.versionNo}',
    subtitle: v.approvedBy,
    timestamp: v.approvedAt,
    icon: Icons.check_circle,
  )).toList(),
)

// vyuh_rule_engine usage for on-device training eligibility check:
final engine = RuleEngine();
final canEnroll = engine.evaluate(
  rules: course.eligibilityRules,
  context: {'employee_grade': auth.grade, 'department': auth.department},
);
if (!canEnroll) showIneligibilityReason(engine.lastFailedRule);

Fully custom Flutter screens
Complex UX, multi-step flows, domain-specific interactions:

Auth: login, MFA setup/verify, biometric enrollment, SSO login, password reset, induction flow
Documents: document detail + review (inline PDF), approval action with e-sig dialog
Assessment: assessment player (timed, question-by-question, submit with e-sig)
Training: session check-in (QR scanner / biometric), OJT sign-off (dual-person e-sig), my dashboard (fl_chart graphs)
Certificates: two-person revocation dialog, certificate PDF viewer, public verify page
Compliance: compliance dashboard (fl_chart, data_table_2), compliance report download
Workflow: pending approvals queue, approval detail with e-sig dialog
E-sig: EsigDialog (reused across all esig actions — prompts password, creates reauth, returns reauth_session_id)
NOT used: vyuh_workflow_engine (not in pubspec; Relic workflow_engine server handles all approval FSM logic); vyuh_form_editor (not in pubspec); Sanity/CMS Vyuh integrations (not in pubspec)
SCORM 1.2 Runtime — JS Bridge Pattern
Flutter WebView (flutter_inappwebview)
  ↓ loads signed URL to scorm_packages Storage
  ↓ injects SCORM API shim: sets window.API = PharmaLearnAPI
  ↓ SCORM content calls window.API.LMSCommit("")
  ↓ JS handler → JavaScriptMessageHandler('LMSCommit')
  ↓ scormStore.commitCmi(sessionId, cmiData)
  ↓ POST /v1/scorm/:id/commit → {lesson_status, score_raw, suspend_data, time}
  ↓ scorm_commit_handler.dart upserts scorm_cmi + updates training_records
  ↓ if lesson_status='passed' → publish assessment.submitted event → cert generation
SCORM offline: CMI commits buffered in Hive ScormCmiCache; synced on reconnect in order. Server upserts are idempotent (same session_id, sequence_number).

Offline Sync — 4 Hive Scenarios
Scenario	Cache key	TTL	Sync strategy
Session check-in	checkin_{sessionId}_{employeeId}	Until synced	On reconnect: check server record exists → if exists discard (server-wins); else POST
Dashboard data	dashboard_{employeeId}	30 min	Background refresh on app foreground; stale-while-revalidate
Viewed PDFs	pdf_{documentId}_{version}	LRU 20 docs	Evict oldest on download of new doc
SCORM CMI commits	scorm_cmi_{sessionId}_{seq}	Until synced	On reconnect: POST each commit in sequence order; server upserts idempotently
Conflict resolution: Server-wins for check-in. If session_attendance row exists for (session_id, employee_id), offline record is discarded silently.

Implementation Build Order
Build in this exact sequence to always have a runnable server:

Sprint	Files	Outcome
S1: Foundation	pharmalearn_shared/ (all), api/bin/server.dart, api/lib/pharma_learn_api.dart, health routes, Makefile	Server starts, GET /health → 200, make dev works
S2: Auth	access/auth/*, access/employees/*, access/roles/*, auth-hook additions	POST /v1/auth/login works; JWT middleware live; permissions in JWT claims
S3: Create	create/documents/*, create/courses/*, create/gtps/*, create/config/*	Document CRUD + approval flow + e-sig middleware
S4: Train	train/schedules/*, train/sessions/*, train/me/*, train/induction/*	Check-in/check-out; dashboard; induction gate
S5: Certify	certify/assessments/*, certify/certificates/*, certify/reauth/*, certify/compliance/*	Assessment submit + two-person revoke + compliance dashboard
S6: Workflow	workflow/approvals/*, workflow/notifications/*, workflow/audit/*, workflow/quality/*	Pending approvals queue; audit trail queries
S7: Lifecycle	lifecycle_monitor/ (all files), workflow_engine/ (all files)	Events fanout; cert expiry; integrity check; approval state machine
S8: SCORM	create/scorm/*, SCORM service, flutter_inappwebview JS bridge	SCORM 1.2 upload + launch + CMI commit via JS bridge
S9: MobX client	Flutter stores + repositories + router + Vyuh entity screens	End-to-end Flutter → API; codegen: make codegen; @VyuhEntity() classes → build_runner → auto CRUD screens for roles, venues, question banks, trainers etc.

UserManual Gap Analysis — Missing Endpoints (Phase 3)
Source: ref/usermANUAL.pdf (Caliber learn-iq LMS, 153 pages). Every feature in the manual was cross-checked against the actual routes.dart files for all five domains. 17 gaps were identified. They are documented here ordered by priority (HIGH → MEDIUM → LOW) so they can be phased into S4/S5/S6 sprints or a new S10 sprint.

Status of non-gap routes (confirmed complete): sessions (full CRUD + check-in/check-out + QR + attendance), batches, OJT (per-task e-sig, sign-off), self-learning (SCORM flow), assessments (start/answer/submit/grade/publish/queue), certificates (3-step revocation), compliance dashboard, waivers (e-sig), competencies + definitions CRUD, question banks, question papers (publish with e-sig), trainers (approve with e-sig), venues, groups, delegations, SSO, biometric enrollment, audit trails, standard reasons, document manager, reports engine (all 15 report types), Prometheus /metrics, all 11 MobX stores.

─────────────────────────────────────────────────────────────────────────────
🔴 HIGH PRIORITY — Core training lifecycle features missing from API
─────────────────────────────────────────────────────────────────────────────

GAP-H1: Feedback & Evaluation Templates CRUD
Manual ref: §6.1.5 (Feedback Template), §6.1.17 (Evaluation Template)
Current state: feedback_templates + evaluation_templates tables exist in DB; zero API endpoints.
Without this: coordinators cannot define the forms used in post-training feedback and evaluations.
Every downstream GAP-H2, GAP-H3, GAP-H4 depends on template definitions existing first.

  Handler files to create:
    create/feedback/feedback_templates_handler.dart    ← GET|POST /v1/feedback-templates
    create/feedback/feedback_template_handler.dart     ← GET|PATCH|DELETE /v1/feedback-templates/:id
    create/feedback/evaluation_templates_handler.dart  ← GET|POST /v1/evaluation-templates
    create/feedback/evaluation_template_handler.dart   ← GET|PATCH|DELETE /v1/evaluation-templates/:id

  Endpoints:
    GET    /v1/feedback-templates              → list (paginated, filterable by type)
    POST   /v1/feedback-templates              → create; body: {name, questions[{text,type,options[]}], is_active}
    GET    /v1/feedback-templates/:id          → detail
    PATCH  /v1/feedback-templates/:id          → update (name, questions, is_active)
    DELETE /v1/feedback-templates/:id          → soft-delete (set is_active=false if in use)
    GET    /v1/evaluation-templates            → list
    POST   /v1/evaluation-templates            → create; body: {name, evaluation_type ('short_term'|'long_term'), questions[...]}
    GET    /v1/evaluation-templates/:id        → detail
    PATCH  /v1/evaluation-templates/:id        → update
    DELETE /v1/evaluation-templates/:id        → soft-delete

  DB tables: feedback_templates, evaluation_templates
  Mount in: mountCreateRoutes()

GAP-H2: Post-Training Feedback Submission (Trainee)
Manual ref: §6.1.13 (Feedback by trainee after session/batch completes)
Current state: feedback_templates table exists; no feedback submission endpoint.
Without this: trainees cannot submit post-training satisfaction feedback; Section 6.2.6 (Feedback Report) returns empty data.

  Handler files to create:
    train/feedback/session_feedback_handler.dart

  Endpoints:
    POST  /v1/train/sessions/:id/feedback     → trainee submits feedback; body: {feedback_template_id, responses[{question_id, answer}]}
    GET   /v1/train/sessions/:id/feedback     → coordinator views aggregated responses; returns per-question stats

  DB tables: session_feedback (or feedback_responses linked to session_id + employee_id + feedback_template_id)
  Guard: employee must have session_attendance row with status='attended' for the session_id
  Mount in: mountTrainRoutes() → sessions sub-router

GAP-H3: Short-Term Evaluation (Supervisor evaluates trainee post-training)
Manual ref: §6.1.14 (Short-Term Evaluation — supervisor fills within ~1 month of training)
Current state: short_term_evaluations table exists; no API endpoint.
Without this: supervisors cannot record whether training transferred to on-the-job behaviour (regulatory requirement for effectiveness evaluation in pharma).

  Handler files to create:
    train/evaluations/short_term_evaluation_handler.dart

  Endpoints:
    POST  /v1/train/batches/:id/short-term-evaluation   → supervisor submits evaluation; body: {evaluation_template_id, employee_id, responses[...], overall_rating}
    GET   /v1/train/batches/:id/short-term-evaluation   → list all short-term evaluations for batch; returns per-employee rating summary
    GET   /v1/train/batches/:id/short-term-evaluation/:employee_id → individual evaluation detail

  DB tables: short_term_evaluations, evaluation_responses
  Guard: requester must be supervisor (role_level check) or coordinator
  Mount in: mountTrainRoutes()

GAP-H4: Long-Term Evaluation (Supervisor periodic follow-up, 3–6 months post-training)
Manual ref: §6.1.15 (Long-Term Evaluation)
Current state: long_term_evaluations table exists; no API endpoint.
Without this: periodic training effectiveness data not captured; GMP audit finding risk.

  Handler files to create:
    train/evaluations/long_term_evaluation_handler.dart

  Endpoints:
    POST  /v1/train/batches/:id/long-term-evaluation    → supervisor submits follow-up evaluation; body: {evaluation_template_id, employee_id, responses[...], observation_period_months}
    GET   /v1/train/batches/:id/long-term-evaluation    → list all long-term evaluations for batch
    GET   /v1/train/batches/:id/long-term-evaluation/:employee_id → individual detail

  DB tables: long_term_evaluations, evaluation_responses
  Guard: same as GAP-H3
  Mount in: mountTrainRoutes()

GAP-H5: External Training Registration
Manual ref: §6.1.20 (External Training — training conducted outside the organisation)
Current state: external_training_records table exists; no API endpoint.
Without this: training completed at external institutions/conferences/workshops cannot be recorded in the LMS; employee training histories are incomplete for regulatory audit.

  Handler files to create:
    train/external/external_training_handler.dart

  Endpoints:
    POST   /v1/train/external-training                  → employee or coordinator submits external training record; body: {employee_id, course_name, institution_name, completion_date, certificate_attachment_id, training_hours, training_type}
    GET    /v1/train/external-training                  → list (paginated; filterable by employee_id, date range)
    GET    /v1/train/external-training/:id              → detail
    PATCH  /v1/train/external-training/:id              → update before approval (e.g. attach scanned certificate)
    POST   /v1/train/external-training/:id/approve      → coordinator approves; optionally triggers training_records insert; body: {esig: {reauth_session_id, meaning}}

  DB tables: external_training_records
  Mount in: mountTrainRoutes()

GAP-H6: Self-Nomination for Scheduled Sessions
Manual ref: §6.1.11 (Self-Nomination — employee nominates themselves for an open training schedule)
Current state: training_nominations table exists; no nomination API endpoint. Current enrollment is coordinator-only via POST /v1/train/schedules/:id/enroll.
Without this: employees cannot self-register for optional or elective training; coordinators must manually enrol every attendee.

  Handler files to create:
    train/schedules/schedule_self_nominate_handler.dart

  Endpoints:
    POST   /v1/train/schedules/:id/self-nominate        → employee nominates self; body: {reason?}; creates training_nominations row + optionally auto-enrols if seats available
    DELETE /v1/train/schedules/:id/self-nominate        → withdraw nomination before acceptance
    GET    /v1/train/schedules/:id/nominations          → coordinator views all nominations; returns {employee_id, nominated_at, status}
    POST   /v1/train/schedules/:id/nominations/:employee_id/accept → coordinator accepts nomination → creates enrollment
    POST   /v1/train/schedules/:id/nominations/:employee_id/reject → coordinator rejects; body: {reason}

  DB tables: training_nominations
  Mount in: mountTrainRoutes() → schedules sub-router

─────────────────────────────────────────────────────────────────────────────
🟡 MEDIUM PRIORITY — Workflow completeness gaps
─────────────────────────────────────────────────────────────────────────────

GAP-M1: Induction — Coordinator-Side Registration
Manual ref: §4.1 (System Manager registers employee for induction on their behalf)
Current state: induction routes only serve the employee's self-service view (GET /v1/train/induction/status, modules, complete). Coordinators have no endpoint to register an employee for induction or view all induction statuses.

  Handler files to create:
    train/induction/induction_coordinator_handler.dart

  Endpoints:
    POST  /v1/train/induction                           → coordinator registers employee for induction; body: {employee_id, induction_template_id, start_date}; inserts employee_induction row
    GET   /v1/train/induction                           → coordinator lists all employee inductions; filterable by status, department, date range
    GET   /v1/train/induction/:id                       → coordinator views specific employee_induction record + progress per module

  DB tables: employee_induction, employee_induction_progress
  Guard: requester must have INDUCTION_MANAGE permission
  Mount in: mountTrainRoutes() — separate path from the employee-facing GET /v1/train/induction/status

GAP-M2: Induction — Trainer Accept/Respond
Manual ref: §6.1.4 (Trainer accepts or declines induction request)
Current state: no trainer-side endpoint for induction; trainer cannot acknowledge assignment.

  Handler files to create:
    train/induction/induction_trainer_handler.dart

  Endpoints:
    POST  /v1/train/induction/:id/trainer-respond       → trainer accepts or declines; body: {accepted: bool, notes?}; updates employee_induction.trainer_confirmed=true or triggers reassignment flow

  DB tables: employee_induction (trainer_id, trainer_confirmed), audit_trails
  Guard: requester must be the trainer assigned (employee_induction.trainer_id = auth user)
  Mount in: mountTrainRoutes()

GAP-M3: Induction — Trainer Records Completion
Manual ref: §6.1.4 (Trainer marks employee as inducted; triggers training_record + certificate)
Current state: POST /v1/train/induction/complete is employee self-service only; there is no trainer-initiated completion record endpoint.

  Handler files to create (add endpoint to induction_coordinator_handler.dart):
    Endpoint added to: train/induction/induction_coordinator_handler.dart

  Endpoints:
    POST  /v1/train/induction/:id/record                → trainer/coordinator marks induction as complete; body: {esig: {reauth_session_id, meaning}}; writes training_records row + triggers certificate generation

  DB tables: employee_induction (status='completed'), training_records, certificates
  Guard: withEsig() middleware; requester must be trainer (employee_induction.trainer_id) or coordinator
  Mount in: mountTrainRoutes()

GAP-M4: Offline Document Reading — Coordinator Records Completion
Manual ref: §6.1.7 (Coordinator marks document reading as done for employees who completed offline/paper)
Current state: document reading is tracked via self-learning/progress endpoint (online SCORM/WBT flow). No endpoint for coordinator to bulk-mark offline reading as complete.

  Handler files to create:
    train/sessions/session_doc_reading_offline_handler.dart

  Endpoints:
    POST  /v1/train/sessions/:id/doc-reading/offline    → coordinator bulk-marks employees as having read doc offline; body: {employee_ids[], completed_at, document_id, evidence_reference?}; upserts content_view_tracking + learning_progress for each employee

  DB tables: content_view_tracking, learning_progress, audit_trails
  Guard: requester must have SESSION_MANAGE permission
  Mount in: mountTrainRoutes() → sessions sub-router

GAP-M5: Course Retraining Assignment
Manual ref: §6.1.19 (Coordinator creates a retraining assignment when an employee fails or competency lapses)
Current state: no dedicated retraining endpoint. Coordinators must manually create a new training_assignment. Retraining lacks a linked reason/original-failure reference which is needed for audit trail in GMP contexts.

  Handler files to create:
    train/retraining/retraining_handler.dart

  Endpoints:
    POST  /v1/train/retraining                          → create retraining assignment; body: {employee_id, course_id, reason ('assessment_fail'|'competency_lapse'|'capa'|'periodic'), original_assignment_id?, due_date}; inserts training_retraining_requests + spawns new employee_assignments row with status='assigned'
    GET   /v1/train/retraining                          → list retraining assignments (coordinator view); filterable by employee, course, reason
    GET   /v1/train/retraining/:id                      → detail with original assignment link + current status

  DB tables: training_retraining_requests, employee_assignments
  Mount in: mountTrainRoutes()

GAP-M6: Pending Task Termination (Employee Deactivation / Transfer)
Manual ref: §4.3 (When an employee is deactivated or transferred, all their open training obligations must be terminable by admin)
Current state: PATCH /v1/access/employees/:id/deactivate exists (sets employees.status='inactive') but does NOT terminate in-flight training obligations, open assessment attempts, or pending approval requests.

  Handler files to create:
    access/employees/employee_task_terminate_handler.dart

  Endpoints:
    POST  /v1/access/employees/:id/pending-tasks/terminate   → admin terminates all open obligations for employee; body: {reason, esig: {reauth_session_id, meaning}}; updates employee_assignments to status='cancelled', assessment_attempts to status='terminated', workflow_requests to status='withdrawn'

  DB tables: employee_assignments, assessment_attempts, workflow_requests, audit_trails
  Guard: withEsig(); requester must have EMPLOYEE_MANAGE or ADMIN permission
  Mount in: mountAccessRoutes()

GAP-M7: Question Paper Extension Request
Manual ref: §6.2.11 (QP Extension — employee or coordinator requests additional time on a running assessment)
Current state: assessment_attempts table + question_paper_extensions table exist; no endpoint to request or approve an extension.

  Handler files to create:
    certify/assessments/assessment_extend_handler.dart

  Endpoints:
    POST  /v1/certify/assessments/:id/extend             → employee requests extension; body: {requested_extension_minutes, reason}; inserts question_paper_extensions row with status='pending'
    POST  /v1/certify/assessments/:id/extend/approve     → coordinator approves; body: {extension_minutes_granted, esig: {...}}; updates question_paper_extensions.status='approved' + extends assessment_attempts.time_limit by granted minutes at server side
    POST  /v1/certify/assessments/:id/extend/reject      → coordinator rejects; body: {reason}

  DB tables: question_paper_extensions, assessment_attempts
  Guard: approve/reject require ASSESSMENT_MANAGE permission; withEsig() on approve
  Mount in: mountCertifyRoutes() → assessments sub-router

─────────────────────────────────────────────────────────────────────────────
🟠 LOW PRIORITY — Supplementary features
─────────────────────────────────────────────────────────────────────────────

GAP-L1: Self-Study Open Courses (Employee-Elected Non-Obligation Learning)
Manual ref: §6.1.21 (Self-Study — employee browses and enrolls in open courses not assigned as obligations)
Current state: self_study_courses table exists; no browse/enroll endpoints. Current learning is obligation-driven only.

  Handler files to create:
    train/self_study/self_study_handler.dart

  Endpoints:
    GET   /v1/train/self-study-courses                  → browse catalogue of open courses; filterable by category, type, duration; returns {id, name, description, duration_hours, thumbnail_url, enrolled_count}
    GET   /v1/train/self-study-courses/:id              → course detail + module list
    POST  /v1/train/self-study-courses/:id/enroll       → employee self-enrolls; creates self_study_enrollments row + spawns learning_progress tracking
    GET   /v1/train/self-study-courses/:id/progress     → employee's own progress in this self-study course
    DELETE /v1/train/self-study-courses/:id/enroll      → unenroll (if not yet started)

  DB tables: self_study_courses, self_study_enrollments, learning_progress
  Mount in: mountTrainRoutes()

GAP-L2: Document Reading Termination (Admin Terminates In-Progress Doc Reading)
Manual ref: §6.1.7 (Admin can terminate an in-progress document reading assignment)
Current state: no termination endpoint for document reading; content_view_tracking rows can only be completed or abandoned.

  Handler files to create:
    train/sessions/session_doc_reading_terminate_handler.dart

  Endpoints:
    POST  /v1/train/sessions/:id/doc-reading/terminate  → admin terminates in-progress document reading; body: {employee_ids[], reason}; updates learning_progress.status='terminated' + content_view_tracking metadata; logs in audit_trails

  DB tables: content_view_tracking, learning_progress, audit_trails
  Guard: requester must have SESSION_MANAGE or ADMIN permission
  Mount in: mountTrainRoutes() → sessions sub-router

GAP-L3: Print Attendance Sheet (PDF Download for Batch)
Manual ref: §6.1.12 (Coordinator prints a physical attendance sheet PDF for paper sign-in during in-person sessions)
Current state: attendance data is stored in session_attendance; no PDF generation endpoint for an attendance roster sheet.

  Handler files to create:
    train/batches/batch_attendance_sheet_handler.dart

  Endpoints:
    GET   /v1/train/batches/:id/attendance-sheet        → generates attendance roster PDF via Edge Function (or returns pre-generated signed URL); PDF contains: session details, scheduled date/time, venue, list of enrolled employees with blank signature columns

  DB tables: training_batches, session_attendance, training_sessions
  Implementation: call supabase.functions.invoke('generate-attendance-sheet', {batch_id}); return signed Storage URL with Content-Disposition: attachment
  Mount in: mountTrainRoutes() → batches sub-router

GAP-L4: Print Question Paper (PDF for Offline/Paper Exam)
Manual ref: §6.2.11 (Coordinator prints question paper PDF for offline paper-based exams)
Current state: question papers have full CRUD + publish endpoint; no PDF render endpoint.

  Handler files to create:
    create/question_papers/question_paper_print_handler.dart

  Endpoints:
    GET   /v1/question-papers/:id/print                 → returns PDF of the question paper; query params: {include_answers: false (default)} for answer-key variant; calls generate-question-paper Edge Function; returns signed URL or inline PDF (Content-Disposition: attachment)

  DB tables: question_papers, question_paper_items, question_bank_questions
  Guard: question paper must be in status='published' to allow print; requires QUESTION_PAPER_MANAGE permission
  Mount in: mountCreateRoutes() → question_papers sub-router

─────────────────────────────────────────────────────────────────────────────
Phase 3 Gap Summary Table
─────────────────────────────────────────────────────────────────────────────
Priority	Gap ID	Feature	Endpoints (count)	DB Tables
🔴 HIGH	GAP-H1	Feedback/Evaluation Templates CRUD	10	feedback_templates, evaluation_templates
🔴 HIGH	GAP-H2	Post-training Feedback Submission (trainee)	2	session_feedback, feedback_responses
🔴 HIGH	GAP-H3	Short-Term Evaluation (supervisor)	3	short_term_evaluations, evaluation_responses
🔴 HIGH	GAP-H4	Long-Term Evaluation (supervisor)	3	long_term_evaluations, evaluation_responses
🔴 HIGH	GAP-H5	External Training Registration + Approval	5	external_training_records
🔴 HIGH	GAP-H6	Self-Nomination for Sessions	5	training_nominations
🟡 MED	GAP-M1	Induction Coordinator Registration	3	employee_induction, employee_induction_progress
🟡 MED	GAP-M2	Induction Trainer Accept/Respond	1	employee_induction
🟡 MED	GAP-M3	Induction Trainer Records Completion	1	employee_induction, training_records, certificates
🟡 MED	GAP-M4	Offline Document Reading Record	1	content_view_tracking, learning_progress
🟡 MED	GAP-M5	Course Retraining Assignment	3	training_retraining_requests, employee_assignments
🟡 MED	GAP-M6	Pending Task Termination (deactivation)	1	employee_assignments, assessment_attempts
🟡 MED	GAP-M7	QP Extension Request + Approve/Reject	3	question_paper_extensions, assessment_attempts
🟠 LOW	GAP-L1	Self-Study Open Courses Catalogue + Enroll	5	self_study_courses, self_study_enrollments
🟠 LOW	GAP-L2	Document Reading Termination	1	content_view_tracking, learning_progress
🟠 LOW	GAP-L3	Print Attendance Sheet PDF	1	training_batches, session_attendance
🟠 LOW	GAP-L4	Print Question Paper PDF	1	question_papers, question_paper_items
Total			49 new endpoints	13 DB tables (all already in schema)

Phase 3 Sprint Recommendation:
S10a (2 weeks): GAP-H1 through GAP-H4 — Feedback/evaluation infrastructure (templates + submission + short/long-term eval). Unblocks Section 6.2 report accuracy.
S10b (1 week): GAP-H5 + GAP-H6 — External training + self-nomination. Completes the training intake surface.
S10c (2 weeks): GAP-M1 through GAP-M4 — Induction coordinator/trainer flows + offline doc reading. Closes the induction lifecycle.
S10d (1 week): GAP-M5 through GAP-M7 — Retraining, task termination, QP extension. Closes compliance edge cases.
S10e (1 week): GAP-L1 through GAP-L4 — Self-study, terminations, PDF prints. Polish sprint.

Note: All 13 DB tables are already in the frozen schema. Zero migrations required for Phase 3 — only new handler files + route mounts.
