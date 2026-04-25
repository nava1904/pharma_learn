import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// POST /v1/train/self-learning/:obligationId/start
///
/// Starts a self-learning session for an obligation.
/// Creates a learning_progress record if not exists.
Future<Response> selfLearningStartHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#obligationId], fieldName: 'obligationId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Verify the obligation belongs to this employee
  final obligation = await supabase
      .from('employee_assignments')
      .select('''
        id, status, training_assignment_id,
        training_assignments!inner(id, course_id)
      ''')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  if (obligation['status'] == 'completed') {
    throw ConflictException('This obligation is already completed');
  }

  if (obligation['status'] == 'waived') {
    throw ConflictException('This obligation has been waived');
  }

  final courseId = obligation['training_assignments']['course_id'] as String;

  // Check for existing progress record
  var progress = await supabase
      .from('learning_progress')
      .select('*')
      .eq('employee_assignment_id', obligationId)
      .maybeSingle();

  final now = DateTime.now().toUtc().toIso8601String();

  if (progress == null) {
    // Create new progress record
    progress = await supabase.from('learning_progress').insert({
      'employee_assignment_id': obligationId,
      'employee_id': auth.employeeId,
      'course_id': courseId,
      'progress_percentage': 0,
      'started_at': now,
      'last_activity_at': now,
      'completion_method': 'self_learning',
    }).select().single();

    // Update obligation status to in_progress
    await supabase
        .from('employee_assignments')
        .update({'status': 'in_progress'})
        .eq('id', obligationId);
  } else {
    // Update last activity
    progress = await supabase.from('learning_progress').update({
      'last_activity_at': now,
    }).eq('id', progress['id']).select().single();
  }

  return ApiResponse.ok(progress).toResponse();
}

/// POST /v1/train/self-learning/:obligationId/progress
///
/// Updates the progress of a self-learning session.
///
/// Body:
/// ```json
/// {
///   "progress_percentage": 50,
///   "bookmark": "chapter-3",
///   "scorm_session_time": "PT30M"
/// }
/// ```
Future<Response> selfLearningProgressHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#obligationId], fieldName: 'obligationId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final progressPercentage = body['progress_percentage'] as int?;
  final bookmark = body['bookmark'] as String?;
  final scormSessionTime = body['scorm_session_time'] as String?;

  if (progressPercentage != null && (progressPercentage < 0 || progressPercentage > 100)) {
    throw ValidationException({'progress_percentage': 'Must be between 0 and 100'});
  }

  // Verify the obligation belongs to this employee
  final obligation = await supabase
      .from('employee_assignments')
      .select('id, status')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  if (obligation['status'] == 'completed') {
    throw ConflictException('Cannot update progress for completed obligation');
  }

  // Get existing progress
  final existingProgress = await supabase
      .from('learning_progress')
      .select('id')
      .eq('employee_assignment_id', obligationId)
      .maybeSingle();

  if (existingProgress == null) {
    throw ConflictException('Please start the learning session first');
  }

  // Update progress
  final updateData = <String, dynamic>{
    'last_activity_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (progressPercentage != null) updateData['progress_percentage'] = progressPercentage;
  if (bookmark != null) updateData['bookmark'] = bookmark;
  if (scormSessionTime != null) updateData['scorm_session_time'] = scormSessionTime;

  final progress = await supabase
      .from('learning_progress')
      .update(updateData)
      .eq('id', existingProgress['id'])
      .select()
      .single();

  return ApiResponse.ok(progress).toResponse();
}

/// POST /v1/train/self-learning/:obligationId/complete
///
/// Marks a self-learning session as complete.
/// If assessment is required, validates that assessment was passed.
///
/// Body (optional):
/// ```json
/// {
///   "esignature": {
///     "reauth_session_id": "uuid",
///     "meaning": "APPROVE"
///   }
/// }
/// ```
Future<Response> selfLearningCompleteHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#obligationId], fieldName: 'obligationId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  // Verify the obligation and get course info
  final obligation = await supabase
      .from('employee_assignments')
      .select('''
        id, status,
        training_assignments!inner(
          id, 
          courses!inner(id, assessment_required, passing_percentage)
        )
      ''')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  if (obligation['status'] == 'completed') {
    throw ConflictException('This obligation is already completed');
  }

  final course = obligation['training_assignments']['courses'] as Map<String, dynamic>;
  final assessmentRequired = course['assessment_required'] as bool? ?? false;
  final passingPercentage = course['passing_percentage'] as int? ?? 80;

  // If assessment required, verify it's passed
  if (assessmentRequired) {
    final passedAttempt = await supabase
        .from('assessment_attempts')
        .select('id, score, passed')
        .eq('employee_assignment_id', obligationId)
        .eq('passed', true)
        .maybeSingle();

    if (passedAttempt == null) {
      throw ValidationException({
        'assessment': 'Assessment required. Minimum score: $passingPercentage%',
      });
    }
  }

  // Update learning progress
  final now = DateTime.now().toUtc().toIso8601String();
  await supabase.from('learning_progress').update({
    'progress_percentage': 100,
    'completed_at': now,
    'last_activity_at': now,
  }).eq('employee_assignment_id', obligationId);

  // Update obligation to completed
  await supabase.from('employee_assignments').update({
    'status': 'completed',
    'completed_at': now,
  }).eq('id', obligationId);

  // Create e-signature if provided
  final esigData = body['esignature'] as Map<String, dynamic>?;
  String? esignatureId;
  if (esigData != null) {
    final reauthSessionId = esigData['reauth_session_id'] as String?;
    if (reauthSessionId != null) {
      final esig = await supabase.rpc(
        'create_esignature_from_reauth',
        params: {
          'p_reauth_session_id': reauthSessionId,
          'p_employee_id': auth.employeeId,
          'p_meaning': esigData['meaning'] ?? 'APPROVE',
          'p_context_type': 'self_learning_completion',
          'p_context_id': obligationId,
        },
      ) as Map<String, dynamic>;
      esignatureId = esig['esignature_id'] as String?;
    }
  }

  // Trigger certificate generation (via Edge Function)
  // This is called inline per design decision Q6
  try {
    await supabase.functions.invoke(
      'generate-certificate',
      body: {
        'employee_id': auth.employeeId,
        'employee_assignment_id': obligationId,
        'course_id': course['id'],
        'esignature_id': esignatureId,
      },
    );
  } catch (e) {
    // Log error but don't fail the completion
    // Certificate can be regenerated manually if needed
  }

  return ApiResponse.ok({
    'status': 'completed',
    'completed_at': now,
    'esignature_id': esignatureId,
  }).toResponse();
}

/// GET /v1/train/self-learning/:obligationId/status
///
/// Returns the current status of a self-learning obligation.
Future<Response> selfLearningStatusHandler(Request req) async {
  final obligationId = parsePathUuid(req.rawPathParameters[#obligationId], fieldName: 'obligationId');
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  final obligation = await supabase
      .from('employee_assignments')
      .select('''
        id, status, due_date, completed_at,
        training_assignments!inner(
          id, name,
          courses!inner(id, title, assessment_required, passing_percentage, duration_minutes)
        ),
        learning_progress(
          id, progress_percentage, started_at, last_activity_at, completed_at, bookmark
        )
      ''')
      .eq('id', obligationId)
      .eq('employee_id', auth.employeeId)
      .maybeSingle();

  if (obligation == null) {
    throw NotFoundException('Obligation not found');
  }

  final course = obligation['training_assignments']['courses'] as Map<String, dynamic>;
  final assessmentRequired = course['assessment_required'] as bool? ?? false;

  // Get assessment status if required
  Map<String, dynamic>? assessmentStatus;
  if (assessmentRequired) {
    final attempts = await supabase
        .from('assessment_attempts')
        .select('id, attempt_number, score, passed, started_at, submitted_at')
        .eq('employee_assignment_id', obligationId)
        .order('attempt_number', ascending: false);

    final passedAttempt = attempts.where((a) => a['passed'] == true).firstOrNull;
    
    assessmentStatus = {
      'required': true,
      'passing_percentage': course['passing_percentage'],
      'total_attempts': attempts.length,
      'passed': passedAttempt != null,
      'latest_attempt': attempts.isNotEmpty ? attempts.first : null,
    };
  }

  final progress = (obligation['learning_progress'] as List?)?.firstOrNull;

  return ApiResponse.ok({
    'obligation_id': obligationId,
    'status': obligation['status'],
    'due_date': obligation['due_date'],
    'course': {
      'id': course['id'],
      'title': course['title'],
      'duration_minutes': course['duration_minutes'],
    },
    'progress': progress != null
        ? {
            'percentage': progress['progress_percentage'],
            'started_at': progress['started_at'],
            'last_activity_at': progress['last_activity_at'],
            'completed_at': progress['completed_at'],
            'bookmark': progress['bookmark'],
          }
        : null,
    'assessment': assessmentStatus,
    'can_complete': (progress?['progress_percentage'] ?? 0) >= 100 &&
        (!assessmentRequired || (assessmentStatus?['passed'] ?? false)),
  }).toResponse();
}
