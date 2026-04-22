import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

/// POST /v1/certify/assessments/:id/answer
/// 
/// Records an answer for a single question during assessment.
/// Enforces timer with 30-second grace period.
Future<Response> assessmentAnswerHandler(Request req) async {
  final attemptId = req.rawPathParameters[#id]!;
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;
  final body = await readJson(req);

  final questionId = body['question_id'] as String?;
  if (questionId == null) {
    throw ValidationException({'question_id': 'Question ID is required'});
  }

  // Get attempt and verify ownership + timer
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, started_at, status, employee_id,
        question_paper:question_papers(time_limit_minutes)
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  if (attempt['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('Not your assessment');
  }

  if (attempt['status'] != 'in_progress') {
    throw ConflictException('Assessment is not in progress');
  }

  // Timer enforcement with 30s grace
  final startedAt = DateTime.parse(attempt['started_at']);
  final timeLimit = attempt['question_paper']['time_limit_minutes'] as int? ?? 60;
  final deadline = startedAt.add(Duration(minutes: timeLimit, seconds: 30));
  
  if (DateTime.now().toUtc().isAfter(deadline)) {
    // Auto-submit the assessment
    await supabase.from('assessment_attempts').update({
      'status': 'auto_submitted',
      'submitted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', attemptId);
    
    throw ConflictException('Assessment time expired - auto-submitted');
  }

  // Upsert response
  await supabase.from('assessment_responses').upsert({
    'attempt_id': attemptId,
    'question_id': questionId,
    'selected_option_ids': body['selected_option_ids'],
    'text_response': body['text_response'],
    'time_spent_seconds': body['time_spent_seconds'] ?? 0,
    'is_marked_for_review': body['is_marked_for_review'] ?? false,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }, onConflict: 'attempt_id,question_id');

  // Get progress count
  final answeredCount = await supabase
      .from('assessment_responses')
      .select('id')
      .eq('attempt_id', attemptId)
      .count();

  // Calculate remaining time
  final now = DateTime.now().toUtc();
  final remainingSeconds = deadline.difference(now).inSeconds - 30; // Exclude grace period

  return ApiResponse.ok({
    'saved': true,
    'question_id': questionId,
    'questions_answered': answeredCount.count,
    'remaining_seconds': remainingSeconds > 0 ? remainingSeconds : 0,
  }).toResponse();
}
