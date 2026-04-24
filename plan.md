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
          employees_handler.dart      ← GET|POST /v1/employees
          employee_handler.dart       ← GET|PATCH /v1/employees/[id]
          employee_roles_handler.dart ← GET|POST|DELETE /v1/employees/[id]/roles
          employee_creds_handler.dart ← POST /v1/employees/[id]/credentials, .../unlock
          routes.dart
        roles/
          roles_handler.dart          ← GET|POST /v1/roles
          role_handler.dart           ← GET|PATCH|DELETE /v1/roles/[id]
          routes.dart
        groups/
          groups_handler.dart         ← GET|POST /v1/groups
          group_handler.dart          ← GET|PATCH /v1/groups/[id]
          group_members_handler.dart  ← GET|POST /v1/groups/[id]/members
          routes.dart
        delegations/
          delegations_handler.dart    ← GET|POST /v1/delegations
          delegation_handler.dart     ← GET /v1/delegations/[id]
          delegation_revoke_handler.dart ← POST /v1/delegations/[id]/revoke
          routes.dart
        sso/
          sso_configs_handler.dart    ← GET|POST /v1/sso/configurations
          sso_config_handler.dart     ← GET|PATCH /v1/sso/configurations/[id]
          sso_test_handler.dart       ← POST /v1/sso/configurations/[id]/test
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
          document_handler.dart       ← GET|PATCH|DELETE /v1/documents/[id]
          document_submit_handler.dart   ← POST /v1/documents/[id]/submit
          document_approve_handler.dart  ← POST /v1/documents/[id]/approve [esig]
          document_reject_handler.dart   ← POST /v1/documents/[id]/reject [esig]
          document_versions_handler.dart ← GET /v1/documents/[id]/versions
          document_readings_handler.dart ← GET|POST /v1/documents/[id]/readings
          document_reading_ack_handler.dart ← POST .../readings/[id]/acknowledge [esig]
          document_integrity_handler.dart   ← GET /v1/documents/[id]/integrity
          document_issue_handler.dart       ← POST /v1/documents/[id]/issue-copy
          routes.dart
        courses/
          courses_handler.dart        ← GET|POST /v1/courses
          course_handler.dart         ← GET|PATCH /v1/courses/[id]
          course_submit_handler.dart  ← POST /v1/courses/[id]/submit
          course_approve_handler.dart ← POST /v1/courses/[id]/approve [esig]
          course_topics_handler.dart  ← GET|POST /v1/courses/[id]/topics
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
          schedules_handler.dart      ← GET|POST /v1/schedules
          schedule_handler.dart       ← GET|PATCH /v1/schedules/[id]
          schedule_submit_handler.dart   ← POST /v1/schedules/[id]/submit
          schedule_approve_handler.dart  ← POST /v1/schedules/[id]/approve [esig]
          schedule_assign_handler.dart   ← POST /v1/schedules/[id]/assign (bulk TNI)
          schedule_enroll_handler.dart   ← POST /v1/schedules/[id]/enroll
          schedule_sessions_handler.dart ← GET|POST /v1/schedules/[id]/sessions
          schedule_invitations_handler.dart ← GET|POST /v1/schedules/[id]/invitations
          schedule_batches_handler.dart  ← GET|POST /v1/schedules/[id]/batches
          routes.dart
        sessions/
          sessions_handler.dart       ← GET /v1/sessions
          session_handler.dart        ← GET|PATCH /v1/sessions/[id]
          session_checkin_handler.dart   ← POST /v1/sessions/[id]/check-in (QR/biometric)
          session_checkout_handler.dart  ← POST /v1/sessions/[id]/check-out
          session_attendance_handler.dart ← GET /v1/sessions/[id]/attendance
          session_attendance_mark_handler.dart ← PATCH /v1/sessions/[id]/attendance/[empId]
          session_attendance_bulk_handler.dart ← POST /v1/sessions/[id]/mark-attendance
          session_complete_handler.dart  ← POST /v1/sessions/[id]/complete [esig]
          routes.dart
        obligations/
          obligations_handler.dart    ← GET|POST /v1/obligations
          obligation_handler.dart     ← GET /v1/obligations/[id]
          obligation_waive_handler.dart ← POST /v1/obligations/[id]/waive [esig]
          routes.dart
        induction/
          induction_handler.dart      ← GET /v1/induction (my status)
          induction_items_handler.dart ← GET /v1/induction/[programId]/items
          induction_item_complete_handler.dart ← POST .../items/[itemId]/complete
          induction_complete_handler.dart ← POST /v1/induction/complete [esig]
          routes.dart
        ojt/
          ojt_handler.dart            ← GET|POST /v1/ojt
          ojt_detail_handler.dart     ← GET /v1/ojt/[id]
          ojt_items_handler.dart      ← GET /v1/ojt/[id]/items
          ojt_signoff_handler.dart    ← POST /v1/ojt/[id]/sign-off [two-person esig, witness]
          ojt_complete_handler.dart   ← POST /v1/ojt/[id]/complete [esig]
          routes.dart
        self_learning/
          self_learning_handler.dart  ← GET /v1/self-learning
          self_learning_assign_handler.dart ← POST /v1/self-learning/assign
          self_learning_progress_handler.dart ← GET|POST /v1/self-learning/[id]/progress
          self_learning_complete_handler.dart ← POST /v1/self-learning/[id]/complete
          routes.dart
        coordinators/
          coordinators_handler.dart   ← GET|POST /v1/coordinators
          coordinator_handler.dart    ← GET|PATCH /v1/coordinators/[id]
          coordinator_deactivate_handler.dart ← POST /v1/coordinators/[id]/deactivate
          routes.dart
        me/
          me_dashboard_handler.dart   ← GET /v1/me/dashboard (graphical progress, EE §5.1.7)
          me_obligations_handler.dart ← GET /v1/me/obligations
          me_sessions_handler.dart    ← GET /v1/me/sessions
          me_certificates_handler.dart ← GET /v1/me/certificates
          routes.dart
        compliance_report_handler.dart ← GET /v1/compliance-report (dept/plant view)
        triggers_handler.dart          ← POST /v1/triggers/process (SOP update → re-enroll)
        routes.dart                   ← Train domain aggregator
      certify/                        ← ASSESSMENTS, CERTIFICATES, COMPLIANCE, E-SIGNATURES
        assessments/
          assessment_start_handler.dart    ← POST /v1/assessments/start
          assessment_handler.dart          ← GET /v1/assessments/[id]
          assessment_answer_handler.dart   ← POST /v1/assessments/[id]/answer
          assessment_submit_handler.dart   ← POST /v1/assessments/[id]/submit [esig]
          assessment_progress_handler.dart ← GET /v1/assessments/[id]/progress
          assessment_results_handler.dart  ← GET /v1/assessments/[id]/results
          assessment_publish_handler.dart  ← POST /v1/assessments/[id]/publish-results [esig]
          routes.dart
        certificates/
          certificates_handler.dart   ← GET /v1/certificates
          certificate_handler.dart    ← GET /v1/certificates/[id]
          certificate_verify_handler.dart ← GET /v1/certificates/[id]/verify (public, no auth)
          certificate_revoke_handler.dart ← POST /v1/certificates/[id]/revoke [two-person esig]
          certificate_download_handler.dart ← GET /v1/certificates/[id]/download (PDF)
          routes.dart
        remedial/
          remedial_handler.dart       ← GET|POST /v1/remedial
          remedial_complete_handler.dart ← POST /v1/remedial/[id]/complete
          routes.dart
        competencies/
          competencies_handler.dart   ← GET|POST /v1/competencies
          competency_handler.dart     ← GET|PATCH /v1/competencies/[id]
          competency_assess_handler.dart ← POST /v1/competencies/[id]/assess
          routes.dart
        waivers/
          waivers_handler.dart        ← GET|POST /v1/waivers
          waiver_handler.dart         ← GET /v1/waivers/[id]
          waiver_approve_handler.dart ← POST /v1/waivers/[id]/approve [esig]
          waiver_reject_handler.dart  ← POST /v1/waivers/[id]/reject
          routes.dart
        esignatures/
          esig_create_handler.dart    ← POST /v1/esignatures/create [esig reauth]
          esig_verify_handler.dart    ← POST /v1/esignatures/verify
          esig_entity_handler.dart    ← GET /v1/esignatures/[entityType]/[entityId]
          routes.dart
        reauth/
          reauth_create_handler.dart  ← POST /v1/reauth/create (get reauth_session_id, 30 min TTL)
          reauth_validate_handler.dart ← POST /v1/reauth/validate
          routes.dart
        compliance/
          compliance_dashboard_handler.dart ← GET /v1/compliance/dashboard
          compliance_certs_handler.dart     ← GET /v1/compliance/certificates
          compliance_overdue_handler.dart   ← GET /v1/compliance/overdue
          compliance_reports_handler.dart   ← GET|POST /v1/compliance/reports
          compliance_report_run_handler.dart ← POST /v1/compliance/reports/[id]/run
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
POST /v1/certificates/[id]/revoke requires TWO separate e_signature objects:

e_signature_primary: first authorized person (e.g. QA Manager)
e_signature_secondary: second authorized person (different employee, different role tier)
The DB chk_two_person_revocation and chk_revoke_different_persons CHECK constraints enforce this at DB level. The handler validates both reauth sessions, creates two electronic_signatures rows, and stores both FKs before the revocation commits.

URS Full Coverage Map
URS Clause	Domain	Endpoint(s)
Alfa §3.1.41-47 (password controls)	access	POST /v1/auth/password/change, GET /v1/config/password-policies
Alfa §4.2.1.16-21 (GTP management)	create, train	POST /v1/gtps, POST /v1/schedules
Alfa §4.2.1.25 (TNI + curricula)	train	POST /v1/schedules/[id]/assign, POST /v1/curricula
Alfa §4.2.1.28 (auto-numbering)	create	POST /v1/config/numbering-schemes/[id]/next
Alfa §4.2.1.34 (e-sig on submit)	create, certify	POST .../submit (all submit endpoints)
Alfa §4.3.3 (plant-wise list)	train, certify	GET /v1/compliance/dashboard
Alfa §4.3.4 (configurable approval)	create, workflow	POST /v1/config/approval-matrices
Alfa §4.3.11 (OJT witness)	train	POST /v1/ojt/[id]/sign-off
Alfa §4.3.12 (training waiver)	train, certify	POST /v1/waivers, POST /v1/obligations/[id]/waive
Alfa §4.3.19 (post-dated records)	train	PATCH /v1/sessions/[id]/attendance/[empId]
Alfa §4.4.6 (unplanned leave delegation)	access	POST /v1/delegations
Alfa §4.4.8 (periodic review)	create	POST /v1/periodic-reviews/[id]/complete
Alfa §4.5.1-5 (login + lockout)	access	POST /v1/auth/login (validate_credential RPC)
Alfa §4.5.9 (biometric login)	access	POST /v1/auth/biometric/login
Alfa §4.5.2-7 (SSO/AD)	access	POST /v1/auth/sso/login, POST /v1/sso/configurations
Alfa §4.6.1.9 (RTO ≤15 min)	lifecycle_monitor	GET /health, business_continuity_plans
EE §5.1.6 (induction gate)	train	POST /v1/induction/complete
EE §5.1.7 (graphical progress)	train	GET /v1/me/dashboard
EE §5.1.8 (attendance)	train	POST /v1/sessions/[id]/check-in
EE §5.1.10 (waiver)	train, certify	POST /v1/obligations/[id]/waive
EE §5.1.15 (competency)	certify	GET
EE §5.1.20 (course approval)	create	POST /v1/courses/[id]/approve
EE §5.1.27-45 (Training Coordinator)	train	POST /v1/coordinators
EE §5.4.2 (AD/SSO)	access	POST /v1/sso/configurations
EE §5.6.10 (session security/idle)	access	auth_middleware idle-timeout
EE §5.9.2 (password management)	access	POST /v1/auth/password/change
EE §5.13.4-5 (retention + archival)	lifecycle_monitor	POST /jobs/archive
SCORM (§5.x content delivery)	create	POST /v1/scorm/packages, GET /v1/scorm/[id]/launch
21 CFR §11.10(c) (record protection)	certify	POST /v1/integrity/verify
21 CFR §11.10(e) (audit trail)	workflow	GET /v1/audit/[type]/[id]
21 CFR §11.50 (sig manifestation)	certify	POST /v1/esignatures/create
21 CFR §11.100(b) (unique username)	access	employees.username immutable trigger (DB)
21 CFR §11.200 (e-sig session chain)	certify	POST /v1/reauth/create + esig_middleware
21 CFR §11.300 (password controls)	access	password_policies + user_credentials
M-06 (two-person cert revocation)	certify	POST /v1/certificates/[id]/revoke
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
29	apps/api_server/pharma_learn/api/lib/routes/certify/certificates/certificate_revoke_handler.dart	Two-person revoke
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
E-sig flow — POST /v1/reauth/create → POST /v1/documents/[id]/approve → verify electronic_signatures row with is_first_in_session=TRUE and prev_signature_id chain
Two-person revoke — POST /v1/certificates/[id]/revoke with one signer → expect 422; with both different signers → expect 200 and DB CHECKs satisfied
Idle-timeout — advance last_activity_at past threshold → next request → 401 SESSION_TIMEOUT + audit_trails row with event_category='SESSION_TIMEOUT'
Rate limit — exceed api_rate_limits threshold → 429 Retry-After header
Audit chain — after 10 API calls → POST /v1/integrity/verify → {is_valid: true}
Induction gate — employee with induction_completed=false hits any non-induction endpoint → 403 InductionGateException
SCORM flow — POST /v1/scorm/packages → GET /v1/scorm/[id]/launch → POST /v1/scorm/[id]/commit (CMI data) → GET /v1/scorm/[id]/progress reflects completion
Health — GET :8080/health → {status: ok, latency_ms: <100}; GET :8086/health → {status: ok, events_outbox_lag: 0}
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
3. certify/certificates/certificate_revoke_handler.dart
// POST /v1/certificates/:id/revoke
// Body: {
//   e_signature_primary:   {reauth_session_id, meaning:'REVOKE', reason},
//   e_signature_secondary: {reauth_session_id, meaning:'REVOKE', reason},
//   revocation_reason_id:  UUID,
//   revocation_notes:      string
// }
Future<Response> certificateRevokeHandler(Request req) async {
  final certId   = parseUuid(req.pathParameters[#id]!);
  final auth     = req.context['auth'] as AuthContext;
  final supabase = req.context['supabase'] as SupabaseClient;
  final body     = await readJson(req);

  final esigPrimary   = EsigRequest.fromJson(body['e_signature_primary'] as Map<String, dynamic>);
  final esigSecondary = EsigRequest.fromJson(body['e_signature_secondary'] as Map<String, dynamic>);

  // 1. Validate BOTH reauth sessions
  final esigSvc = EsigService(supabase);
  final primaryValid   = await esigSvc.validateReauthSession(esigPrimary.reauthSessionId);
  final secondaryValid = await esigSvc.validateReauthSession(esigSecondary.reauthSessionId);
  if (!primaryValid || !secondaryValid) {
    throw EsigRequiredException('Both e-signatures required for certificate revocation');
  }

  // 2. Load certificate + validate it's revocable
  final cert = await supabase.from('certificates')
      .select().eq('id', certId).single();
  if (cert['status'] != 'ACTIVE') {
    throw ConflictException('Certificate is not active');
  }

  // 3. Resolve employee IDs from reauth sessions
  final primaryEmpId   = await _getEmployeeFromReauth(supabase, esigPrimary.reauthSessionId);
  final secondaryEmpId = await _getEmployeeFromReauth(supabase, esigSecondary.reauthSessionId);
  if (primaryEmpId == secondaryEmpId) {
    throw ValidationException({'e_signature_secondary': 'Must be a different employee than primary signer'});
  }

  // 4. Create BOTH e-signature records
  final primaryEsigId   = await esigSvc.createEsignature(
    employeeId: primaryEmpId, meaning: 'REVOKE',
    entityType: 'certificate', entityId: certId,
    isFirstInSession: esigPrimary.isFirstInSession,
  );
  final secondaryEsigId = await esigSvc.createEsignature(
    employeeId: secondaryEmpId, meaning: 'REVOKE',
    entityType: 'certificate', entityId: certId,
    isFirstInSession: esigSecondary.isFirstInSession,
    prevSignatureId: primaryEsigId,  // chain §11.200
  );

  // 5. Revoke certificate (DB CHECK constraints enforce two-person rule)
  await supabase.from('certificates').update({
    'status': 'REVOKED',
    'revoked_at': DateTime.now().toIso8601String(),
    'revoked_by_primary': primaryEmpId,
    'revoked_by_secondary': secondaryEmpId,
    'revoke_esig_primary': primaryEsigId,
    'revoke_esig_secondary': secondaryEsigId,
    'revocation_reason_id': body['revocation_reason_id'],
  }).eq('id', certId);

  // 6. Consume both sessions
  await Future.wait([
    esigSvc.consumeReauthSession(esigPrimary.reauthSessionId),
    esigSvc.consumeReauthSession(esigSecondary.reauthSessionId),
  ]);

  // 7. Publish revocation event
  await OutboxService(supabase).publish(
    aggregateType: 'certificate', aggregateId: certId,
    eventType: EventTypes.certificateRevoked,
    payload: {'primary_signer': primaryEmpId, 'secondary_signer': secondaryEmpId},
  );

  return ApiResponse.ok({'certificate_id': certId, 'status': 'REVOKED'}).toResponse();
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
S9: MobX client	Flutter stores + repositories + router + Vyuh entity screens	End-to-end Flutter → API; codegen: make codegen
