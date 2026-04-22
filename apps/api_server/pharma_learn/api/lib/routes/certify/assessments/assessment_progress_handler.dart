import 'package:relic/relic.dart';
import 'package:pharmalearn_shared/pharmalearn_shared.dart';

import '../../../utils/param_helpers.dart';

/// GET /v1/certify/assessments/:id/progress
///
/// Returns current progress for an in-progress assessment attempt.
/// Shows answered questions, time remaining, etc.
Future<Response> assessmentProgressHandler(Request req) async {
  final attemptId = parsePathUuid(req.rawPathParameters[#id]);
  final auth = RequestContext.auth;
  final supabase = RequestContext.supabase;

  // Get the assessment attempt
  final attempt = await supabase
      .from('assessment_attempts')
      .select('''
        id, status, started_at, submitted_at, time_limit_minutes,
        employee_id,
        question_paper_id,
        question_papers!inner(
          id, name, total_marks, passing_percentage,
          question_paper_items!inner(question_id)
        )
      ''')
      .eq('id', attemptId)
      .maybeSingle();

  if (attempt == null) {
    throw NotFoundException('Assessment attempt not found');
  }

  // Verify ownership - only the employee can see their own progress
  if (attempt['employee_id'] != auth.employeeId) {
    throw PermissionDeniedException('You can only view your own assessment progress');
  }

  // Get answered questions
  final answers = await supabase
      .from('assessment_answers')
      .select('question_id, answered_at')
      .eq('attempt_id', attemptId);

  final questionItems = attempt['question_papers']['question_paper_items'] as List;
  final totalQuestions = questionItems.length;
  final answeredQuestions = answers.length;

  // Calculate time remaining
  final startedAt = DateTime.parse(attempt['started_at'] as String);
  final timeLimitMinutes = attempt['time_limit_minutes'] as int?;
  
  int? timeRemainingSeconds;
  bool isExpired = false;
  
  if (timeLimitMinutes != null && timeLimitMinutes > 0) {
    final endTime = startedAt.add(Duration(minutes: timeLimitMinutes));
    final now = DateTime.now().toUtc();
    
    if (now.isAfter(endTime)) {
      isExpired = true;
      timeRemainingSeconds = 0;
    } else {
      timeRemainingSeconds = endTime.difference(now).inSeconds;
    }
  }

  // Get answered question IDs
  final answeredIds = answers.map((a) => a['question_id']).toSet();

  return ApiResponse.ok({
    'attempt_id': attemptId,
    'status': attempt['status'],
    'started_at': attempt['started_at'],
    'time_limit_minutes': timeLimitMinutes,
    'time_remaining_seconds': timeRemainingSeconds,
    'is_time_expired': isExpired,
    'total_questions': totalQuestions,
    'answered_questions': answeredQuestions,
    'unanswered_questions': totalQuestions - answeredQuestions,
    'completion_percentage': totalQuestions > 0 
        ? ((answeredQuestions / totalQuestions) * 100).round() 
        : 0,
    'answered_question_ids': answeredIds.toList(),
    'question_paper': {
      'id': attempt['question_papers']['id'],
      'name': attempt['question_papers']['name'],
      'total_marks': attempt['question_papers']['total_marks'],
      'passing_percentage': attempt['question_papers']['passing_percentage'],
    },
  }).toResponse();
}
