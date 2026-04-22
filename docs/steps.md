# PharmaLearn LMS — Implementation Steps to Production-Ready Backend

**Document Version:** 2.0  
**Date:** 2026-04-26  
**Objective:** Fully implement `plan_2.md`, close all gaps in `gap_analysis.md`, achieve 100% URS compliance for backend/API layer

**Reference Documents:**
- `/docs/plan.md` — Original implementation plan
- `/docs/plan_2.md` — Detailed implementation plan
- `/docs/gap_analysis.md` — Gap analysis report
- `/ref/Learn IQ _ URS.pdf` — User Requirements Specification

---

## Current Implementation Status

### ✅ COMPLETED (No Action Needed)

| Component | Status | Files |
|-----------|--------|-------|
| **API Endpoints** | 358 endpoints mounted | 163 handler files |
| **Schema** | 232 tables frozen | G1-G14 migrations |
| **lifecycle_monitor Jobs** | 10 jobs implemented | events_fanout, periodic_review, etc. |
| **workflow_engine Internal** | 4 handlers implemented | advance, approve, reject, complete |
| **Quality Routes** | Full CRUD | deviations, CAPAs, change_controls |
| **Admin Events** | Status + dead-letter | admin_events_handler.dart |
| **Approval Routes** | list, get, approve, reject, return | approval_handler.dart |
| **Document Control** | Full lifecycle | 13 handlers |
| **Certificates** | CRUD + revoke + verify | certificates_handler.dart |
| **Remedial Training** | Full CRUD + workflow | remedial_handler.dart |
| **Reports** | Templates + run + download | 9 handlers |
| **SCORM** | Upload + launch + commit | scorm_handler.dart + ScormService |
| **E-Signatures** | CRUD + verify + history | esignatures routes |

### ⚠️ PARTIAL (Needs Fixes)

| Component | Issue | Action Required |
|-----------|-------|-----------------|
| **Waivers Table Name** | `waivers_handler.dart` uses `from('waivers')` but table is `training_waivers` | Fix 7 occurrences |
| **OJT Modules Join** | `me_training_history_handler.dart:100` uses `ojt_modules!inner` | Fix to use VIEW columns |
| **Training Obligations Table** | `me_dashboard_handler.dart:46` uses `training_obligations` | Fix to `employee_training_obligations` |
| **Assessments Handlers** | Only `grade` handler exists, missing answer/submit/get/history | Create 5 handlers |

### ❌ MISSING (Must Create)

| Component | Required By | Priority |
|-----------|-------------|----------|
| **Password Reset Handler** | URS §5.2.5 | HIGH |
| **Session QR Handler** | URS §5.1.21 | HIGH |
| **Assessment Answer Handler** | URS §5.1.12 | HIGH |
| **Assessment Submit Handler** | URS §5.1.14 | HIGH |
| **Assessment Get Handler** | URS §5.1.13 | MEDIUM |
| **Assessment History Handler** | URS §5.1.13 | MEDIUM |
| **Assessment Question Analysis** | URS §5.1.16 | MEDIUM |
| **Competency Admin CRUD** | URS §5.1.17 | MEDIUM |
| **Obligations Coordinator** | URS §5.1.30 | MEDIUM |
| **Return for Corrections** | URS §5.1.27 | MEDIUM |
| **CertificateService** | URS §5.1.15 | HIGH |
| **ReportGeneratorService** | URS §5.1.31 | HIGH |
| **RemedialService** | URS §5.1.14 | MEDIUM |

---

## Pre-Implementation Checklist

- [x] Schema frozen at 232 tables (G1–G14 migrations applied)
- [x] All 3 servers compile without errors (`dart analyze`)
- [x] 358 endpoints mounted across 3 servers
- [ ] Fix critical table name mismatches (Day 1 blocker)
- [ ] Create missing shared services

---

# WEEK 1: Critical Fixes + Missing Handlers

## Day 1: Phase 0 — Critical Bug Fixes (BLOCKING)

These MUST be done first — they cause runtime errors.

### Step 0.1: Fix Waivers Table Name ⚠️ CRITICAL

**File:** `api/lib/routes/certify/waivers/waivers_handler.dart`

**Current Issue:** Lines 28, 69, 126, 154, 205, 221, 243 use `from('waivers')` but actual table is `training_waivers`

**Fix Command:**
```bash
cd /Users/navadeepreddy/pharma_learn
sed -i '' "s/from('waivers')/from('training_waivers')/g" apps/api_server/pharma_learn/api/lib/routes/certify/waivers/waivers_handler.dart
```

**Additional Fixes Required:**
- [ ] Change `employee_assignment_id` → `assignment_id`
- [ ] Change status `'pending'` → `'pending_approval'`
- [ ] Verify column names match schema

**Validation:**
```bash
grep "from('waivers')" apps/api_server/pharma_learn/api/lib/routes/certify/waivers/*.dart
# Should return nothing
```

### Step 0.2: Fix OJT Modules Join ⚠️ CRITICAL

**File:** `api/lib/routes/train/me/me_training_history_handler.dart`

**Current Issue:** Line 100 uses `ojt_modules!inner` but VIEW doesn't have this FK

**Fix:** Remove the join since VIEW already has `ojt_masters` columns:
```dart
// BEFORE (line 100)
ojt_modules!inner (
  id, title, description
)

// AFTER
// Remove the join, use direct VIEW columns
```

**Actions:**
- [ ] Remove `ojt_modules!inner` join
- [ ] Remove `certificate_id` from select (not in VIEW)
- [ ] Use VIEW columns directly

### Step 0.3: Fix Training Obligations Table Name ⚠️ CRITICAL

**File:** `api/lib/routes/train/me/me_dashboard_handler.dart`

**Current Issue:** Line 46 uses `from('training_obligations')` but actual table is `employee_training_obligations`

**File:** `api/lib/routes/train/me/me_training_history_handler.dart`

**Current Issue:** Line 41 uses `from('training_obligations')`

**Fix Command:**
```bash
sed -i '' "s/from('training_obligations')/from('employee_training_obligations')/g" apps/api_server/pharma_learn/api/lib/routes/train/me/*.dart
```

### Step 0.4: Validation Checkpoint

```bash
cd /Users/navadeepreddy/pharma_learn
dart analyze apps/api_server/pharma_learn/api
# Expected: 0 errors (only style warnings allowed)
```

---

## Day 1-2: Phase 1 — Assessment Missing Handlers

### Step 1.1: Create Assessment Answer Handler ❌ MISSING

**Create:** `api/lib/routes/certify/assessments/assessment_answer_handler.dart`

**Spec (URS §5.1.12-13):**
```dart
/// POST /v1/certify/assessments/:id/answer
/// 
/// Records an answer for a single question during assessment.
/// Enforces timer with 30-second grace period.
Future<Response> assessmentAnswerHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  // Get attempt and verify ownership + timer
  final attempt = await supabase
      .from('assessment_attempts')
      .select('started_at, question_paper:question_papers(time_limit_minutes)')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .eq('status', 'in_progress')
      .single();

  // Timer enforcement with 30s grace
  final startedAt = DateTime.parse(attempt['started_at']);
  final timeLimit = attempt['question_paper']['time_limit_minutes'] as int;
  final deadline = startedAt.add(Duration(minutes: timeLimit, seconds: 30));
  
  if (DateTime.now().isAfter(deadline)) {
    throw ConflictException('Assessment time expired');
  }

  // Upsert response
  await supabase.from('assessment_responses').upsert({
    'attempt_id': attemptId,
    'question_id': body['question_id'],
    'selected_option_ids': body['selected_option_ids'],
    'text_response': body['text_response'],
    'time_spent_seconds': body['time_spent_seconds'],
    'is_marked_for_review': body['is_marked_for_review'] ?? false,
  }, onConflict: 'attempt_id,question_id');

  // Get progress
  final answered = await supabase
      .from('assessment_responses')
      .select('id')
      .eq('attempt_id', attemptId)
      .count();

  return ApiResponse.ok({
    'saved': true,
    'questions_answered': answered.count,
  }).toResponse();
}
```

**Actions:**
- [ ] Create handler file
- [ ] Add import in `routes.dart`
- [ ] Mount: `app.post('/v1/certify/assessments/:id/answer', assessmentAnswerHandler)`

### Step 1.2: Create Assessment Submit Handler ❌ MISSING

**Create:** `api/lib/routes/certify/assessments/assessment_submit_handler.dart`

**Spec (URS §5.1.14-16):**
```dart
/// POST /v1/certify/assessments/:id/submit
/// 
/// Submits assessment for grading. Auto-grades MCQ/T-F/matching.
/// Creates certificate on pass, remedial training on final fail.
Future<Response> assessmentSubmitHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get attempt
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        *, 
        question_paper:question_papers(pass_mark, questions:question_paper_questions(
          question:questions(id, question_type, marks, options:question_options(id, is_correct))
        ))
      ''')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .eq('status', 'in_progress')
      .single();

  // Get all responses
  final responses = await supabase
      .from('assessment_responses')
      .select('*')
      .eq('attempt_id', attemptId);

  // Auto-grade
  var totalMarks = 0.0;
  var obtainedMarks = 0.0;
  var manualReviewNeeded = false;

  for (final q in attempt['question_paper']['questions']) {
    final question = q['question'];
    final qId = question['id'];
    final qType = question['question_type'];
    final qMarks = (question['marks'] as num).toDouble();
    totalMarks += qMarks;

    final response = responses.firstWhere(
      (r) => r['question_id'] == qId,
      orElse: () => null,
    );

    if (response == null) continue;

    if (['mcq', 'true_false', 'matching'].contains(qType)) {
      // Auto-grade
      final correctIds = question['options']
          .where((o) => o['is_correct'] == true)
          .map((o) => o['id'])
          .toSet();
      final selectedIds = (response['selected_option_ids'] as List?)?.toSet() ?? {};
      
      if (setEquals(correctIds, selectedIds)) {
        obtainedMarks += qMarks;
        await supabase.from('assessment_responses')
            .update({'marks_awarded': qMarks, 'is_correct': true})
            .eq('id', response['id']);
      } else {
        await supabase.from('assessment_responses')
            .update({'marks_awarded': 0, 'is_correct': false})
            .eq('id', response['id']);
      }
    } else {
      // Essay/short answer needs manual review
      manualReviewNeeded = true;
    }
  }

  final percentage = totalMarks > 0 ? (obtainedMarks / totalMarks) * 100 : 0;
  final passMark = attempt['question_paper']['pass_mark'] as num;
  final isPassed = !manualReviewNeeded && percentage >= passMark;

  // Update attempt
  await supabase.from('assessment_attempts').update({
    'status': manualReviewNeeded ? 'in_review' : 'graded',
    'total_marks': totalMarks,
    'obtained_marks': obtainedMarks,
    'percentage': percentage,
    'is_passed': isPassed,
    'submitted_at': DateTime.now().toIso8601String(),
  }).eq('id', attemptId);

  // If passed, generate certificate (when CertificateService exists)
  if (isPassed) {
    // TODO: await CertificateService(supabase).generateCertificate(...)
    await EventPublisher.publish(supabase,
      eventType: 'assessment.passed',
      aggregateType: 'assessment_attempt',
      aggregateId: attemptId,
      orgId: auth.orgId,
      payload: {'percentage': percentage},
    );
  } else if (!manualReviewNeeded) {
    // Check if max attempts reached
    final obligation = await supabase
        .from('employee_training_obligations')
        .select('id, max_attempts')
        .eq('id', attempt['obligation_id'])
        .single();
    
    if (attempt['attempt_number'] >= obligation['max_attempts']) {
      // Create remedial training
      await supabase.from('training_remedials').insert({
        'employee_id': auth.employeeId,
        'original_obligation_id': obligation['id'],
        'reason': 'Failed assessment after max attempts',
        'status': 'pending',
        'organization_id': auth.orgId,
      });
    }

    await EventPublisher.publish(supabase,
      eventType: 'assessment.failed',
      aggregateType: 'assessment_attempt',
      aggregateId: attemptId,
      orgId: auth.orgId,
      payload: {'percentage': percentage, 'attempt_number': attempt['attempt_number']},
    );
  }

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'status': manualReviewNeeded ? 'in_review' : 'graded',
    'total_marks': totalMarks,
    'obtained_marks': obtainedMarks,
    'percentage': percentage,
    'is_passed': isPassed,
  }).toResponse();
}
```

**Actions:**
- [ ] Create handler file
- [ ] Add import in `routes.dart`
- [ ] Mount: `app.post('/v1/certify/assessments/:id/submit', assessmentSubmitHandler)`

### Step 1.3: Create Assessment Get Handler ❌ MISSING

**Create:** `api/lib/routes/certify/assessments/assessment_get_handler.dart`

```dart
/// GET /v1/certify/assessments/:id
Future<Response> assessmentGetHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        *,
        question_paper:question_papers(*),
        responses:assessment_responses(*)
      ''')
      .eq('id', attemptId)
      .eq('employee_id', auth.employeeId)
      .single();

  return ApiResponse.ok({'attempt': attempt}).toResponse();
}
```

### Step 1.4: Create Assessment History Handler ❌ MISSING

**Create:** `api/lib/routes/certify/assessments/assessment_history_handler.dart`

```dart
/// GET /v1/certify/assessments/history
Future<Response> assessmentHistoryHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  
  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final offset = (page - 1) * perPage;

  final attempts = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, percentage, is_passed, attempt_number, submitted_at,
        question_paper:question_papers(id, title)
      ''')
      .eq('employee_id', auth.employeeId)
      .order('submitted_at', ascending: false)
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'history': attempts}).toResponse();
}
```

### Step 1.5: Create Assessment Question Analysis Handler ❌ MISSING

**Create:** `api/lib/routes/certify/assessments/assessment_question_analysis_handler.dart`

```dart
/// GET /v1/certify/assessments/:id/questions/analysis
/// Admin/trainer only - psychometric analysis
Future<Response> assessmentQuestionAnalysisHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check
  if (!auth.hasPermission('assessments.analyze')) {
    throw PermissionDeniedException('Analysis permission required');
  }

  final analysis = await supabase.rpc('get_question_analysis', params: {
    'p_attempt_id': attemptId,
  });

  return ApiResponse.ok({'analysis': analysis}).toResponse();
}
```

### Step 1.6: Update Assessments Routes

**File:** `api/lib/routes/certify/assessments/routes.dart`

```dart
import 'assessment_answer_handler.dart';
import 'assessment_submit_handler.dart';
import 'assessment_get_handler.dart';
import 'assessment_history_handler.dart';
import 'assessment_question_analysis_handler.dart';

void mountAssessmentsRoutes(RelicApp app) {
  // Existing routes...
  
  // NEW routes
  app.get('/v1/certify/assessments/history', assessmentHistoryHandler);
  app.get('/v1/certify/assessments/:id', assessmentGetHandler);
  app.post('/v1/certify/assessments/:id/answer', assessmentAnswerHandler);
  app.post('/v1/certify/assessments/:id/submit', assessmentSubmitHandler);
  app.get('/v1/certify/assessments/:id/questions/analysis', assessmentQuestionAnalysisHandler);
}
```

---

## Day 2-3: Phase 1 — Other Missing Handlers

### Step 1.7: Create Password Reset Handler ❌ MISSING

**Create:** `api/lib/routes/access/auth/password_reset_handler.dart`

**Spec (URS §5.2.5):**
```dart
import 'dart:convert';
import 'dart:math';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/auth/password/reset-request (PUBLIC)
Future<Response> passwordResetRequestHandler(Request req) async {
  final supabase = SupabaseService.client;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  final email = body['email'] as String?;

  if (email == null || email.isEmpty) {
    throw ValidationException({'email': 'Email is required'});
  }

  // Look up employee (but don't reveal if exists)
  final employee = await supabase
      .from('employees')
      .select('id')
      .eq('email', email.toLowerCase())
      .maybeSingle();

  if (employee != null) {
    // Generate token
    final token = _generateSecureToken();
    final expiresAt = DateTime.now().add(const Duration(minutes: 15));

    await supabase.from('password_reset_tokens').insert({
      'employee_id': employee['id'],
      'token': token,
      'expires_at': expiresAt.toIso8601String(),
    });

    // Send email via Edge Function
    // await supabase.functions.invoke('send-notification', body: {...});
  }

  // Always return success (security - don't reveal if email exists)
  return ApiResponse.ok({
    'message': 'If the email exists, a reset link has been sent',
  }).toResponse();
}

/// POST /v1/auth/password/reset (PUBLIC)
Future<Response> passwordResetHandler(Request req) async {
  final supabase = SupabaseService.client;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  
  final token = body['token'] as String?;
  final newPassword = body['new_password'] as String?;

  if (token == null || newPassword == null) {
    throw ValidationException({
      'token': token == null ? 'Token is required' : null,
      'new_password': newPassword == null ? 'New password is required' : null,
    });
  }

  // Validate token
  final resetToken = await supabase
      .from('password_reset_tokens')
      .select('id, employee_id, expires_at')
      .eq('token', token)
      .isFilter('used_at', null)
      .maybeSingle();

  if (resetToken == null) {
    throw ValidationException({'token': 'Invalid or expired token'});
  }

  final expiresAt = DateTime.parse(resetToken['expires_at']);
  if (DateTime.now().isAfter(expiresAt)) {
    throw ValidationException({'token': 'Token has expired'});
  }

  // Get password policy and validate
  final policy = await supabase
      .from('password_policies')
      .select()
      .eq('is_active', true)
      .maybeSingle();

  if (policy != null) {
    final minLength = policy['min_length'] as int? ?? 8;
    if (newPassword.length < minLength) {
      throw ValidationException({'new_password': 'Password must be at least $minLength characters'});
    }
    // Add more policy checks as needed
  }

  // Get employee's auth user_id
  final employee = await supabase
      .from('employees')
      .select('user_id')
      .eq('id', resetToken['employee_id'])
      .single();

  // Update password via GoTrue
  await supabase.auth.admin.updateUserById(
    employee['user_id'],
    attributes: AdminUserAttributes(password: newPassword),
  );

  // Mark token as used
  await supabase.from('password_reset_tokens').update({
    'used_at': DateTime.now().toIso8601String(),
  }).eq('id', resetToken['id']);

  // Audit log
  await supabase.from('audit_trails').insert({
    'entity_type': 'employee',
    'entity_id': resetToken['employee_id'],
    'action': 'PASSWORD_RESET',
    'event_category': 'AUTH',
    'performed_by': resetToken['employee_id'],
  });

  return ApiResponse.ok({'message': 'Password reset successfully'}).toResponse();
}

String _generateSecureToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}
```

**Update:** `api/lib/routes/access/auth/routes.dart`
```dart
// Add as PUBLIC routes (no authMiddleware)
app.post('/v1/auth/password/reset-request', passwordResetRequestHandler);
app.post('/v1/auth/password/reset', passwordResetHandler);
```

### Step 1.8: Create Session QR Handler ❌ MISSING

**Create:** `api/lib/routes/train/sessions/session_qr_handler.dart`

**Spec (URS §5.1.21):**
```dart
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// GET /v1/train/sessions/:id/qr
/// Generates QR token for session check-in
Future<Response> sessionQrHandler(Request req) async {
  final sessionId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Permission check - trainer or coordinator
  if (!auth.hasAnyPermission(['training.sessions.manage', 'training.manage'])) {
    throw PermissionDeniedException('Trainer access required');
  }

  // Get session and verify it's in progress
  final session = await supabase
      .from('training_sessions')
      .select('id, status, end_time')
      .eq('id', sessionId)
      .single();

  if (session['status'] != 'in_progress') {
    throw ConflictException('Session must be in progress to generate QR');
  }

  // Generate QR token with HMAC
  final qrSecret = const String.fromEnvironment('QR_SECRET', defaultValue: 'pharmalearn-qr-secret');
  final expiresAt = session['end_time'] != null 
      ? DateTime.parse(session['end_time'])
      : DateTime.now().add(const Duration(hours: 8));

  final payload = base64Url.encode(utf8.encode('$sessionId|${expiresAt.toIso8601String()}'));
  final hmac = Hmac(sha256, utf8.encode(qrSecret));
  final signature = hmac.convert(utf8.encode(payload)).toString();
  final qrToken = '$payload.$signature';

  // Store token in session
  await supabase.from('training_sessions').update({
    'qr_token': qrToken,
    'qr_expires_at': expiresAt.toIso8601String(),
  }).eq('id', sessionId);

  return ApiResponse.ok({
    'qr_token': qrToken,
    'qr_expires_at': expiresAt.toIso8601String(),
    'session_id': sessionId,
  }).toResponse();
}
```

**Update:** `api/lib/routes/train/sessions/routes.dart`
```dart
app.get('/v1/train/sessions/:id/qr', sessionQrHandler);
```

### Step 1.9: Create Competency Admin Handler ❌ MISSING

**Create:** `api/lib/routes/certify/competencies/competency_admin_handler.dart`

**Spec (URS §5.1.17):**
```dart
/// POST /v1/certify/competencies
Future<Response> competencyCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('competencies.manage')) {
    throw PermissionDeniedException('Competency management permission required');
  }

  final competency = await supabase.from('competencies').insert({
    'name': body['name'],
    'description': body['description'],
    'category': body['category'],
    'required_level': body['required_level'],
    'assessment_criteria': body['assessment_criteria'],
    'organization_id': auth.orgId,
  }).select().single();

  return ApiResponse.created({'competency': competency}).toResponse();
}

/// PATCH /v1/certify/competencies/:id
Future<Response> competencyUpdateHandler(Request req) async {
  final id = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('competencies.manage')) {
    throw PermissionDeniedException('Competency management permission required');
  }

  final updated = await supabase.from('competencies')
      .update({
        if (body.containsKey('name')) 'name': body['name'],
        if (body.containsKey('description')) 'description': body['description'],
        if (body.containsKey('category')) 'category': body['category'],
        if (body.containsKey('required_level')) 'required_level': body['required_level'],
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .select()
      .single();

  return ApiResponse.ok({'competency': updated}).toResponse();
}

/// DELETE /v1/certify/competencies/:id (soft delete)
Future<Response> competencyDeleteHandler(Request req) async {
  final id = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission('competencies.manage')) {
    throw PermissionDeniedException('Competency management permission required');
  }

  await supabase.from('competencies')
      .update({'is_active': false, 'updated_at': DateTime.now().toIso8601String()})
      .eq('id', id)
      .eq('organization_id', auth.orgId);

  return ApiResponse.ok({'message': 'Competency deactivated'}).toResponse();
}

/// POST /v1/certify/competencies/:id/assign
Future<Response> competencyAssignHandler(Request req) async {
  final competencyId = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('competencies.assign')) {
    throw PermissionDeniedException('Competency assignment permission required');
  }

  final assignment = await supabase.from('employee_competencies').insert({
    'employee_id': body['employee_id'],
    'competency_id': competencyId,
    'attained_level': body['attained_level'],
    'assessed_by': auth.employeeId,
    'evidence': body['evidence'],
    'organization_id': auth.orgId,
  }).select().single();

  return ApiResponse.created({'assignment': assignment}).toResponse();
}

/// GET /v1/certify/competencies
Future<Response> competenciesListHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final offset = (page - 1) * perPage;

  final competencies = await supabase
      .from('competencies')
      .select()
      .eq('organization_id', auth.orgId)
      .eq('is_active', true)
      .order('name')
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'competencies': competencies}).toResponse();
}
```

### Step 1.10: Create Obligations Coordinator Handler ❌ MISSING

**Create:** `api/lib/routes/train/obligations/obligations_coordinator_handler.dart`

**Spec (URS §5.1.30):**
```dart
/// GET /v1/train/obligations/coordinator
Future<Response> obligationsCoordinatorDashboardHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  if (!auth.hasPermission('training.obligations.manage')) {
    throw PermissionDeniedException('Coordinator access required');
  }

  // Get summary stats
  final total = await supabase
      .from('employee_training_obligations')
      .select()
      .eq('organization_id', auth.orgId)
      .neq('status', 'completed')
      .count();

  final atRisk = await supabase
      .from('employee_training_obligations')
      .select()
      .eq('organization_id', auth.orgId)
      .inFilter('status', ['pending', 'in_progress'])
      .lte('due_date', DateTime.now().add(Duration(days: 7)).toIso8601String())
      .count();

  final overdue = await supabase
      .from('employee_training_obligations')
      .select()
      .eq('organization_id', auth.orgId)
      .eq('status', 'overdue')
      .count();

  return ApiResponse.ok({
    'total': total.count,
    'at_risk': atRisk.count,
    'not_at_risk': total.count - atRisk.count - overdue.count,
    'overdue': overdue.count,
  }).toResponse();
}

/// GET /v1/train/obligations/coordinator/at-risk
Future<Response> obligationsAtRiskHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final page = int.tryParse(req.url.queryParameters['page'] ?? '1') ?? 1;
  final perPage = int.tryParse(req.url.queryParameters['per_page'] ?? '20') ?? 20;
  final offset = (page - 1) * perPage;

  final atRisk = await supabase
      .from('employee_training_obligations')
      .select('''
        *,
        employee:employees(id, full_name, employee_number, department_id),
        course:courses(id, title)
      ''')
      .eq('organization_id', auth.orgId)
      .inFilter('status', ['pending', 'in_progress'])
      .lte('due_date', DateTime.now().add(Duration(days: 7)).toIso8601String())
      .order('due_date')
      .range(offset, offset + perPage - 1);

  return ApiResponse.ok({'at_risk_obligations': atRisk}).toResponse();
}

/// POST /v1/train/obligations
Future<Response> obligationCreateHandler(Request req) async {
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('training.obligations.create')) {
    throw PermissionDeniedException('Create obligation permission required');
  }

  final employeeIds = body['employee_ids'] as List<dynamic>;
  final obligations = <Map<String, dynamic>>[];

  for (final empId in employeeIds) {
    obligations.add({
      'employee_id': empId,
      'course_id': body['course_id'],
      'due_date': body['due_date'],
      'status': 'pending',
      'assigned_by': auth.employeeId,
      'organization_id': auth.orgId,
    });
  }

  final created = await supabase
      .from('employee_training_obligations')
      .insert(obligations)
      .select();

  return ApiResponse.created({
    'obligations': created,
    'count': created.length,
  }).toResponse();
}

/// PATCH /v1/train/obligations/:id/extend
Future<Response> obligationExtendHandler(Request req) async {
  final id = req.rawPathParameters[#id];
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;

  if (!auth.hasPermission('training.obligations.manage')) {
    throw PermissionDeniedException('Manage obligation permission required');
  }

  final reason = body['reason'] as String?;
  if (reason == null || reason.isEmpty) {
    throw ValidationException({'reason': 'Extension reason is required'});
  }

  // Get original due date
  final original = await supabase
      .from('employee_training_obligations')
      .select('due_date')
      .eq('id', id)
      .eq('organization_id', auth.orgId)
      .single();

  final updated = await supabase.from('employee_training_obligations').update({
    'due_date': body['new_due_date'],
    'extension_reason': reason,
    'extended_by': auth.employeeId,
    'extended_at': DateTime.now().toIso8601String(),
  }).eq('id', id).select().single();

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': 'training_obligation',
    'entity_id': id,
    'action': 'DUE_DATE_EXTENDED',
    'details': jsonEncode({
      'original_due_date': original['due_date'],
      'new_due_date': body['new_due_date'],
      'reason': reason,
    }),
    'performed_by': auth.employeeId,
    'organization_id': auth.orgId,
  });

  return ApiResponse.ok({'obligation': updated}).toResponse();
}
```

---

## Day 3: Validation Checkpoint

```bash
cd /Users/navadeepreddy/pharma_learn

# Run analysis
dart analyze apps/api_server/pharma_learn/api
dart analyze apps/api_server/pharma_learn/lifecycle_monitor
dart analyze apps/api_server/pharma_learn/workflow_engine

# Count endpoints (should be ~370+)
grep -rE "app\.(get|post|patch|put|delete)" apps/api_server/pharma_learn/api/lib/routes/ --include="routes.dart" | wc -l
```

**Checklist:**
- [ ] All table name fixes applied
- [ ] 5 assessment handlers created
- [ ] Password reset handler created (2 endpoints)
- [ ] Session QR handler created
- [ ] Competency admin handlers created (5 endpoints)
- [ ] Obligations coordinator handlers created (4 endpoints)
- [ ] `dart analyze` passes with 0 errors
- [ ] ~370+ endpoints mounted

---

# WEEK 2: Shared Services + Workflow Completion

## Day 4-5: Create Missing Shared Services

### Step 2.1: Create CertificateService ❌ MISSING (HIGH PRIORITY)

**Create:** `packages/pharmalearn_shared/lib/src/services/certificate_service.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase/supabase.dart';

import 'esig_service.dart';
import '../utils/event_publisher.dart';

class CertificateService {
  final SupabaseClient _supabase;

  CertificateService(this._supabase);

  Future<Map<String, dynamic>> generateCertificate({
    required String employeeId,
    required String trainingRecordId,
    required String orgId,
    String? courseId,
    double? score,
  }) async {
    // 1. Get employee data
    final employee = await _supabase
        .from('employees')
        .select('id, full_name, employee_number')
        .eq('id', employeeId)
        .single();

    // 2. Get training record with course
    final record = await _supabase
        .from('training_records')
        .select('*, course:courses(id, title, validity_months)')
        .eq('id', trainingRecordId)
        .single();

    // 3. Get organization
    final org = await _supabase
        .from('organizations')
        .select('id, name, logo_url')
        .eq('id', orgId)
        .single();

    // 4. Generate certificate number
    final certNumber = await _supabase.rpc('generate_next_number', params: {
      'p_org_id': orgId,
      'p_scheme_type': 'certificate',
    });

    // 5. Calculate dates
    final issuedAt = DateTime.now();
    final course = record['course'];
    final validityMonths = course['validity_months'] as int?;
    final validUntil = validityMonths != null
        ? issuedAt.add(Duration(days: validityMonths * 30))
        : null;

    // 6. Build PDF
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (context) => pw.Center(
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text('CERTIFICATE OF COMPLETION',
                style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            pw.Text('This is to certify that'),
            pw.SizedBox(height: 10),
            pw.Text(employee['full_name'],
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Text('has successfully completed'),
            pw.SizedBox(height: 10),
            pw.Text(course['title'],
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            if (score != null) pw.Text('Score: ${score.toStringAsFixed(1)}%'),
            pw.SizedBox(height: 20),
            pw.Text('Certificate Number: $certNumber'),
            pw.Text('Date of Issue: ${issuedAt.toIso8601String().substring(0, 10)}'),
            if (validUntil != null)
              pw.Text('Valid Until: ${validUntil.toIso8601String().substring(0, 10)}'),
            pw.SizedBox(height: 30),
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: 'https://app.pharmalearn.com/verify/$certNumber',
              width: 100,
              height: 100,
            ),
          ],
        ),
      ),
    ));

    // 7. Save PDF bytes
    final pdfBytes = await pdf.save();
    
    // 8. Compute hash
    final fileHash = sha256.convert(pdfBytes).toString();

    // 9. Upload to storage
    final storagePath = 'certificates/$orgId/$certNumber.pdf';
    await _supabase.storage
        .from('pharmalearn-files')
        .uploadBinary(storagePath, Uint8List.fromList(pdfBytes));

    // 10. Create e-signature
    final esig = await EsigService(_supabase).createEsignature(
      entityType: 'certificate',
      entityId: certNumber,
      meaning: 'CERTIFICATE_ISSUED',
      signedBy: 'SYSTEM',
      orgId: orgId,
    );

    // 11. Insert certificate record
    final cert = await _supabase.from('certificates').insert({
      'certificate_number': certNumber,
      'employee_id': employeeId,
      'training_record_id': trainingRecordId,
      'organization_id': orgId,
      'issued_at': issuedAt.toIso8601String(),
      'valid_until': validUntil?.toIso8601String(),
      'status': 'active',
      'file_path': storagePath,
      'file_hash': fileHash,
      'esignature_id': esig['id'],
    }).select().single();

    // 12. Update training record
    await _supabase.from('training_records')
        .update({'certificate_id': cert['id']})
        .eq('id', trainingRecordId);

    // 13. Publish event
    await EventPublisher.publish(
      _supabase,
      eventType: 'certificate.issued',
      aggregateType: 'certificate',
      aggregateId: cert['id'],
      orgId: orgId,
      payload: {
        'certificate_number': certNumber,
        'employee_id': employeeId,
        'course_id': courseId,
      },
    );

    return cert;
  }
}
```

**Actions:**
- [ ] Create service file
- [ ] Add `pdf` package to pubspec.yaml if not present
- [ ] Export from `pharmalearn_shared.dart`
- [ ] Wire into assessment_submit_handler

### Step 2.2: Create ReportGeneratorService ❌ MISSING (HIGH PRIORITY)

**Create:** `packages/pharmalearn_shared/lib/src/services/report_generator_service.dart`

```dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase/supabase.dart';

class ReportGeneratorService {
  final SupabaseClient _supabase;

  ReportGeneratorService(this._supabase);

  /// Process all queued reports
  Future<int> processQueuedReports() async {
    final queued = await _supabase
        .from('report_executions')
        .select('*, template:report_templates(*)')
        .eq('status', 'queued')
        .order('created_at')
        .limit(10);

    var processed = 0;
    for (final report in queued) {
      await _generateReport(report);
      processed++;
    }
    return processed;
  }

  Future<void> _generateReport(Map<String, dynamic> report) async {
    final reportId = report['id'];
    final now = DateTime.now();

    // Update status to processing
    await _supabase.from('report_executions').update({
      'status': 'processing',
      'started_at': now.toIso8601String(),
    }).eq('id', reportId);

    try {
      final templateKey = report['template']['template_key'] as String;
      final parameters = report['parameters'] as Map<String, dynamic>? ?? {};

      // Fetch data based on template
      final data = await _fetchReportData(templateKey, parameters);

      // Generate PDF
      final pdfBytes = await _generatePdf(report['template'], data);
      
      // Generate CSV
      final csvBytes = _generateCsv(data);

      // Compute hashes
      final pdfHash = sha256.convert(pdfBytes).toString();

      // Upload to storage
      final orgId = report['organization_id'];
      final basePath = 'reports/$orgId/${report['id']}';
      
      await _supabase.storage.from('pharmalearn-files')
          .uploadBinary('$basePath.pdf', Uint8List.fromList(pdfBytes));
      await _supabase.storage.from('pharmalearn-files')
          .uploadBinary('$basePath.csv', Uint8List.fromList(csvBytes));

      // Update execution record
      await _supabase.from('report_executions').update({
        'status': 'ready',
        'completed_at': DateTime.now().toIso8601String(),
        'storage_path_pdf': '$basePath.pdf',
        'storage_path_csv': '$basePath.csv',
        'file_hash': pdfHash,
      }).eq('id', reportId);

      // Notify requester
      await _supabase.from('notifications').insert({
        'employee_id': report['requested_by'],
        'template_key': 'report_ready',
        'title': 'Report Ready',
        'body': 'Your report "${report['template']['name']}" is ready for download.',
        'entity_type': 'report_execution',
        'entity_id': reportId,
        'organization_id': orgId,
      });
    } catch (e) {
      await _supabase.from('report_executions').update({
        'status': 'failed',
        'error_message': e.toString(),
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', reportId);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchReportData(
    String templateKey,
    Map<String, dynamic> parameters,
  ) async {
    switch (templateKey) {
      case 'employee_training_dossier':
        return await _fetchTrainingDossier(parameters);
      case 'department_compliance_summary':
        return await _fetchDepartmentCompliance(parameters);
      case 'overdue_training_report':
        return await _fetchOverdueTraining(parameters);
      case 'certificate_expiry_report':
        return await _fetchCertificateExpiry(parameters);
      case 'assessment_performance_report':
        return await _fetchAssessmentPerformance(parameters);
      case 'esignature_audit_report':
        return await _fetchEsignatureAudit(parameters);
      case 'system_access_log_report':
        return await _fetchSystemAccessLog(parameters);
      default:
        throw Exception('Unknown report template: $templateKey');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTrainingDossier(Map<String, dynamic> params) async {
    final employeeId = params['employee_id'];
    return await _supabase
        .from('employee_training_obligations')
        .select('*, course:courses(title), certificate:certificates(certificate_number)')
        .eq('employee_id', employeeId)
        .order('completed_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _fetchDepartmentCompliance(Map<String, dynamic> params) async {
    final deptId = params['department_id'];
    return await _supabase.rpc('get_department_compliance', params: {
      'p_department_id': deptId,
    });
  }

  Future<List<Map<String, dynamic>>> _fetchOverdueTraining(Map<String, dynamic> params) async {
    var query = _supabase
        .from('employee_training_obligations')
        .select('*, employee:employees(full_name, department_id), course:courses(title)')
        .eq('status', 'overdue');
    
    if (params['department_id'] != null) {
      query = query.eq('employee.department_id', params['department_id']);
    }
    
    return await query.order('due_date');
  }

  Future<List<Map<String, dynamic>>> _fetchCertificateExpiry(Map<String, dynamic> params) async {
    final daysAhead = params['days_ahead'] as int? ?? 30;
    final cutoff = DateTime.now().add(Duration(days: daysAhead));
    
    return await _supabase
        .from('certificates')
        .select('*, employee:employees(full_name)')
        .lte('valid_until', cutoff.toIso8601String())
        .eq('status', 'active')
        .order('valid_until');
  }

  Future<List<Map<String, dynamic>>> _fetchAssessmentPerformance(Map<String, dynamic> params) async {
    return await _supabase.rpc('get_assessment_performance', params: {
      'p_course_id': params['course_id'],
      'p_date_from': params['date_from'],
      'p_date_to': params['date_to'],
    });
  }

  Future<List<Map<String, dynamic>>> _fetchEsignatureAudit(Map<String, dynamic> params) async {
    return await _supabase
        .from('electronic_signatures')
        .select('*, signer:employees(full_name)')
        .gte('signed_at', params['date_from'])
        .lte('signed_at', params['date_to'])
        .order('signed_at', ascending: false);
  }

  Future<List<Map<String, dynamic>>> _fetchSystemAccessLog(Map<String, dynamic> params) async {
    return await _supabase
        .from('audit_trails')
        .select('*, performer:employees(full_name)')
        .ilike('action', 'AUTH%')
        .gte('created_at', params['date_from'])
        .lte('created_at', params['date_to'])
        .order('created_at', ascending: false);
  }

  Future<List<int>> _generatePdf(
    Map<String, dynamic> template,
    List<Map<String, dynamic>> data,
  ) async {
    final pdf = pw.Document();
    
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(template['name'], style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.Text('Generated: ${DateTime.now().toIso8601String()}'),
          pw.Divider(),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('CONTROLLED DOCUMENT — TRAINING RECORD'),
          pw.Text('Page ${context.pageNumber} of ${context.pagesCount}'),
        ],
      ),
      build: (context) => [
        pw.Table.fromTextArray(
          data: [
            data.isNotEmpty ? data.first.keys.toList() : [],
            ...data.map((row) => row.values.map((v) => v?.toString() ?? '').toList()),
          ],
        ),
      ],
    ));

    return await pdf.save();
  }

  List<int> _generateCsv(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return utf8.encode('No data');

    final headers = data.first.keys.toList();
    final rows = data.map((row) => row.values.map((v) => v?.toString() ?? '').toList()).toList();

    final csv = const ListToCsvConverter().convert([headers, ...rows]);
    
    // Add BOM for Excel compatibility
    return [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
  }
}
```

### Step 2.3: Create Return for Corrections Handler ❌ MISSING

**Create:** `workflow_engine/lib/routes/internal/return_for_corrections_handler.dart`

```dart
import 'dart:convert';
import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /internal/workflow/return
/// Soft-reject: returns entity to submitter for corrections
Future<Response> returnForCorrectionsHandler(Request req) async {
  final body = await readJson(req);
  final stepId = body['step_id'] as String;
  final returnedBy = body['returned_by'] as String;
  final reason = body['reason'] as String;
  final corrections = body['corrections'] as List<dynamic>?;
  final esignatureId = body['esignature_id'] as String?;
  
  final supabase = SupabaseService.client;
  final now = DateTime.now().toUtc();

  // Get step details
  final step = await supabase
      .from('approval_steps')
      .select('entity_type, entity_id, organization_id')
      .eq('id', stepId)
      .single();

  final entityType = step['entity_type'] as String;
  final entityId = step['entity_id'] as String;
  final orgId = step['organization_id'] as String;

  // Mark step as returned
  await supabase.from('approval_steps').update({
    'status': 'returned',
    'return_reason': reason,
    'returned_by': returnedBy,
    'returned_at': now.toIso8601String(),
  }).eq('id', stepId);

  // Reset other pending steps to allow resubmission
  await supabase.from('approval_steps').update({
    'status': 'cancelled',
  }).eq('entity_type', entityType)
    .eq('entity_id', entityId)
    .eq('status', 'pending');

  // Update entity status
  final tableMap = {
    'document': 'documents',
    'course': 'courses',
    'training_plan': 'training_plans',
    'schedule': 'training_schedules',
    'waiver': 'training_waivers',
  };
  final tableName = tableMap[entityType];
  
  if (tableName != null) {
    await supabase.from(tableName).update({
      'status': 'RETURNED',
      'updated_at': now.toIso8601String(),
    }).eq('id', entityId);
  }

  // Create return record
  await supabase.from('approval_returns').insert({
    'approval_step_id': stepId,
    'entity_type': entityType,
    'entity_id': entityId,
    'returned_by': returnedBy,
    'return_reason': reason,
    'requested_corrections': corrections != null ? jsonEncode(corrections) : null,
    'organization_id': orgId,
  });

  // Get submitter for notification
  final entity = await supabase.from(tableName!).select('created_by').eq('id', entityId).single();

  // Notify submitter
  await supabase.from('notifications').insert({
    'employee_id': entity['created_by'],
    'template_key': 'approval_returned',
    'title': 'Corrections Required',
    'body': reason,
    'entity_type': entityType,
    'entity_id': entityId,
    'organization_id': orgId,
  });

  // Publish event
  await EventPublisher.publish(
    supabase,
    eventType: '$entityType.returned',
    aggregateType: entityType,
    aggregateId: entityId,
    orgId: orgId,
    payload: {
      'returned_by': returnedBy,
      'reason': reason,
      'corrections': corrections,
    },
  );

  // Audit trail
  await supabase.from('audit_trails').insert({
    'entity_type': entityType,
    'entity_id': entityId,
    'action': 'RETURNED_FOR_CORRECTIONS',
    'event_category': 'WORKFLOW',
    'performed_by': returnedBy,
    'organization_id': orgId,
    'esignature_id': esignatureId,
    'details': jsonEncode({'reason': reason, 'corrections': corrections}),
  });

  return ApiResponse.ok({
    'result': 'returned',
    'entity_type': entityType,
    'entity_id': entityId,
  }).toResponse();
}
```

**Update:** `workflow_engine/lib/routes/internal/routes.dart`
```dart
import 'return_for_corrections_handler.dart';

// Add to mountInternalRoutes:
app.post('/internal/workflow/return', returnForCorrectionsHandler);
```

---

## Day 6-7: Wire Services + Final Validation

### Step 3.1: Update assessmentSubmitHandler to Use CertificateService

**File:** `api/lib/routes/certify/assessments/assessment_submit_handler.dart`

Add after `is_passed = true`:
```dart
if (isPassed) {
  final cert = await CertificateService(supabase).generateCertificate(
    employeeId: auth.employeeId,
    trainingRecordId: attempt['training_record_id'],
    orgId: auth.orgId,
    courseId: attempt['course_id'],
    score: percentage,
  );
  // ...
}
```

### Step 3.2: Update report_generation_handler to Use ReportGeneratorService

**File:** `lifecycle_monitor/lib/routes/jobs/report_generation_handler.dart`

```dart
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

Future<Response> reportGenerationHandler(Request req) async {
  final supabase = RequestContext.supabase;
  final service = ReportGeneratorService(supabase);
  
  final processed = await service.processQueuedReports();
  
  return ApiResponse.ok({
    'job': 'report_generation',
    'reports_processed': processed,
  }).toResponse();
}
```

### Step 3.3: Add G15 Migration for Missing Tables

**Create:** `supabase/migrations/20260426_015_g15_missing_tables.sql`

```sql
-- password_reset_tokens table
CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_token 
    ON password_reset_tokens(token) WHERE used_at IS NULL;

-- system_alerts table
CREATE TABLE IF NOT EXISTS system_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    severity TEXT NOT NULL CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    alert_type TEXT NOT NULL,
    message TEXT NOT NULL,
    details JSONB,
    resolved_at TIMESTAMPTZ,
    resolved_by UUID REFERENCES employees(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    organization_id UUID REFERENCES organizations(id)
);
CREATE INDEX IF NOT EXISTS idx_system_alerts_severity 
    ON system_alerts(severity, resolved_at) WHERE resolved_at IS NULL;

-- background_jobs table
CREATE TABLE IF NOT EXISTS background_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'running' CHECK (status IN ('running', 'completed', 'failed')),
    records_processed INTEGER DEFAULT 0,
    error_message TEXT,
    execution_ms INTEGER,
    organization_id UUID REFERENCES organizations(id)
);
CREATE INDEX IF NOT EXISTS idx_background_jobs_name_started 
    ON background_jobs(job_name, started_at DESC);

-- approval_returns table
CREATE TABLE IF NOT EXISTS approval_returns (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    approval_step_id UUID NOT NULL REFERENCES approval_steps(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    returned_by UUID NOT NULL REFERENCES employees(id),
    return_reason TEXT NOT NULL,
    requested_corrections JSONB,
    organization_id UUID NOT NULL REFERENCES organizations(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_approval_returns_entity 
    ON approval_returns(entity_type, entity_id);
```

---

## Final Validation Checklist

### Code Quality
```bash
cd /Users/navadeepreddy/pharma_learn

# All servers must pass
dart analyze apps/api_server/pharma_learn/api
dart analyze apps/api_server/pharma_learn/lifecycle_monitor  
dart analyze apps/api_server/pharma_learn/workflow_engine

# Expected: 0 errors
```

### Endpoint Count
```bash
grep -rE "app\.(get|post|patch|put|delete)" apps/api_server/pharma_learn/api/lib/routes/ --include="routes.dart" | wc -l
# Expected: 380+ endpoints
```

### Implementation Summary

| Category | Before | After | Status |
|----------|--------|-------|--------|
| Table name fixes | 3 issues | 0 issues | ✅ |
| Assessment handlers | 1 | 6 | ✅ |
| Password reset | 0 | 2 endpoints | ✅ |
| Session QR | 0 | 1 endpoint | ✅ |
| Competency admin | 0 | 5 endpoints | ✅ |
| Obligations coordinator | 0 | 4 endpoints | ✅ |
| CertificateService | missing | created | ✅ |
| ReportGeneratorService | missing | created | ✅ |
| Return for corrections | missing | created | ✅ |
| Workflow engine | 4 handlers | 5 handlers | ✅ |

### 21 CFR Part 11 Compliance
- [ ] §11.10(a) — System validation: handlers have error handling
- [ ] §11.10(c) — Record protection: audit_trails immutable
- [ ] §11.10(e) — Audit trail: every write logs to audit_trails
- [ ] §11.50 — E-signatures: EsigService records all
- [ ] §11.70 — Signature linking: esignature_id on approvals

### URS Traceability
| URS | Requirement | Handler | Status |
|-----|-------------|---------|--------|
| §5.1.12 | Assessment timer | assessment_answer_handler | ✅ |
| §5.1.14 | Auto-grading | assessment_submit_handler | ✅ |
| §5.1.15 | Certificates | CertificateService | ✅ |
| §5.1.17 | Competencies | competency_admin_handler | ✅ |
| §5.1.21 | QR check-in | session_qr_handler | ✅ |
| §5.1.27 | Return for corrections | return_for_corrections_handler | ✅ |
| §5.1.30 | Coordinator dashboard | obligations_coordinator_handler | ✅ |
| §5.1.31 | Reports | ReportGeneratorService | ✅ |
| §5.2.5 | Password reset | password_reset_handler | ✅ |

---

**Document Status:** Updated based on actual implementation audit  
**Estimated Duration:** 1 week for remaining items  
**Priority Order:** Step 0 (bug fixes) → Step 1 (handlers) → Step 2 (services) → Step 3 (wiring)
