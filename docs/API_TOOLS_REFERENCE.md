# PharmaLearn LMS — API & Tools Reference

> **Version:** 3.0 | **Date:** April 2026  
> **Framework:** Relic HTTP (Dart) | **Database:** PostgreSQL 15+ (Supabase)  
> **Endpoints:** 646+ | **Handlers:** 197

---

## Executive Summary

| Metric | Value |
|--------|-------|
| **API Framework** | Relic HTTP 1.2.0 |
| **Total Endpoints** | 646+ |
| **Handler Files** | 197 |
| **Route Modules** | 7 (access, create, train, certify, reports, workflow, health) |
| **Supporting Services** | 2 (lifecycle_monitor, workflow_engine) |
| **Database Client** | Supabase Dart SDK 2.5.0 |

---

## Table of Contents

1. [Core Dependencies](#1-core-dependencies)
2. [API Framework (Relic HTTP)](#2-api-framework-relic-http)
3. [Complete API Reference](#3-complete-api-reference)
4. [Database Client (Supabase)](#4-database-client-supabase)
5. [Authentication & Security Tools](#5-authentication--security-tools)
6. [File & Content Processing](#6-file--content-processing)
7. [Background Services](#7-background-services)
8. [Development Tools](#8-development-tools)
9. [API Response Patterns](#9-api-response-patterns)

---

## 1. Core Dependencies

### 1.1 API Server Dependencies

```yaml
# apps/api_server/pharma_learn/api/pubspec.yaml
name: pharma_learn_api
version: 1.0.0
publish_to: none

environment:
  sdk: ">=3.8.0 <4.0.0"

dependencies:
  # Shared library
  pharmalearn_shared:
    path: ../../../../packages/pharmalearn_shared
  
  # HTTP Framework
  relic: ^1.2.0                 # Dart HTTP server framework
  
  # Database
  supabase: ^2.5.0              # Supabase client (PostgreSQL, Auth, Storage)
  
  # Authentication
  dart_jsonwebtoken: ^2.12.1    # JWT creation & validation
  
  # File Processing
  archive: ^3.4.0               # ZIP/SCORM package handling
  xml: ^6.5.0                   # XML parsing (SCORM manifests)
  mime: ^2.0.0                  # MIME type detection
  
  # Utilities
  logger: ^2.3.0                # Structured logging
  uuid: ^4.4.0                  # UUID generation
  http: ^1.2.1                  # HTTP client for external calls
  crypto: ^3.0.3                # Cryptographic functions (SHA-256)

dev_dependencies:
  lints: ^3.0.0                 # Dart linting rules
  test: ^1.25.0                 # Unit testing
  mocktail: ^1.0.1              # Mocking for tests
```

### 1.2 Shared Library Dependencies

```yaml
# packages/pharmalearn_shared/pubspec.yaml
name: pharmalearn_shared
version: 1.0.0
publish_to: none

environment:
  sdk: ">=3.8.0 <4.0.0"

dependencies:
  relic: ^1.2.0
  supabase: ^2.5.0
  dart_jsonwebtoken: ^2.12.1
  crypto: ^3.0.3
  http: ^1.2.1
  logger: ^2.3.0
  uuid: ^4.4.0
  json_annotation: ^4.9.0       # JSON serialization annotations
  mime: ^2.0.0
  archive: ^3.6.1
  xml: ^6.5.0

dev_dependencies:
  build_runner: ^2.4.9          # Code generation
  json_serializable: ^6.7.1     # JSON serialization codegen
  lints: ^3.0.0
  test: ^1.25.0
  mocktail: ^1.0.1
```

### 1.3 Dependency Matrix

| Package | Version | Purpose | Used In |
|---------|---------|---------|---------|
| `relic` | 1.2.0 | HTTP server framework | API routing, middleware |
| `supabase` | 2.5.0 | Database client | All CRUD operations |
| `dart_jsonwebtoken` | 2.12.1 | JWT handling | Auth middleware |
| `archive` | 3.4.0 | ZIP handling | SCORM upload |
| `xml` | 6.5.0 | XML parsing | SCORM manifest |
| `logger` | 2.3.0 | Logging | All handlers |
| `uuid` | 4.4.0 | UUID generation | Entity IDs |
| `http` | 1.2.1 | HTTP client | Webhooks, integrations |
| `crypto` | 3.0.3 | Hashing | E-signature integrity |
| `mime` | 2.0.0 | MIME detection | File uploads |
| `json_annotation` | 4.9.0 | JSON models | Request/response models |

---

## 2. API Framework (Relic HTTP)

### 2.1 Framework Overview

**Relic** is a lightweight Dart HTTP framework used for building the PharmaLearn API server.

```dart
// main.dart - Application entry point
import 'package:relic/relic.dart';
import 'routes/routes.dart';

void main() async {
  final app = RelicApp();
  
  // Register middleware
  app.use(corsMiddleware());
  app.use(authMiddleware());
  app.use(loggingMiddleware());
  
  // Mount all routes
  mountAllRoutes(app);
  
  // Start server
  await app.listen(port: 8080);
  print('PharmaLearn API running on port 8080');
}
```

### 2.2 Route Registration

```dart
// routes/routes.dart
import 'package:relic/relic.dart';

void mountAllRoutes(RelicApp app) {
  mountHealthRoutes(app);    // /v1/health/*
  mountAccessRoutes(app);    // /v1/access/*
  mountCertifyRoutes(app);   // /v1/certify/*
  mountCreateRoutes(app);    // /v1/create/*
  mountReportsRoutes(app);   // /v1/reports/*
  mountWorkflowRoutes(app);  // /v1/workflow/*
  mountTrainRoutes(app);     // /v1/train/*
}

// routes/train/routes.dart - Module routes
void mountTrainRoutes(RelicApp app) {
  // Sub-route mounting
  mountMeRoutes(app);
  mountScheduleRoutes(app);
  mountSessionRoutes(app);
  
  // Direct route registration
  app
    ..post('/v1/train/sessions/:id/check-in', sessionCheckinHandler)
    ..post('/v1/train/sessions/:id/check-out', sessionCheckoutHandler)
    ..get('/v1/train/me/dashboard', meDashboardHandler);
}
```

### 2.3 Handler Pattern

```dart
// Typical handler structure
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

Future<Response> sessionCheckinHandler(Request request) async {
  try {
    // 1. Extract context (from auth middleware)
    final context = request.context;
    final employeeId = context['employee_id'] as String;
    final orgId = context['organization_id'] as String;
    
    // 2. Parse request body
    final body = await request.json();
    final sessionId = request.params['id'];
    final method = body['method'] as String;
    
    // 3. Validate
    if (sessionId == null) {
      return Response.badRequest(body: {'error': 'Session ID required'});
    }
    
    // 4. Business logic via Supabase
    final supabase = SupabaseService.instance;
    
    // Check session exists
    final session = await supabase
        .from('training_sessions')
        .select()
        .eq('id', sessionId)
        .eq('organization_id', orgId)
        .maybeSingle();
    
    if (session == null) {
      return Response.notFound(body: {'error': 'Session not found'});
    }
    
    // Record attendance
    final attendance = await supabase
        .from('session_attendance')
        .insert({
          'session_id': sessionId,
          'employee_id': employeeId,
          'organization_id': orgId,
          'check_in_time': DateTime.now().toIso8601String(),
          'attendance_method': method,
          'status': 'present',
        })
        .select()
        .single();
    
    // 5. Create audit trail
    await supabase.from('audit_trails').insert({
      'entity_type': 'session_attendance',
      'entity_id': attendance['id'],
      'action': 'created',
      'event_category': 'DATA_CHANGE',
      'performed_by': employeeId,
      'organization_id': orgId,
    });
    
    // 6. Return response
    return Response.ok(body: {
      'success': true,
      'attendance_id': attendance['id'],
      'check_in_time': attendance['check_in_time'],
    });
    
  } catch (e, stack) {
    logger.error('Check-in failed', error: e, stackTrace: stack);
    return Response.internalServerError(body: {'error': 'Check-in failed'});
  }
}
```

### 2.4 Middleware Chain

```dart
// Middleware registration order
app.use(corsMiddleware());      // 1. CORS headers
app.use(authMiddleware());      // 2. JWT validation
app.use(loggingMiddleware());   // 3. Request logging

// Auth middleware example
Middleware authMiddleware() {
  return (Handler handler) {
    return (Request request) async {
      // Skip auth for public routes
      if (request.url.path.startsWith('/v1/health')) {
        return handler(request);
      }
      
      // Extract JWT
      final authHeader = request.headers['authorization'];
      if (authHeader == null || !authHeader.startsWith('Bearer ')) {
        return Response.unauthorized(body: {'error': 'Missing token'});
      }
      
      final token = authHeader.substring(7);
      
      try {
        // Validate JWT
        final jwt = JWT.verify(token, SecretKey(jwtSecret));
        
        // Add claims to context
        final newRequest = request.change(context: {
          ...request.context,
          'employee_id': jwt.payload['sub'],
          'organization_id': jwt.payload['org_id'],
          'permissions': jwt.payload['permissions'] ?? [],
        });
        
        return handler(newRequest);
      } catch (e) {
        return Response.unauthorized(body: {'error': 'Invalid token'});
      }
    };
  };
}
```

---

## 3. Complete API Reference

### 3.1 ACCESS Module (42 handlers)

#### Authentication Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| POST | `/v1/access/auth/login` | `login_handler.dart` | User login with username/password |
| POST | `/v1/access/auth/logout` | `logout_handler.dart` | End user session |
| POST | `/v1/access/auth/register` | `register_handler.dart` | Register new user |
| POST | `/v1/access/auth/password/change` | `password_handler.dart` | Change password |
| POST | `/v1/access/auth/password/reset` | `password_reset_handler.dart` | Request password reset |
| POST | `/v1/access/auth/password/reset/confirm` | `password_reset_handler.dart` | Confirm reset with token |
| POST | `/v1/access/auth/mfa/enable` | `mfa_handler.dart` | Enable MFA |
| POST | `/v1/access/auth/mfa/verify` | `mfa_handler.dart` | Verify MFA code |
| POST | `/v1/access/auth/mfa/disable` | `mfa_handler.dart` | Disable MFA |
| POST | `/v1/access/auth/refresh` | `refresh_handler.dart` | Refresh access token |
| GET | `/v1/access/auth/sessions` | `sessions_handler.dart` | List active sessions |
| DELETE | `/v1/access/auth/sessions/:id` | `sessions_handler.dart` | Terminate session |
| GET | `/v1/access/auth/permissions` | `permissions_handler.dart` | Get user permissions |
| GET | `/v1/access/auth/profile` | `profile_handler.dart` | Get current user profile |
| PATCH | `/v1/access/auth/profile` | `profile_handler.dart` | Update profile |
| GET | `/v1/access/auth/esig-cert` | `esig_cert_handler.dart` | Get e-signature certificate |

#### Biometric Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/access/biometric` | `biometric_handler.dart` | List biometric registrations |
| POST | `/v1/access/biometric/register` | `biometric_register_handler.dart` | Register biometric template |
| POST | `/v1/access/biometric/verify` | `biometric_verify_handler.dart` | Verify biometric |

#### Employee Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/access/employees` | `employees_handler.dart` | List employees (paginated) |
| POST | `/v1/access/employees` | `employees_handler.dart` | Create employee |
| GET | `/v1/access/employees/:id` | `employee_handler.dart` | Get employee details |
| PATCH | `/v1/access/employees/:id` | `employee_handler.dart` | Update employee |
| POST | `/v1/access/employees/bulk` | `employee_bulk_handler.dart` | Bulk import employees |
| POST | `/v1/access/employees/:id/credentials` | `employee_credentials_handler.dart` | Set credentials |
| POST | `/v1/access/employees/:id/deactivate` | `employee_deactivate_handler.dart` | Deactivate employee |
| GET | `/v1/access/employees/:id/profile` | `employee_profile_handler.dart` | Get employee profile |
| GET | `/v1/access/employees/:id/roles` | `employee_roles_handler.dart` | Get employee roles |
| POST | `/v1/access/employees/:id/roles` | `employee_roles_handler.dart` | Assign role |
| DELETE | `/v1/access/employees/:id/roles/:roleId` | `employee_roles_handler.dart` | Remove role |
| POST | `/v1/access/employees/:id/terminate-tasks` | `employee_task_terminate_handler.dart` | Terminate pending tasks |

#### Role & Permission Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/access/roles` | `roles_handler.dart` | List roles |
| POST | `/v1/access/roles` | `roles_handler.dart` | Create role |
| GET | `/v1/access/roles/:id` | `role_handler.dart` | Get role |
| PATCH | `/v1/access/roles/:id` | `role_handler.dart` | Update role |
| DELETE | `/v1/access/roles/:id` | `role_handler.dart` | Delete role |

#### Group & Subgroup Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/access/groups` | `groups_handler.dart` | List groups |
| POST | `/v1/access/groups` | `groups_handler.dart` | Create group |
| GET | `/v1/access/groups/:id` | `group_handler.dart` | Get group |
| PATCH | `/v1/access/groups/:id` | `group_handler.dart` | Update group |
| DELETE | `/v1/access/groups/:id` | `group_handler.dart` | Delete group |
| GET | `/v1/access/groups/:id/members` | `group_members_handler.dart` | List group members |
| POST | `/v1/access/groups/:id/members` | `group_members_handler.dart` | Add member |
| DELETE | `/v1/access/groups/:id/members/:employeeId` | `group_members_handler.dart` | Remove member |
| GET | `/v1/access/subgroups` | `subgroups_handler.dart` | List subgroups |
| POST | `/v1/access/subgroups` | `subgroups_handler.dart` | Create subgroup |

#### Other ACCESS Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/access/departments` | `departments_handler.dart` | List departments |
| GET | `/v1/access/delegations` | `delegations_handler.dart` | List delegations |
| POST | `/v1/access/delegations` | `delegation_handler.dart` | Create delegation |
| DELETE | `/v1/access/delegations/:id` | `delegation_revoke_handler.dart` | Revoke delegation |
| GET | `/v1/access/sso/configs` | `sso_configs_handler.dart` | List SSO configs |
| POST | `/v1/access/sso/configs` | `sso_config_handler.dart` | Create SSO config |
| POST | `/v1/access/sso/test` | `sso_test_handler.dart` | Test SSO connection |
| GET | `/v1/access/consent` | `consent_handler.dart` | Get consent status |
| POST | `/v1/access/consent` | `consent_handler.dart` | Grant consent |
| POST | `/v1/access/consent/withdraw` | `consent_withdraw_handler.dart` | Withdraw consent |
| GET | `/v1/access/notifications` | `notification_handler.dart` | Get notifications |
| PATCH | `/v1/access/notifications/:id` | `notification_handler.dart` | Mark as read |
| GET | `/v1/access/global-profiles` | `global_profiles_handler.dart` | List global profiles |
| GET | `/v1/access/job-responsibilities` | `job_responsibilities_handler.dart` | List job responsibilities |
| GET | `/v1/access/mail-settings` | `mail_settings_handler.dart` | Get mail settings |
| PATCH | `/v1/access/mail-settings` | `mail_settings_handler.dart` | Update mail settings |

### 3.2 CREATE Module (49 handlers)

#### Course Management

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/courses` | `courses_handler.dart` | List courses |
| POST | `/v1/courses` | `courses_handler.dart` | Create course |
| GET | `/v1/courses/:id` | `course_handler.dart` | Get course |
| PATCH | `/v1/courses/:id` | `course_handler.dart` | Update course |
| POST | `/v1/courses/:id/submit` | `course_submit_handler.dart` | Submit for approval |
| POST | `/v1/courses/:id/approve` | `course_approve_handler.dart` | Approve course |
| DELETE | `/v1/courses/:id` | `course_delete_handler.dart` | Delete course |
| GET | `/v1/courses/:id/topics` | `course_topics_handler.dart` | Get course topics |
| POST | `/v1/courses/:id/topics` | `course_topics_handler.dart` | Add topic |
| GET | `/v1/courses/:id/documents` | `course_documents_handler.dart` | Get course documents |
| POST | `/v1/courses/:id/documents` | `course_documents_handler.dart` | Link document |

#### Document Control

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/documents` | `documents_handler.dart` | List documents |
| POST | `/v1/documents` | `documents_handler.dart` | Create document |
| GET | `/v1/documents/:id` | `document_handler.dart` | Get document |
| PATCH | `/v1/documents/:id` | `document_handler.dart` | Update document |
| POST | `/v1/documents/:id/submit` | `document_submit_handler.dart` | Submit for approval |
| POST | `/v1/documents/:id/approve` | `document_approve_handler.dart` | Approve document |
| POST | `/v1/documents/:id/reject` | `document_reject_handler.dart` | Reject document |
| DELETE | `/v1/documents/:id` | `document_delete_handler.dart` | Delete document |
| GET | `/v1/documents/:id/export` | `document_export_handler.dart` | Export as PDF |
| POST | `/v1/documents/:id/issue` | `document_issue_handler.dart` | Issue document |
| GET | `/v1/documents/:id/versions` | `document_versions_handler.dart` | Get versions |
| GET | `/v1/documents/:id/readings` | `document_readings_handler.dart` | Get reading status |
| POST | `/v1/documents/:id/readings/:employeeId/ack` | `document_reading_ack_handler.dart` | Acknowledge reading |
| GET | `/v1/documents/:id/integrity` | `document_integrity_handler.dart` | Verify integrity |

#### Categories, Subjects, Topics

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/categories` | `categories_handler.dart` | List categories |
| POST | `/v1/categories` | `categories_handler.dart` | Create category |
| GET | `/v1/categories/:id` | `category_handler.dart` | Get category |
| PATCH | `/v1/categories/:id` | `category_handler.dart` | Update category |
| GET | `/v1/subjects` | `subjects_handler.dart` | List subjects |
| POST | `/v1/subjects` | `subjects_handler.dart` | Create subject |
| GET | `/v1/topics` | `topics_handler.dart` | List topics |
| POST | `/v1/topics` | `topics_handler.dart` | Create topic |

#### Group Training Plans (GTPs)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/gtps` | `gtps_handler.dart` | List GTPs |
| POST | `/v1/gtps` | `gtps_handler.dart` | Create GTP |
| GET | `/v1/gtps/:id` | `gtp_handler.dart` | Get GTP |
| PATCH | `/v1/gtps/:id` | `gtp_handler.dart` | Update GTP |
| POST | `/v1/gtps/:id/submit` | `gtp_submit_handler.dart` | Submit for approval |
| POST | `/v1/gtps/:id/approve` | `gtp_approve_handler.dart` | Approve GTP |
| GET | `/v1/gtps/:id/courses` | `gtp_courses_handler.dart` | Get GTP courses |
| POST | `/v1/gtps/:id/courses` | `gtp_courses_handler.dart` | Add course to GTP |

#### Question Banks & Papers

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/question-banks` | `question_banks_handler.dart` | List question banks |
| POST | `/v1/question-banks` | `question_banks_handler.dart` | Create question bank |
| GET | `/v1/question-banks/:id` | `question_bank_handler.dart` | Get question bank |
| POST | `/v1/question-banks/:id/questions` | `question_bank_handler.dart` | Add question |
| GET | `/v1/question-papers` | `question_papers_handler.dart` | List question papers |
| POST | `/v1/question-papers` | `question_papers_handler.dart` | Create question paper |
| GET | `/v1/question-papers/:id` | `question_paper_handler.dart` | Get question paper |
| GET | `/v1/question-papers/:id/print` | `question_paper_print_handler.dart` | Print-ready format |

#### Trainers & Venues

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/trainers` | `trainers_handler.dart` | List trainers |
| POST | `/v1/trainers` | `trainers_handler.dart` | Create trainer |
| GET | `/v1/trainers/:id` | `trainer_handler.dart` | Get trainer |
| POST | `/v1/trainers/:id/approve` | `trainer_approve_handler.dart` | Approve trainer |
| GET | `/v1/venues` | `venues_handler.dart` | List venues |
| POST | `/v1/venues` | `venues_handler.dart` | Create venue |
| GET | `/v1/venues/:id` | `venue_handler.dart` | Get venue |

#### Other CREATE Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/curricula` | `curricula_handler.dart` | List curricula |
| POST | `/v1/curricula` | `curricula_handler.dart` | Create curriculum |
| GET | `/v1/curricula/:id` | `curriculum_handler.dart` | Get curriculum |
| POST | `/v1/scorm` | `scorm_handler.dart` | Upload SCORM package |
| GET | `/v1/scorm/:id` | `scorm_handler.dart` | Get SCORM details |
| GET | `/v1/feedback/evaluation-templates` | `evaluation_templates_handler.dart` | List eval templates |
| POST | `/v1/feedback/evaluation-templates` | `evaluation_templates_handler.dart` | Create eval template |
| GET | `/v1/feedback/feedback-templates` | `feedback_templates_handler.dart` | List feedback templates |
| GET | `/v1/config` | `config_handler.dart` | Get system config |
| PATCH | `/v1/config` | `config_handler.dart` | Update system config |
| GET | `/v1/config/master-data` | `master_data_handler.dart` | Get master data |
| GET | `/v1/config/retention-policies` | `retention_policies_handler.dart` | Get retention policies |
| GET | `/v1/config/validation-rules` | `validation_rules_handler.dart` | Get validation rules |
| GET | `/v1/periodic-reviews` | `periodic_reviews_handler.dart` | List periodic reviews |
| POST | `/v1/periodic-reviews/:id/complete` | `periodic_review_handler.dart` | Complete review |

### 3.3 TRAIN Module (42 handlers)

#### Employee Dashboard ("Me" Routes)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/me/dashboard` | `me_dashboard_handler.dart` | My training dashboard |
| GET | `/v1/train/me/sessions` | `me_sessions_handler.dart` | My sessions |
| GET | `/v1/train/me/obligations` | `me_obligations_handler.dart` | My training obligations |
| GET | `/v1/train/me/certificates` | `me_certificates_handler.dart` | My certificates |
| GET | `/v1/train/me/history` | `me_training_history_handler.dart` | My training history |

#### Training Schedules

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/schedules` | `schedules_handler.dart` | List schedules |
| POST | `/v1/train/schedules` | `schedules_handler.dart` | Create schedule |
| GET | `/v1/train/schedules/:id` | `schedule_handler.dart` | Get schedule |
| PATCH | `/v1/train/schedules/:id` | `schedule_handler.dart` | Update schedule |
| POST | `/v1/train/schedules/:id/workflow/:action` | `schedule_workflow_handler.dart` | Workflow action |
| GET | `/v1/train/schedules/:id/invitations` | `schedule_invitations_handler.dart` | Get invitations |
| POST | `/v1/train/schedules/:id/invitations` | `schedule_invitations_handler.dart` | Send invitations |
| POST | `/v1/train/schedules/:id/enroll` | `schedule_enrollment_handler.dart` | Enroll trainee |
| POST | `/v1/train/schedules/:id/self-nominate` | `schedule_self_nominate_handler.dart` | Self-nominate |
| DELETE | `/v1/train/schedules/:id/self-nominate` | `schedule_self_nominate_handler.dart` | Withdraw nomination |
| GET | `/v1/train/schedules/:id/nominations` | `schedule_self_nominate_handler.dart` | List nominations |
| POST | `/v1/train/schedules/:id/nominations/:employeeId/accept` | `schedule_self_nominate_handler.dart` | Accept nomination |
| POST | `/v1/train/schedules/:id/nominations/:employeeId/reject` | `schedule_self_nominate_handler.dart` | Reject nomination |
| GET | `/v1/train/schedules/:id/batches` | `batches_handler.dart` | Get batches |
| POST | `/v1/train/schedules/:id/batches` | `batches_handler.dart` | Create batch |

#### Training Sessions

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/sessions` | `sessions_handler.dart` | List sessions |
| GET | `/v1/train/sessions/:id` | `session_handler.dart` | Get session |
| GET | `/v1/train/sessions/:id/attendance` | `session_attendance_handler.dart` | Get attendance |
| POST | `/v1/train/sessions/:id/check-in` | `session_checkin_handler.dart` | Check in |
| POST | `/v1/train/sessions/:id/check-out` | `session_checkout_handler.dart` | Check out |
| POST | `/v1/train/sessions/:id/complete` | `session_complete_handler.dart` | Complete session |
| GET | `/v1/train/sessions/:id/qr` | `session_qr_handler.dart` | Get QR code |
| POST | `/v1/train/sessions/:id/doc-reading/offline` | `session_doc_reading_handler.dart` | Offline doc reading |
| POST | `/v1/train/sessions/:id/doc-reading/terminate` | `session_doc_reading_handler.dart` | Terminate reading |

#### Batches

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/batches/:id/attendance-sheet` | `batch_attendance_sheet_handler.dart` | Get attendance sheet |

#### Induction

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/induction` | `induction_coordinator_handler.dart` | List inductions |
| POST | `/v1/train/induction` | `induction_coordinator_handler.dart` | Create induction |
| GET | `/v1/train/induction/:id` | `induction_coordinator_handler.dart` | Get induction |
| GET | `/v1/train/induction/:id/items` | `induction_items_handler.dart` | Get induction items |
| POST | `/v1/train/induction/:id/record` | `induction_coordinator_handler.dart` | Record completion |
| POST | `/v1/train/induction/:id/trainer-respond` | `induction_trainer_handler.dart` | Trainer response |
| GET | `/v1/train/induction/trainer/pending` | `induction_trainer_handler.dart` | Trainer pending |
| POST | `/v1/train/induction/:id/trainer-reassign` | `induction_trainer_handler.dart` | Reassign trainer |

#### OJT (On-the-Job Training)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/ojt` | `ojt_handler.dart` | List OJT assignments |
| POST | `/v1/train/ojt` | `ojt_handler.dart` | Create OJT assignment |
| GET | `/v1/train/ojt/:id` | `ojt_detail_handler.dart` | Get OJT details |
| POST | `/v1/train/ojt/:id/tasks/:taskId/complete` | `ojt_detail_handler.dart` | Complete task |

#### Self-Learning & Self-Study

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/train/self-learning` | `self_learning_handler.dart` | My self-learning |
| POST | `/v1/train/self-learning/:id/progress` | `self_learning_progress_handler.dart` | Update progress |
| GET | `/v1/train/self-study` | `self_study_handler.dart` | Available self-study |
| POST | `/v1/train/self-study/:courseId/enroll` | `self_study_handler.dart` | Enroll in self-study |

#### Other TRAIN Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| POST | `/v1/train/sessions/:id/feedback` | `session_feedback_handler.dart` | Submit feedback |
| POST | `/v1/train/evaluations/short-term` | `short_term_evaluation_handler.dart` | Short-term eval |
| POST | `/v1/train/evaluations/long-term` | `long_term_evaluation_handler.dart` | Long-term eval |
| GET | `/v1/train/external` | `external_training_handler.dart` | External training |
| POST | `/v1/train/external` | `external_training_handler.dart` | Record external training |
| POST | `/v1/train/retraining` | `retraining_handler.dart` | Assign retraining |
| GET | `/v1/train/obligations` | `obligations_handler.dart` | List obligations |
| GET | `/v1/train/obligations/:id` | `obligation_handler.dart` | Get obligation |
| GET | `/v1/train/obligations/compliance-report` | `compliance_report_handler.dart` | Compliance report |
| GET | `/v1/train/coordinators` | `coordinators_handler.dart` | List coordinators |
| POST | `/v1/train/coordinators` | `coordinator_handler.dart` | Assign coordinator |
| GET | `/v1/train/triggers` | `training_triggers_handler.dart` | List trigger rules |
| POST | `/v1/train/triggers` | `training_triggers_handler.dart` | Create trigger rule |
| POST | `/v1/train/triggers/process` | `triggers_handler.dart` | Process triggers |

### 3.4 CERTIFY Module (31 handlers)

#### Re-Authentication

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| POST | `/v1/certify/reauth` | `reauth_create_handler.dart` | Create reauth session |
| POST | `/v1/certify/reauth/:sessionId/verify` | `reauth_validate_handler.dart` | Verify password |

#### E-Signatures

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/certify/esignatures` | `esignatures_handler.dart` | List e-signatures |
| POST | `/v1/certify/esignatures` | `esignature_handler.dart` | Apply e-signature |
| GET | `/v1/certify/esignatures/:id` | `esignature_handler.dart` | Get e-signature |

#### Assessments

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/certify/assessments` | `assessments_handler.dart` | List available assessments |
| POST | `/v1/certify/assessments/:paperId/start` | `assessment_handler.dart` | Start assessment |
| GET | `/v1/certify/assessments/:attemptId` | `assessment_detail_handler.dart` | Get attempt details |
| POST | `/v1/certify/assessments/:attemptId/answer` | `assessment_answer_handler.dart` | Submit answer |
| POST | `/v1/certify/assessments/:attemptId/submit` | `assessment_submit_handler.dart` | Submit assessment |
| GET | `/v1/certify/assessments/:attemptId/progress` | `assessment_progress_handler.dart` | Get progress |
| GET | `/v1/certify/assessments/:attemptId/results` | `assessment_results_handler.dart` | Get results |
| POST | `/v1/certify/assessments/:attemptId/grade` | `assessment_grade_handler.dart` | Manual grading |
| POST | `/v1/certify/assessments/:attemptId/extend` | `assessment_extend_handler.dart` | Extend time |
| POST | `/v1/certify/assessments/:paperId/publish` | `assessment_publish_handler.dart` | Publish paper |
| GET | `/v1/certify/grading-queue` | `grading_queue_handler.dart` | Grading queue |

#### Certificates

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/certify/certificates` | `certificates_handler.dart` | List certificates |
| GET | `/v1/certify/certificates/:id` | `certificate_handler.dart` | Get certificate |
| GET | `/v1/certify/certificates/:id/download` | `certificate_handler.dart` | Download PDF |
| POST | `/v1/certify/certificates/:id/verify` | `certificate_handler.dart` | Verify certificate |

#### Competencies

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/certify/competencies` | `competencies_handler.dart` | List competencies |
| GET | `/v1/certify/competencies/:id` | `competency_handler.dart` | Get competency |
| GET | `/v1/certify/competencies/admin` | `competency_admin_handler.dart` | Admin view |
| POST | `/v1/certify/competencies/admin` | `competency_admin_handler.dart` | Create competency |

#### Other CERTIFY Endpoints

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/certify/compliance` | `compliance_handler.dart` | Compliance dashboard |
| GET | `/v1/certify/compliance/report` | `compliance_report_handler.dart` | Compliance report |
| GET | `/v1/certify/waivers` | `waivers_handler.dart` | List waivers |
| POST | `/v1/certify/waivers` | `waiver_create_handler.dart` | Create waiver |
| GET | `/v1/certify/waivers/:id` | `waiver_handler.dart` | Get waiver |
| POST | `/v1/certify/waivers/:id/approve` | `waiver_handler.dart` | Approve waiver |
| GET | `/v1/certify/analytics/courses/:id` | `course_analytics_handler.dart` | Course analytics |
| GET | `/v1/certify/analytics/questions/:id` | `question_stats_handler.dart` | Question stats |
| GET | `/v1/certify/integrity/:entityType/:id` | `integrity_handler.dart` | Verify integrity |
| GET | `/v1/certify/remedial` | `remedial_handler.dart` | List remedial |
| POST | `/v1/certify/remedial` | `remedial_handler.dart` | Assign remedial |
| GET | `/v1/certify/training-matrix` | `training_matrix_handler.dart` | Training matrix |
| GET | `/v1/certify/inspection` | `inspection_handler.dart` | Inspection dashboard |

### 3.5 REPORTS Module (8 handlers)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/reports/templates` | `report_templates_handler.dart` | List report templates |
| GET | `/v1/reports/templates/:id` | `report_template_handler.dart` | Get template |
| POST | `/v1/reports/:templateId/run` | `report_run_handler.dart` | Run report |
| GET | `/v1/reports/runs` | `report_runs_handler.dart` | List report runs |
| GET | `/v1/reports/runs/:id` | `report_run_status_handler.dart` | Get run status |
| GET | `/v1/reports/runs/:id/download` | `report_run_download_handler.dart` | Download report |
| GET | `/v1/reports/schedules` | `report_schedules_handler.dart` | List schedules |
| POST | `/v1/reports/schedules` | `report_schedules_handler.dart` | Create schedule |
| GET | `/v1/reports/schedules/:id` | `report_schedule_handler.dart` | Get schedule |
| PATCH | `/v1/reports/schedules/:id` | `report_schedule_handler.dart` | Update schedule |
| DELETE | `/v1/reports/schedules/:id` | `report_schedule_handler.dart` | Delete schedule |

### 3.6 WORKFLOW Module (9 handlers)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/workflow/approvals` | `approval_handler.dart` | My pending approvals |
| POST | `/v1/workflow/approvals/:id/approve` | `approval_handler.dart` | Approve |
| POST | `/v1/workflow/approvals/:id/reject` | `approval_handler.dart` | Reject |
| GET | `/v1/workflow/audit/:entityType/:id` | `audit_handler.dart` | Get audit trail |
| GET | `/v1/workflow/notifications` | `notification_handler.dart` | Workflow notifications |
| GET | `/v1/workflow/quality/deviations` | `deviation_handler.dart` | List deviations |
| GET | `/v1/workflow/quality/capas` | `capa_handler.dart` | List CAPAs |
| GET | `/v1/workflow/quality/change-controls` | `change_control_handler.dart` | List change controls |
| GET | `/v1/workflow/standard-reasons` | `standard_reason_handler.dart` | List standard reasons |
| GET | `/v1/workflow/admin/events` | `admin_events_handler.dart` | Admin event log |

### 3.7 HEALTH Module (3 handlers)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/v1/health` | `health_handler.dart` | Basic health check |
| GET | `/v1/health/detailed` | `health_detailed_handler.dart` | Detailed health |
| GET | `/v1/health/metrics` | `metrics_handler.dart` | Prometheus metrics |

### 3.8 Supporting Services

#### Lifecycle Monitor (7 handlers)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/health` | `health_handler.dart` | Service health |
| POST | `/jobs/archive` | `archive_job_handler.dart` | Archive old data |
| POST | `/jobs/compliance-metrics` | `compliance_metrics_handler.dart` | Calculate compliance |
| POST | `/jobs/events-fanout` | `events_fanout_handler.dart` | Process event outbox |
| POST | `/jobs/integrity-check` | `integrity_check_handler.dart` | Verify integrity |
| POST | `/jobs/overdue-training` | `overdue_training_handler.dart` | Check overdue |
| POST | `/jobs/periodic-review` | `periodic_review_handler.dart` | Process reviews |
| POST | `/jobs/report-generation` | `report_generation_handler.dart` | Generate reports |

#### Workflow Engine (4 handlers)

| Method | Endpoint | Handler | Description |
|--------|----------|---------|-------------|
| GET | `/health` | `health_handler.dart` | Service health |
| POST | `/internal/advance-step` | `advance_step_handler.dart` | Advance workflow |
| POST | `/internal/approve-step` | `approve_step_handler.dart` | Approve step |
| POST | `/internal/complete-workflow` | `complete_workflow_handler.dart` | Complete workflow |
| POST | `/internal/reject-workflow` | `reject_workflow_handler.dart` | Reject workflow |

---

## 4. Database Client (Supabase)

### 4.1 Client Initialization

```dart
// SupabaseService singleton
import 'package:supabase/supabase.dart';

class SupabaseService {
  static SupabaseService? _instance;
  late final SupabaseClient _client;
  
  SupabaseService._internal() {
    _client = SupabaseClient(
      Platform.environment['SUPABASE_URL']!,
      Platform.environment['SUPABASE_SERVICE_KEY']!,
    );
  }
  
  static SupabaseService get instance {
    _instance ??= SupabaseService._internal();
    return _instance!;
  }
  
  // Query builder access
  SupabaseQueryBuilder from(String table) => _client.from(table);
  
  // Storage access
  SupabaseStorageClient get storage => _client.storage;
  
  // Auth access (for user operations)
  GoTrueClient get auth => _client.auth;
}
```

### 4.2 Query Patterns

```dart
// List with pagination
final result = await supabase
    .from('employees')
    .select('id, employee_id, first_name, last_name, email, status')
    .eq('organization_id', orgId)
    .eq('status', 'active')
    .order('last_name')
    .range(offset, offset + limit - 1);

// Get single record
final employee = await supabase
    .from('employees')
    .select('*, department:departments(*), roles:employee_roles(role:roles(*))')
    .eq('id', employeeId)
    .single();

// Insert with return
final newRecord = await supabase
    .from('training_records')
    .insert({
      'employee_id': employeeId,
      'course_id': courseId,
      'organization_id': orgId,
      'training_date': DateTime.now().toIso8601String(),
      'overall_status': 'completed',
    })
    .select()
    .single();

// Update
await supabase
    .from('training_records')
    .update({'overall_status': 'completed'})
    .eq('id', recordId);

// Delete (soft delete pattern)
await supabase
    .from('documents')
    .update({'status': 'obsolete', 'is_active': false})
    .eq('id', documentId);

// Complex query with joins
final sessions = await supabase
    .from('training_sessions')
    .select('''
      *,
      schedule:training_schedules(*),
      attendance:session_attendance(
        *,
        employee:employees(id, first_name, last_name)
      )
    ''')
    .eq('organization_id', orgId)
    .gte('session_date', startDate)
    .lte('session_date', endDate)
    .order('session_date');
```

### 4.3 RPC Calls (Stored Procedures)

```dart
// Call PostgreSQL function
final result = await supabase.rpc('get_employee_compliance_status', params: {
  'p_employee_id': employeeId,
  'p_organization_id': orgId,
});

// Calculate training hours
final hours = await supabase.rpc('calculate_training_hours', params: {
  'p_employee_id': employeeId,
  'p_start_date': startDate,
  'p_end_date': endDate,
});
```

---

## 5. Authentication & Security Tools

### 5.1 JWT Handling

```dart
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

// Generate JWT
String generateAccessToken(Employee employee, List<String> permissions) {
  final jwt = JWT({
    'sub': employee.id,
    'org_id': employee.organizationId,
    'employee_id': employee.employeeId,
    'email': employee.email,
    'permissions': permissions,
    'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
  });
  
  return jwt.sign(
    SecretKey(jwtSecret),
    expiresIn: Duration(minutes: 15),
  );
}

// Verify JWT
Map<String, dynamic>? verifyToken(String token) {
  try {
    final jwt = JWT.verify(token, SecretKey(jwtSecret));
    return jwt.payload as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}
```

### 5.2 Hash Generation (21 CFR Part 11)

```dart
import 'package:crypto/crypto.dart';

// Generate integrity hash for e-signatures
String generateIntegrityHash(Map<String, dynamic> data, String previousHash) {
  final canonical = canonicalizeJson(data);
  final combined = '$canonical|${previousHash ?? ''}';
  final bytes = utf8.encode(combined);
  return sha256.convert(bytes).toString();
}

// Verify hash chain
bool verifyHashChain(List<AuditTrail> entries) {
  for (var i = 1; i < entries.length; i++) {
    final expected = generateAuditHash(
      entries[i].entityType,
      entries[i].entityId,
      entries[i].action,
      entries[i].performedBy,
      entries[i].createdAt,
      entries[i - 1].rowHash,
    );
    if (entries[i].rowHash != expected) {
      return false;
    }
  }
  return true;
}
```

---

## 6. File & Content Processing

### 6.1 SCORM Package Processing

```dart
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

// Extract and parse SCORM package
Future<ScormPackage> processScormUpload(List<int> zipBytes) async {
  final archive = ZipDecoder().decodeBytes(zipBytes);
  
  // Find imsmanifest.xml
  final manifestFile = archive.files.firstWhere(
    (f) => f.name.endsWith('imsmanifest.xml'),
    orElse: () => throw Exception('Invalid SCORM package: no manifest'),
  );
  
  // Parse manifest
  final manifestXml = XmlDocument.parse(utf8.decode(manifestFile.content));
  final metadata = manifestXml.findAllElements('metadata').first;
  final resources = manifestXml.findAllElements('resource');
  
  // Extract launch URL
  final launchResource = resources.firstWhere(
    (r) => r.getAttribute('adlcp:scormtype') == 'sco',
  );
  final launchUrl = launchResource.getAttribute('href');
  
  // Detect SCORM version
  final schemaVersion = metadata
      .findElements('schemaversion')
      .firstOrNull
      ?.text ?? '1.2';
  
  return ScormPackage(
    version: schemaVersion,
    launchUrl: launchUrl,
    manifestJson: manifestToJson(manifestXml),
  );
}
```

### 6.2 File Upload

```dart
// Upload to Supabase Storage
Future<String> uploadFile(
  String bucket,
  String path,
  List<int> bytes,
  String mimeType,
) async {
  final response = await supabase.storage
      .from(bucket)
      .uploadBinary(path, bytes, fileOptions: FileOptions(
        contentType: mimeType,
        upsert: false,
      ));
  
  return supabase.storage.from(bucket).getPublicUrl(path);
}

// Generate signed URL (for private files)
Future<String> getSignedUrl(String bucket, String path, {Duration? expiresIn}) async {
  return await supabase.storage
      .from(bucket)
      .createSignedUrl(path, expiresIn?.inSeconds ?? 3600);
}
```

---

## 7. Background Services

### 7.1 Lifecycle Monitor Jobs

| Job | Schedule | Handler | Description |
|-----|----------|---------|-------------|
| **Archive** | Daily 2am | `archive_job_handler.dart` | Archive old records |
| **Compliance Metrics** | Hourly | `compliance_metrics_handler.dart` | Calculate metrics |
| **Events Fanout** | Every 5min | `events_fanout_handler.dart` | Process event outbox |
| **Integrity Check** | Daily 3am | `integrity_check_handler.dart` | Verify hash chains |
| **Overdue Training** | Hourly | `overdue_training_handler.dart` | Check overdue |
| **Periodic Review** | Daily 1am | `periodic_review_handler.dart` | Process reviews |
| **Report Generation** | On-demand | `report_generation_handler.dart` | Generate reports |

### 7.2 Workflow Engine Operations

```dart
// Workflow state machine
enum WorkflowState {
  draft,
  initiated,
  pendingApproval,
  approved,
  returned,
  dropped,
  active,
  inactive,
}

// Valid transitions
final validTransitions = {
  WorkflowState.draft: [WorkflowState.initiated],
  WorkflowState.initiated: [WorkflowState.pendingApproval],
  WorkflowState.pendingApproval: [
    WorkflowState.approved,
    WorkflowState.returned,
    WorkflowState.dropped,
  ],
  WorkflowState.approved: [WorkflowState.active, WorkflowState.inactive],
  WorkflowState.returned: [WorkflowState.initiated],
  WorkflowState.active: [WorkflowState.inactive],
  WorkflowState.inactive: [WorkflowState.active],
};
```

---

## 8. Development Tools

### 8.1 Testing

```dart
// Unit test example
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  group('SessionCheckinHandler', () {
    late MockSupabaseClient mockSupabase;
    
    setUp(() {
      mockSupabase = MockSupabaseClient();
    });
    
    test('should return 400 if session ID missing', () async {
      final request = MockRequest(params: {});
      final response = await sessionCheckinHandler(request);
      expect(response.statusCode, 400);
    });
    
    test('should create attendance record', () async {
      when(() => mockSupabase.from('session_attendance').insert(any()))
          .thenAnswer((_) async => {'id': 'test-id'});
      
      final request = MockRequest(
        params: {'id': 'session-123'},
        body: {'method': 'biometric'},
      );
      
      final response = await sessionCheckinHandler(request);
      expect(response.statusCode, 200);
    });
  });
}
```

### 8.2 Logging

```dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
);

// Usage
logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message', error: exception, stackTrace: stackTrace);
```

---

## 9. API Response Patterns

### 9.1 Success Responses

```dart
// Single item
return Response.ok(body: {
  'data': employee.toJson(),
});

// List with pagination
return Response.ok(body: {
  'data': employees.map((e) => e.toJson()).toList(),
  'pagination': {
    'total': totalCount,
    'page': page,
    'limit': limit,
    'pages': (totalCount / limit).ceil(),
  },
});

// Action result
return Response.ok(body: {
  'success': true,
  'message': 'Training completed successfully',
  'training_record_id': recordId,
});
```

### 9.2 Error Responses

```dart
// 400 Bad Request
return Response.badRequest(body: {
  'error': 'Validation failed',
  'details': {
    'field': 'email',
    'message': 'Invalid email format',
  },
});

// 401 Unauthorized
return Response.unauthorized(body: {
  'error': 'Authentication required',
});

// 403 Forbidden
return Response.forbidden(body: {
  'error': 'Insufficient permissions',
  'required_permission': 'training:write',
});

// 404 Not Found
return Response.notFound(body: {
  'error': 'Resource not found',
  'resource': 'employee',
  'id': employeeId,
});

// 500 Internal Server Error
return Response.internalServerError(body: {
  'error': 'Internal server error',
  'request_id': requestId,
});
```

### 9.3 Standard Headers

```dart
// CORS headers (from middleware)
{
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
}

// Response headers
{
  'Content-Type': 'application/json',
  'X-Request-Id': requestId,
  'X-Response-Time': '${duration}ms',
}
```

---

## Quick Reference

### Endpoint Count by Module

| Module | Handlers | Approx. Endpoints |
|--------|----------|-------------------|
| ACCESS | 42 | ~100 |
| CREATE | 49 | ~120 |
| TRAIN | 42 | ~110 |
| CERTIFY | 31 | ~80 |
| REPORTS | 8 | ~25 |
| WORKFLOW | 9 | ~30 |
| HEALTH | 3 | ~5 |
| Lifecycle Monitor | 7 | ~10 |
| Workflow Engine | 4 | ~5 |
| **TOTAL** | **197** | **~646** |

### Technology Stack Summary

| Layer | Technology | Version |
|-------|------------|---------|
| API Framework | Relic HTTP | 1.2.0 |
| Database | PostgreSQL | 15+ |
| Database Client | Supabase | 2.5.0 |
| Auth | Supabase GoTrue | 2.0+ |
| JWT | dart_jsonwebtoken | 2.12.1 |
| Hashing | crypto | 3.0.3 |
| SCORM | archive + xml | 3.4.0 + 6.5.0 |
| Logging | logger | 2.3.0 |

---

*API Reference Version 3.0 — April 2026*
